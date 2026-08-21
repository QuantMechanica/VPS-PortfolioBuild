# DL-089 — Pattern-Filter-Optimierung v3: Walk-Forward-Jahreszensus, Auswahlregel, Trial-Deflation

**Date:** 2026-08-21
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER, 2026-08-21 abends, im Chat: Direktive („In Wahrheit entstehen da
mehrere hundert Backtests! Einer je Pattern je Buy/Sell Richtung … Außerdem testest du
jedes Jahr einzeln, damit wird Overfitting verhindert! … du als AI interpretierst und
anhand der Ergebnisse bis zu drei buy und bis zu drei sell Filter auswählst. Danach …
Gesamttest … und daraus entsteht dann das Portfolio!") plus 12 explizite
Einzelentscheide über die strukturierte Abfrage, plus Nachtrag („Die numerischen
Parameter Optimization kannst du mit Codex bereits mitbauen, deren Optimierungstest
sind aber Phase 2").
**Operative Spezifikation:** `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md`
**Scope:** Optimierungszweig Q14→Q15→Q16 (DL-084/DL-088). Kernfunnel Q00–Q13 unberührt.

## Entscheide

1. **Messdesign:** je (EA, Symbol) ein Zensus 77 Muster × 2 Richtungen × Kalenderjahre
   einzeln (2019–2025) + Baseline je Jahr; Blacklist-Semantik (ODER-Verknüpfung).
2. **Auswahlregel (versiegelt):** Konsistenz ≥ 2/3 der Auswahljahre mit je ≥ +5 %
   relativer Verbesserung auf return_to_maxdd gegen die Jahres-Baseline; Auswahl bis zu
   3 Buy + 3 Sell; „kein Filter" ist stets Kandidat.
3. **Frequenz-Boden fail-closed:** Aktivitätskriterium (≥ 10 Entry-Handelstage je
   gewertetem Jahr, pro-rata gem. CEO-MP-#4); Riss in EINEM Jahr ⇒ Filter unzulässig,
   Ausschluss VOR Renditebetrachtung.
4. **OOS-Protokoll:** ankernder Walk-Forward, Mindestfenster 3 Jahre, Prüfjahre
   2022–2025; Stabilitätskriterium gemäß Plan §2.
5. **Overfit-Deflation:** `declared_trial_count = 154` (Suchraum; Einzeljahre =
   wiederholte Messung, keine Trials). Q16-Vertrag (PBO < 0,40; DSR p < 0,05) unverändert.
6. **_opt-EA:** Pattern-Filter-Inputs UND numerische Parameter-Inputs werden jetzt
   gebaut (Codex); Phase 1 optimiert nur Pattern; numerische Optimierung = Phase 2
   (AI_PARAM-Hebel, DL-088).
7. **Pilot:** QM5_13213/USDJPY über Instrument QM5_21501; Skalierung erst nach
   Pilot-Bewertung.
8. **Portfolio:** getrennte Bewertung FTMO und DXZ.

## Supersessions (bewusst, OWNER)

- Plan-v2-Entscheid E0-1 („Zensus selegiert nicht; Promotion quell-abgeleitet und
  vorregistriert") ist für v3 ersetzt durch datengetriebene Auswahl unter versiegelter
  Regel + WF + volle Trial-Deflation + Q16-Sealed-Head-to-Head.
- Charter-Kappe „≤ 1 Prädikat/Sleeve" → „≤ 3 je Richtung" (im Einklang mit DL-088).

## Warum ein Decision Record

Auswahlregel, Trial-Zahl und OOS-Protokoll sind Gate-Vertragsgrößen (ROT-Zone der
Stehenden Vollmacht) — sie binden die Auswertung, bevor Daten gesehen werden, und
dürfen nachträglich nur durch neuen OWNER-Entscheid geändert werden.
