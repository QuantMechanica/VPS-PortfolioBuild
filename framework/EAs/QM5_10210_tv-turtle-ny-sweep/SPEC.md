# QM5_10210_tv-turtle-ny-sweep - Strategy Spec

**EA ID:** QM5_10210
**Slug:** `tv-turtle-ny-sweep`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA builds a pre-New-York reference high and low from the same NY calendar day before the cash open. After the NY open, a long setup requires a sweep below the reference low followed by a bullish expansion candle back above that low; a short setup requires a sweep above the reference high followed by a bearish expansion candle back below that high. Entry is at a retrace into the confirmation candle body, using a limit order when price has not retraced yet, with the stop beyond the sweep extreme plus a 0.25 ATR(14) buffer and the target at the opposite side of the reference range. Open positions are flattened at the NY cash-session close if the range target has not been reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe_minutes` | 5 | 5 or 15 | Strategy bar timeframe; non-15 values use M5. |
| `strategy_preopen_start_hhmm_ny` | 0 | 0-2359 | Start of the NY-time reference window. |
| `strategy_ny_open_hhmm` | 930 | 0-2359 | NY cash-session open gate. |
| `strategy_ny_flat_hhmm` | 1600 | 0-2359 | NY cash-session flat time. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for expansion and stop buffer. |
| `strategy_stop_atr_buffer` | 0.25 | 0.0-5.0 | ATR multiple added beyond the manipulation extreme. |
| `strategy_expansion_atr_mult` | 1.20 | 0.1-5.0 | Minimum body size versus ATR unless body-ratio test passes. |
| `strategy_expansion_body_ratio` | 0.60 | 0.0-1.0 | Minimum body share of full candle range unless ATR test passes. |
| `strategy_retrace_body_fraction` | 0.50 | 0.0-1.0 | Retrace level inside the confirmation candle body. |
| `strategy_max_scan_bars` | 240 | 30-500 | Maximum closed bars scanned for the intraday session range. |
| `strategy_pending_expiry_minutes` | 120 | 1-600 | Expiry for retrace limit entries. |
| `strategy_max_spread_atr_fraction` | 0.20 | 0.0-1.0 | Spread no-trade threshold as a fraction of ATR. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index analog named in the card; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index CFD analog named in the card and live-routable.
- `WS30.DWX` - Dow 30 index CFD analog named in the card and live-routable.

**Explicitly NOT for:**
- Symbols outside the three registered index CFDs - the card does not authorize a broader universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Expected trade frequency | intraday, at most one long and one short per NY session |
| Typical hold time | minutes to same-day NY session close |
| Expected drawdown profile | fixed-risk single-position index reversal trades |
| Regime preference | NY open liquidity-sweep reversal after volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/qfqRq8DM/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10210_tv-turtle-ny-sweep.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | e6a7eb40-b053-4fae-ac44-a9075b8f5bfc |
