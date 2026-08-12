# CODEX BRIEF — Kleinpaket: Pulse-Dormant-Overcount + 10513-Q10-Requal-Pfad + Agy-401

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
Drei unabhängige Restpunkte aus den 07-31-Reviews; je eigener Commit.

## 1. Pulse-Dormant-Overcount (aus KS-Recon: 10706-Falsch-Positiv)

`tools/strategy_farm/live_book_pulse.py` klassifiziert „dormant" aus den
letzten 4 MB des EA-Logs — Load-Events altern auf lauten Logs heraus (bewiesen:
10706 war armiert, Pulse meldete dormant). Fix: autoritative Arm-Status-
Ermittlung = letztes KS_BASELINE_LOADED/ABSENT **seit letztem INIT_OK** je
Sleeve über den vollen Log (streaming, nicht Voll-Load ins RAM; Logs können
groß sein). Test mit synthetischem Log >4 MB, Load-Event am Anfang.

## 2. 10513/XAUUSD — sauberer Q10-Re-Confirm-Pfad (Provenienz-Defekt)

10513 ist der letzte Baseline-Kandidat ohne Weg zur KS-Abdeckung (Staging-
Baseline trägt dokumentierten Manifest-Provenienz-Defekt aus der 07-24/25-
Welle). Aufgabe: exakten Requal-Weg bestimmen und einreihen — welcher
kanonische Mechanismus erzeugt einen frischen, provenienz-sauberen Q10-Lauf
für 10513/XAUUSD auf dem AKTUELLEN Binary (farmctl enqueue-backtest? bestehende
Q10-Row-Historie prüfen — kein Wave-Bruch, kein MNT-007-Konflikt, Einzel-Item)?
Einreihen, Row-ID dokumentieren. NICHT die Staging-Baseline deployen; nach
Q10-PASS läuft die normale gen_q10_baseline-Kette (separates Ticket).

## 3. Agy-401 (aus MNT-003-Observe: Governor-Quota-Pull failing)

`agy_governor.py` loggt HTTP 401 bei jedem Quota-Pull (Task-Contract selbst
Result 0). Diagnose: welches Credential zieht `agy_quota.py` (CredRead-Ziel),
ist es abgelaufen/rotiert, und was ist der dokumentierte Refresh-Weg (agy CLI
re-login in Session 1? OWNER-Aktion nötig?). KEINE Credential-Werte in Logs/
Repo. Falls Refresh interaktiv sein muss: exakte OWNER-Anleitung (1-2 Zeilen)
ins Deliverable. Bis dahin prüfen, ob der Governor bei 401 fail-safe pausiert
statt agy blind weiterlaufen zu lassen (AGY_LOW_QUOTA-Semantik bei unbekanntem
Verbrauch — konservativ?).

## Do NOT

Kein Factory-Eingriff, keine Task-/Flag-Mutation außer dem einen 10513-Enqueue,
niemals T_Live-Writes, keine Credentials irgendwo ausgeben.

## Deliverable

`docs/ops/evidence/2026-07-31_small_fixes_pulse_10513_agy401.md` mit Commits,
Tests, 10513-Row-ID, Agy-Befund. Danach `update-task <id> --state REVIEW
--artifact-path <deliverable> --verdict "<kurz>"`.
