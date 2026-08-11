# QM5_9644_bandy-tps-bounded-mr-index — Strategy Spec

**EA ID:** QM5_9644
**Slug:** `bandy-tps-bounded-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press 2015, ISBN 978-0-9791037-7-1 — TPS layered mean-reversion, here recast into an R4-compliant bounded 3-unit scale-in on US equity-index proxies)
**Author of this spec:** Claude (capacity-spilled build_ea)
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Daily-bar, long-only, bounded 3-unit scale-in mean-reversion on index CFDs. On each
closed D1 bar the EA computes `z = (Close - SMA(Close,20)) / StdDev(Close,20)`, a
200-day close SMA regime gate, and ATR(14). A ladder of three equal-risk units is
opened as the market stretches further below its mean, every rung gated by
`Close > SMA200`: unit-1 when flat and `z <= -2.0`, unit-2 when 1 unit is held and
`z <= -2.5`, unit-3 when 2 units are held and `z <= -3.0`. There is a hard cap of
three units (structural — not a tunable input) — no further adds occur on deeper `z`.
All units share ONE magic and are tracked by an internal `units_held` counter
(persisted via GlobalVariables), never by multiple magic numbers. The whole position
exits together on any of: `z >= 0` take-profit (exit at the next session open), a
10-trading-day time stop measured from the unit-1 entry, or an aggregate catastrophic
stop at `entry_unit_1 - 4.0*ATR(14)` (ATR snapshotted at unit-1 entry). Additions
(unit-2/3) are skipped once >15 trading days have elapsed since unit-1; new entries
are skipped when ATR(14)/Close is in the top 1st percentile of the trailing 252 bars;
unit-1 (only) is additionally blocked within ±30 min of high-impact news. All indicator
and percentile state is computed once per closed D1 bar and cached; the per-tick path
reads only cached state plus the current Bid/Ask.

### units_held state machine & aggregate stop (the novel/risky piece — read carefully)

- **State (per magic, persisted via `GlobalVariableSet`/`Get`, keyed
  `QM_9644_<symbol>_*`):** `units_held ∈ {0,1,2,3}`, `unit1_entry_price`,
  `unit1_atr` (ATR snapshotted at unit-1 entry, fixed), `unit1_entry_time`,
  `unit1_cat_stop` (the aggregate stop level), `bars_since_unit1`. GlobalVariables
  survive terminal restarts within the same terminal → satisfies the card's
  persistence requirement without multiple magics. On `OnInit` (and again on the
  first tick) the loaded state is reconciled against live positions: if `units_held>0`
  but no live position carries this magic, the state is reset to flat (guards against
  a stale GlobalVariable left by a prior tester run in the shared pool).
- **One unit per closed D1 bar.** The ladder rung is latched in the once-per-bar
  `AdvanceDaily()` and fired at the next session open; `units_held` is only advanced
  on a CONFIRMED fill (`OnUnitFilled`). The 3-unit cap is enforced by having exactly
  three fixed ladder rungs with no path beyond unit-3 — it cannot be exceeded.
- **Aggregate stop — single fixed level, two enforcement paths at the SAME price.**
  `cat_stop = unit1_entry_price - 4.0*unit1_atr`, computed once at unit-1 fill and
  held fixed for the life of the ladder. Every leg (unit-1/2/3) is opened with
  `req.sl = cat_stop`; because the level is identical and never changes, there is no
  per-leg `OrderModify` race. In addition, `Strategy_ManageOpenPosition` runs an
  authoritative per-tick VIRTUAL stop: if the current Bid breaches `cat_stop` it
  flattens ALL legs atomically (`CloseAllLegs(QM_EXIT_SL_HIT)`) rather than relying on
  the tester filling three separate broker SLs. Both mechanisms fire at the identical
  level, so they are always consistent.
- **Per-unit sizing = 1/3 of the budget to the SHARED stop.** Each unit is opened via
  the explicit-risk overload `QM_TM_OpenPosition(req, ticket, magic, RISK_MODE,
  budget/3)` (RISK_FIXED/3 in backtest, RISK_PERCENT/3 live) with `req.sl = cat_stop`.
  Because every leg risks 1/3 of the budget measured to the same aggregate stop, the
  three legs sum to the full budget at the stop → bounded worst-case ≈ the budget
  (no martingale, no per-unit doubling; HR14 bounded-worst-case).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_z_lookback` | 20 | 10-50 | SMA/StdDev period for the z-score (D1). |
