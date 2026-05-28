# QM5_10379_et-30min-brk - Strategy Spec

**EA ID:** QM5_10379
**Slug:** `et-30min-brk`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on an M5 chart and records the high and low of the first 30 minutes of the regular index session. After that range is complete, it places a buy stop at the range high and a sell stop at the range low, with only one filled position allowed for the symbol and magic. It skips sessions where the opening range is too narrow relative to spread or too wide relative to ATR(20). Open trades are closed at the configured session close, and once profit reaches the ATR threshold the stop is moved to breakeven and trailed by ATR distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hhmm` | 930 | 0000-2359 | Regular-session start used to begin the opening range. |
| `strategy_range_minutes` | 30 | 1-240 | Number of minutes used to build the opening range. |
| `strategy_latest_entry_hhmm` | 1600 | 0000-2359 | Latest time for placing the breakout bracket. |
| `strategy_session_close_hhmm` | 1600 | 0000-2359 | Time to cancel pending orders and close open positions. |
| `strategy_atr_period` | 20 | 1-200 | ATR period on M5 for range filter and stop distances. |
| `strategy_initial_stop_atr` | 0.75 | 0.10-5.00 | Initial stop distance as ATR multiple. |
| `strategy_breakeven_atr` | 0.75 | 0.10-5.00 | Profit threshold for breakeven/trailing activation. |
| `strategy_trail_atr` | 0.75 | 0.10-5.00 | Trailing stop distance after activation. |
| `strategy_max_range_atr` | 1.50 | 0.10-10.00 | Maximum opening-range width as ATR multiple. |
| `strategy_min_range_spreads` | 4.00 | 1.00-20.00 | Minimum opening-range width as current-spread multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the ES/SPX opening-range source logic; backtest-only per DWX discipline.
- `NDX.DWX` - liquid US large-cap index CFD analog for Nasdaq 100.
- `WS30.DWX` - liquid US large-cap index CFD analog for Dow 30.
- `GDAXI.DWX` - verified DAX custom symbol used as the nearest available DWX port for the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable variants; `SP500.DWX` is the canonical S&P 500 custom symbol.

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
| Trades / year / symbol | `180` |
| Typical hold time | Intraday, from post-range breakout to same-session close or trailing stop. |
| Expected drawdown profile | High-cadence intraday whipsaw risk in range-bound sessions. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/30-min-break-out.17762/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10379_et-30min-brk.md`

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
| v1 | 2026-05-25 | Initial build from card | 02bbc7a4-2aa6-47cd-b2fb-4349f021f13a |
