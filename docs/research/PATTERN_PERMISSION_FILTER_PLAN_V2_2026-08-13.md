# Pattern-Permission-Filter — Plan v2 (nach Doppel-Review)

Supersedes `PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md` (v1). v1 bleibt als Beleg
stehen; **v2 ist der verbindliche Bauplan.**

## Provenance

- v1: OWNER-freigegeben 2026-08-13.
- **Codex-Review** `95e77e50` → `docs/ops/evidence/2026-08-13_95e77e50_codex_review_pattern_filter_plan.md`
  — Verdikt `PLAN_REQUIRES_REVISION_BEFORE_IMPLEMENTATION`, 9 BLOCKER + 8 MAJOR.
- **Unabhängige Lückenjagd** (13 Agenten, 6 Linsen, adversariale Widerlegungsrunde,
  `wf_147783cb`) — 35 Rohfunde → 10 bestätigt, 25 widerlegt (Anhang B).
- Beide Pässe liefen unabhängig und konvergierten auf denselben Hauptbefund.
- OWNER-Entscheide 2026-08-13 (unten E0-1..E0-3).

## Konvergenz-Hauptbefund (beide Pässe, von mir am Quellcode verifiziert)

`Strategy_EntrySignal()` der Balke-Straddle-Sleeves **platziert das Buy-Bein selbst**:
`QM5_13213…mq5:309-313` ruft `QM_TM_OpenPosition(buy_req, …)` *innerhalb* der
Signalfunktion und gibt via `req` nur den Sell-Stop zurück, den der Aufrufer bei
`:517-521` platziert (13301 identisch, `:334-341, :543-547`). v1s Veto-Punkt
(nach Signal-Rückgabe) sieht das Buy-Bein **nie** — `allow_buy=false` wäre dort ein
No-Op, kein Veto. Ein so gebauter Zensus hätte die Buy-Hälfte des 77×2-Rasters gegen
die *ungefilterte* Baseline gemessen: ~2 Fabrik-Tage auf still ungültige Zellen.

---

## OWNER-Entscheide (2026-08-13)

**E0-1 — Firewall: Messen ≠ Auswählen.**
Der Zensus liefert Landschaft und vollständigen Trial-Ledger; er **selegiert keinen
Promotions-Kandidaten**. Promotionskandidaten sind unabhängig **quell-abgeleitet** aus
der sanktionierten Filter-Liste und **vor Einsicht der Zensus-Returns vorregistriert**
(≤1 Prädikat/Sleeve, Charter §6.5). Grund: „Bestes von 154 auf DEV → promoten" ist
exakt die Slot-Sweep-Methodik, unter der die Referenz-Rewrite regressierte; ein
Sealed-OOS-Head-to-Head heilt eine kategoriale In-Sample-Bestenauswahl nicht.

**E0-2 — Prädikate 99/100 bleiben drin, korrigiert (77 gesamt).**
Datum wird aus dem unveränderlichen Eröffnungszeitpunkt der Referenzbar in explizitem
UTC abgeleitet, nie aus `TimeCurrent()`.

**E0-3 — v1 misst Blacklist-Semantik only** (Richtung sperren, wenn Prädikat feuert).
Whitelist ist ein anderes Experiment (Trade-Zahlen kollabieren, Frequenz-Floor) und
ist für v1 ausdrücklich außerhalb des Umfangs — als Grenze dokumentiert, damit ein
Negativergebnis nicht als „Muster wertlos" fehlgelesen wird.

---

## Aufgelöste Blocker

### A1 (Codex #7, Jagd #1) — Veto gehört IN `Strategy_EntrySignal`
Für Sleeves mit In-Hook-Platzierung (Straddle-Familie) wird die Erlaubnis **einmal pro
Referenzbar vor beiden Platzierungen** ausgewertet: Buy-Platzierung auf `allow_buy`
gegated, zurückgegebenes Sell-Bein auf `allow_sell`, bei `valid=false` **beide Beine
übersprungen** und `g_strategy_orders_day_key` **nicht** gesetzt (nichts zurückzurollen).
Voraussetzung: Signalkonstruktion wird **nebenwirkungsfrei** refaktoriert (beide
Requests zurückgeben, Platzierung ausschließlich beim Aufrufer, Tagesstatus nur aus
Platzierungsergebnis). Zulässig, weil Challenger neue EA-Identitäten sind; Live-Binaries
bleiben unangetastet. Der generische Ein-`req`-Pfad gilt weiter für Single-Order-Sleeves.
**Abnahmetest:** Ein Buy-blockierendes Profil senkt auf 13213/13301 nachweisbar die
Long-Entries, ein Sell-blockierendes die Short-Entries — jede Richtung unabhängig
unterdrückbar. Ein Test, der nur zeigt, dass `req` gefiltert wird, ist unzureichend.

### A2 (Codex #8) — Pending-Order-Lebenszyklus
Erlaubnis wird **nicht** bei Platzierung eingerastet. Verbietet eine neue
Referenzbar-Entscheidung eine ruhende Richtung, wird deren Pending-Order **entfernt**;
bei ungültigen Daten beide. Offene Positionen, Management und Exits werden nie
unterdrückt. Ein Veto zum Trigger-Zeitpunkt wäre wirkungslos — broker-seitige
Aktivierung ruft den EA-Entry-Hook nicht auf.
**Abnahmetest:** Fixtures für allowed / buy-only / sell-only / neither / invalid history /
Tageswechsel während Order ruht / eine fehlgeschlagene Platzierung / Neustart /
Gegen-Trigger-Storno.

