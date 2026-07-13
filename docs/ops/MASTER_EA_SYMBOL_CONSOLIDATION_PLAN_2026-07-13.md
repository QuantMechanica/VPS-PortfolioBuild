# Master-EA / Symbol-Konsolidierung — Umsetzungsplan

**Auftraggeber:** OWNER (2026-07-13, inspiriert von Balke-Video XgfpXQzpJtk).
**Projektleitung:** Claude. **Programmierung:** headless Codex (Framework/Kern) +
headless Sonnet (Strategie-Module) — Claude reviewt, definiert Gates, fährt die
Regression, verantwortet den T_Live-Schritt.

## Ziel

Pro Symbol **einen** „Master-EA", der alle Survivor-Strategien dieses Symbols in **einem
Chart** handelt — je Strategie eigene Magic, eigenes Risk, eigene Parameter. Ergebnis:
MT5 aufgeräumt (23 Charts → ~10 Symbol-Charts), gleiche Trade-Identität (Magics
unverändert), gleiche Evidenz-Kette. Danach den Master-EA **neu backtesten** (= Symbol-
Portfolio-Sicht + Regressions-Beweis). Erst XAUUSD als Pilot, dann Template pro Symbol.

## Pilot-Scope: XAUUSD (5 Live-Strategien)

| EA | Slug | TF | Magic | Live-Risk% |
|---|---|---|---|---|
| 10403 | et-turtle20x | D1 | 104030002 | 0.234 |
| 10513 | mql5-ichimoku | D1 | 105130003 | 0.324 |
| 12567 | cum-rsi2-commodity | D1 | 125670003 | 0.794 |
| 12989 | grimes-nested-pb-v2 | H4 | 129890003 | 0.257 |
| 1556 | aa-zak-mom12 | D1 | 15560004 | 0.640 |

Alle D1/H4, Single-Position, low-freq → ideale Piloten (keine Tick-Komplexität).

## Architektur-Entscheidungen (Claude, verbindlich)

1. **Compile-time, nicht runtime-GUI** (anders als Balke). Grund: die V5-Pipeline verlangt
   deterministische, reproduzierbare Backtests. Ein .mq5 pro Symbol, Strategien als Module.
2. **★Magic-Erhalt ist NON-NEGOTIABLE.** Jede Sub-Strategie eröffnet unter ihrer
   ORIGINAL-Magic (`QM_MagicChecked(sub_ea_id, sub_slot, symbol)`). Das erhält q08-Streams,
   Live-Puls, Portfolio-Mathematik und die Qualifikations-Evidenz. Keine neuen Magics.
3. **Master-EA = Dispatcher**, kein neuer Edge. OnTick: Corset (KillSwitch/News/Friday)
   einmal, dann je aktiver Sub-Strategie: NoTradeFilter → Manage → Exit → (auf DEREN TF-
   NewBar) Entry mit DEREN Magic/Risk.
4. **TF-Explizitheit:** Sub-Strategien lesen Signale auf IHREM TF (`PERIOD_D1`/`PERIOD_H4`
   explizit, nicht `PERIOD_CURRENT`). Chart-TF wird irrelevant. Jede Portierung muss TF-
   hart machen (Audit-Punkt je Modul).
5. **q08-Stream dekomponiert automatisch** — der Two-Pass-Walk ordnet über die
   Eröffnungs-Magic zu. Master-Backtest → je-Magic-Stream = je-Strategie-Stream. Das ist
   der Hebel für die Regression (s.u.).
6. **KillSwitch/News/Friday** MVP = symbolweit geteilt (reicht; Book-Halt greift). Per-
   Strategie-DD-Halt (Balke-Feature) = v2, optional.
7. **Risk** je Sub-Strategie eigener RISK_PERCENT-Input; Summe = das bisherige Symbol-
   Budget. Viele Inputs (OWNER akzeptiert), gruppiert `strategyN_*`.

## ★Acceptance-Gate (der Beweis, dass Konsolidierung verhaltensneutral ist)

Master-EA über Full-History (2017–2025, Model 4) auf dem XAU-Chart laufen lassen →
je-Magic-q08-Stream extrahieren → gegen den EINZELN verifizierten Standalone-Stream jeder
Strategie diffen (die Referenzen aus dem 13.07.-Sweep: 10403 209/$14.411, 10513 76/$9.649,
12567 73/$4.677, 12989 51/$13.878, 1556 53/$6.370). **Match = Konsolidierung ändert kein
Verhalten.** Erst dann geht's live. (Nutzt die Verifikations-Infra vom 12./13.07.)
Für Centgenauigkeit läuft die Regression im **RISK_FIXED**-Modus mit den Standalone-Backtest-
Werten (Phase 2.5 liefert den expliziten FIXED-Pfad); Live-RISK_PERCENT ist ein separater
Sizing-Modus desselben Moduls.

## Phasenplan + Delegation

**Phase 0 — Spec (Claude, JETZT fertig):** dieses Dokument + Modul-Interface-Definition.

