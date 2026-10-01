# Security Policy

[Deutsche Fassung](SECURITY.md)

This project is a work in progress. Do not include real credentials, VM names,
IP addresses, UUIDs, logs, or backup files in a public security report or issue.

Use a private contact method for the relevant GitLab or GitHub project first.
If no private reporting method is available, leave only a brief public request
for contact and withhold technical details.

## Do not commit secrets

- `config.env` or `.env`
- ESXi passwords, API session cookies, or private certificate keys
- Logs and cron output
- `vm_backup_selection.txt`
- Backup manifests, VM metadata, OVF, NVRAM, or VMDK files
- Screenshots containing inventory, network, or datastore details

## Before publishing

```bash
git status --short
git ls-files
rg -n -i -uu '(password|secret|token|cookie|private.key|authorization|bearer)' .
```

Review each match individually. Placeholders in tests and `config.example.env`
or `config.example.de.env` are allowed; real values are not. Before each
release, also run an established secret scanner against the full Git history.

## Security limitations

The software does not encrypt backups or sign manifests. Operators are
responsible for encrypted storage, access control, offline or immutable copies,
key management, log rotation, and regular restore tests.
