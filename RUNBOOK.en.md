# Operations and Restore Runbook

[Deutsche Fassung](RUNBOOK.md)

This runbook describes a conservative operating procedure. Run commands that
modify systems only after a successful preflight and in an approved
environment.

**Compatibility:** VMware ESXi 8.0 Update 2. Newer ESXi versions have not yet
been tested and must be validated separately before use.

## 1. Initial setup

```bash
cd /path/to/esxi-backup
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp config.example.env config.env
chmod 600 config.env
```

Configure a dedicated ESXi account, TLS verification, the target VM, and backup
storage in `config.env`. Avoid using a root account when an account with fewer
permissions will work.

Before each production run, check:

```bash
stat -c '%a %n' config.env
df -h "$(pwd)"
python3 backup_vm.py inventory
python3 backup_vm.py preflight
```

On POSIX systems, the configuration file must have permissions `600`.

## 2. Certificates

`ESXI_SSL_VERIFY=true` is the secure default. The ESXi certificate chain must
be available in the system or Python trust store.

`ESXI_SSL_VERIFY=false` is intended only for a time-limited test on an isolated
network. The corresponding warning must not appear during normal operation.

## 3. Back up the configured VM

```bash
python3 backup_vm.py preflight
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode full
```

Replace `ExampleVM` with the exact value of `TARGET_VM_NAME`.

After the run, verify the backup:

```bash
python3 backup_vm.py verify backups/ExampleVM/full_0001
```

Investigate any non-zero exit code, failed SHA-256 check, or remaining
`.inprogress` or `.failed` directory.

## 4. Back up selected VMs

Generate a local inventory selection file:

```bash
./start_vm_liste.sh
chmod 600 vm_backup_selection.txt
```

Enable only the desired VM rows. Then run:

```bash
./start_select_vm_backup.sh \
  --selection-file vm_backup_selection.txt \
  --list-only
```

Start the backup only after all fatal checks pass:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt
```

Regenerate the file after inventory changes. Do not blindly edit UUID or MoRef
mismatches; first confirm that the entry still refers to the intended VM.

## 5. Delta storage

The first backup of a VM is a full backup. Later backups can split large VMDK
extents into local SHA-256-addressed blocks.

Keep `backup_manifest.json`, `delta_manifest.json`, the full base, and
`.delta_store` together. Never delete individual chunk files manually. Keep
all manifests readable before cleanup. Delta storage reduces local disk use,
but does not necessarily reduce data transferred from ESXi.

Automatic cleanup stops if a manifest is damaged, unreadable, or outside the
permitted path tree.

## 6. Restore test

List restore points:

```bash
./start_restore_vm_backup.sh --list-backups
```

Run a dry run first:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test \
  --dry-run
```

For an isolated restore, omit `--dry-run`:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test
```

By default, the restored VM remains powered off and its network adapter stays
disconnected. The current restore supports exactly one virtual disk; a backup
with multiple disks is blocked before any write operation.

Manually verify that:

- The VM geometry and datastore destination are correct.
- The VMDK opens and the guest file system is consistent.
- The original and restored VMs do not have MAC or IP address conflicts.
- Temporary upload files and snapshots have been removed.
- The application starts successfully on an isolated network.

## 7. Weekly run

Run this manually before scheduling it:

```bash
./run_weekly_vm_backup.sh
```

Example cron entry for Sunday at 02:00:

```cron
0 2 * * 0 /path/to/esxi-backup/run_weekly_vm_backup.sh
```

Cron output and application logs can contain infrastructure details. Keep them
local with permissions `600`; do not copy them into tickets or Git.

## 8. Troubleshooting

After an interrupted live backup, first check:

1. Is a temporary snapshot still present on ESXi?
2. Is a `CopyVirtualDisk` task still running?
3. Is there a temporary `esxi_api_backup_tmp` directory on the datastore?
4. Does the `.failed` manifest report cleanup errors?

Do not manually delete temporary files while an ESXi copy task is running.
Resolve unclear states by checking the ESXi task history first.

## 9. Regular checks

- Daily: last run, exit code, free space, and remaining snapshots.
- Weekly: verify the hashes of a recent restore point.
- Monthly: perform an isolated restore test.
- After updates: run unit tests, preflight, a full backup, and a restore test.
- Regularly: rotate logs and keep them protected.
- Regularly: check that an offline or immutable copy is available for
  ransomware recovery.
