# QM5_10711_tv-mktopen-imp — Strategy Spec

**EA ID:** QM5_10711
**Slug:** `tv-mktopen-imp`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

At each M15 bar close, the EA checks whether the just-closed bar falls within the configured market-open window in broker time. If it does and no trade has been placed yet today, it measures the impulse: the bar's true range must be ≥ 1.5× ATR(14) (impulse threshold) and ≤ 4.0× ATR(14) (spike filter). A long entry fires when the impulse bar also closes above its midpoint and above its own open; a short entry fires when it closes below its midpoint and below its own open. The initial stop is set to the opposite extreme of the impulse candle, take profit is 3.0R. An optional breakeven rule moves the stop to entry after price reaches 1.5R. Any open position is force-closed at the configured session-end time. Only one trade per day is allowed per symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hhmm` | 1430 | 0-2359 | Broker-server HHMM for the start of the market-open window (per-symbol setfile override required for correct broker-time mapping). |
| `strategy_session_end_hhmm` | 2000 | 0-2359 | Broker-server HHMM at or after which any open position is force-closed and new entries are suppressed. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the impulse threshold and spike filter. |
| `strategy_atr_impulse_factor` | 1.5 | 0.1-10.0 | Minimum true-range multiple of ATR for an impulse candle. |
| `strategy_max_spike_factor` | 4.0 | 0.1-20.0 | Maximum true-range multiple of ATR; bars larger than this are skipped as spike/news risk. |
| `strategy_rr_target` | 3.0 | 0.1-20.0 | Take-profit distance expressed in initial risk units (R). |
| `strategy_max_spread_pct_of_sl` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of planned SL distance; 0 = disabled. Zero spread (.DWX tester) always passes. |
| `strategy_breakeven_enabled` | false | true/false | Enable the optional breakeven rule. |
| `strategy_breakeven_rr` | 1.5 | 0.1-20.0 | Profit in R at which the stop is moved to entry when breakeven is enabled. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_temporal, qm_news_compliance, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only strategy-specific inputs are listed above.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — canonical DAX 40 DWX symbol; ported from card's GER40.DWX (not in matrix). DAX opens 09:00 CET = ~10:00 broker; set `strategy_session_start_hhmm=1000` in setfile.
- `NDX.DWX` — US large-cap index CFD; captures Nasdaq cash-open impulse at 09:30 ET = 16:30 broker; set `strategy_session_start_hhmm=1630` in setfile.
- `WS30.DWX` — US large-cap index CFD; same open timing as NDX; set `strategy_session_start_hhmm=1630` in setfile.
- `XAUUSD.DWX` — liquid metals CFD included in the card target list; impulse at London or NY open.
- `EURUSD.DWX` — liquid FX major included in the card target list; impulse at London open.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- `SP500.DWX` — card designates it as optional backtest-only comparison, not a primary target for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework wiring) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, up to session end (default ~20:00 broker) |
| Expected drawdown profile | Stop-defined impulse losses, $1,000 fixed risk per trade in backtest |
| Regime preference | Volatility-expansion / market-open momentum |
| Win rate target (qualitative) | Medium; 3.0R winners offset frequent impulse failures |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source script
**Pointer:** TradingView script `Market Open Impulse [LuciTech]`, author handle `TradesLuci`, published 2025-08-12, https://www.tradingview.com/script/5VVg9PqU-Market-Open-Impulse-LuciTech/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10711_tv-mktopen-imp.md`

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
| v1 | 2026-05-31 | Initial build from card | 718a6fd1-ff74-4f26-8898-feb9a44419fe |
| v2 | 2026-06-05 | ONINIT_FAILED fix (EA_MAGIC_NOT_REGISTERED); magic_numbers.csv + resolver updated; .mq5 rewritten with correct parameter set | 550b146e-c280-4114-858e-3206d5aa8a51 |
