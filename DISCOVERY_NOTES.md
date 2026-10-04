# Discovery Notes

## 2026-10-04 — Initial backup review

### Host and tools

- Host: `mail.doonze.net`, Dell PowerEdge R710, Debian 12.15 Bookworm amd64.
- Hardware: eight-disk RAID; exact RAID/controller/partition details not recorded.
- Restic 0.14.0-1+b5 installed from Debian Bookworm. The install added only
  Restic; no packages were upgraded or removed.
- Restic compression `auto` is available with repository format 2. Restic
  encryption is mandatory; repository/password handling remains to be completed.
- NAS repository path approved: `/nfs/backups/debianr710-restic`; not initialized.
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
- Existing Duplicity data is retained until Restic restore verification.

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
- Foundry in a home directory uses about 20% of space; home directories remain
  in scope. One ~44 GB qcow2 VM image is a candidate for backup; confirm exact
  path/backing chain and safe snapshot/offline capture before scanning it.
- Omit `/lib` from file restoration; use package inventory/reinstallation.
- Hard-exclude `/nfs` and `/smb`; never traverse symlink targets. Restic should
  store symlinks as links only.
- App-generated backups exist for Emby, Sonarr, Radarr, Lidarr, SABnzbd, and the
  Plex database; exact paths still need verification.
- Minecraft lives under `/home/justin/Minecraft/running`; update-time recovery
  copies live in `/home/justin/Minecraft/backup`. Include both. A live-world
  snapshot is accepted as best-effort without pausing the server.
- MariaDB: no current logical dumps. Dump schema for all databases; include data
  by default, with `resource-monitor` known schema-only. Full DB inventory pending.
- Recovery target: reinstall then-current Debian stable on the existing RAID,
  install Restic, and restore files. No disk-image/PXE requirement now.

### VM image note

A qcow2 file is a virtual disk image, not an ordinary static document. Restic
can store it as a file and deduplicate changed chunks across snapshots, but it
does not coordinate with QEMU or guarantee a consistent guest filesystem while
the VM is writing. Capture it with the VM shut down or from a verified
QEMU/libvirt snapshot; confirm all backing-chain files and the VM definition.
The exact image path, allocated size, backing chain, and VM state remain unknown.
