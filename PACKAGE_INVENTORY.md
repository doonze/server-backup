# Installed Package Inventory

The package inventory is a recovery artifact, separate from this context file.
It records all installed Debian packages with package name, version, and
architecture. It also records manually installed and held packages to make a
rebuild practical.

## Refresh policy

- Capture a baseline after every intentional package install, removal, or
  upgrade; the scheduled backup orchestrator should also generate a fresh
  machine-readable inventory for each Restic run.
- Do not rely only on `apt-mark showmanual`: the full installed package list is
  required. Keep manual and held lists as supplemental files.
- Keep output in chunks of at most 450 package records per file so no project
  inventory file becomes unwieldy.
- Record capture date and Debian release. Do not include secrets or repository
  credentials. `/etc/apt` is backed up separately after source files are reviewed.
- Keep one current project baseline; do not accumulate separately dated
  inventory exports. Restic's ordinary retained snapshots may still contain
  historical system states as part of the complete backup.

## Baseline status

The 2026-10-04 post-Restic-install baseline is captured in
`package-inventory/`: 3,791 installed package records plus manual and held
package lists. Future runs overwrite the stable runtime inventory at
`/var/backups/server-backup/staging/latest-package-inventory`; no new
run-specific package-inventory directories are created.
