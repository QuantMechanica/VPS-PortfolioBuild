---
ea_id: QM5_1387
slug: modified-schiff-pitchfork-h4
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: a64c1bd8-36f0-4190-94f8-26d4e51d6e88
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1387_modified-schiff-pitchfork-h4.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_PREMATURE_TRIGGER_REENQUEUE_FULL_BATCH_FIRST
---

# QM5_1387 modified-schiff-pitchfork-h4 — zero-trade rework critique

Router fired DL-062 on `completed=12 / fail=2 / zero_trade=2 (zt_pct=1.0)` with 25
P2 runs still **pending**. The trigger fired on a statistically insufficient sample
mid-batch. The two confirmed zero-trade fails are on in-whitelist symbols (USDCAD.DWX
and NDX.DWX), which is a real signal — but must be evaluated against the full batch
and the geometric-setup probability of a H4 pitchfork strategy.

## 1. Evidence sample (work_items)

| symbol       | status   | verdict    | notes                           |
|--------------|----------|------------|---------------------------------|
| USDCAD.DWX   | done     | FAIL       | in-whitelist; 0 trades          |
| NDX.DWX      | done     | FAIL       | in-whitelist; 0 trades          |
| XAUUSD.DWX   | failed   | INFRA_FAIL | in-whitelist; infrastructure    |
| SP500.DWX    | failed   | INFRA_FAIL | NOT in whitelist; should be OOU |
| USDJPY.DWX   | failed   | INFRA_FAIL | in-whitelist; infrastructure    |
| 7× more      | failed   | INFRA_FAIL | mix of in/out-whitelist         |
| 25× FX cross | pending  | —          | mostly out-of-whitelist         |

COUNTS: done/FAIL=2, failed/INFRA_FAIL=10, pending=25.

## 2. Root causes — not strategy mortality

### 2a. Premature DL-062 trigger (primary)

`fail_count=2` out of a still-in-progress 37-symbol dispatch is not a statistically
valid zero-trade sample. `zt_pct=1.0` is guaranteed any time early completions happen
to be zero-trade — which is expected for a geometric strategy that requires a specific
3-pivot configuration to form. With 25 runs still pending, the real zero-trade rate
may be much lower.

### 2b. Dispatcher universe mismatch (scope)

Card §"Zusätzliche Filter" gives an explicit symbol whitelist:
`EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF, XAUUSD, NDX.DWX, WS30.DWX,
GDAXI.DWX, UK100.DWX` — 11 symbols. SP500.DWX is explicitly excluded.

The dispatcher ran SP500.DWX (INFRA_FAIL), 20+ FX crosses (AUDCAD, AUDCHF, etc.),
and other out-of-whitelist symbols. Same bug as QM5_1088 / QM5_1089 / QM5_1096 /
QM5_1097 (memory `project_qm_dispatcher_universe_mismatch_2026-05-23`).

### 2c. Geometric-setup sparsity in a 1-year window (real, but not fatal)

The Modified-Schiff pitchfork fires only when a valid 3-pivot ABC configuration
forms within the last 100 H4 bars AND the current price is at the warning-line
rejection distance. In a 1-year window (2024 = ~6,500 H4 bars for 5-day symbols):

- **NDX.DWX 2024**: the index was in a near-uninterrupted bull trend January–July
  (ATH driven), corrected sharply July–August, then resumed upward into year-end.
  In a persistent trend, the pitchfork ML slopes steeply upward; price rarely
  reaches the LWL (the trigger boundary), so entries are infrequent. In a 1-year
  window, it is plausible that no qualifying 3-pivot bullish-reversion setup formed
  while price was simultaneously at the LWL.

- **USDCAD.DWX 2024**: CAD weakened steadily (oil weakness + Fed policy
  divergence). In a unidirectional trend, the "bearish Modified-Schiff" (for SELL
  trades) would dominate, but it requires P1 to be the highest of the three pivots.
  In a trending market with persistent lower highs, the P0/P1/P2 pivot structure may
  not form the specific ABC required.

A 1-year window for an H4 geometric strategy with a 100-bar lookback (covering
~16 trading days of history) and a 50-bar freshness gate is tight. The typical
pitchfork analyst reviews months of data to find valid setups; 1 year may contain
0–2 valid configurations on any given symbol, below the min_trades threshold.

This is **not** a dead edge — it is a sample-size issue. 5-year window is required
to assess the setup frequency reliably.

