# Server Backup

**Status:** Active — first snapshot and selected restore tests validated

Plan, implement, and validate file-level backups and a recovery path for
`mail.doonze.net`, the Dell PowerEdge R710 running Debian. The target recovery
method is to reinstall the then-current Debian stable release on the existing
RAID, install Restic, and restore selected files and service data.

## Current state

- Restic 0.14.0 is installed from Debian Bookworm.
- The encrypted repository `/nfs/backups/debianr710-restic` is initialized.
  First snapshot: `29ab3833` (2026-10-04); `restic check` found no errors.
- The first snapshot processed 171.946 GiB and stored 95.814 GiB after Restic
  deduplication and compression.
- Selected restores passed: package inventory and SQL dump files restored;
  `vmdashboard` imported into a temporary schema and passed `mariadb-check`;
  the restored qcow2 passed `qemu-img check`. A full host rebuild is not tested.
- The timer is enabled for daily 05:00 America/Chicago. Each run applies
  7-daily/4-weekly/12-monthly retention and prunes unreferenced data. Alerting
  is a TODO.
- The old Déjà Dup set `/nfs/backups/debianr710` was removed after restore
  validation. The historical LuckyBackup set remains untouched.
- Future runs publish package inventory at one stable latest-only path rather
  than a timestamped path per run.
- Planned UI: Backrest at `https://server.doonze.net/backrest`, behind Apache
  with password authentication scoped to that path; not installed yet.

## Project documents

- `PROJECT_CONTEXT.md` — systems, paths, conventions, and safeguards.
- `BACKUP_PLAN.md` — scope, design, and readiness gates.
- `DATABASE_BACKUP_POLICY.md` — schema/data rules per database.
- `RESTORE_RUNBOOK.md` — draft rebuild and restore procedure.
- `PACKAGE_INVENTORY.md` — package snapshot and upkeep rules.
- `DISCOVERY_NOTES.md` — dated observations and prior-backup findings.

No repository password, database dump, or backup payload belongs in this Git
project. See `.gitignore` and keep recovery secrets outside Git.