**Phase 1 — Framework-Multi-Magic (headless CODEX):**
- `QM_FrameworkInitMulti` o.ä.: mehrere (ea_id, slot)→Magic-Kontexte in einer Instanz.
- `QM_TM_OpenPosition` akzeptiert per-Call Magic + Risk% (statt global `g_qm_fw_magic`).
- `QM_LotsForRisk` per-Strategie-Risk.
- Rückwärtskompatibel: bestehende Single-Magic-EAs unverändert (Default-Pfad).
- **Gate:** ein bestehender Single-EA (z.B. 12567) kompiliert + backtestet identisch nach
  dem Framework-Change (Regression auf den 13.07.-Referenzen).

**Phase 1.5 — q08-Serializer per-Magic (headless CODEX) [NEU, aus Phase-1-Review]:**
- Befund (Codex-Design-Note 13.07.): der q08-JSONL-Writer sammelt owned position_ids, schreibt
  aber EINE Host-EA-Datei OHNE per-Row-Magic. Damit dekomponiert der Stream NICHT je Sub-Magic.
- Fix: `magic`-Feld je q08-Row ergänzen (aus dem Eröffnungs-Deal), backward-kompatibel
  (Single-Magic-EAs bekommen ihre Magic in die Row, Format-Superset). Nötig für (a) das
  per-Magic-Regression-Gate in Phase 4 und (b) spätere per-Strategie-Live-Attribution.
- **Gate:** 12567 reproduziert weiter 73/$4.676,76; die Row trägt jetzt magic=125670003.
- **Status Phase 1: ✅ ABGESCHLOSSEN + gemerged (c172395e); Gate GRÜN (12567 centgenau).**

**Phase 2 — Master-EA-Skelett + Modul-Interface (headless CODEX):**
- `framework/EAs/QM5_MXAU_master-xauusd/` (neue ea_id-Klasse, z.B. 20001).
- Dispatcher-OnTick; Strategie-Modul-Interface (`StratN_Entry/Exit/Manage/NoTrade`, TF,
  Magic-Kontext, Risk). Inputs `strategyN_*`. Registry-Eintrag + Resolver.
- **Gate:** kompiliert 0/0; mit 0 aktiven Modulen = No-Op-Backtest sauber.
- **Status Phase 2: ✅ ABGESCHLOSSEN + gemerged (430f917c5 Merge, 0832efc4e .ex5-Rebuild).**
  `CQMStrategyModule`-Interface (Init/Deinit/Enabled/Magic/TF/RiskPercent/NoTrade/ManageOpen/
  CheckExit/CheckEntry) + `QM_ModuleOwnsPosition`. Dispatcher: Corset einmal → per-Modul
  Manage/Exit immer → Entry auf Modul-TF-NewBar (auch bei entries_blocked konsumiert →
  kein Late-Entry-Bug). Master eröffnet NIE unter Host-Magic 200010000; 5 XAU-Sub-Magics
  als Closed-Allowlist; Init-Guards (Magic-Allowlist, TF≠CURRENT, Risk>0). Gate GRÜN
  (T8, unabhängig): Compile 0/0, No-Op-Smoke 0 Trades, MASTER_INIT_OK host_magic=200010000
  active_modules=0, Model-4 real ticks.
