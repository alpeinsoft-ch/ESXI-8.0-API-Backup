# Safety-gated ESXi API Backup

[Deutsche Fassung](README.md)

> **Developed by:** Alpein Software Swiss AG<br>
> **Programmed by:** [Samuel Werner (Cyberwerner)](https://github.com/Cyberwerner4444)<br>
> **Assisted by:** AI<br>
> **Warning:** WIPCODING content

This repository contains a standalone Python backup and restore tool for
VMware ESXi. It exports virtual machines through the vSphere API, supports
powered-off and running VMs, verifies backup files with SHA-256, and can split
large VMDKs into locally deduplicated blocks.

**Compatibility:** Developed and tested with **VMware ESXi 8.0 Update 2**.
Newer ESXi versions have not yet been tested.

> **Work in progress — do not use in production without validation.** Test
> permissions, TLS certificates, storage requirements, snapshot behavior, and
> a complete restore in an isolated environment before deployment.

Detailed operating and restore instructions are available in both languages:

- [Betriebs- und Restore-Runbook auf Deutsch](RUNBOOK.md)
- [Operations and restore runbook in English](RUNBOOK.en.md)

## Safety model

The dedicated `backup_vm.py` entry point backs up only the VM configured in
`TARGET_VM_NAME`. A backup starts only after all of these checks pass:

- The operator confirms the exact VM name with `--confirm-vm`.
- The name, optional configured instance UUID, and expected VM geometry match.
- The VM is either `poweredOff` or `poweredOn`.
- No existing snapshot is found.
- The backup destination has enough free space.

The separate selection mode can back up multiple explicitly selected VMs.
Before each run, selection files are checked against the current ESXi
inventory using the MoRef, UUID, and VM name.

Additional safeguards:

- TLS certificate verification is enabled by default.
- NFC download URLs can send session cookies only to approved ESXi hosts.
- Restore will not overwrite an existing VM or datastore directory.
- Restored network adapters are disconnected by default.
- Delta manifests and filenames are checked for path manipulation.
- Configuration, logs, and newly created files use restrictive permissions.
- `.gitignore` excludes logs, backups, configuration, inventory lists, and
  bytecode from Git.

## Important limitations

- Backups and metadata are **not encrypted automatically**. Use encrypted,
  access-controlled storage for the backup destination.
- SHA-256 detects changes, but without an external signature it does not prove
  authenticity against an attacker who can write to the backup.
- Live backups are crash-consistent by default. Test quiescing for each VM and
  enable it deliberately.
- Local delta storage reduces space after export; it is not a VMware CBT-only
  transfer.
- Restore currently supports exactly one virtual disk. Backups with multiple
  VMDK descriptors are rejected rather than partially restored.
- A backup should not be considered reliable until a restore has been tested
  successfully.

## Requirements

- Python 3.10 or newer
- Access to the ESXi/vSphere API and datastore HTTP endpoints
- A dedicated account with only the permissions required
- A trusted certificate or a locally installed CA
- Sufficient protected backup storage

Install the dependencies:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## Configuration

```bash
cp config.example.env config.env
chmod 600 config.env
```

At minimum, configure these values:

```dotenv
ESXI_HOST=192.0.2.10
ESXI_USER=backup-api-user
ESXI_PASSWORD=CHANGE_ME
ESXI_SSL_VERIFY=true
TARGET_VM_NAME=ExampleVM
EXPECTED_CPU=2
EXPECTED_RAM_MB=4096
EXPECTED_DISK_COUNT=1
EXPECTED_DISK_SIZE_GB=25
BACKUP_OUTPUT_DIR=./backups
```

`192.0.2.10` is reserved for documentation and is not a real target. Never
commit a production password to Git. Alternatively, set `ESXI_PASSWORD` as an
environment variable for the process only.

If ESXi returns a trusted hostname in NFC lease URLs that differs from
`ESXI_HOST`, add it explicitly:

```dotenv
ESXI_NFC_ALLOWED_HOSTS=esxi.example.invalid
```

## Back up the configured VM

Inspect the inventory:

```bash
python3 backup_vm.py inventory
```

Run the preflight checks:

```bash
python3 backup_vm.py preflight
```

Start a backup. The value must exactly match `TARGET_VM_NAME`:

```bash
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode full
```

To use local delta storage:

```bash
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode delta
```

Verify a backup:

```bash
python3 backup_vm.py verify backups/ExampleVM/full_0001
```

## Back up explicitly selected VMs

Generate an inventory selection file:

```bash
./start_vm_liste.sh
```

The generated `vm_backup_selection.txt` contains infrastructure identities
and is intentionally excluded from Git. An [English example selection
file](vm_backup_selection.example.txt) is included in the repository. Enable
only the VM rows you want, then run a preflight without starting a backup:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt --list-only
```

When the preflight is clear, start interactively:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt
```

`--yes` skips the final confirmation and should be used only in controlled
automation.

## Restore

List available restore points:

```bash
./start_restore_vm_backup.sh --list-backups
```

Start with a dry run:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test \
  --dry-run
```

A real restore creates the VM powered off with its network adapter disconnected
by default. `--connect-network` and `--power-on` are separate, explicit
decisions.

## Automation

`run_weekly_vm_backup.sh` uses a lock file to prevent overlapping weekly runs.
Before adding it to cron, complete a successful manual run with the same
selection file. See the [operations and restore runbook](RUNBOOK.en.md).

## Project files

- `safe_esxi_backup.py` — ESXi connection, preflight, export, and verification
- `backup_vm.py` — safety-gated entry point for the configured target VM
- `select_vm_backup.py` — interactive or file-based VM selection
- `vm_backup_selection.py` — local selection file generator
- `restore_vm_backup.py` — conservative restore under a new VM name
- `delta_storage.py` — local block deduplication and materialization
- `tests/test_safety.py` — safety and regression tests
- `SECURITY_REVIEW.en.md` — publication and file audit

## Tests

```bash
python -m unittest discover -s tests -v
```

Tests do not replace an ESXi integration test. Export, snapshot cleanup, and
restore also need validation against a non-production ESXi environment.

## License

This project is licensed under the [MIT License](LICENSE). An unofficial
German translation for reference is available in [LICENSE.de.md](LICENSE.de.md).
