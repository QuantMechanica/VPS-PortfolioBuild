I now have everything needed, all key conflicts resolved against the files. Final verification summary before synthesizing:

- **Containment released 07:44Z, 10/10 workers alive, census flowing** (8 active, throughput recovering).
- **Q12 hold inert** (2,565 cells/48h) but **14 of 21 held pairs have no `_opt` build** — the real census-frontier lever.
- **Live book is fine** (WARN-level manifest gap, KS 23/24, DD 2.64%, trading) — Plan A's #1 lever is factually wrong.
- **EV audit confirms FTMO positive-EV at 0.50x** but names real-execution/slippage as the one open measurand — same gate as DXZ.
- **MNT-036 package exists** (needs refresh+sign, not from-scratch); **pointer unsigned** (`approved_by=null`); **provenance repair done** (58b96908); **atomic budgeter NOT_IMPLEMENTED**.

---

# QuantMechanica V5 — CEO-Exekutionsplan (Start 2026-09-02)
*Synthese aus 3 Perspektivplänen (DXZ-first / FTMO-first / Throughput-first) + verifiziertem Audit-Digest. Alle Konflikte gegen die Dateien geprüft. Read-only.*

## 1 · Strategische These (ein Absatz)

**Beide Geld-Venues hängen an EINER heute unbeantworteten Frage — nicht an 25 Paaren.** Das lebende 24-Sleeve-DXZ-Buch (real gefüllt seit 19.07) zeigt realisierte Sharpe −3,25 gegen modellierte +2,4 (−1,3σ über 40 Tage). Dasselbe Buch ist laut `EV_FUNDED_ACCOUNT.md` für FTMO bei 0,50× positiv-EV (Break-even-Gebühr 15,5–26k$ gegen ~540$ reale Gebühr, auf *beiden* Messbasen) — mit *real execution/slippage* als der einzigen offenen Messgröße, wörtlich §5. Beide Venues laufen also durch **dieselbe Rekonziliation**: ist die −3,25/+2,4-Lücke Slippage (fixbar, These überlebt) oder fehlende Edge (beide Venues scheitern)? Das ist MNT-036, fällig **2026-09-06**, und das Paket ist bereits zu ~80 % gebaut. `book_build_guard` liefert authoritativ `qualified_pairs=0` und braucht ohnehin eine separate OWNER-Order — die 25-Paar-Zensur (Plan C) ist **notwendig aber nicht hinreichend**: sie erzeugt ein größeres, diversifizierteres Buch (besser für beide Venues *später*), aber keine bewiesene Edge, und darf den Edge-Read nicht verdrängen. Die drei Pläne sind keine konkurrierenden Wege, sondern **ein Weg mit gemeinsamem Wurzel-Gate** (der Edge-Read auf dem existierenden Buch) plus eine Durchsatzmaschine, die zuverlässig darunter weiterlaufen muss. Der eine hochwertigste Hebel dieser Woche ist daher, den Edge-Read sauber zu liefern und das existierende Buch provenance-sauber/signiert zu machen — nicht, die Nullwert-Zensur zu beschleunigen.

## 2 · Kritischer Pfad zum ersten Geld je Venue (mit Daten)

**Gemeinsames Wurzel-Gate (beide Venues): Edge-Read.** `2026-09-06` — MNT-036 refresh (rekonziliertes P&L/D-Score-Export + Slippage-vs-absent-edge-Attribution für 1556/XAU, 10706/GBP, 13128/NDX) → OWNER zeichnet 3-Sleeve-Dispositionen. Ergebnis „Slippage" ⇒ beide Thesen überleben; „absent edge" ⇒ beide Venues zurück ans Reißbrett.