- **★Gate-Lektion (für Phase 3/4):** `run_smoke.ps1` deployt die `.ex5` fest aus
  `C:\QM\repo`, NICHT aus dem Worktree. Vor-Merge-Gates aus einem Worktree müssen die
  `.ex5` erst manuell ins Ziel-Terminal (`D:\QM\mt5\T<n>\MQL5\Experts\QM\`) kopieren, sonst
  `REPORT_MISSING` (deploy_skip=source_missing). Nach dem Merge greift der Deploy automatisch.
  Zusätzlich: `-MinTrades 0` wird von run_smoke auf den 5/yr-Ökonomie-Floor überschrieben →
  ein No-Op-Skelett meldet `MIN_TRADES_NOT_MET` trotz sauberem Run (run_01 status=OK zählt).

**Phase 2.5 — Expliziter Fixed-Lot-Sizing-Pfad (headless CODEX) [NEU, OWNER-Wahl A 13.07.]:**
- Befund: die per-Modul-Regression (Phase 3/4) muss das Standalone-**RISK_FIXED**-Backtest-
  Sizing centgenau reproduzieren. Standalones sizen im Backtest über RISK_FIXED (fixes
  Risiko-*Geld* `g_qm_risk_fixed`, Lots aus SL-Distanz). Phase 1 lieferte NUR einen expliziten
  PERCENT-Pfad (`QM_RiskSizerRiskMoney(equity, explicit_risk_percent)` / `QM_LotsForRisk(...,
  explicit_risk_percent)`) — der explizite FIXED-Branch fehlt.
- Fix: paralleler expliziter FIXED-Pfad (mode+value je Call), der den globalen FIXED-Branch
  (base_risk = fixed, × portfolio_weight, per_trade_cap) 1:1 spiegelt, ohne Globals zu
  mutieren. Durch `QM_TM_OpenPosition` threaden. Phase-1-PERCENT-Overload bleibt (backward-
  kompatibel; ggf. als Wrapper mode=PERCENT).
- **Gate:** (a) risk_sizer-Unit-Test beweist explizit-FIXED == global-FIXED (identisches
  risk_money + Lots für gleiche Inputs); (b) ein bestehender Single-EA (12567) reproduziert
  weiter 73/$4.676,76 (backward-compat). Kein Phase-3-Modul nötig — reiner Framework-Beweis.
- **Status Phase 2.5: ✅ ABGESCHLOSSEN + gemerged (9b4202b1e).** Overloads
  `QM_RiskSizerRiskMoney(equity, mode, value)` + `QM_LotsForRisk(sym, sl, mode, value)`
  (PERCENT delegiert an Phase-1-Pfad; FIXED spiegelt Global-Branch ohne Global-Mutation),
  durch `QM_TM_OpenPosition` + `QM_Entry` gethreadet. Gates GRÜN (T8, unabhängig):
  Unit `AssertExact` explicit-FIXED==global-FIXED (2 PASS, 0 fails) + 12567 = 73/$4.676,76.

**Phase 3 — die 5 XAU-Strategien als Module portieren (headless SONNET):**
- Je Strategie: Entry/Exit/Manage-Logik 1:1 aus dem Standalone-EA übernehmen, TF-hart,
  Original-Magic-Kontext. **Dualmodus (CLAUDE.md-Pflicht):** Regression = expliziter FIXED-Pfad
  mit dem `g_qm_risk_fixed`-Wert aus dem Standalone-Backtest-Set; Live = expliziter PERCENT-Pfad
  mit dem deployten Sub-Sleeve-Risk. Pro Modul der committete Standalone-Code als Quelle
  (nach dem 13.07.-Rebuild verifiziert).
- **Gate je Modul:** Master mit NUR diesem Modul aktiv, im **FIXED**-Regressionsmodus,
  reproduziert den Standalone-q08-Stream **centgenau** (Einzel-Regression vor der Integration).
  Deploy-Lektion aus Phase 2 beachten (Worktree-`.ex5` vor dem Smoke ins Terminal kopieren).

**Phase 4 — Integration + Full-Regression (CLAUDE fährt, Codex fixt Drift):**
- Alle 5 Module aktiv, Full-History-Backtest, je-Magic-Stream-Diff gegen alle 5 Referenzen.
- Bei Drift: Root-Cause (meist TF- oder Corset-Reihenfolge), Codex fixt, Re-Run.
- **Gate:** 5/5 Streams centgenau = grün für Live.

**Phase 5 — T_Live-Migration XAU (CLAUDE + OWNER, gated):**
- Master-EA-Preset (5 Sub-Risks = die deployten Werte), SHA-Deploy, Chart-Session:
  die 5 XAU-Einzel-Charts schließen → 1 XAU-Master-Chart. Magics unverändert → offene
  Positionen + History nahtlos. Hard-Rule-Workflow, OWNER-Freigabe, Verify.

**Phase 6 — Template pro Symbol:** NDX (3 Sleeves), EURUSD (3), AUDUSD, USDJPY, GBPUSD, …
Jeder Symbol-Master = Kopie des Patterns + dessen Survivor-Module. Pro Symbol Phase 3–5.

## Delegation-Contract (verbindlich, OWNER-Wunsch)

- **headless Codex:** Phase 1 (Framework-Kern), Phase 2 (Skelett/Interface), Drift-Fixes
  Phase 4. Grund: Framework-Änderungen = Codex' Default-Domäne, höchstes Risiko.
- **headless Sonnet:** Phase 3 (Modul-Portierung, mechanisch, Regel 24 Coding=Sonnet-Lane).
- **Claude (PM):** Specs, PR-Review, Regressions-Gates (T6–T10), Phase 5 T_Live, Reporting.
- Alle Programmier-Tasks laufen in `agents/*`-Worktrees; jeder PR muss sein Phasen-Gate
  bestehen, bevor Claude merged.

## Risiken + Guardrails

- **Live-Geld:** XAU läuft live (23-Buch). NICHTS an T_Live vor grüner Full-Regression +
  OWNER-Freigabe. Master-EA ist bis Phase 5 ausschließlich Backtest.
- **Framework-Change trifft ALLE EAs:** Phase-1-Gate (bestehender EA identisch) ist Pflicht,
  sonst gefährdet der Change das ganze Buch. Rückwärtskompatibilität = harte Anforderung.
- **Build-Atomarität** (Lektion 12./13.07.): jede Binary Build+Commit atomar; No-Op-Compile-
  Fix ist drin (`compile_one` force-rebuild).
- **Reversibel:** Master-EA ist additiv; Rollback = zurück zu den 5 Einzel-Charts (Presets
  bleiben archiviert), da Magics identisch.

## Sofort startbar (Phase 1)

Phase 1 ist **non-live, reversibel, im Worktree** → sicher sofort an headless Codex
delegierbar. Phase 5 (Live) bleibt OWNER-gated. Claude kann Phase 1 jetzt dispatchen,
sobald OWNER „los" sagt (oder die Codex-Lane läuft).
