# Sicherheits- und Veröffentlichungsprüfung

Stand: 2026-10-01

[English version](SECURITY_REVIEW.en.md)

## Ergebnis

Der öffentliche Projektbaum enthält keine bekannten realen Zugangsdaten,
Hostnamen, VM-Namen, UUIDs, Datastore-Pfade, Produktionslogs oder Backup-Daten.
Beispielwerte verwenden neutrale Namen, Null-/Test-UUIDs und den für
Dokumentation reservierten IPv4-Bereich `192.0.2.0/24`.

Die Prüfung ist eine Momentaufnahme. Vor jedem Push muss erneut über den
Arbeitsbaum **und den vollständigen Git-Verlauf** gescannt werden.

## Systemanalyse

Entwicklungs- und Teststand ist VMware ESXi 8.0 Update 2. Das Verhalten auf
neueren ESXi-Versionen wurde bisher nicht validiert.

Der Backup-Ablauf besteht aus vier Schichten:

1. `safe_esxi_backup.py` verbindet sich mit ESXi, sammelt Inventardaten,
   erzwingt Preflight-Regeln und exportiert die VM.
2. Bei ausgeschalteten VMs wird `ExportVm` verwendet. Bei laufenden VMs wird
   ein temporärer Snapshot erzeugt; falls `ExportSnapshot` nicht unterstützt
   wird, folgt ein Datastore-seitiger `CopyVirtualDisk`-Fallback.
3. `delta_storage.py` kann exportierte VMDK-Extents nachträglich in lokale,
   SHA-256-adressierte Blöcke zerlegen und für Restore wieder materialisieren.
4. `restore_vm_backup.py` prüft Backup-Dateien und Metadaten, lädt genau eine
   virtuelle Festplatte hoch und legt eine neue, zunächst ausgeschaltete VM an.

Stärken sind die explizite Zielbestätigung, Identitätsprüfungen, Snapshot- und
Temp-Cleanup, Hash-Verifikation, standardmäßig getrennte Restore-Netzwerke und
die Weigerung, bestehende Ziele zu überschreiben.

## Behobene Sicherheitsprobleme

| Schwere | Problem | Maßnahme |
|---|---|---|
| Hoch | Reale Inventar-, UUID-, Pfad- und Logdaten lagen im Projektbaum. | Aus dem öffentlichen Baum entfernt und Ignore-Regeln ergänzt. |
| Hoch | Ein manipulierter NFC-Lease-Host hätte den ESXi-Sitzungscookie erhalten können. | HTTPS- und Host-Allowlist-Prüfung vor jedem Lease-Download. |
| Hoch | Delta-Garbage-Collection konnte bei beschädigten Manifesten benötigte Blöcke löschen. | Fail-closed bei unlesbaren/unsicheren Manifesten und Pfadbegrenzung. |
| Hoch | Mehrplatten-Backups wären im Restore nur teilweise verarbeitet worden. | Restore blockiert Mehrplatten-Backups vor schreibenden Aktionen. |
| Mittel | TLS-Verifikation war standardmäßig deaktiviert. | Sicherer Standard `true`, CA-Trust und Warnung bei Deaktivierung. |
| Mittel | Unbekannte Datastore-Browserfehler galten als „Ordner fehlt“. | Unbekannte Fehler blockieren den Restore. |
| Mittel | OVF wurde mit einem allgemeinen XML-Parser verarbeitet. | Wechsel auf `defusedxml` plus Größenlimit. |
| Mittel | Restore vertraute ungehashten Metadaten und OVF-Dateien. | Größe und SHA-256 werden in neuen Manifesten gespeichert und geprüft. |
| Mittel | Konfiguration und Laufzeitdateien konnten zu offene Rechte erhalten. | POSIX-Prüfung auf `600` und Prozess-Umask `077`. |
| Mittel | Abhängigkeiten waren veraltet. | Aktualisierte, exakt gepinnte Versionen und Dependency-Audit. |
| Niedrig | Absolute interne Konfigurations- und Backup-Pfade waren fest verdrahtet. | Relative/discoverbare Konfiguration und neutrale Beispiele. |

## Verbleibende Risiken

- Das Programm verschlüsselt Backup-Inhalte nicht.
- SHA-256 schützt ohne extern signiertes Manifest nicht gegen einen Angreifer,
  der Backup-Dateien und Manifeste gemeinsam verändern kann.
- Live-Backups sind ohne getestetes Quiescing nur crash-konsistent.
- Restore unterstützt derzeit genau eine virtuelle Festplatte.
- ESXi-Rollen und minimale Berechtigungen müssen gegen die konkrete Plattform
  getestet und dokumentiert werden.
- Unit-Tests ersetzen keinen Export-/Restore-Integrationstest auf ESXi.
- Auto-Installation aus dem öffentlichen Paketindex setzt Vertrauen in PyPI,
  DNS/TLS und die gepinnten Pakete voraus.

