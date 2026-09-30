# Betriebs- und Restore-Runbook

Dieses Runbook beschreibt einen konservativen Ablauf. Befehle mit schreibender
Wirkung erst nach erfolgreichem Preflight und in einer freigegebenen Umgebung
ausführen.

## 1. Einmalige Einrichtung

```bash
cd /pfad/zum/esxi-backup
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp config.example.env config.env
chmod 600 config.env
```

In `config.env` ein dediziertes ESXi-Konto, TLS-Prüfung, Ziel-VM und
Backup-Speicher konfigurieren. Kein Root-Konto verwenden, wenn ein Konto mit
minimalen Rechten möglich ist.

Vor jedem produktiven Einsatz prüfen:

```bash
stat -c '%a %n' config.env
df -h "$(pwd)"
python3 backup_vm.py inventory
python3 backup_vm.py preflight
```

Die Konfigurationsdatei muss unter POSIX Rechte `600` besitzen.

## 2. Zertifikate

`ESXI_SSL_VERIFY=true` ist der sichere Standard. Die ESXi-Zertifikatskette muss
im Trust Store des Systems bzw. der Python-Umgebung verfügbar sein.

`ESXI_SSL_VERIFY=false` ist nur für einen zeitlich begrenzten Test in einem
isolierten Netz vorgesehen. Die Warnung im Log darf im Normalbetrieb nicht
auftreten.

## 3. Dedizierte Ziel-VM sichern

```bash
python3 backup_vm.py preflight
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode full
```

Dabei `ExampleVM` durch den exakten Wert aus `TARGET_VM_NAME` ersetzen.

Nach dem Lauf:

```bash
python3 backup_vm.py verify backups/ExampleVM/full_0001
```

Ein Exit-Code ungleich null, ein fehlgeschlagener SHA-256-Test oder ein
verbliebener `.inprogress`-/`.failed`-Ordner muss untersucht werden.

## 4. Liste ausgewählter VMs sichern

Lokale Inventarliste erzeugen:

```bash
./start_vm_liste.sh
chmod 600 vm_backup_selection.txt
```

Nur gewünschte VM-Zeilen aktivieren. Anschließend:

```bash
./start_select_vm_backup.sh \
  --selection-file vm_backup_selection.txt \
  --list-only
```

Erst wenn alle fatalen Prüfungen `PASS` sind:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt
```

Die Datei nach Inventaränderungen neu erzeugen. UUID-/MoRef-Abweichungen nicht
blind korrigieren; zuerst sicherstellen, dass tatsächlich dieselbe VM gemeint
ist.

## 5. Delta-Speicherung

Der erste Stand einer VM ist ein Full-Backup. Folgende Stände können große
VMDK-Extents in lokale SHA-256-Blöcke zerlegen.

Wichtige Regeln:

- `backup_manifest.json`, `delta_manifest.json`, Full-Basis und `.delta_store`
  gemeinsam aufbewahren;
- niemals einzelne Chunk-Dateien manuell löschen;
- vor jeder Bereinigung alle Manifeste lesbar halten;
- Delta reduziert lokalen Speicher, nicht zwingend den ESXi-Netzwerktransfer.

Die automatische Bereinigung bricht ab, sobald ein Manifest beschädigt,
unlesbar oder außerhalb des erlaubten Pfadbaums ist.

## 6. Restore-Test

Restore-Punkte prüfen:

```bash
./start_restore_vm_backup.sh --list-backups
```

Dry-Run:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test \
  --dry-run
```

Echter isolierter Restore:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test
```

Standardmäßig bleibt die VM ausgeschaltet und die Netzwerkkarte getrennt.
Der aktuelle Restore unterstützt genau eine virtuelle Festplatte; ein
Mehrplatten-Backup wird vor schreibenden Aktionen blockiert.
Danach manuell prüfen:

- VM-Geometrie und Datastore-Ziel stimmen;
- VMDK lässt sich öffnen und das Gastdateisystem ist konsistent;
- Original-VM und Restore haben keine MAC-/IP-Kollision;
- temporäre Upload-Dateien und Snapshots wurden entfernt;
- Anwendung startet in einem isolierten Netzwerk vollständig.

## 7. Wochenlauf

Vor Cron zuerst manuell testen:

```bash
./run_weekly_vm_backup.sh
```

Beispiel für Sonntag 02:00 Uhr:

```cron
0 2 * * 0 /pfad/zum/esxi-backup/run_weekly_vm_backup.sh
```

Cron-Ausgaben und Programmlogs enthalten Infrastrukturinformationen. Sie
bleiben lokal, benötigen Rechte `600` und dürfen nicht in Tickets oder Git
kopiert werden.

## 8. Fehlerbehandlung

Bei einem abgebrochenen Live-Backup zuerst kontrollieren:

1. Gibt es auf ESXi einen temporären Snapshot?
2. Läuft noch ein `CopyVirtualDisk`-Task?
3. Existiert ein temporärer Ordner `esxi_api_backup_tmp` auf dem Datastore?
4. Enthält das `.failed`-Manifest konkrete Cleanup-Fehler?

Während ein ESXi-Kopiertask noch läuft, temporäre Dateien nicht manuell löschen.
Unklare Zustände zuerst im ESXi-Taskverlauf auflösen.

## 9. Regelmäßige Kontrollen

- täglich: letzter Lauf, Exit-Code, freier Speicher, verbliebene Snapshots;
- wöchentlich: Hash-Verifikation eines aktuellen Restore-Punkts;
- monatlich: isolierter Restore-Test;
- nach Updates: Unit-Tests, Preflight, Full-Backup und Restore-Test;
- regelmäßig: Rotation und geschützte Aufbewahrung der Logs;
- regelmäßig: Offline-/immutable Kopie gegen Ransomware prüfen.
