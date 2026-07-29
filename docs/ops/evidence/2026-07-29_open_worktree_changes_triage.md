# Offene Arbeitsbaumänderungen — Triage 2026-07-29

## Scope und Sicherheitsentscheidung

Die Analyse ist read-only gegen den kanonischen Checkout
`C:\QM\repo` auf `agents/board-advisor` / `637d5a152...`. Bestehende
Änderungen wurden weder verworfen noch überschrieben. Die Maintenance-
Implementierung bleibt bis zur Integration im separaten Worktree
`C:\QM\worktrees\mnt-20260729-integration`.

Factory bleibt auf ausdrückliche OWNER-Absicht OFF. Aus dieser Triage folgt
insbesondere **kein** Factory_ON, kein AutoTrading-Eingriff und keine
automatische Veröffentlichung generierter Dateien.

## Klassifikation

### 1. QM5_20172 Build-Receipt-Umbenennung

- Getrackte Altdatei ist gelöscht; dieselben Bytes liegen unter
  `2026-07-26_qm5_20172_q02_enqueue_build_result.codex_review_fail_attempt_1.json`.
- Git-Blob alt und neu sind identisch:
  `298429ca11d8e21ecb0e641a09ba6bd937c6bc92`.
- Disposition: **behalten**, als semantische Quarantäne des stale Build-
  Receipts in MNT-048 integrieren. Nicht als frisches Build-Ergebnis werten.

### 2. Generierter Public-Snapshot-Drift

Betroffen sind:

- `public-data/process-roadmap.json`
- `public-data/public-snapshot.json`
- `public-data/strategy-archive.json`

Der Task-Scheduler-Nachweis bindet die Änderung an
`QM_Public_Snapshot_Hourly`: letzter Lauf `2026-07-29T12:07:07+02:00`,
Wrapper-Log `2026-07-29T10:07:02Z` bis `10:07:06Z`. Der Lauf erfolgte nach
dem Factory-OFF-Zeitpunkt und vor wirksamer Task-Deaktivierung bzw. vor dem
neuen frühen OFF-Guard. Der Task ist inzwischen deaktiviert.

Der Drift ist nicht nur ein Zeitstempelwechsel: `strategy-archive.json` nahm
QM5_20182 auf, obwohl dessen Q02-/Build-Folge wegen des Factory-OFF-Bypass-
Incidents quarantänisiert ist. Daher ist dieser generierte Arbeitsbaumstand
**nicht freigabefähig**.

Disposition: Dateien im kanonischen Checkout unangetastet lassen; nach
fachlicher Bereinigung von QM5_20182 und erst in einem zulässigen
Maintenance-/Restart-Zustand deterministisch aus gültigen Quellen neu
generieren. Der neue Wrapper-Guard muss dabei Factory-OFF respektieren.
Diese Folgearbeit ist MNT-049/MNT-052 zugeordnet.

### 3. MNT-043/044-Dateien im kanonischen Checkout

Sechs ungetrackte Scanner-, Schema-, Test- und Evidenzdateien liegen sowohl
im kanonischen als auch im Integrations-Worktree. SHA-256-Vergleich aller
sechs Dateien ist bytegleich. Die Integrationskopie ist die maßgebliche
Maintenance-Änderung.

Disposition: Im kanonischen Checkout vorerst nichts löschen. Erst nachdem
die Integrationsänderung dauerhaft gesichert und übernommen wurde, darf die
doppelte ungetrackte Kopie mit expliziter Zielprüfung bereinigt werden. Das
ist ein MNT-031-Integrationspunkt und keine zweite fachliche Implementierung.

## Ergänzte Planpunkte

1. MNT-048: QM5_20172-Receipt-Quarantäne zusammen mit frischem, generations-
   und hashgebundenem Build/Q02 nach dem Restart abschließen.
2. MNT-049/MNT-052: den ungültigen Public-Snapshot-Drift nicht übernehmen;
   nach Quellenbereinigung kontrolliert neu generieren und OFF-Guard sowie
   Output-Hashes belegen.
3. MNT-031: Integrationsbranch sichern/übernehmen; erst danach die
   bytegleichen ungetrackten MNT-043/044-Duplikate im kanonischen Checkout
   gezielt bereinigen.
