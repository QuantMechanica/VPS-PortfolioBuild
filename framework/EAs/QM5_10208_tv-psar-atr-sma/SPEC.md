# QM5_10208_tv-psar-atr-sma - Strategy Spec

**EA ID:** QM5_10208
**Slug:** `tv-psar-atr-sma`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades H1 trend-following reversals from the approved TradingView PSAR ATR SMA card. It enters long when the last closed bar closes above SMA(100) and Parabolic SAR flips from above price to below price. It enters short when the last closed bar closes below SMA(100) and Parabolic SAR flips from below price to above price. There is no fixed take profit; the initial stop is 6.0 x ATR(14), and the open position is managed with a one-way ATR trailing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Base timeframe for SMA, ATR, and PSAR calculations |
| `strategy_sma_period` | `100` | `50-200` P3 sweep range | Trend filter length |
| `strategy_atr_period` | `14` | `1+` | ATR lookback used for stop distance |
| `strategy_atr_stop_mult` | `6.0` | `3.0-6.0` P3 sweep range | Initial and trailing ATR stop multiplier |
| `strategy_psar_start` | `0.02` | `>0` | PSAR acceleration factor start |
| `strategy_psar_increment` | `0.02` | `>0` | PSAR acceleration factor increment |
| `strategy_psar_maximum` | `0.20` | `>0` | PSAR acceleration factor cap |
| `strategy_max_spread_stop_fraction` | `0.15` | `0.0-1.0` | Blocks entry when spread exceeds this fraction of ATR stop distance |
| `strategy_psar_warmup_bars` | `80` | `20+` | Bounded closed-bar warmup window for custom PSAR state |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid FX pair with SMA, ATR, and PSAR available from DWX OHLC
- `GBPUSD.DWX` - card target; liquid FX pair with the same indicator surface
- `XAUUSD.DWX` - card target; gold CFD with DWX OHLC and ATR/PSAR portability
- `GDAXI.DWX` - DWX matrix DAX custom symbol used in place of card-stated `GER40.DWX`
- `NDX.DWX` - card target; Nasdaq 100 index CFD with DWX OHLC and trend-following fit

**Explicitly NOT for:**
- Any symbol not registered above - this EA relies on active `magic_numbers.csv` rows and does not expand the universe at runtime.

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
| Trades / year / symbol | `60` |
| Typical hold time | Not specified in frontmatter; ATR trailing stop implies multi-hour to multi-day trend holds |
| Expected drawdown profile | Fixed-risk trend system with losses bounded by the ATR stop and framework risk sizing |
| Regime preference | Trend-following; prefers sustained directional moves after PSAR reversals |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/sbDSg0RD-PSAR-with-ATR-Trailing-Stop-SMA-Filter/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10208_tv-psar-atr-sma.md`

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
| v1 | 2026-06-09 | Initial build from card | 2ce271ab-f3a2-4f8c-a057-b3efe3b4c0fc |
