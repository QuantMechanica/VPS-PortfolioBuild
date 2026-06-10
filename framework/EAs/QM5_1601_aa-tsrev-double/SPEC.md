# QM5_1601_aa-tsrev-double — Strategy Spec

**EA ID:** QM5_1601
**Slug:** `aa-tsrev-double`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude (Board Advisor)
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

At the start of each calendar month the EA evaluates the symbol's 24-month return history.
It splits those 24 months into an older block (t-24 to t-13) and a recent block (t-12 to t-1).
If the older block return is positive and the recent block return is also positive, the symbol is classified as a "realized winner."
If the older block return is negative but the recent block return is positive, the symbol is classified as a "contrarian loser."
Both groups are expected to have positive forward returns per Liu & Papailias (2023) via Alpha Architect.
The EA enters a long position on the first D1 bar of the new month when the symbol qualifies, and closes the position on the first D1 bar of any subsequent month when it no longer qualifies.
Stop loss is set at 3x ATR(20, D1) below the entry price.
Because the MT5 tester cannot generate MN1 bars for custom symbols, monthly boundaries are detected by comparing the calendar month of successive D1 bar open times.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_old_ret_start_months` | 24 | 13-36 | Older return block start in months ago |
| `strategy_old_ret_end_months` | 13 | 2-24 | Older return block end in months ago |
| `strategy_recent_ret_start_months` | 12 | 2-24 | Recent return block start in months ago |
| `strategy_recent_ret_end_months` | 1 | 1-6 | Recent return block end in months ago |
| `strategy_trading_days_per_month` | 21 | 18-23 | Trading-day approximation used to convert months to D1 bar offsets |
| `strategy_sl_atr_mult` | 3.0 | 1.5-6.0 | Stop loss distance in multiples of ATR(period, D1) |
| `strategy_atr_period` | 20 | 10-50 | ATR lookback for stop-loss sizing |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 US large-cap index; backtest-only (broker does not route orders); strong liquidity and long history from 2018
- `NDX.DWX` — Nasdaq 100 US large-cap index; live-tradable; strong trend and reversal dynamics
- `WS30.DWX` — Dow Jones 30 US large-cap index; live-tradable; complements SP500/NDX in US basket
- `GDAXI.DWX` — DAX 40 German index; live-tradable; adds geographic diversification
- `UK100.DWX` — FTSE 100 UK index; live-tradable; adds geographic diversification

**Explicitly NOT for:**
- Forex pairs — monthly return momentum/reversal dynamics differ from equity indices
- Commodities — different seasonality and regime dynamics

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all signal computation uses D1 bars only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default); month-change detected within new-bar handler |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly rebalance cadence) |
| Typical hold time | 1 month (one calendar month on average) |
| Expected drawdown profile | Moderate; single-symbol ATR stop limits catastrophic loss per position |
| Regime preference | Mean-revert + trend (contrarian loser and realized winner both trade long in upward-trending month) |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** paper / blog
**Pointer:** Larry Swedroe, "Combining Reversals with Time-Series Momentum Strategies", Alpha Architect, 2023-04-07
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1601_aa-tsrev-double.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | cef1eed4-12d2-4b5e-9976-71bb11b1ab1a |
