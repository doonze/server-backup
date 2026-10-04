# Database Backup Policy

**Status:** Inventory captured; dumps, orchestration, and restore test are still pending.

## Policy

- Create a schema dump for every MariaDB database.
- Include table data by default.
- Keep an explicit, reviewed exception list for schema-only databases.
- Known exception: `resource_monitor` data can be rebuilt; preserve its schema,
  omit its rows.
- Do not copy `/var/lib/mysql` live as a substitute for a logical/consistent
  database backup.
- Include routines, events, and triggers where present; record database names,
  dump status, and restore procedure without recording credentials.
- The orchestrator must stop if a required dump fails and must not tell Restic to
  record a successful run with a missing or empty required dump.

## Discovered inventory (2026-10-04)

MariaDB is 10.11.18. The following application databases were discovered;
data is included by default except for `resource_monitor`.

| Database | Schema | Data |
| --- | --- | --- |
| djangohome | Yes | Yes |
| fileindex | Yes | Yes |
| guacamole | Yes | Yes |
| home_login | Yes | Yes |
| media_reencode | Yes | Yes |
| nextcloud | Yes | Yes |
| phpbb | Yes | Yes |
| phpmyadmin | Yes | Yes |
| postfixadmin | Yes | Yes |
| rainloop | Yes | Yes |
| resource_monitor | Yes | No |
| servermail | Yes | Yes |
| servmon | Yes | Yes |
| vmdashboard | Yes | Yes |

`information_schema`, `performance_schema`, and `sys` are MariaDB system
schemas, not application databases. Do not dump their generated contents. Do
not restore the internal `mysql` system tables across MariaDB versions; export
portable account/grant definitions separately with `mariadb-dump --system=users`.

Engine inventory found InnoDB application tables except MyISAM tables in
`postfixadmin` and `servmon`; `resource_monitor` also has MEMORY tables, whose
data is intentionally excluded. Use a transaction-consistent dump for InnoDB
schemas and a brief table read-lock for the two databases containing MyISAM
tables. This may briefly block writes to those databases and must be scheduled
accordingly. Recheck engines before each dump so newly added nontransactional
tables are not silently treated as InnoDB-only.

## Orchestrator requirements

1. Use a supported MariaDB dump method with explicit consistency options.
2. Write dumps to a root-only local staging directory, not to `/nfs` or `/smb`.
3. Verify exit status and nonzero/expected output before Restic runs.
4. Include successful dumps in the same Restic snapshot as the package inventory.
5. Keep dumps encrypted in Restic; do not commit raw SQL files to Git.
6. Test restore into a non-production database before declaring readiness.
