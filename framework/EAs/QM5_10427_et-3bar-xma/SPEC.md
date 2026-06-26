# QM5_10427_et-3bar-xma - Strategy Spec

**EA ID:** QM5_10427
**Slug:** `et-3bar-xma`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades an M15 stop-entry breakout after three consecutive same-color completed bars. Long setups require the last three completed bars to close above their opens, the latest close to remain below its high, the latest close to be above EMA(200), a three-bar high-low range below 0.75 ATR(20), and a latest-bar body/range ratio above 0.65. Short setups mirror the same rules below EMA(200) and place a sell stop at the three-bar low.

Stops use the larger of the setup range and 0.75 ATR(20). Targets use 0.5 times the setup range, and discretionary exits close at the configured broker-time session close. The framework handles risk sizing, magic validation, news, kill switch, and Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_xma_period` | 200 | 1+ | EMA trend-filter length from the card's XAverage(200). |
| `strategy_atr_period` | 20 | 1+ | ATR period for range cap and V5 stop floor. |
| `strategy_max_range_atr_mult` | 0.75 | >0 | Maximum three-bar setup range as a multiple of ATR(20). |
| `strategy_min_stop_atr_mult` | 0.75 | >0 | Minimum stop distance as a multiple of ATR(20). |
| `strategy_body_range_min` | 0.65 | >0 | Latest completed bar body/range threshold. |
| `strategy_target_range_mult` | 0.50 | >0 | Target distance as a multiple of the setup range. |
| `strategy_entry_buffer_points` | 0 | 0+ | Optional stop-entry offset beyond the three-bar high/low. |
| `strategy_window1_start_hhmm` | 0 | 0-2359 | First allowed broker-time entry window start. |
| `strategy_window1_end_hhmm` | 2359 | 0-2359 | First allowed broker-time entry window end. |
| `strategy_window2_start_hhmm` | -1 | -1 or 0-2359 | Second allowed entry window start; -1 disables it. |
| `strategy_window2_end_hhmm` | -1 | -1 or 0-2359 | Second allowed entry window end; -1 disables it. |
| `strategy_window3_start_hhmm` | -1 | -1 or 0-2359 | Third allowed entry window start; -1 disables it. |
| `strategy_window3_end_hhmm` | -1 | -1 or 0-2359 | Third allowed entry window end; -1 disables it. |
| `strategy_session_close_hhmm` | 2359 | 0-2359 | Broker-time session close exit threshold. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card-stated S&P 500 exposure; valid backtest-only custom symbol.
- `NDX.DWX` - card-stated US index basket member and liquid Nasdaq 100 proxy.
- `WS30.DWX` - card-stated US index basket member and liquid Dow 30 proxy.
- `GDAXI.DWX` - valid matrix DAX symbol used for the card's GER40.DWX intent.
- `XAUUSD.DWX` - card-stated metals member with portable OHLC/EMA/ATR data.

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Intraday, flat by configured session close |
| Expected drawdown profile | Asymmetric 0.5R target versus 1.0R setup stop, bounded by fixed-risk sizing |
| Regime preference | Volatility-expansion breakout after compact range and trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/working-system-needs-improvement.14001/page-4`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10427_et-3bar-xma.md`

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
| v1 | 2026-06-26 | Initial build from card | 60b49d1e-662e-4986-b3ed-513c79890058 |