### 2d. INFRA_FAIL pattern on 10 symbols

10 symbols (XAUUSD, SP500, USDJPY, and 7 more) show `failed/INFRA_FAIL`. This
infrastructure failure pattern is not zero-trade evidence — these runs did not
complete. Possible causes:
- H4 history depth insufficient for the 100-bar ZigZag scan warm-up
- Set-file generation issue for some symbols
- The batch is mid-flight; terminal workers may have retried or timed out

INFRA_FAILs must be triaged separately — they do not contribute to the strategy
zero-trade verdict.

## 3. Why DL-062 fired

Two zero-trade fails on in-whitelist symbols, both at `fail_count/zt_count = 2/2 = 1.0`.
The classifier does not know that 25 runs are pending, that H4 geometric strategies
have inherently sparse setup frequencies, or that a 1-year window is insufficient
for this class of entry trigger.

**This DL-062 fire is premature (insufficient sample) + scope-contaminated by the
universe mismatch. Neither of the two zero-trade symbols has produced enough evidence
to call the edge dead.**

## 4. Recommended change vector

Reject the router hint to relax entry conditions. The Modified-Schiff geometric
rules (pivot detection, magnitude gates, warning-line touch, rejection bar, macro
bias, time-stop) are from the published Mikula/Morge methodology; relaxing them
destroys the strategy. Required actions, in order:

1. **Wait for current batch to complete**: the 25 pending runs may produce trades on
   in-whitelist FX/XAU/index symbols. The full batch COUNTS are the real DL-062 input.

2. **Ops (codex)**: honor the symbol whitelist from card §"Zusätzliche Filter". Do
   NOT fan Modified-Schiff across FX crosses or SP500 (explicitly excluded). Same fix
   shared with QM5_1088 / QM5_1089 / QM5_1096 / QM5_1097 / QM5_1048.

3. **Re-enqueue after scope fix**: in-whitelist 11 symbols only, H4, **≥5y window**
   (2019–2024 covers two major trend cycles + COVID volatility). Set
   `min_trades_required = expected_trades × years × 0.3` — the strategy card does
   not specify `expected_trades_per_year_per_symbol`, but the "~2 setups/yr/symbol"
   estimate from geometric sparsity gives `2 × 5 × 0.3 = 3` over the window — set
   floor at 3.

4. **INFRA_FAIL triage (codex)**: determine why 10 symbols received INFRA_FAIL.
   For in-whitelist symbols (XAUUSD, USDJPY) this blocks a complete zero-trade
   verdict.

5. **Edge Lab compliance**: card pre-dates the 2026-05-22 charter. Live parameters
   `RISK_PERCENT=0.5%` + `SL = 1.5×ATR(14,H4)` + time-stop at 24H4 bars are
   compatible with ≤5% daily / ≤10% total DD if portfolio concurrency is capped at
   2 simultaneous positions. News-filter declared (±15 min red-impact). Mechanical,
   no-ML, no grid/martingale — all satisfied. Add explicit FTMO-compliance block to
   card.

6. **Do NOT mark DEAD** based on 2 data points from a 37-run in-progress batch.

## 5. Falsification

If, after full-batch completion and re-enqueue on whitelist-only symbols at ≥5y,
the EA still produces 0 trades per symbol across the 5-year window, then the
critique is wrong and one of:
(a) The pivot-freshness gate (`P2_time ≥ T_now − 50 H4 bars`) is too tight for
    DWX symbols in the post-2019 regimes, preventing any setup from qualifying; or
(b) The macro-bias filter (`close[1] > (P0+P1)/2`) systematically rejects setups
    near the warning-line in DWX FX/index regimes.
Either would justify shortening the freshness gate or widening the macro-bias window
as separate specific recalibrations — not blanket entry relaxation.

## 6. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1387_modified-schiff-pitchfork-h4.md`
  — confirmed 11-symbol whitelist, SP500 explicitly excluded, H4 pitchfork mechanic,
  G0_APPROVED with R1-R4 all PASS.
- Direct sqlite query: 37 P2 rows total: 2 done/FAIL (USDCAD, NDX), 10 failed/INFRA_FAIL,
  25 pending. Batch NOT complete at time of DL-062 trigger.
- EA build confirmed: `D:\QM\mt5\T1\MQL5\Experts\QM\QM5_1387_modified-schiff-pitchfork-h4.ex5`
  (built 2026-05-19).
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`.
