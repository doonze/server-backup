# Restore Runbook (Draft)

**Status:** Selected file, database, and VM-image restore tests passed on 2026-10-04; a full Debian rebuild and service recovery remain untested.

## Recovery objective

Reinstall the Debian stable release current at recovery time on the existing
Dell R710 RAID, then use Restic and the package/database inventories to restore
selected configuration, home data, application exports, and database content.
This is a file-level rebuild, not a bootable disk image.

## Before relying on this runbook

- Document RAID controller, array/virtual-disk layout, partitioning, boot mode,
  network addressing, DNS, and NAS/autofs setup.
- Keep a known-good Debian installer/recovery path and verify physical console
  access. Network boot is unverified and optional.
- Store the Restic password outside both the server and NAS; do not place it in
  Git. Without it, repository data is unrecoverable.
- Complete and test the Restic repository, DB exports, package inventory, and
  restore procedure first.

## Draft recovery sequence

1. Rebuild the RAID/virtual disk using documented controller settings; install
   the current Debian stable release and establish network access.
2. Install Code Puppy/required administration tooling and Restic from a trusted
   Debian repository; confirm the supported repository format.
3. Mount the NAS through the documented existing autofs arrangement. Verify it
   is the expected NFS export before accessing the Restic repository.
4. Retrieve the Restic password from the external password manager; never paste
   it into chat or store it in this Git project.
5. Inspect snapshots and restore first to a separate recovery directory for
   validation. Restore `/etc`, `/home`, `/root`, all `/opt`, and approved `/var`
   paths; never restore `/nfs` or `/smb`. Do not restore Emby/Plex metadata or
   raw live MariaDB files.
6. Reinstall recorded packages and vendor applications from supported sources;
   do not blindly overlay old `/lib` binaries onto a different Debian release.
7. Restore MariaDB schema/data according to `DATABASE_BACKUP_POLICY.md`, then
   import app-generated backups and selected Plex configuration.
8. Restore the VM image only after verifying its qcow2 backing chain and that
   the captured image is consistent; restore its VM definition before starting.
9. Reboot only after reviewing boot, network, permissions, and service state;
   verify access, databases, services, Minecraft, VM, and NAS mounts.

## Validation record (2026-10-04)

- Snapshot `29ab3833` passed `restic check` with no errors.
- A package inventory chunk and SQL dump files restored to temporary storage;
  both selected compressed dumps passed `gzip -t`.
- The `vmdashboard` dump was imported into a temporary schema (three base tables);
  `mariadb-check` passed, and the scratch schema was dropped afterward.
- The VM image restored to a temporary NAS path. `qemu-img info` showed qcow2,
  80 GiB virtual size, and no backing file; `qemu-img check` reported no errors.
  The temporary restore copy was removed. The guest was not booted.

## Not yet proven

- RAID recreation details and bootloader/UEFI recovery.
- Restic restore of ownership, ACLs, xattrs, and every selected system path.
- Restore/import consistency for all MariaDB databases and app-specific order.
- Guest OS boot, restored VM definition, and application-level VM health.
- NAS availability during a fresh install and password recovery.
- Downtime and total recovery duration.
