# Security and Publication Review

Review date: 2026-10-01

[Deutsche Fassung](SECURITY_REVIEW.md)

## Result

The public project tree contains no known real credentials, hostnames, VM
names, UUIDs, datastore paths, production logs, or backup data. Example values
use neutral names, null or test UUIDs, and the documentation-only IPv4 range
`192.0.2.0/24`.

This review is a snapshot. Before each push, scan both the working tree and the
complete Git history again.

## System overview

The development and test environment is VMware ESXi 8.0 Update 2. Behavior on
newer ESXi versions has not been validated.

The backup process has four layers:

1. `safe_esxi_backup.py` connects to ESXi, collects inventory data, enforces
   preflight rules, and exports the VM.
2. Powered-off VMs use `ExportVm`. For running VMs, the program creates a
   temporary snapshot; if `ExportSnapshot` is unsupported, it falls back to a
   datastore-side `CopyVirtualDisk` operation.
3. `delta_storage.py` can split exported VMDK extents into local,
   SHA-256-addressed blocks and materialize them again for restore.
4. `restore_vm_backup.py` verifies backup files and metadata, uploads exactly
   one virtual disk, and creates a new VM that is powered off initially.

Safeguards include explicit target confirmation, identity checks, snapshot and
temporary-file cleanup, hash verification, disconnected restore networks by
default, and refusal to overwrite existing targets.

## Security issues addressed

| Severity | Issue | Mitigation |
|---|---|---|
| High | Real inventory, UUID, path, and log data was present in the project tree. | Removed it from the public tree and added ignore rules. |
| High | A manipulated NFC lease host could have received the ESXi session cookie. | Check HTTPS and an allowed-host list before each lease download. |
| High | Delta garbage collection could delete needed blocks when manifests were damaged. | Fail closed on unreadable or unsafe manifests and restrict paths. |
| High | Restore could have processed only part of a multi-disk backup. | Block multi-disk backups before any write operation. |
| Medium | TLS verification was disabled by default. | Set the secure default to `true`, support CA trust, and warn when disabled. |
| Medium | Unknown datastore browser errors were treated as “directory missing.” | Block restore when an error is unknown. |
| Medium | OVF files were parsed with a general-purpose XML parser. | Use `defusedxml` and enforce a size limit. |
| Medium | Restore trusted metadata and OVF files without hashes. | Store and verify size and SHA-256 values in new manifests. |
| Medium | Configuration and runtime files could have overly broad permissions. | Check for POSIX mode `600` and set process umask to `077`. |
| Medium | Dependencies were outdated. | Update to exact pinned versions and audit dependencies. |
| Low | Absolute internal configuration and backup paths were hard-coded. | Use discoverable or relative configuration and neutral examples. |

## Remaining risks

- The program does not encrypt backup data.
- Without an externally signed manifest, SHA-256 does not protect against an
  attacker who can modify both backup files and manifests.
- Live backups are only crash-consistent unless quiescing has been tested.
- Restore currently supports exactly one virtual disk.
- ESXi roles and minimum required permissions must be tested and documented
  for the actual platform.
- Unit tests do not replace an export and restore integration test on ESXi.
- Installing packages from the public index requires trusting PyPI, DNS/TLS,
  and the pinned packages.

## Review of public files

| File | Review result |
|---|---|
| `.gitlab-ci.yml` | Runs only unit tests, SAST, and secret detection; no build, review, or deployment stages. |
| `.gitignore` | Excludes secrets, logs, backups, inventory lists, bytecode, virtual environments, and runtime data. |
| `LICENSE` / `LICENSE.de.md` | Standard MIT License and an unofficial German reading translation; copyright holder is Alpein Software Swiss AG. |
| `README.md` / `README.en.md` | German primary guide and English translation; WIP warning, requested credits at the top, and no internal operational data. |
| `RUNBOOK.md` / `RUNBOOK.en.md` | German and English operating guides with placeholder paths, neutral VM names, and a safe operating sequence. |
| `SECURITY.md` / `SECURITY.en.md` | Publication and reporting guidance without internal contact or infrastructure details. |
| `SECURITY_REVIEW.md` / `SECURITY_REVIEW.en.md` | Audit, fixes, and remaining risks documented without real target system data. |
| `backup_vm.py` | Neutral entry point; no secrets or hard-coded customer name. |
| `config.example.env` / `config.example.de.env` | Documentation IP and placeholders only; TLS enabled by default and no real password. |
| `delta_storage.py` | Path and digest checks, fail-closed cleanup, and no infrastructure values. |
| `inventory_discovery.py` | Neutral wrapper; inventory output stays local and is not included. |
| `requirements.txt` | Exact pins for public package versions only. |
| `restore_vm_backup.py` | Fail-closed target checks, safe XML parsing, hash verification, and single-disk restriction. |
| `run_once_vm_backup_test.sh` | No internal paths; uses `mktemp` and restrictive umask. |
| `run_weekly_vm_backup.sh` | Local logs, lock, and inventory list are ignored; restrictive umask and process lock. |
| `safe_esxi_backup.py` | Configurable target; hardened TLS, lease host, file permissions, and preflight. |
| `select_vm_backup.py` | Revalidates selected identities; local selection and backup data are ignored. |
| `start_restore_vm_backup.sh` | No internal configuration path or predictable `/tmp` log file. |
| `start_select_vm_backup.sh` | No internal configuration path; generic local configuration discovery. |
| `start_vm_backup_selection.sh` | No internal configuration path; generic local configuration discovery. |
| `start_vm_liste.sh` | No operational identities; generated private list is ignored. |
| `tests/test_safety.py` | Synthetic names, UUIDs, MAC addresses, and secrets only; security regression checks included. |
| `vm_backup_selection.example.txt` / `vm_backup_selection.example.de.txt` | Synthetic, disabled example rows; comments are provided in both languages. |
| `vm_backup_selection.py` | Writes local inventory data; output is protected by an ignore rule. |

## Private artifacts removed

The following categories were removed from the public tree rather than
anonymized: historical analysis reports, a step log, old startup parameters, a
duplicate requirements file, a real VM selection file, three runtime logs, and
all discovered `.pyc` files. The originals are stored outside the repository
in a private local archive.

## Checks recorded in the review

- Python syntax check: passed
- Shell syntax check: passed
- Unit tests: 62 passed
- Bandit: no findings in application code
- Ruff `E9,F`: passed
- Dependency audit: no known vulnerabilities in the test environment
- Pattern scan for previous VM, path, and UUID names: no matches
- Secret scan: only the documented placeholders `CHANGE_ME` and `secret`
- Public `main` history: one sanitized root commit without GitLab scaffolding