## Einzelprüfung der öffentlichen Dateien

| Datei | Prüfung und Ergebnis |
|---|---|
| `.gitlab-ci.yml` | Führt nur Unit-Tests, SAST und Secret Detection aus; keine Build-, Review- oder Deployment-Stufen. |
| `.gitignore` | Schließt Secrets, Logs, Backups, Inventarlisten, Bytecode, virtuelle Umgebungen und Laufzeitdaten aus. |
| `LICENSE` / `LICENSE.de.md` | Englische MIT-Standardlizenz und unverbindliche deutsche Leseübersetzung; Rechteinhaber ist Alpein Software Swiss AG. |
| `README.md` / `README.en.md` | Deutsche Hauptfassung und englische Übersetzung; WIP-Hinweis, gewünschte Urheberangaben oben und keine internen Betriebsdaten. |
| `RUNBOOK.md` / `RUNBOOK.en.md` | Deutsche und englische Betriebsanleitungen mit Platzhalterpfaden, neutralen VM-Namen und sicherer Reihenfolge. |
| `SECURITY.md` / `SECURITY.en.md` | Veröffentlichungs- und Meldehinweise ohne interne Kontakt- oder Infrastrukturdaten. |
| `SECURITY_REVIEW.md` / `SECURITY_REVIEW.en.md` | Dokumentiert Audit, Fixes und Restrisiken ohne reale Zielsystemdaten. |
| `backup_vm.py` | Neutral umbenannter Einstieg; keine Geheimnisse oder feste Kundenbezeichnung. |
| `config.example.env` / `config.example.de.env` | Nur Dokumentations-IP und Platzhalter; TLS sicher voreingestellt, kein echtes Passwort. |
| `delta_storage.py` | Pfad-/Digest-Prüfung, fail-closed Cleanup, keine Infrastrukturwerte. |
| `inventory_discovery.py` | Neutraler Wrapper; Inventarausgabe bleibt lokal und wird nicht mitgeliefert. |
| `requirements.txt` | Nur exakt gepinnte öffentliche Paketversionen. |
| `restore_vm_backup.py` | Fail-closed Zielprüfung, sichere XML-Verarbeitung, Hashprüfung, Single-Disk-Sperre. |
| `run_once_vm_backup_test.sh` | Keine internen Pfade; temporäre Datei über `mktemp`, restriktive Umask. |
| `run_weekly_vm_backup.sh` | Lokale Logs/Lock/Inventarliste sind ignoriert; restriktive Umask und Prozess-Lock. |
| `safe_esxi_backup.py` | Ziel konfigurierbar; TLS/Lease-Host/Dateirechte und Preflight gehärtet. |
| `select_vm_backup.py` | Validiert ausgewählte Identitäten erneut; lokale Auswahl- und Backupdaten sind ignoriert. |
| `start_restore_vm_backup.sh` | Kein interner Konfigurationspfad; keine vorhersehbare `/tmp`-Logdatei. |
| `start_select_vm_backup.sh` | Kein interner Konfigurationspfad; generische lokale Konfigurationssuche. |
| `start_vm_backup_selection.sh` | Kein interner Konfigurationspfad; generische lokale Konfigurationssuche. |
| `start_vm_liste.sh` | Keine Betriebsidentitäten; erzeugte private Liste ist ignoriert. |
| `tests/test_safety.py` | Nur synthetische Namen, UUIDs, MACs und Secrets; Sicherheitsregressionen ergänzt. |
| `vm_backup_selection.example.txt` / `vm_backup_selection.example.de.txt` | Synthetische, deaktivierte Beispielzeilen mit Kommentaren in beiden Sprachen. |
| `vm_backup_selection.py` | Schreibt lokale Inventardaten; Ausgabe ist per Ignore-Regel geschützt. |

## Entfernte private Artefakte

Folgende Kategorien wurden nicht anonymisiert veröffentlicht, sondern aus dem
öffentlichen Baum entfernt: historische Analyseberichte, Schrittprotokoll,
alte Startparameter, doppelte Requirements-Datei, reale VM-Auswahldatei, drei
Laufzeitlogs sowie sämtliche gefundenen `.pyc`-Dateien. Die Originale liegen
außerhalb des Repositorys in einem privaten lokalen Archiv.

## Im Audit festgehaltene Nachweise

- Python-Syntaxprüfung: bestanden
- Shell-Syntaxprüfung: bestanden
- Unit-Tests: 62 bestanden
- Bandit: keine Findings im Anwendungscode
- Ruff `E9,F`: bestanden
- Dependency-Audit: keine bekannten Schwachstellen in der Testumgebung
- Musterprüfung auf frühere VM-/Pfad-/UUID-Bezeichnungen: keine Treffer
- Secret-Scan: nur die dokumentierten Platzhalter `CHANGE_ME` und `secret`
- Öffentlicher `main`-Verlauf: ein bereinigter Root-Commit ohne GitLab-Scaffold