**FTMO (strukturell der schnellere erste Payout, entkoppelt von 25 Paaren):**
- `09-02…09-05` Doktrin-Reframe (Timebox raus, Admission = „forward-EV@0,50× + überlebt 5%/10%-Caps") + FTMO-konformes swap-positives Subset wählen + atomischen Pre-Trade-Daily-Loss-Budgeter bauen (`runtime_integration=NOT_IMPLEMENTED`, harte Voraussetzung).
- `09-06` Edge-Read (gemeinsam).
- `~09-14` EV-Neurechnung auf dem *exakten* Subset + Budgeter validiert.
- `~09-16` **OWNER-Kauf/Nicht-Kauf-Einseiter** (EV-Tabelle, Subset, Budgeter-Status, Edge-Attribution, reale Gebühr vs Break-even, evidenzbasierte Pass-Wahrscheinlichkeit).
- OWNER kauft (Geld-Limit) → CEO startet P1@0,50×, kein Zeit-Clock, nur Cap-Proximity-Alarme → +10% (P1) → +5% (Verification) → funded → 60-Tage-Payout-Zyklus.
- **Ehrliches Datum:** Entscheidungspaket = Mitte-September-Lieferung. Erster Payout realistisch Q4-2026→Q1-2027, aber schneller und mit ~540$/Versuch billig iterierbar. **Kein 25-Paar-Gate, keine Zensur, kein Free-Trial-Probe nötig.**

**DXZ (größeres Kapital, langsamer; Uhr = Track-Record-Länge×Qualität des existierenden Buchs):**
- `09-06` Edge-Read (gemeinsam) + Roster nach Probation fixiert.
- `~09-08` unsigned Dry-Run-Pointer + Provenance-Vorlage → OWNER zeichnet aktuelles Roster + signiert `live_deployment_pointer.json` → Risk-Freeze SP-A1/A2 hebt auf → Buch ist reproduzierbar/provenance-sauber (`live_book_pulse` WARN klärt). Provenance-Repair der 10 Presets ist bereits erledigt (Task 58b96908). **Live-Buch-Bindung = OWNER, nicht Selbst-Signatur.**
- Danach: Monate sauberer, low-DD Track-Record. **D-Score-Reset-Frage** (setzt Roster-Erweiterung die DarwinIA-Uhr zurück?) MUSS vor jeder Buch-Erweiterung beantwortet werden.
- `~09-16+` optional: Interim-Q11-Buch (21 Q11-PASS-Paare) verbreitert den Track-Record Monate früher — *falls* OWNER den Q11-Trigger (ROT) freigibt und die D-Score-Frage günstig ausfällt.
- **Ehrliches Datum:** September-Lieferung = allokations-*fähiges* (signiert, reproduzierbar, edge-attribuiert) und verbreitertes Buch. Erste DXZ-Allokation Q1-2027, konditioniert auf den Edge-Read.

## 3 · Rangierte Aktionsliste

### Nächste 72h (bis ~2026-09-05)
| # | Aktion | Owner | Aufwand | Zone |
|---|--------|-------|---------|------|
| 1 | **Operating-Doktrin reframen:** erstes Geld = Edge-Read des existierenden Buchs, NICHT time-to-25. Board/Mission Control umpriorisieren. (Sealed OWNER-DEC-A1-Trigger bleibt unberührt — nur interne Steuerung.) | claude-interactive | 1h | GRÜN |
| 2 | **MNT-036-Delta bauen:** rekonziliertes P&L/D-Score-Export + backtest-vs-live-Attribution für 1556/10706/13128 auf das existierende 2026-08-21-Paket; SP-E5-Matrix OWNER-signaturreif. Fällig 09-06. *Der Edge-Read — gated beide Venues.* | claude-interactive | 3–4h | GRÜN |
| 3 | **Atomischen FTMO-Pre-Trade-Daily-Loss-Budgeter** kommissionieren (Spec Rulepack Z.274/288; `runtime_integration=NOT_IMPLEMENTED`). Harte Voraussetzung für jeden bezahlten Challenge. | claude-headless | 8–10h | GRÜN |
| 4 | **14 fehlende `_opt`-Sibling-Builds** kommissionieren (XAU zuerst: 10145,10403,10513,11294,21502; dann 20086×2,21505,11660,9641,10911,20048,12855,12849). Card→Source→governed COMPILE_EA, seriell. *Echter Zensur-Frontier-Hebel.* | claude-headless | ~20h | GELB |
| 5 | **T11/T12 einfrieren** (93c6959b/8f0b1b9e/a7c69b44 mit throughput-neutraler Notiz parken) + **durable Containment-Fix** (`raise … from exc` in `custom_history_copy_on_claim.py`, Per-Terminal-Quarantäne); Codex baut, Claude reviewt; **Scope-Change → OWNER** mit 4-Trips-in-12h-Ledger. | claude-interactive→codex | 0,5h + 3h | GELB (Scope=ROT) |
| 6 | **Q14-Analytic-Lane bedienen:** f81a14df/64604d7a als KEEP_INCUMBENT terminal schließen; Orphan-HEAD_TO_HEAD superseden (append-only). *NB: erhöht `qualified_pairs` NICHT (nicht Q14-kontiguierlich) — reine Lane-Hygiene.* | claude-interactive | 1h | GRÜN |
| 7 | **EINE gebündelte OWNER-Vorlage** (alle ROT/Geld zusammen): (a) FTMO-Admission-Reframe ratifizieren; (b) Interim-Q11-Buch-Entscheid (Q11-Trigger + Concentration-Policy-Ratifikation + Zensur-als-Parallel-Challenger) — mit vorab beantworteter D-Score-Reset-Frage und der `Q10_NEWS=CONFIG_LOCKED`-Kontiguitäts-Warnung; (c) Notiz: Pointer-Signatur folgt MNT-036. | claude-interactive | 4h | ROT-Bündel |
| 8 | **Schtask-Hygiene:** ExecutionTimeLimit erhöhen für PumpMaintenance/Dashboard/HourlyMonitor/UnbuiltCards (alle bei 267014 gekillt); ~12 tote One-offs deregistrieren. | codex | 2–3h | GRÜN |
| 9 | **Claude-Headless-Lane bei HANDOFF re-enablen** (nie mid-session — Duplicate-Session-Race). Measure/collect/_opt/dry-run → Sonnet; Codex nur Frontier. | handoff | 0,5h | GRÜN |

### Nächste 7d (bis ~2026-09-09)
- `09-06` **MNT-036 → OWNER**; OWNER zeichnet 3-Sleeve-Dispositionen (Edge-Read komplett). — owner
- **FTMO-konformes swap-positives Subset** wählen (2026-07-30-FTMO-Swap-Snapshot + venue cost) + **EV-Neurechnung auf exaktem Subset** @0,44/0,50/0,60×. — claude-headless, 6h
- **Budgeter fertigstellen + validieren** gegen 5%/10%-Caps. — claude-headless
- **14 `_opt`-Builds abschließen**; Zensur-Frontier 8→~22 Paare (throughput-neutral bis Fleet-Stunden, aber notwendig). — claude-headless
- Nach OWNER-Roster-OK + MNT-036: **unsigned Dry-Run-Pointer + Provenance-Vorlage** → OWNER signiert → Freeze SP-A1/A2 hebt auf → `live_book_pulse`-WARN klärt. — claude-interactive prep → owner sign
- **v4-Buch-Zeremonie end-to-end Dry-Run** auf 3 Pilotpaaren (build_book_dxz --dry-run → manifest → deploy_tlive_book --dry-run → pointer unsigned → verify → validate_golive), kein Live-Write. — claude-headless, 8h
- Silent-Failure-Monitor nach Business-Relevanz partitionieren; tote BLOCKED/RECYCLE-Zeilen bulk-archivieren (append-only). — codex/sonnet

### Nächste 30d (bis ~2026-10-02)
- `~09-16` **FTMO-Kauf/Nicht-Kauf-Einseiter → OWNER**; bei Kauf: P1@0,50× starten, Cap-Alarme, kein Clock. — owner (Geld)
- Bei OWNER-OK: **Interim-Q11-DXZ-Buch** aus best-diversifiziertem Q11-Subset bauen (die 21 Paare sind XAU/XTI-lastig — Diversitäts-Caps erzwingen), Q12–Q14 als Parallel-Challenger. — owner-Trigger, dann claude
- Zensur auf ~22 fähigen Paaren bei wiederhergestellten ~72–80 cells/h; Q12→Q14-Ketten per Analytic-Lane bedienen.
- **2026-OOS-Bestätigungspass** auf bereits importierten 2026-Q1..Apr-Daten (window_source-getaggt, ROT-sicher, kein OFF-Fenster) für Buch-Frontier-Paare; Dukascopy-Backfill→2026-07 als OWNER-Buch-Eligibility-Vorlage. *(Buch handelt Sep-2026-Regime, bewertet bis 2025-12-31.)*
- **D-Score-Reset-Frage** klären (DXZ-Docs/Support) vor jeder Buch-Erweiterung.
- Later-Bucket-Tooling-Debt nur falls Codex-Quota frei wird.

## 4 · STOP-Liste (explizit, alle evidenzbelegt)

1. **STOP** time-to-25 / Q12-Zensur als Master-Gate für erstes Geld. `qualified_pairs=0`, braucht ohnehin OWNER-Order; Zensur ist n=1 all-KEEP_INCUMBENT; beide Geldpfade laufen über den Edge-Read des existierenden Buchs. Zensur bleibt Parallel-Challenger, nie Trigger.
2. **STOP** alle T11/T12-Ignitionen (93c6959b/8f0b1b9e/a7c69b44). Host CPU-bound bei 10 Terminals (~96%, 60,8% Util, 247 CPU-Pauses/h); jeder Versuch löste Fleet-weite Containment aus. Netto-negativ bis De-Serialisierung.
3. **STOP** die 27.08-Compute-Accelerators als Durchsatzhebel zählen. `warm_cell_runner` lief 0,53× + Byte-Parity-Fail; Native-Optimizer kann keine Per-Pass-Trade-Lists/entry_trading_days liefern. Als NOT_FEASIBLE_AS_BUILT schließen; DURCHSATZ-Forecast korrigieren. Planungsbasis: kalt ~72–80 cells/h.
4. **STOP** einen Factory_OFF/ON-Zyklus oder Runtime-Activation-Decision brennen, um den `Q12_DL089`-Rollout-Hold zu lösen. Er ist inert (2.565 Zellen/48h unter gehaltenen Parents), self-cleart bei Zensur-Abschluss. (Als billige Hygiene per governed re-enqueue lösbar — aber kein OFF/ON-Fenster/OWNER-Token dafür.)
5. **STOP** neues Card-Sourcing + build_ea-BLOCKED/RECYCLE-Re-Attempts (280 BLOCKED + 60 RECYCLE). Supply ist nicht der Constraint (3.941 Cards, 420 gebaut-nie-eingetreten). Tote Zeilen auf Sonnet bulk-archivieren.
6. **STOP** measure/collect/_opt-builds/Zeremonie an gedrosseltes Codex (proj. 224% EOW) routen. Codex nur Frontier; Rest an ~98%-idle Sonnet.
7. **STOP** den Free-FTMO-Trial-Live-Forward-Probe als Edge-Test. Trial expired; Single-Sleeve ≠ komponiertes Buch. Das DXZ-Live-Buch IST das komponierte Live-Forward-Experiment.
8. **STOP** die `live_book_pulse`-ALARM als „Sleeves dunkel / Track-Record wird vernichtet"-Notfall behandeln. Es ist eine WARN-Manifest-Reconciliation-Lücke (`live_preset_path=null`), gleiche Wurzel wie der unsignierte Pointer; KS-Baseline 23/24 loaded_ok, Buch handelt. Pointer signieren ⇒ klärt.
9. **STOP** (NICHT tun) busy_timeout auf 30000ms standardisieren (invertiert die bewusste Short-Timeout-Claim-Path-Doktrin — SCHÄDLICH). 750ms-Claim-Path-Default lassen.
10. **STOP** den Claude-Headless-Heartbeat mid-session warm halten (Duplicate-Session-Race). Nur bei Handoff re-enablen.

## 5 · Doktrin: CEO-Autorität (jetzt umsetzen) vs OWNER-only

**CEO setzt eigenständig um (GRÜN/GELB, danach berichten):**
- Erstes Geld vom 25-Paar-Gate entkoppeln als *Operating*-Doktrin (Board-Steuerung; der sealed OWNER-DEC-A1-Trigger bleibt formell bestehen).
- Compute-Accelerators als NOT_FEASIBLE schließen; ~72–80 cells/h als Planungsbasis.
- T11/T12-Expansion einfrieren bis 10-Terminal-Util nachhaltig >85%.
- Card-Sourcing/build_ea-Re-Attempts einfrieren; tote Zeilen archivieren.
- Codex→Frontier-only; Sonnet-Lane für Rest re-admittieren (bei Handoff).
- 14 `_opt`-Builds, Q14-Lane-Hygiene, Schtask-Hygiene, Factory-hours-lost-KPI (Alarm ~55–61%-Decke, NICHT 80%).
- Containment-*Code*-Fix (`raise … from exc`).

**Nur OWNER (Geld / AutoTrading / ROT — eskalieren):**
- Jeder Kauf: FTMO-Gebühr, Hardware. *(Geld)*
- AutoTrading-Toggle T_Live. *(Hard-Limit)*
- `live_deployment_pointer` signieren / Risk-Freeze aufheben — Live-Buch-Bindung. *(Live-Konto = ROT; Provenance-first + frische Approval, keine Selbst-Signatur)*
- Interim-Q11-Buch / Buch-Trigger von Q14-terminal auf Q11-PASS ändern. *(Candidate-Pool/Buch-Trigger, sealed OWNER-DEC-A1)*
- Concentration/Tail-Policy ratifizieren (`concentration_tail_limits.v1.json → OWNER_RATIFIED`). *(Sealed Threshold)*
- Zensur-Waiver als Buch-Gate; MNT-036-Sleeve-Dispositionen (REDUCE/REMOVE live). *(Live-Konto)*
- Containment-SCOPE (fleet-wide → per-terminal). *(Containment-Scope)*
- Dukascopy-2026-Backfill als Buch-Eligibility-Gate (bereits DEFERRED).
- **Explizit NICHT CEO-umdefinierbar: Gate-Thresholds/Kriterien.** Das ist ein Sicherheits-Invariant (Goodhart/Selbst-Benotung), kein Legacy-Cruft — Audit-Finding GOV-01 (Envelope-Rewrite) wurde genau deshalb widerlegt. Der brief-Satz „everything else can be redesigned" gilt für Ops/Tooling, nicht für die Kriterien, an denen das Buch benotet wird.

## 6 · Factory/Tooling-Rebuilds: jetzt vs später

**JETZT (geldrelevant, auf/nahe kritischem Pfad):**
- Durable Containment-Fix (Cause-Chaining + Per-Terminal-Quarantäne) — entfernt den dominanten Durchsatz-Tax. *(Scope → OWNER)*
- 14 `_opt`-Builds (Sonnet) — Zensur-Frontier.
- Atomischer FTMO-Budgeter (Sonnet) — hartes Gate für bezahlten Challenge.
- Factory-hours-lost-KPI auf existierender Telemetrie (throughput_telemetry.py, concurrency_ab_measure.py) — billig.
- Schtask-Hygiene (267014-Kills, tote One-offs); Silent-Failure-Monitor nach Relevanz partitionieren.

**SPÄTER (echte Schuld, aber off-critical-path; opportunistisch, nicht jetzt bei gedrosseltem Codex):**
- `farmctl.py` 30.318-Zeilen-Monolith in Package carven (D10-03) — modul-für-modul, wenn Codex-Quota frei.
- SQLite VACUUM (189MB toter Freelist) + Composite-(phase,status)-Index — NUR in geplantem OFF-Fenster; **750ms-Claim-Path-busy_timeout NICHT anfassen** (D10-02 widerlegt).
- Jobs-Table von History-Store trennen — erst Consumer enumerieren.
- One-off-Script-Archiv (~46), docs/ops-Runbook-Konsolidierung (6.428 Files), Stale-DB-Backups (1,1GB) rotieren — GRÜN-Housekeeping auf Sonnet.
- Zeremonie-Stack-Unifikation (Single-Fleet-Manifest) — später und nur via OWNER (Scope=ROT); D10-01 als CRITICAL widerlegt (Live-Ursache war copy-on-claim, nicht Binding-Scope → der schmale raise-from-Fix ist der richtige erste Schritt).

## 7 · Täglich zu beobachtende Metriken

1. **Factory-hours-lost-by-class / Slot-Util** (Decke ~55–61%; Alarm bei Woche deutlich darunter) + done-cells/h (gesund ~72–80).
2. **Containment-Trips/Tag** (Ziel 0; jeder Fleet-weite Trip = Stunden Seriell).
3. **Live-Buch:** DD% (Halt 10%; jetzt 2,64%), Equity vs HWM (101.871), **Sleeves-traded-count** (die „10 von 24"-Frequenz-Frage), `live_book_pulse`-Verdikt (sollte nach Pointer-Signatur auf OK klären), `breached`-Flag.
4. **Live-vs-modeled-Edge** (−3,25 vs +2,4 — die geldentscheidende Zahl; mit MNT-036-Rekonziliation aktualisieren).
5. **Zensur-Frontier:** kontiguierliche `qualified_pairs` (authoritativ, jetzt 0), gebaute `_opt`-Programme (9→23), OPT_CENSUS-Zellen/48h.
6. **Agent-Lanes:** Codex-projected-EOW% (Throttle), Claude-Headless-Heartbeat-Frische + Weekly-Quota (Reset 09-03T22Z).
7. **Datierte Deadlines:** MNT-036 (09-06), Budgeter-Build-ETA, Pointer-Signatur-Readiness.

---

## Konfliktauflösung — welcher Plan gewann und warum

| Streitpunkt | Gewinner | Warum (Datei-Beleg) |
|---|---|---|
| **Live-Buch „14 Sleeves dunkel" (Plan A #1-Hebel)** | **Plan A verliert (Fakten)** | `live_book_pulse.json`: Verdikt ALARM aber alle 26 Alarme = WARN; KS-Baseline loaded_ok=23/24; DD-Guard liest Live-Equity alle ~30s (DD 2,64%, breached=false), handelt heute. `loaded_sleeve_count=0` = Manifest-Reconciliation-Lücke (alle `live_preset_path=null`), gleiche Wurzel wie unsignierter Pointer. Kein Track-Record-Void. → Herabgestuft von „#1-Notfall" auf „Pointer signieren, WARN klärt". |
| **FTMO viabel jetzt (Plan B) vs geparkt-korrekt (Plan A)** | **Split — Plan B gewinnt Doktrin, Plan A/Audit gewinnt Sequenzierung** | `EV_FUNDED_ACCOUNT.md` bestätigt Plan B: komponiertes Buch @0,50× positiv-EV (Break-even 15,5–26k$ beide Basen); Timebox ist OWNER-Direktive, keine FTMO-Regel. Audit-ECON-02-Korrektur („Speed 0,96 killt FTMO") verwechselt Single-Sleeve-Speed mit Buch-EV und ist zu stark. ABER: entscheidend ist NICHT der Reframe, sondern derselbe Edge-Read wie DXZ + Budgeter (NOT_IMPLEMENTED) + OWNER-Geld. Plan Bs Free-Trial-Probe verliert (ECON-03 widerlegt: Trial expired, Single-Sleeve ≠ Buch). |
| **Zensur wertlos / Interim-Q11-Buch (Plan A/C, D6-01) vs Zensur-Funktion (D8-02 widerlegt)** | **Interim-Buch-Vorlage gewinnt als Vorschlag; „zero info value" verliert an Präzision** | `optimization_fork/`: n=1 echte Zensur (41162/EURUSD, pattern-0-best), alle KEEP_INCUMBENT. OWNER-DEC-A2 machte KEEP_INCUMBENT terminal genau um diese Kosten zu senken. Interim-Buch ist die größtmögliche Kompression und billig/sicher als OWNER-Vorlage — aber „wertlos" überzeichnet n=1 und ignoriert die Overfit-Resistenz-Evidenz. |
| **Q12-Hold P0 (brief/Plan C) vs inert (D1-01)** | **Inert gewinnt** | 2.565 OPT_CENSUS-Zellen/48h unter aktiv gehaltenen Parents (DB-verifiziert). Echter Hebel: 14 der 21 gehaltenen Paare haben KEIN `_opt`-Programm (nur 7 mappen auf die 9 existierenden 41xxx). Plan Cs „Hold lösen ⇒ 19 Paare ⇒ 3× Durchsatz" verliert; Plan Cs 14-Build-Aktion gewinnt. |
| **Compute-Accelerators wiren (ECON-01) vs tot (D1-03/Plan C)** | **Tot gewinnt** | warm-runner 0,53× + Byte-Parity-Fail; Native-Optimizer kann Per-Pass-Trade-Lists nicht emittieren. ECON-01s „14h wire and flip" ist von seinen eigenen Korrekturen widerlegt. |
| **T11/T12** | **Konsens: STOP** | Alle 3 Pläne + Audit (D3-F3): CPU-bound bei 10 Terminals; jeder Versuch trippte Containment. |
| **Swap-Capture (Plan A/B)** | **Bereits geparkt gewinnt (niedrigere Prio)** | D9-02 widerlegt: reale Swap-Daten existieren (2026-07-30-FTMO-Snapshot), bereits als SP-C4/C5 getickt; DXZ-Live-Buch ist die swap-inklusive Ground-Truth. |
| **MNT-036 Build-Aufwand (beide Pläne)** | **Delta gewinnt** | Paket existiert (`2026-08-21_probation_package_mnt036.md`, 19KB) + SP-E5-Matrix. Braucht Refresh+Rekonziliation+Signatur, nicht from-scratch. Beide Pläne überzeichnen den Aufwand. |
| **Claude-Headless-Lane** | **Konsens mit Safety-Caveat** | Re-enable nur bei HANDOFF (D7-1-Korrektur: mid-session warm = Duplicate-Session-Race). |
| **Reliability vs Kapazität als Durchsatz-Tax** | **Plan C gewinnt** | ~55–60% der 7-Tage-Stunden an zwei Incident-Klassen verloren; der durable Containment-Fix (raise-from + Per-Terminal) ist der echte Kapazitätshebel, nicht Expansion. |

**Verbleibende offene, geldkritische Frage (an OWNER/DXZ):** Setzt eine Roster-Erweiterung (Interim-Buch) die DarwinIA/D-Score-Uhr zurück? Nicht lokal beleg­bar; MUSS vor jeder Buch-Erweiterung beantwortet werden, sonst schlägt der DXZ-Accelerator ins Gegenteil um.