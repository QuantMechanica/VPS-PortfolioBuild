# DL-082 grid allocation and deterministic build gate

- Date: 2026-08-17
- Router task: `f24e9f6d-b354-434d-b155-1caa54848d8a`
- Scope: `QM5_30001`, `QM5_30005`, `QM5_30006`, `QM5_38007`
- Authority: `DL-082_grid_cap_extended_commercial_ea_deconstructions.md` (ADOPTED), extending the bounded-grid exception in DL-081 to exactly these four cards
- Outcome: **PARTIAL — governed allocation complete; source builds deterministically gated on missing or unrepresentable card mechanics**

## Decision

The four strategies are authorized bounded-grid builds. The earlier Edge Lab charter refusal is not repeated here. No card was rejected because it uses a grid or martingale progression.

The build nevertheless cannot proceed mechanically from the approved cards. `QM_TM_Grid.mqh` requires a concrete base lot, one fixed positive grid distance, a bounded level count, and a declared sizing progression at `QM_GridInit`; its configuration-time loss calculation assumes that same fixed distance for every level. The build contract forbids inventing absent alpha or silently replacing a card's declared schedule. The four generated `Unknown Strategy` skeletons therefore remain unchanged.

The DL-082 bound was not weakened. No value above `1.0%` was selected or proposed.

## Governed allocation completed

The allocation ran as one rollback-capable transaction under `D:\QM\strategy_farm\state\governed_magic_allocator.lock`, using the canonical allocator's validation and `apply_plan` path. It appended 14 active rows and did not retire, delete, or rebind any existing row.

| EA | Slot | Symbol | Magic |
|---|---:|---|---:|
| QM5_30001 | 0 | AUDCAD.DWX | 300010000 |
| QM5_30001 | 1 | AUDNZD.DWX | 300010001 |
| QM5_30001 | 2 | NZDCAD.DWX | 300010002 |
| QM5_30005 | 0 | EURUSD.DWX | 300050000 |
| QM5_30005 | 1 | GBPUSD.DWX | 300050001 |
| QM5_30005 | 2 | AUDUSD.DWX | 300050002 |
| QM5_30005 | 3 | USDCAD.DWX | 300050003 |
| QM5_30006 | 0 | AUDCHF.DWX | 300060000 |
| QM5_30006 | 1 | GBPCHF.DWX | 300060001 |
| QM5_30006 | 2 | EURCHF.DWX | 300060002 |
| QM5_30006 | 3 | NZDCHF.DWX | 300060003 |
| QM5_38007 | 0 | AUDCAD.DWX | 380070000 |
| QM5_38007 | 1 | NZDCAD.DWX | 380070001 |
| QM5_38007 | 2 | EURCHF.DWX | 380070002 |

The canonical resolver regenerator reported `17337 rows kept, 0 dropped` after the allocation and an overlapping three-row QM5_33007 allocation. Commit `c3f3261be` durably contains all 14 rows and the regenerated resolver; that concurrent commit's resolver records 17,337 rows and registry SHA-256 `1C8994180714305099DACE0E4E7EE4D4C1C41FF6B11A5713B1F8386B65CEC5D3`. Later shared-registry changes are unrelated to this task and were not staged or claimed here.

Focused registry checks found:

- 14/14 requested rows present and active;
- zero duplicate magic values across the registry;
- zero duplicate `(ea_id, symbol_slot)` keys across the registry;
- every magic equals `ea_id * 10000 + symbol_slot`.

## Per-card build gates

### QM5_30001 — Waka Waka

The card defines the Level-0 BB/RSI trigger, base lot, level count, and lot progression. Its grid spacing is not representable by the existing module's validated configuration: levels use a widening 24/24/28/28/35/40/45/50-pip schedule multiplied by `ATR_D1[1] / ATR_Historical_Mean`, while `QM_GridInit` accepts one fixed integer `level_distance_pips` and validates loss using that uniform distance. The card never defines the historical ATR mean's lookback or an upper bound on the ratio. Substituting one distance would change the strategy and could understate the declared schedule's worst-case loss.

Required amendment: define the ATR historical mean and a finite multiplier bound, then either provide a module-compatible fixed basket distance or authorize a separately reviewed extension of the shared grid primitive that validates the actual per-level schedule. This ticket does neither.

### QM5_30005 — Dark Venus

The card defines the initial Bollinger entry, 15-pip distance, 1.50 progression, seven levels, and basket exit. It does not define the condition that opens levels 2..7. Its sizing formula depends on `SL_Distance_Points`, but the exact rules define no order stop distance from which a base lot can be calculated. The no-trade rule also blocks whenever one strategy position is already open, contradicting progression beyond Layer 1.

Required amendment: define the adverse-move/reference rule for each added level, a closed-form base-lot input compatible with the 1% basket cap, and the intended exception to the one-position filter.

### QM5_30006 — Dark Kronos

The card defines the initial trend/RSI entry, basket TP/SL, and a `0.01` linear lot increment. It does not define a grid distance, maximum grid levels, base lot, or added-level trigger. The no-trade rule blocks at one position while the strategy is classified as a linear grid. Those omissions prevent a mechanical `QM_GridInit` configuration and `QM_GridOpenNextLevel` path.

Required amendment: define the complete grid schedule (reference price, adverse-distance rule, level limit, base lot, and progression) plus the intended one-position-filter exception.

### QM5_38007 — ATR grid engine

The card defines ATR spacing, linear lots, five levels, and thresholds relative to `FirstEntry`. It never defines how Level 0 / `FirstEntry` is created or how the initial long-versus-short direction is selected. The no-trade rule again blocks at one position, contradicting the five-level basket.

Required amendment: define the Level-0 trigger and direction-selection rule and the intended one-position-filter exception.

## Package and verification state

The approved cards were copied byte-for-byte into each package as `docs/strategy_card.md`:

| EA | Strategy-card SHA-256 |
|---|---|
| QM5_30001 | `EADB4BE6E563DAFE29FA137A44DB847AE132833FD1AA826532115A8832A5A572` |
| QM5_30005 | `03656638E5901DB785847C5DB8D00277E1CE269662E1FA43F112A23D5640219C` |
| QM5_30006 | `C672451791B526A20A45F04CCA4C9E18DC3D67B9E87653B04349735D53CB786E` |
| QM5_38007 | `053F40D06661AEED85C4DE3CFD0BCF0CAD8F1433828F306FF60C4A9BE2A19B6F` |

For each EA, the source is still the pre-existing 126-line `Unknown Strategy` skeleton with its manual-implementation TODO. There is no EX5, no SPEC, and no set file. Consequently:

- `QM_GridInit` and the every-tick `QM_GridMaxDrawdownGuard` calls cannot honestly be claimed present;
- compile/build checks are not applicable to an implementation that was not created;
- no backtest or pipeline phase was run;
- first-backtest maximum aggregate floating loss is **NOT AVAILABLE**;
- no `floating_loss_exceeds_cap` conclusion or pipeline verdict is asserted.

This is a fail-closed build gate, not a profitability or pipeline verdict.

## Explicitly deferred DL-082 questions

- Starting-equity snapshot versus current/day-start/static-initial equity: divergence recorded; no basis changed here.
- Book aggregation: a per-EA 1% bound does not compose across multiple grid sleeves; no portfolio policy was invented here.

No T_Live or AutoTrading setting was enabled, no terminal was started, no running backtest was interrupted, and neither QM5_10771 nor the live roster was touched.