| `strategy_regime_ma_period` | 200 | 100-300 | Long-only regime gate SMA(Close, N, D1). |
| `strategy_z_entry_unit1` | -2.0 | -3.0..-1.0 | Enter unit-1 when flat and z <= this. |
| `strategy_z_entry_unit2` | -2.5 | -3.5..-1.5 | Add unit-2 when 1 unit held and z <= this. |
| `strategy_z_entry_unit3` | -3.0 | -4.0..-2.0 | Add unit-3 when 2 units held and z <= this. |
| `strategy_z_exit` | 0.0 | -0.5..+0.5 | Take-profit: exit ALL when z >= this (zero line). |
| `strategy_time_exit_days` | 10 | 5-21 | Exit ALL after N closed D1 bars from unit-1 entry. |
| `strategy_stale_ladder_days` | 15 | 10-30 | Skip unit-N (N>1) if > N days elapsed since unit-1. |
| `strategy_atr_period` | 14 | 5-30 | ATR period (D1) for the catastrophic-stop distance. |
| `strategy_catastrophic_atr` | 4.0 | 3.0-5.0 | Aggregate SL = entry_unit_1 - mult * ATR(14, D1). |
| `strategy_vol_lookback` | 252 | 60-504 | Trailing-window length for the chaos percentile filter. |
| `strategy_vol_top_pctile` | 1.0 | 0.5-5.0 | Skip new entries if ATR/close in the top N-th percentile. |

The 3-unit cap is deliberately NOT an input (it is a Hard-Rule-14 bounded-worst-case
constraint, realised as three fixed ladder rungs). Framework inputs of note:
`qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30` with
`qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ` (unit-1 news blackout, entry path only);
`qm_friday_close_enabled = false` (multi-day holds span weekends up to the 10-day time
stop). Per-unit risk is 1/3 of `RISK_FIXED` (backtest) or `RISK_PERCENT` (live).

---

## 3. Symbol Universe

Registered (all present in `dwx_symbol_matrix.csv` with the correct `.DWX` suffix),
slots 0-2 — the full US large-cap index basket per the P2 Saturation Rule:

- `SP500.DWX` (slot 0, magic 96440000) — S&P 500; the card's backtest-primary index
  (OWNER-provided Custom Symbol ticks 2018-07→2026-05); Bandy's canonical US-equity
  proxy.
- `NDX.DWX` (slot 1, magic 96440001) — Nasdaq 100; live-tradable growth index;
  parallel-validation target for the T_Live promotion gate.
- `WS30.DWX` (slot 2, magic 96440002) — Dow 30; live-tradable broad US large-cap index;
  second parallel-validation target.

All three are index CFDs whose mean-reversion dynamics port directly to the same
z-score/SMA200 ladder (card R3 PASS). SP500.DWX is backtest-primary; NDX/WS30 are
live-routable and registered regardless per the P2 saturation rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (z-score / SMA200 / ATR / vol-percentile state all on `PERIOD_D1`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` — state advances once per closed D1 bar; per-tick path reads cached state only |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~5` (card `expected_trades_per_year_per_symbol: 5`; note a "trade" may comprise up to 3 scale-in legs) |
| Typical hold time | `a few days up to the 10-trading-day time stop` |
| Expected drawdown profile | `~22% expected DD (card expected_dd_pct: 22.0)` |
| Regime preference | `mean-reversion inside a confirmed bull regime (Close > SMA200)` |
| Expected PF (card) | `~1.18 (card expected_pf: 1.18)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** `Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press (2015), ISBN 978-0-9791037-7-1 — TPS (Time-Price-Score) layered mean-reversion, recast into an R4-compliant hard-capped 3-unit bounded scale-in on US equity-index proxies`
**R1 lineage recorded and R2-R4 PASS** per `artifacts/cards_approved/QM5_9644_bandy-tps-bounded-mr-index.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 total budget, split 1/3 per unit (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent, split 1/3 per unit |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%), split 1/3 per unit |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The 1/3-per-unit split is applied via the explicit per-call risk overload of
`QM_TM_OpenPosition`, NOT via `PORTFOLIO_WEIGHT` (which stays 1.0 for Q11 to assign).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial build from card | build task d9102952-d408-4b39-a53a-f395807f9840 |
