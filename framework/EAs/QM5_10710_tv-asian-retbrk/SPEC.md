# QM5_10710_tv-asian-retbrk - Strategy Spec

**EA ID:** QM5_10710
**Slug:** `tv-asian-retbrk`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView script `Breakout asia USD/CHF`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades M15 breakouts from an Asian-session high/low range. It builds the range from 20:00-23:59 and 00:00-08:00 broker/exchange time, then waits for a candle close outside the locked range. A later candle must retest the broken boundary and close back beyond it before the EA enters in that breakout direction. The stop is beyond the retest candle by the configured buffer, the target is 3.0R, and any still-open trade is closed after 48 M15 bars or when the next Asian range begins.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session1_start_hour` | 20 | 0-23 | Hour for the first Asian range segment start. |
| `strategy_session1_start_min` | 0 | 0-59 | Minute for the first Asian range segment start. |
| `strategy_session1_end_hour` | 23 | 0-23 | Hour for the first Asian range segment end. |
| `strategy_session1_end_min` | 59 | 0-59 | Minute for the first Asian range segment end. |
| `strategy_session2_start_hour` | 0 | 0-23 | Hour for the second Asian range segment start. |
| `strategy_session2_start_min` | 0 | 0-59 | Minute for the second Asian range segment start. |
| `strategy_session2_end_hour` | 8 | 0-23 | Hour for the second Asian range segment end. |
| `strategy_session2_end_min` | 0 | 0-59 | Minute for the second Asian range segment end. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for buffer and maximum-stop checks. |
| `strategy_tp_r` | 3.0 | >0 | Take-profit multiple of initial stop distance. |
| `strategy_buf_min_points` | 2.0 | >=0 | Minimum retest-candle stop buffer in points. |
| `strategy_buf_atr_frac` | 0.10 | >=0 | ATR fraction used for the retest-candle stop buffer. |
| `strategy_max_stop_atr` | 2.5 | >0 | Maximum allowed stop distance as a multiple of ATR(14). |
| `strategy_max_spread_stop` | 0.15 | >=0 | Maximum spread as a fraction of stop distance. |
| `strategy_retest_tolerance_pts` | 2.0 | >=0 | Point tolerance for "slightly" beyond the retested range boundary. |
| `strategy_max_hold_bars` | 48 | >=1 | Maximum holding period in M15 bars. |
| `strategy_one_per_session` | true | true/false | Enforces the source default of one trade per Asian session. |

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - Source script is explicitly USD/CHF-specific.
- `EURUSD.DWX` - Card names it as a portable major-FX test symbol.
- `GBPUSD.DWX` - Card names it as a portable major-FX test symbol.
- `USDJPY.DWX` - Card names it as a portable major-FX test symbol.
- `XAUUSD.DWX` - Card names it as a portable liquid non-FX extension.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - The card is an FX/metal intraday session-range strategy, not an index opening-range system.

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
| Trades / year / symbol | `120` |
| Typical hold time | Intraday; capped at 48 M15 bars (12 hours) |
| Expected drawdown profile | Fixed-risk breakout system with losses capped by candle stop and 2.5x ATR stop filter |
| Regime preference | Breakout with retest confirmation after Asian range compression |
| Win rate target (qualitative) | Medium, with 3.0R winners expected to carry payoff asymmetry |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `Breakout asia USD/CHF`, author handle `samuelmathieu0508`, published 2025-08-13, https://www.tradingview.com/script/eoKh4Pay/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10710_tv-asian-retbrk.md`

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
| v1 | 2026-05-31 | Initial build from card | 119a64b7-d420-443a-bb15-31d93a70c010 |
