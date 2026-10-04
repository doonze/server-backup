#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
PATH=/usr/sbin:/usr/bin:/sbin:/bin

PROJECT_DIR=/home/justin/puppy_workspace/projects/active/server-backup
SOURCES_FILE="$PROJECT_DIR/config/backup-sources.txt"
EXCLUDES_FILE="$PROJECT_DIR/config/restic-excludes.txt"
REPOSITORY=/nfs/backups/debianr710-restic
NAS_MOUNT=/nfs/backups
EXPECTED_NFS_SOURCE=192.168.0.116:/volume1/nfs/backups
STAGING_ROOT=/var/backups/server-backup/staging
RESTIC_CACHE_DIR=/var/cache/restic/server-backup
PASSWORD_FILE=/etc/restic/server-backup-password
VM_NAME=win10
VM_IMAGE=/var/lib/libvirt/images/win10.qcow2
PLEX_DB_DIR='/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases'
RUN_DIR=

log() { printf '[server-backup] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die 'must run as root'
[[ -n "${CREDENTIALS_DIRECTORY:-}" ]] && PASSWORD_FILE="$CREDENTIALS_DIRECTORY/restic-password"
[[ -s "$PASSWORD_FILE" ]] || die "Restic password file is missing: $PASSWORD_FILE"
[[ $(stat -c %u "$PASSWORD_FILE") == 0 ]] || die 'Restic password file must be root-owned'
password_mode=$(stat -c %a "$PASSWORD_FILE")
[[ $password_mode == 400 || $password_mode == 600 ]] || die 'Restic password file must have mode 0400 or 0600'
[[ -r "$SOURCES_FILE" && -r "$EXCLUDES_FILE" ]] || die 'source or exclusion configuration is unreadable'

exec 9>/run/lock/server-backup.lock
flock -n 9 || die 'another backup run is already in progress'

check_nas() {
    [[ -d "$NAS_MOUNT" ]] || die "NAS mount path is missing: $NAS_MOUNT"
    timeout 30 stat -- "$NAS_MOUNT" >/dev/null || die 'NAS autofs mount did not respond'
    local mount_info fstype source
    mount_info=$(findmnt -n -T "$NAS_MOUNT" -o FSTYPE,SOURCE) || die 'cannot identify NAS mount'
    read -r fstype source <<< "$mount_info"
    [[ $fstype == nfs || $fstype == nfs4 ]] || die "refusing non-NFS target at $NAS_MOUNT (found $fstype $source)"
    [[ $source == "$EXPECTED_NFS_SOURCE" ]] || die "unexpected NFS export at $NAS_MOUNT (found $source)"
    [[ $REPOSITORY == "$NAS_MOUNT"/* ]] || die 'repository is outside the verified NAS mount'
    [[ ! -L "$REPOSITORY" ]] || die 'repository path must not be a symlink'
    local probe
    probe=$(mktemp "$NAS_MOUNT/.server-backup-write-test.XXXXXX") || die 'NAS is not writable'
    rm -f -- "$probe" || die 'could not remove NAS write-test file'
    log "verified writable NFS mount ($source)"
}

check_nas
install -d -o root -g root -m 0700 "$RESTIC_CACHE_DIR"
export RESTIC_REPOSITORY="$REPOSITORY"
export RESTIC_PASSWORD_FILE="$PASSWORD_FILE"
export RESTIC_CACHE_DIR

case "${1:-backup}" in
    --init)
        [[ ! -e "$REPOSITORY/config" ]] || die 'repository already has a Restic config; refusing to initialize over it'
        restic init --repository-version 2
        exit 0
        ;;
    backup)
        ;;
    *)
        die 'usage: server-backup.sh [backup|--init]'
        ;;
esac

[[ -f "$REPOSITORY/config" ]] || die 'Restic repository is not initialized; run with --init after recording the password off-server'
restic snapshots >/dev/null || die 'Restic repository authentication/check failed'

vm_state=$(virsh domstate "$VM_NAME" 2>/dev/null) || die "cannot query VM $VM_NAME state"
[[ $vm_state == 'shut off' ]] || die "VM $VM_NAME is '$vm_state'; refusing a potentially inconsistent qcow2 backup"
for path in /var /var/lib /var/lib/libvirt /var/lib/libvirt/images "$VM_IMAGE"; do
    [[ ! -L "$path" ]] || die "VM path component is a symlink: $path"
done
[[ -f "$VM_IMAGE" ]] || die "VM image is missing: $VM_IMAGE"
vm_info=$(qemu-img info --output=json "$VM_IMAGE") || die 'cannot inspect VM image metadata'
printf '%s' "$vm_info" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("format")=="qcow2" and not d.get("backing-filename") and not d.get("format-specific",{}).get("data",{}).get("corrupt",False) else 1)' || die 'VM image format/backing chain/corruption state changed; review before backup'

install -d -o root -g root -m 0700 "$STAGING_ROOT"
run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
RUN_DIR="$STAGING_ROOT/run-$run_id"
install -d -o root -g root -m 0700 "$RUN_DIR" "$RUN_DIR/mariadb" "$RUN_DIR/app-backups/plex"

cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$RUN_DIR" && -d "$RUN_DIR" ]]; then
        if (( status == 0 )); then
            case "$RUN_DIR" in
                "$STAGING_ROOT"/run-*) rm -rf -- "$RUN_DIR" ;;
                *) log "WARNING: unexpected staging path retained: $RUN_DIR" ;;
            esac
        else
            log "backup failed; restricted staging retained for diagnosis: $RUN_DIR"
        fi
    fi
    exit "$status"
}
trap cleanup EXIT

# Generate a complete installed-package inventory plus supplemental APT state.
raw_packages="$RUN_DIR/packages.raw.tsv"
dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\t${Architecture}\n' \
    | awk -F '\t' '$1 ~ /^ii/ {print $2 "\t" $3 "\t" $4}' \
    | LC_ALL=C sort > "$raw_packages"
package_count=$(wc -l < "$raw_packages")
(( package_count > 0 )) || die 'installed package inventory is empty'
split -l 449 -d -a 2 "$raw_packages" "$RUN_DIR/package-part-"
for chunk in "$RUN_DIR"/package-part-*; do
    [[ -f "$chunk" ]] || continue
    suffix=${chunk##*-}
    output="$RUN_DIR/installed-packages-part-${suffix}.tsv"
    { printf 'Package\tVersion\tArchitecture\n'; cat "$chunk"; } > "$output"
    rm -f -- "$chunk"
done
rm -f -- "$raw_packages"
{ printf '# Manual APT packages\n'; apt-mark showmanual | LC_ALL=C sort; } > "$RUN_DIR/manual-packages.txt"
{ printf '# Held APT packages\n'; apt-mark showhold | LC_ALL=C sort; } > "$RUN_DIR/held-packages.txt"
log "generated package inventory: $package_count installed packages"

# Dump every non-system application schema/data by default. resource_monitor is
# schema-only. Non-InnoDB data uses table read-locks for consistency.
mariadb --batch --skip-column-names --execute='SHOW DATABASES' > "$RUN_DIR/mariadb/database-list.txt"
app_db_count=0
resource_monitor_seen=0
while IFS= read -r database; do
    case "$database" in
        information_schema|performance_schema|sys|mysql) continue ;;
    esac
    [[ $database =~ ^[A-Za-z0-9_]+$ ]] || die "unexpected database name; review before dump: $database"
    ((app_db_count += 1))
    destination="$RUN_DIR/mariadb/${database}.sql.gz"
    if [[ $database == resource_monitor ]]; then
        resource_monitor_seen=1
        mariadb-dump --no-data --routines --events --triggers --databases "$database" | gzip -1 > "$destination"
    else
        non_innodb=$(mariadb --batch --skip-column-names --database="$database" \
            --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' AND engine IS NOT NULL AND engine <> 'InnoDB'")
        [[ $non_innodb =~ ^[0-9]+$ ]] || die "could not determine storage engines for $database"
        if (( non_innodb > 0 )); then
            log "$database has non-InnoDB tables; using a table read-lock during its dump"
            mariadb-dump --quick --lock-tables --routines --events --triggers --databases "$database" | gzip -1 > "$destination"
        else
            mariadb-dump --quick --single-transaction --routines --events --triggers --databases "$database" | gzip -1 > "$destination"
        fi
    fi
    gzip -t "$destination" || die "compressed dump failed validation: $database"
    [[ -s "$destination" ]] || die "empty database dump: $database"
    log "dumped database schema/data policy for $database"
done < "$RUN_DIR/mariadb/database-list.txt"
(( app_db_count > 0 )) || die 'no application databases were discovered'
(( resource_monitor_seen == 1 )) || die 'expected schema-only database resource_monitor was not found'
mariadb-dump --system=users | gzip -1 > "$RUN_DIR/mariadb/system-users.sql.gz"
gzip -t "$RUN_DIR/mariadb/system-users.sql.gz" || die 'portable MariaDB account dump failed validation'
[[ -s "$RUN_DIR/mariadb/system-users.sql.gz" ]] || die 'portable MariaDB account dump is empty'
log "dumped $app_db_count application databases and portable MariaDB user/grant definitions"

# Stage only the latest dated Plex database backups; never copy its live DB/WAL
# or the large metadata tree. find does not follow symlinks.
copy_latest_plex_backup() {
    local prefix="$1" latest source destination before after
    latest=$(find "$PLEX_DB_DIR" -maxdepth 1 -type f -name "${prefix}-20??-??-??" -printf '%f\n' | LC_ALL=C sort | tail -n 1)
    [[ -n "$latest" ]] || die "no dated Plex backup found for $prefix"
    source="$PLEX_DB_DIR/$latest"
    [[ ! -L "$source" && -s "$source" ]] || die "Plex backup is missing, empty, or a symlink: $source"
    before=$(stat -c '%s:%Y' "$source")
    destination="$RUN_DIR/app-backups/plex/$latest"
    cp --preserve=mode,timestamps -- "$source" "$destination"
    after=$(stat -c '%s:%Y' "$source")
    [[ $before == "$after" && $(stat -c %s "$destination") == "${before%%:*}" ]] || die "Plex backup changed during staging: $source"
    log "staged Plex backup $latest"
}
copy_latest_plex_backup com.plexapp.plugins.library.db
copy_latest_plex_backup com.plexapp.plugins.library.blobs.db

mapfile -t sources < <(grep -v -E '^[[:space:]]*(#|$)' "$SOURCES_FILE")
((${#sources[@]} > 0)) || die 'backup source list is empty'
for source in "${sources[@]}"; do
    [[ -e "$source" && ! -L "$source" ]] || die "source is missing or a symlink: $source"
done
log 'starting Restic backup with explicit sources, exclusions, and one-filesystem boundary'
restic --compression auto backup --one-file-system --exclude-file "$EXCLUDES_FILE" \
    --tag server-backup --tag mail.doonze.net "${sources[@]}"
restic snapshots >/dev/null || die 'Restic snapshot verification failed'
log 'Restic backup completed and repository authentication verified'
