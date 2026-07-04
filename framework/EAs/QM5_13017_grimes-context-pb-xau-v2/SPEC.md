# QM5_13017_grimes-context-pb-xau-v2 — Strategy Spec

**EA ID:** QM5_13017
**Slug:** `grimes-context-pb-xau-v2`
**Source:** `exit-surgery-10939-xau` — XAUUSD sibling of QM5_12990 (GBPUSD surgery)
**Author of this spec:** Claude
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

The EA trades H4 continuation pullbacks only when the D1 trend context agrees. A long setup requires the D1 close above EMA(50), EMA(20) above EMA(50), D1 ADX(14) at least 16, a recent H4 surprise leg that closes beyond a 30-bar high and moves at least 2.5 ATR(20), then a 25%-55% controlled pullback that holds H4 EMA(20). It enters long after an H4 close above the pullback's 3-bar high; shorts mirror the same rules in a D1 downtrend.

**v2 surgical change (XAUUSD):** `strategy_time_exit_h4_bars` extended from 18 to 36 (72h → 144h hard ceiling). All entry, stop, target, breakeven, and 61.8%-retracement-exit logic are unchanged from the parent (QM5_10939). Evidence: Q08 hold-gradient scan showed all 12 trades in the >3d bucket killed at TIME_MGMT exits with WR 83% and avg net +575 — the 72h ceiling amputates every winner in the best bucket. See `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`, §3.3.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_13017_grimes-context-pb-xau-v2.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 1-200 | ATR period for surprise, pullback quality, stop buffer, and maximum stop checks. |
| `strategy_d1_fast_ema` | 20 | 1-200 | Fast D1 EMA used for trend context and H4 pullback EMA quality. |
| `strategy_d1_slow_ema` | 50 | 1-300 | Slow D1 EMA used for trend context. |
| `strategy_d1_adx_period` | 14 | 1-100 | D1 ADX period for weak-context rejection. |
| `strategy_d1_adx_min` | 16.0 | 0-100 | Minimum D1 ADX required before entry. |
| `strategy_surprise_lookback` | 12 | 1-50 | Maximum H4 bars over which the surprise leg may form. |
| `strategy_breakout_lookback` | 30 | 5-200 | Prior H4 high/low window the surprise leg must close beyond. |
| `strategy_surprise_atr_mult` | 2.5 | 0.1-10.0 | Minimum surprise-leg distance in ATR units. |
| `strategy_climax_bar_atr_mult` | 3.0 | 0.1-10.0 | Rejects surprise legs with a single oversize bar. |
| `strategy_pullback_min_bars` | 3 | 1-20 | Minimum H4 pullback length after the surprise leg. |
| `strategy_pullback_max_bars` | 10 | 1-50 | Maximum H4 pullback length after the surprise leg. |
| `strategy_pullback_min_pct` | 25.0 | 0-100 | Minimum pullback retracement as percent of surprise leg. |
| `strategy_pullback_max_pct` | 55.0 | 0-100 | Maximum pullback retracement as percent of surprise leg. |
| `strategy_trigger_lookback` | 3 | 1-10 | Pullback high/low trigger window for entry confirmation. |
| `strategy_pullback_bar_atr_mult` | 1.5 | 0.1-10.0 | Maximum allowed pullback bar range in ATR units. |
| `strategy_stop_atr_buffer` | 0.25 | 0-5.0 | ATR buffer beyond the pullback extreme for stop placement. |
| `strategy_max_stop_atr_mult` | 2.25 | 0.1-10.0 | Rejects entries whose stop distance exceeds this ATR multiple. |
| `strategy_target_r_mult` | 2.0 | 0.1-10.0 | Profit target in initial-risk units. |
| `strategy_breakeven_r_mult` | 1.5 | 0.1-5.0 | Open profit in R required before moving stop to breakeven. |
| `strategy_time_exit_h4_bars` | 36 | 1-100 | **v2 surgical delta:** time exit after 36 H4 bars (144h). Parent used 18 (72h). |
| `strategy_spread_stop_max_pct` | 8.0 | 0-100 | Rejects entries when spread exceeds this percent of stop distance. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0, magic 130170000)

**Explicitly NOT for:** any symbol not in the list above. Surgery scope is XAUUSD only — the hold-gradient evidence (WR 83%, avg +575 in >3d bucket) was measured on the XAUUSD Q08 run of QM5_10939. The GBPUSD sibling surgery is QM5_12990.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(20), D1 EMA(50), D1 ADX(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "H4 context pullback on XAUUSD. Conservative estimate 20-30 trades/year. Surgery v2 tests whether extending the time exit from 72h to 144h recovers the >3d edge." |
| Typical hold time | Up to 36 H4 bars (144h), roughly six trading days. |
| Expected drawdown profile | Controlled by structural stop capped at 2.25 ATR and one active position per symbol/magic. |
| Regime preference | Context-filtered trend continuation after volatility expansion and controlled pullback. |
| Win rate target (qualitative) | Medium-high (targeting the >3d bucket WR 83% that the parent amputated). |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "Context in Pullbacks: What Should Happen?", 2023-11-29, https://www.adamhgrimes.com/context-in-pullbacks-what-should-happen/
**R1-R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_13017_grimes-context-pb-xau-v2.md`
**Exit surgery evidence:** `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`, §3.3

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-05 | Initial build from exit-surgery card | XAUUSD sibling of QM5_12990; surgical delta: strategy_time_exit_h4_bars 18->36 |
