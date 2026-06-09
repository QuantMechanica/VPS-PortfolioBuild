# QM5_10217_tv-price-vol-brk - Strategy Spec

**EA ID:** QM5_10217
**Slug:** `tv-price-vol-brk`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar, the EA compares the breakout candle against the previous `strategy_breakout_lookback` bars. It opens long when the closed candle closes above the prior high benchmark, its tick volume is above the prior maximum tick volume, and price is above the trend SMA. It opens short on the mirrored downside breakout when close is below the prior low benchmark, tick volume exceeds the prior maximum, and price is below the trend SMA. Exits are the card's V5 protective bracket: stop distance is the wider of breakout-bar structure and ATR, capped at the ATR cap, and take profit is `strategy_tp_r_mult` times that risk; an opposite signal closes the prior opposite position before replacement entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_breakout_lookback` | 20 | 2-500 | Number of prior closed bars used for price and tick-volume breakout benchmarks. |
| `strategy_trend_ma_period` | 50 | 2-500 | SMA period used as the trend filter. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the protective stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiple used as the minimum volatility stop. |
| `strategy_atr_cap_mult` | 3.0 | >0 | ATR multiple used as the maximum stop cap. |
| `strategy_tp_r_mult` | 2.0 | >0 | Take-profit multiple of the final stop risk. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread gate; 0 disables this strategy-level filter. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card-listed high-volatility gold CFD with native DWX tick volume.
- `NDX.DWX` - card-listed index CFD proxy for high-volatility large-cap technology exposure.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` DAX exposure.
- `EURUSD.DWX` - card-listed major FX pair with DWX OHLC and tick-volume coverage.
- `GBPJPY.DWX` - card-listed high-volatility FX cross with DWX OHLC and tick-volume coverage.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol outside the registered list above - magic resolution rejects unregistered symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Not specified in card frontmatter; bracket exits imply hours to days depending on breakout follow-through. |
| Expected drawdown profile | Fixed $1,000 risk per backtest trade, bounded by framework risk and kill-switch controls. |
| Regime preference | Volatility-expansion breakout with volume confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/jc2hs2qK-Price-and-Volume-Breakout-Buy-Strategy-TradeDots/`
**R1-R4 verdict (Q00):** all PASS - see `artifacts/cards_approved/QM5_10217_tv-price-vol-brk.md`

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
| v1 | 2026-06-10 | Initial build from card | 8a59ecde-044e-4c15-baa4-baee0a2df571 |