### A3 (Codex #1–3, Jagd #4–5) — Statistik-Vertrag
- `declared_trial_count` wird in DSR/PBO verdrahtet. **Bei `declared` absent/0/None
  bleibt das Verhalten byte-identisch** (`N_CANDIDATE_STRATEGIES = 369` als Fallback) —
  `declared_trial_count` entsteht strukturell nur im Q14-Ledger, normale Q08-Läufe
  tragen keinen. Eine Änderung des Flotten-Defaults 369 selbst ist eine **separate,
  OWNER-ratifizierte Gate-Rekalibrierung**, nicht Teil dieses Baus.
- **Familien-Einheit: 154 pro Sleeve** (77 × 2 Richtungen), nicht die flottenweite 1386 —
  Pooling würde jeden Sleeve für fremde Trials überbestrafen. Cross-Sleeve-Kontrolle
  läuft über den unabhängigen Q16-Sealed-OOS je Challenger, nicht über Pooling.
- **DSR-Kalibrierung vor dem Zensus:** die aktuellen DSR-Beträge sind wegen
  `sharpe_std = 1.0` (`sub_8_2:135`) nicht beweiskräftig; PBO kann Familien vermischen.
  Beides wird in P0 kalibriert bzw. exakt-familiär rekonstruiert.
**Abnahmetest:** Rückwärtskompatibilität (declared fehlt ⇒ bit-identische Ergebnisse)
UND Wirksamkeit (declared=154 ⇒ nachweisbar strengere Deflation), plus Vorher/Nachher
auf einem realen Q08-Fall.

### A4 (Codex #4–5) — Selektionsregel
DEV-Zielgröße, Mindestverbesserung, **Feuerhäufigkeit als Zulassungsbedingung**
(ein Prädikat mit zu wenigen Auslösungen ist gar nicht erst kandidatenfähig),
kategoriale Robustheit und globale Auswahl über Karten-Shards hinweg werden explizit
definiert. Mein v1-Kriterium (2 von 3 Zeitdritteln) ist **nicht** ausreichend und wird
durch die Kombination Feuerzahl-Schwelle + Mindestverbesserung + Teilfenster-Stabilität
ersetzt. Unter E0-1 ist diese Regel ohnehin nur noch Charakterisierung, keine Kür.

### A5 (Codex #9) — Zensus-Binary
Der Zensus bekommt eine **eigene, hash-gebundene Zensus-EA-Identität** mit
Lineage-Manifest. Ohne rechtmäßiges ausführbares Subjekt läuft kein Trial.

### A6 (Codex #10, Jagd #7) — Blast-Radius ehrlich
v1s „kein Schema-/Setfile-Change" ist **falsch**. Vollständige Aufzählung (Schema,
Q14/Q15, Setfiles, Registry, Lint) wird Teil von P2; Default-OFF-Äquivalenz wird
**bewiesen**, nicht behauptet. Zensus-Caps laufen in einem **eigenen Pool**, getrennt
von den 11 lebenden Welle-1-Karten.

### A7 (Codex #14, Jagd #6) — Historien- und Zeitvertrag
Pro Prädikat eine auditierte Zeile: Mindest-Bar-Bedarf, Verhalten bei zu kurzer
Historie, Referenz-TF-Semantik. Ein pauschaler Lookback genügt nicht (90/91 brauchen
100 Bars). Kalender-Prädikate nach E0-2 aus dem Bar-Eröffnungszeitpunkt in UTC.

### A8 (Codex #16, Jagd #2) — Rekonstruktion nur diagnostisch
Die Offline-Rekonstruktion aus dem instrumentierten Lauf bleibt **diagnostisch**,
bis Zustandsäquivalenz bewiesen ist — sie ersetzt keine Backtests.
**Launch-Sperre:** Buy-Zellen der Straddle-Sleeves starten erst, wenn der
A1-Richtungstest grün ist.

---

## Phasen v2

`Schritt 0` (erledigt: Doppel-Review) → **P0** Statistik-Vertrag + DSR-Kalibrierung →
**P1** Filter-Include + 77 Prädikate + **A1/A2-Integration** (Pflicht-Deliverable) →
**P2** Zensus-Maschinerie + voller Blast-Radius-Nachweis → **P2.5 Vorregistrierung**
der quell-abgeleiteten Promotionskandidaten (neue Stufe aus E0-1, **vor** Zensus-Returns)
→ **P3** Zensus (Straddle-Buy-Zellen gesperrt bis A1-Test grün) → **P4** Promotion der
vorregistrierten Kandidaten als neue EA-Identität, Q02→Q10, Q16.

**Kein Zensus wird enqueued, bevor A1–A7 im Code aufgelöst und ihre Abnahmetests grün sind.**

## Anhang A — Umfang unverändert
77 Prädikate (72 + 4 reklassifiziert + 1 Tick-Volumen-Proxy); 21 Kill-Liste + 3
Steuerwerte bleiben draußen. Katalog siehe v1.

## Anhang B — Widerlegte Funde
25 der 35 Rohfunde wurden in der Widerlegungsrunde erledigt (u. a. „ruhende Order
triggert über Nacht unter neuer Erlaubnis", „ATR-Doppelverschiebung bei 44/57/58/82/83/87",
„Loop-Prädikate mitteln die offene Bar mit", „Perzentil-Prädikate 90/91 fehletikettieren
die ersten 100 Bars"). Vollständig in `wf_147783cb` journal.jsonl — nicht erneut aufrollen.
