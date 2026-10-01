# Safety-gated ESXi API Backup

[English version](README.en.md)

> **Entwickelt von:** Alpein Software Swiss AG<br>
> **Programmiert von:** [Samuel Werner (Cyberwerner)](https://github.com/Cyberwerner4444)<br>
> **Unterstützt von:** KI<br>
> **Achtung:** WIPCODING-Inhalt

Dieses Repository enthält ein eigenständiges Python-basiertes Backup- und
Restore-Werkzeug für VMware ESXi. Es erstellt VM-Exporte über die vSphere API,
unterstützt ausgeschaltete und laufende VMs, verifiziert Sicherungsdateien per
SHA-256 und kann große VMDKs lokal in deduplizierte Blöcke zerlegen.

**Kompatibilitätsstand:** Entwickelt für und getestet mit **VMware ESXi 8.0
Update 2**. Neuere ESXi-Versionen wurden bisher nicht getestet.

> **Work in Progress — nicht ungeprüft produktiv einsetzen.** Berechtigungen,
> TLS-Zertifikate, Speicherbedarf, Snapshot-Verhalten und ein vollständiger
> Restore müssen vor dem Einsatz in einer isolierten Umgebung getestet werden.

Eine ausführliche Betriebs- und Restore-Anleitung steht in beiden Sprachen
bereit:

- [Betriebs- und Restore-Runbook auf Deutsch](RUNBOOK.md)
- [Operations and restore runbook in English](RUNBOOK.en.md)

## Sicherheitsmodell

Der dedizierte Einstieg `backup_vm.py` sichert ausschließlich die in
`TARGET_VM_NAME` konfigurierte VM. Ein Backup startet erst, wenn:

- der Bediener den VM-Namen mit `--confirm-vm` exakt bestätigt;
- Name, optional hinterlegte Instance-UUID und erwartete VM-Geometrie passen;
- der Zustand `poweredOff` oder `poweredOn` ist;
- kein bestehender Snapshot gefunden wird;
- am Backup-Ziel genügend freier Speicher verfügbar ist.

Der separate Auswahlmodus kann mehrere ausdrücklich ausgewählte VMs sichern.
Auswahldateien werden vor jedem Lauf gegen MoRef, UUID und Namen im aktuellen
ESXi-Inventar geprüft.

Weitere Schutzmaßnahmen:

- TLS-Zertifikatsprüfung ist standardmäßig aktiviert.
- NFC-Download-URLs dürfen Sitzungscookies nur an freigegebene ESXi-Hosts senden.
- Restore überschreibt weder eine bestehende VM noch einen Datastore-Ordner.
- Restore-Netzwerkkarten bleiben standardmäßig getrennt.
- Delta-Manifeste und Dateinamen werden gegen Pfadmanipulation geprüft.
- Konfiguration, Logs und neu erzeugte Dateien erhalten restriktive Rechte.
- Logs, Backups, Konfiguration, Inventarlisten und Bytecode sind per `.gitignore`
  von Git ausgeschlossen.

## Wichtige Grenzen

- Backups und Metadaten werden **nicht automatisch verschlüsselt**. Das
  Ziel-Dateisystem muss verschlüsselt und zugriffsgeschützt sein.
- SHA-256 erkennt Veränderungen, bietet aber ohne externe Signatur keine
  kryptografische Echtheitsgarantie gegen einen Angreifer mit Schreibzugriff.
- Live-Backups sind standardmäßig crash-konsistent. Quiescing muss pro VM
  getestet und bewusst aktiviert werden.
- Die lokale Delta-Funktion reduziert Speicherbedarf nach dem Export; sie ist
  kein VMware-CBT-Only-Transfer.
- Der aktuelle Restore unterstützt genau eine virtuelle Festplatte. Backups mit
  mehreren VMDK-Deskriptoren werden sicher abgewiesen statt teilweise restauriert.
- Ein vorhandenes Backup gilt erst nach einem erfolgreich getesteten Restore
  als belastbar.

## Voraussetzungen

- Python 3.10 oder neuer
- Zugriff auf die ESXi/vSphere API und Datastore-HTTP-Endpunkte
- ein dediziertes Konto mit den minimal erforderlichen Rechten
- ein vertrauenswürdiges Zertifikat bzw. eine lokal installierte CA
- ausreichend freier, geschützter Backup-Speicher

Installation:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## Konfiguration

```bash
cp config.example.de.env config.env
chmod 600 config.env
```

Mindestens diese Werte anpassen:

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

`192.0.2.10` ist eine reservierte Dokumentationsadresse und kein reales Ziel.
Ein produktives Passwort darf nie in Git gelangen. Alternativ kann
`ESXI_PASSWORD` nur für den Prozess als Umgebungsvariable gesetzt werden.

Wenn ESXi in NFC-Lease-URLs einen anderen vertrauenswürdigen Hostnamen als
`ESXI_HOST` zurückgibt, kann dieser explizit ergänzt werden:

```dotenv
ESXI_NFC_ALLOWED_HOSTS=esxi.example.invalid
```

## Dediziertes Ziel-VM-Backup

Inventar prüfen:

```bash
python3 backup_vm.py inventory
```

Preflight ausführen:

```bash
python3 backup_vm.py preflight
```

Backup starten; der Wert muss exakt `TARGET_VM_NAME` entsprechen:

```bash
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode full
```

Lokale Delta-Speicherung auswählen:

```bash
python3 backup_vm.py backup --confirm-vm ExampleVM --backup-mode delta
```

Backup prüfen:

```bash
python3 backup_vm.py verify backups/ExampleVM/full_0001
```

## Explizite VM-Auswahl

Inventarliste erzeugen:

```bash
./start_vm_liste.sh
```

Die erzeugte `vm_backup_selection.txt` enthält Infrastrukturidentitäten und ist
absichtlich von Git ausgeschlossen. Eine [deutsche Beispieldatei](vm_backup_selection.example.de.txt)
liegt im Repository. Nur gewünschte VM-Zeilen aktivieren und zuerst einen
reinen Preflight ausführen:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt --list-only
```

Danach interaktiv starten:

```bash
./start_select_vm_backup.sh --selection-file vm_backup_selection.txt
```

`--yes` überspringt die letzte Bestätigung und sollte nur in kontrollierter
Automation verwendet werden.

## Restore

Restore-Punkte auflisten:

```bash
./start_restore_vm_backup.sh --list-backups
```

Zuerst ausschließlich den Dry-Run verwenden:

```bash
./start_restore_vm_backup.sh \
  --backup-dir backups/ExampleVM/full_0001 \
  --new-name ExampleVM-Restore-Test \
  --dry-run
```

Ein echter Restore wird standardmäßig ausgeschaltet und mit getrennter
Netzwerkkarte angelegt. `--connect-network` und `--power-on` sind getrennte,
explizite Entscheidungen.

## Automatisierung

`run_weekly_vm_backup.sh` verwendet eine Lock-Datei, um parallele Wochenläufe
zu verhindern. Vor einer Cron-Aktivierung muss ein manueller Lauf mit derselben
Auswahldatei erfolgreich abgeschlossen sein. Details stehen im [Betriebs- und
Restore-Runbook](RUNBOOK.md).

## Projektdateien

- `safe_esxi_backup.py` – Verbindung, Preflight, Export und Verifikation
- `backup_vm.py` – dedizierter, sicherheitsgesperrter Ziel-VM-Einstieg
- `select_vm_backup.py` – interaktive bzw. dateibasierte VM-Auswahl
- `vm_backup_selection.py` – Generator für lokale Auswahldateien
- `restore_vm_backup.py` – konservativer Restore unter neuem VM-Namen
- `delta_storage.py` – lokale Block-Deduplizierung und Materialisierung
- `tests/test_safety.py` – Sicherheits- und Regressionstests
- `SECURITY_REVIEW.md` – Veröffentlichungs- und Datei-Audit auf Deutsch

## Tests

```bash
python -m unittest discover -s tests -v
```

Tests ersetzen keinen ESXi-Integrationstest. Export, Snapshot-Cleanup und
Restore müssen zusätzlich gegen eine nicht produktive ESXi-Umgebung geprüft
werden.

## Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE). Eine unverbindliche
deutsche Übersetzung zur Orientierung steht in [LICENSE.de.md](LICENSE.de.md);
maßgeblich bleibt der englische Lizenztext.
