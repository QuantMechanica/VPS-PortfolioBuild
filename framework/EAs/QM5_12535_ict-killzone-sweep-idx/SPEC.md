# QM5_12535_ict-killzone-sweep-idx - Strategy Spec

**EA ID:** QM5_12535
**Slug:** ict-killzone-sweep-idx
**Source:** ict-2022-model-canonical-2026-06-12
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades M15 liquidity sweeps inside fixed broker-time killzones. It looks for a closed bar that sweeps the nearest prior-day, Asia-range, or H1 pivot liquidity pool and closes back through it, then waits up to eight M15 bars for a market-structure shift plus a three-candle fair value gap. Entry is a limit order at the fair value gap midpoint, with the stop beyond the sweep extreme plus a 0.3 ATR(14) buffer and the runner target at 3R. The EA closes half at the opposite liquidity pool capped at 2R, and exits any remainder by the card's session time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for sweep-extreme stop buffer. |
| strategy_atr_buffer_mult | 0.30 | 0.0-2.0 | ATR multiplier added beyond the sweep extreme for stop placement. |
| strategy_max_risk_atr_mult | 2.50 | 0.5-10.0 | Skip entries where entry-to-stop distance exceeds this ATR multiple. |
| strategy_mss_max_bars | 8 | 1-32 | Maximum M15 bars allowed between sweep and displacement/MSS. |
| strategy_order_valid_bars | 8 | 1-32 | Pending FVG midpoint limit order lifetime in M15 bars. |
| strategy_h1_pivot_lookback | 24 | 4-96 | H1 pivot scan used for liquidity pools. |
| strategy_m15_pivot_lookback | 32 | 6-96 | M15 pivot scan used for MSS levels. |
| strategy_max_spread_points | 120 | 0-1000 | Maximum spread in points allowed for new entries; 0 disables this entry filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Card-listed Nasdaq index target for NY AM killzone liquidity sweeps.
- `WS30.DWX` - Card-listed Dow index target for NY AM killzone liquidity sweeps.
- `XAUUSD.DWX` - Card-listed gold target for NY AM killzone liquidity sweeps.
- `GDAXI.DWX` - Card-listed DAX target for London killzone liquidity sweeps.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - No broker-backed Custom Symbol history for build registration.
- Unlisted single equities or sector ETFs - The card is explicitly an index/gold fidelity variant, not a stock or ETF strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous-day high/low; H1 pivot highs/lows; M15 Asia range and execution bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday; limit order valid up to 8 M15 bars, runner exits by broker 21:00 for NY symbols or 16:00 for GDAXI |
| Expected drawdown profile | Approximately 10% card-level expected drawdown with FTMO daily/total DD awareness downstream |
| Regime preference | Liquidity sweep followed by displacement and volatility expansion inside killzones |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ict-2022-model-canonical-2026-06-12
**Source type:** video / in-house precedent
**Pointer:** https://www.youtube.com/@InnerCircleTrader and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12535_ict-killzone-sweep-idx.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12535_ict-killzone-sweep-idx.md`

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
| v1 | 2026-06-12 | Initial build from card | d02df8c0-476e-4f78-abc4-47b46c8915fc |
