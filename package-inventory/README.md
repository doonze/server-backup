# Package Inventory Snapshots

## Baseline — 2026-10-04

Captured after installing Restic 0.14.0-1+b5. The full dpkg inventory contains
3,791 installed package records with package name, version, and architecture.
The TSV is split into nine files: eight chunks with 449 records each and a final
chunk with 199 records. Each chunk has a header row.

- `installed-packages-2026-10-04-part-00.tsv` through `part-08.tsv` — all
  installed packages.
- `manual-packages-2026-10-04.txt` — `apt-mark showmanual` snapshot.
- `held-packages-2026-10-04.txt` — `apt-mark showhold` snapshot.

This is an inventory, not a package installation script. On a rebuild, compare
versions and availability with the Debian stable release then in use. Refresh
the project snapshot after APT package changes; the future backup orchestrator
must generate a current inventory for every Restic run as well.