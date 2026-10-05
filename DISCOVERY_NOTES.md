# Discovery Notes

## 2026-10-04 — Initial backup review

### Host and tools

- Host: `mail.doonze.net`, Dell PowerEdge R710, Debian 12.15 Bookworm amd64.
- Hardware: eight-disk RAID; exact RAID/controller/partition details not recorded.
- Restic 0.14.0-1+b5 installed from Debian Bookworm. The install added only
  Restic; no packages were upgraded or removed.
- Restic compression `auto` is available with repository format 2. Restic
  encryption is mandatory. The password is stored root-only on the server and
  Justin confirms it is saved in his external password manager; no secret is
  recorded here.
- NAS repository path: `/nfs/backups/debianr710-restic`; initialized on
  2026-10-04, first snapshot `29ab3833`.
- `/nfs/backups` is an autofs-backed NFS mount. NAS had about 4.8 TB free on the
  last check; recheck before the initial backup. Never traverse `/nfs` or `/smb`.

### Déjà Dup / Duplicity

- Root's Déjà Dup profile includes `$HOME`, `/home`, `/etc`, `/opt`, `/var`;
  it is set daily and targets `/nfs/backups/debianr710`.
- Root profile excludes temporary/cache paths, `/nfs`, full Emby/Plex data trees,
  selected `*arr` cover-art paths, and several application paths. See current
  host settings for exact exclusions; do not copy them blindly.
- Déjà Dup's `last-backup` was 2026-05-07; its `last-run` was 2026-10-04. The
  latest visible Duplicity archive ended 2026-05-07. An October status log scan
  did not prove a new backup completed. Déjà Dup was stopped/disabled by Justin.
- At discovery, existing Duplicity data was retained pending Restic restore
  verification. After selected restore tests passed on 2026-10-04, Justin asked
  to remove `/nfs/backups/debianr710`; that set was subsequently deleted.

### LuckyBackup

- A saved root LuckyBackup profile targets `/nfs/backups/R710_server_backup/`
  from `/`, last recorded in April 2022 with rsync warnings. It uses deletion
  propagation and excludes `/nfs`, selected Plex/Emby state, and other paths.
- Treat this as historical only. Do not run or delete it before Restic is tested.

### Scope confirmed by Justin

- Include all home directories and `/etc`.
- Storage-scope correction from Justin: `/var` uses about 63% of server space,
  mostly Emby/Plex; `/opt` is not a major space consumer. Include all `/opt` and
  most of `/var`, excluding Emby/Plex data/metadata and volatile paths.
- Home directories remain in scope; Foundry is reported at about 20% of server
  space. The `win10` VM is currently shut off. Its qcow2 image is
  `/var/lib/libvirt/images/win10.qcow2`: 80 GiB virtual size, about 42 GiB
  allocated (44.2 GB reported by `qemu-img`), no backing file reported, and no
  symlink in its path components. Capture only while the VM is shut down.
- Omit `/lib` from file restoration; use package inventory/reinstallation.
- Exclude `/nfs` and `/smb` as Restic sources and never follow symlinks into
  those paths. Targeted NAS inspection/administration is allowed when Justin
  requests it. Restic should store symlinks as links only.
- Emby's MBBackup plugin config points to `/nfs/backups/apps/emby` with
  retention 5. This is already on the NAS and must not be traversed as a source.
- Sonarr backups are in `/var/lib/sonarr/Backups` (44.3 MB observed, including
  current v4 manual/scheduled exports); they are covered by `/var`.
- Plex dated database copies are in
  `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases`.
  The latest observed library and blobs backups are dated 2026-10-04. Stage only
  the latest dated copies; exclude the rest of the Plex tree.
- Radarr, Lidarr, and SABnzbd backup exports are under the broad `/home`, `/opt`,
  or `/var` sources unless they are on an excluded NAS path; exact paths remain
  to confirm.
- Minecraft lives under `/home/justin/Minecraft/running`; update-time recovery
  copies live in `/home/justin/Minecraft/backup`. Include both. A live-world
  snapshot is accepted as best-effort without pausing the server.
- MariaDB 10.11.18 inventory found 14 application databases. Include schema and
  data by default; `resource_monitor` is schema-only. Exclude generated system
  schemas and export portable account/grant definitions separately. `postfixadmin`
  and `servmon` contain MyISAM tables and need brief read locks for consistent
  dumps; see `DATABASE_BACKUP_POLICY.md`.
- Recovery target: reinstall then-current Debian stable on the existing RAID,
  install Restic, and restore files. No disk-image/PXE requirement now.

### VM image note

A qcow2 file is a virtual disk image, not an ordinary static document. Restic
can store it as a file and deduplicate changed chunks across snapshots, but it
does not coordinate with QEMU. The `win10` VM was shut off during inspection;
its image is `/var/lib/libvirt/images/win10.qcow2`, with 80 GiB virtual size and
about 42 GiB allocated. `qemu-img info` reported no backing file and no
corruption. The file is not a symlink. The scheduled backup must fail closed if
`win10` is running, so it never captures a changing disk. The VM's CD-ROM points
to `/home/justin/Downloads/virtio-win-0.1.271.iso`, which is covered by `/home`.

## 2026-10-04 — First snapshot and selected restore checks

- First snapshot `29ab3833`: 713,313 files, 171.946 GiB processed; Restic
  reported 128.493 GiB added to the repository and 95.814 GiB stored after
  compression. `restic check` reported no errors.
- A package inventory chunk and full/schema-only SQL dumps restored; the dump
  archives passed `gzip -t`. A `vmdashboard` restore into a temporary schema
  produced three base tables and passed `mariadb-check`; the scratch schema was
  dropped.
- The restored `win10.qcow2` passed `qemu-img check` (80 GiB virtual capacity,
  about 44.2 GB allocated); its temporary NAS restore copy was removed.
- Removed `/nfs/backups/debianr710` after these checks at Justin's request.
  The separate `/nfs/backups/R710_server_backup` LuckyBackup set remains.
- Future package inventories use one stable latest-only runtime path;
  Restic's ordinary backup snapshots still retain point-in-time state.
- Planned UI endpoint: `https://server.doonze.net/backrest`, with Apache auth
  scoped only to `/backrest`; Backrest scheduling is not intended.
