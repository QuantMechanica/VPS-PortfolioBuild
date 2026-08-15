# Century-Suite Intake Triage — 100 Strategy Cards (QM5_30001–QM5_41012)

**Date:** 2026-08-15
**Decider:** Claude (G0 intake authority), on OWNER instruction to analyze and queue the
Desktop drop `Strategy_Cards_Overview.md` ("Master Century Suite", 12 pillars).
**Verdict:** 82 APPROVED · 16 REJECTED · 2 DEFERRED.

## Provenance & claim hygiene

The source document self-declares "G0 APPROVED" using foreign nomenclature (G0/R1–R4
tables, "Factory CEO", per-card PF 2.10–2.85, win rates, "pass rates"). None of those
numbers carry evidence paths — they were treated as **unevidenced marketing claims and
ignored** (Hard Rule: evidence over claims). Only the mechanical card bodies were
evaluated. Approval stamped conservative ordering priors instead (PF 1.20–1.35,
DD 12–25% by timeframe/class); Q02–Q10 measure reality.

All 100 card files existed untracked in `strategy-seeds/cards/` and are mechanically
complete (schema v2, deterministic shift-1 rules, closed-form sizing). Frequency
boilerplate ("80-160 trades/year" on 97/100 cards) was replaced by conservative
per-TF `expected_trades_per_year_per_symbol` (M1 250 · M5 150 · M15 110 · H1 70 ·
H4 40 · D1 25; grid 30001: 20).

## Rejected (16) — `farmctl reject-card`, g0_status: REJECTED

| EA | Reason class | Reason |
|---|---|---|
| QM5_30004 | R4 Hard Rule | Feedforward ANN filter = ML forbidden (card self-declares FAIL) |
| QM5_30007 | R4 Hard Rule | LLM sentiment module = ML/LLM forbidden (self-declared FAIL) |
| QM5_40006 | R4 + R3 | Lorentzian KNN = ML; BTC/ETH not in DWX universe |
| QM5_31001 | Closed line | ICT Silver Bullet retired 2026-06-27 (no mechanical edge); SMC/ICT closed |
| QM5_31008 | Closed line | Gold Reaper do-not-clone (vol-gated EOD-flat already ported as QM5_20007) |
| QM5_32005 | R3 | Russell 2000 not in DWX universe, no mapping |
| QM5_32006 | R3 | BTCUSD not in DWX universe |
| QM5_34002 | R3 | Brent leg unavailable — two-leg cointegration unbuildable |
| QM5_41007 | R3 | No VIX feed in MT5/DWX universe |
| QM5_41008 | R3 | Roll-yield needs futures-curve data absent from CFD feed |
| QM5_40001 | Duplicate | Turn-of-month = QM5_1049 (approved) |
| QM5_40003 | Duplicate | Connors RSI(2) = QM5_10429 / QM5_10523 (SP500+NDX covered) |
| QM5_40004 | Duplicate | Cumulative RSI(2) = QM5_10430 (SP500+NDX covered) |
| QM5_40007 | Duplicate | AQR TSMOM = QM5_1056 moskowitz-tsmom-multiasset |
| QM5_41004 | Duplicate | Golden Cross 50/200 = QM5_10114 |
| QM5_41012 | Duplicate | TTM Squeeze = QM5_10395 |

Duplicate rejections: symbol extension belongs to the existing EA's scope, not a new
card. Do not re-litigate closed lines (Orthogonal Return Sources Program discipline).

## Deferred (2) — g0_status: DEFERRED, not in reservoir

QM5_32002 (ES VWAP absorption) and QM5_32004 (index gap fill): index-intraday-MR
cluster cap from the Orthogonal Return Sources Program 2026-08-13 — **one build until
probe-ticket 166696e5 correlation evidence lands** (sibling of dispatched card
68333e26). Re-evaluate on probe completion.

## Approved (82) — normalization applied

- **Symbol normalization** to `framework/registry/dwx_symbol_matrix.csv`:
  US500→SP500, NAS100→NDX, GER40→GDAXI, WTICRUDE→XTIUSD, US30→WS30 (all `.DWX`);
  futures aliases NQ→NDX, ES→SP500, CL→XTIUSD, GC→XAUUSD, 6E→EURUSD; micro/FDAX
  contracts dropped. Frontmatter `target_symbols`/`primary_target_symbols` + body
  tokens rewritten; a "Target Symbols & Timeframe (QM execution normalization)"
  body section appended to every approved card.
- **Grid cards** (30001, 30005, 30006, 38007): approved with the binding note that the
  V5 grid cap applies — per-grid-cycle risk ≤1% equity + `QM_KillSwitch`; the source
  EAs' 20–30% equity-stop parameters are their numbers, not ours.
- **Volume-profile cards** (41009, 41010): MT5 tick-volume approximation with
  venue-session redefinition; Q02/Q04 judge whether the auction edge survives.
- EA IDs 30001–41012 reserved atomically via `farmctl reserve-ea-ids`
  (strategy_id `MASTER-CENTURY-SUITE-2026-08-15`); rejected rows set `retired`,
  deferred rows `allocated`, approved rows `active`.
- Cards copied to `strategy-seeds/cards/approved/` (repo record) and
  `D:\QM\strategy_farm\artifacts\cards_approved\` (runtime reservoir).
  **Post-copy prebuild validation: 82/82 READY.**

## Incidental factory-wide defect found & fixed

`prebuild_validate_card` was failing for **every** reservoir card (new and legacy) on
`magic_registry_duplicate`: the 2026-08-12 XBRUSD→XTIUSD re-symboling of the Brent
family left 23 stale `retired` XBRUSD rows in `framework/registry/magic_numbers.csv`
whose magics were re-owned by active XTIUSD rows (status-blind duplicate scan).
Fix: dropped the 23 stale rows (12841…20171, git history preserves them), regenerated
`QM_MagicResolver.mqh` (15964 rows, sha 6E04BA92…). Legacy card QM5_21508 re-validates
READY. Without this fix the entire approved reservoir was invisible to the build lane.

## Evidence

- Plan/results: session scratchpad `century_plan.json`, `century_results.json`
  (a5fb6dbe-91a5-4edd-9416-e4c90f60845a)
- Farm DB events: `card approved`/`card rejected` ×98, 2026-08-15 (farm_state.sqlite)
- Registry: `framework/registry/ea_id_registry.csv` (+100 rows), `magic_numbers.csv` (−23 rows)
- Validation: 82/82 READY via `prebuild_validate_card` + `strategy_card_schema_issues`
