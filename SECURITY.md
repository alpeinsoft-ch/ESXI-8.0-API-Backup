# Sicherheitsrichtlinie

Dieses Projekt ist Work in Progress. Sicherheitsmeldungen sollen nicht mit
realen Zugangsdaten, VM-Namen, IP-Adressen, UUIDs, Logs oder Backup-Dateien in
einem öffentlichen Issue veröffentlicht werden.

Bitte zuerst einen privaten Kontaktweg des jeweiligen GitLab-/GitHub-Projekts
verwenden. Falls noch kein privater Meldeweg eingerichtet ist, nur eine kurze
öffentliche Bitte um Kontakt hinterlassen und technische Details zurückhalten.

## Nicht als Geheimnis einchecken

- `config.env` oder `.env`
- ESXi-Passwörter, API-Sitzungscookies und Zertifikatsschlüssel
- Logs und Cron-Ausgaben
- `vm_backup_selection.txt`
- Backup-Manifeste, VM-Metadaten, OVF-, NVRAM- oder VMDK-Dateien
- Screenshots mit Inventar-, Netzwerk- oder Datastore-Daten

## Vor einer Veröffentlichung

```bash
git status --short
git ls-files
rg -n -i -uu '(password|secret|token|cookie|private.key|authorization|bearer)' .
```

Treffer müssen einzeln bewertet werden. Platzhalter in Tests und
`config.example.env` sind erlaubt; reale Werte sind es nicht. Zusätzlich sollte
vor jedem Release ein etablierter Secret-Scanner über den gesamten Git-Verlauf
laufen.

## Sicherheitsgrenzen

Die Software verschlüsselt Backups nicht selbst und signiert Manifeste nicht.
Der Betreiber ist für verschlüsselten Speicher, Zugriffskontrolle,
Offline-/Immutable-Kopien, Schlüsselmanagement, Log-Rotation und regelmäßige
Restore-Tests verantwortlich.
