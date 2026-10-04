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
- Keep the newest dated inventory in this project; older snapshots may be
  retained when useful for change history.

## Baseline status

The 2026-10-04 post-Restic-install baseline is captured in
`package-inventory/`: 3,791 installed package records plus manual and held
package lists. The runtime inventory staging path for the future orchestrator
is still TBD.
