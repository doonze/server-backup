# Database Backup Policy

**Status:** Discovery required; no MariaDB dumps currently exist.

## Policy

- Create a schema dump for every MariaDB database.
- Include table data by default.
- Keep an explicit, reviewed exception list for schema-only databases.
- Known exception: `resource-monitor` data can be rebuilt; preserve its schema,
  omit its rows. Verify the actual database name during inventory.
- Do not copy `/var/lib/mysql` live as a substitute for a logical/consistent
  database backup.
- Include routines, events, and triggers where present; record database names,
  dump status, and restore procedure without recording credentials.
- The orchestrator must stop if a required dump fails and must not tell Restic to
  record a successful run with a missing or empty required dump.

## Pending inventory

For each database, record:

| Database | Schema | Data | Restore notes |
| --- | --- | --- | --- |
| resource-monitor | Yes | No | Rebuildable rows |
| Other databases | Yes | Yes by default | Review individually |

The current database list, application owners, sizes, and schema-only exceptions
are not yet established. Plex's library database backup is a separate app-level
artifact; confirm its path and whether MariaDB also contains Plex-related data.

## Orchestrator requirements

1. Use a supported MariaDB dump method with explicit consistency options.
2. Write dumps to a root-only local staging directory, not to `/nfs` or `/smb`.
3. Verify exit status and nonzero/expected output before Restic runs.
4. Include successful dumps in the same Restic snapshot as the package inventory.
5. Keep dumps encrypted in Restic; do not commit raw SQL files to Git.
6. Test restore into a non-production database before declaring readiness.
