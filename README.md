# Server Backup

**Status:** Active — design and implementation

Plan, implement, and validate file-level backups and a recovery path for
`mail.doonze.net`, the Dell PowerEdge R710 running Debian. The target recovery
method is to reinstall the then-current Debian stable release on the existing
RAID, install Restic, and restore selected files and service data.

## Current state

- Restic 0.14.0 is installed from Debian Bookworm.
- The proposed encrypted repository is
  `/nfs/backups/debianr710-restic`; it is not initialized.
- Restic source/exclusion files and backup script are prepared; systemd units are installed but disabled.
- MariaDB and VM inventory are recorded. Repository initialization, secret escrow, MyISAM-lock approval, first backup, and restore checks remain pending.
- The old Déjà Dup and LuckyBackup backups are retained until a Restic restore
  has been verified.

## Project documents

- `PROJECT_CONTEXT.md` — systems, paths, conventions, and safeguards.
- `BACKUP_PLAN.md` — scope, design, and readiness gates.
- `DATABASE_BACKUP_POLICY.md` — schema/data rules per database.
- `RESTORE_RUNBOOK.md` — draft rebuild and restore procedure.
- `PACKAGE_INVENTORY.md` — package snapshot and upkeep rules.
- `DISCOVERY_NOTES.md` — dated observations and prior-backup findings.

No repository password, database dump, or backup payload belongs in this Git
project. See `.gitignore` and keep recovery secrets outside Git.