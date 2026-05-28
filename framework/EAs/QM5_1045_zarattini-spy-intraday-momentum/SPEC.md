# QM5_1045_zarattini-spy-intraday-momentum - Strategy Spec

**EA ID:** QM5_1045
**Slug:** `zarattini-spy-intraday-momentum`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

On each closed M30 bar at a clock-hour or half-hour mark inside the US cash session, the EA compares the bar close with noise boundaries around the session open. The boundary width is the average intraday high-low move up to the same session time over the previous 14 trading days, with the card's signed overnight-gap adjustment applied to the side made easier by the gap. A close above the upper boundary opens a long position; a close below the lower boundary opens a short position. Positions are flattened at the session close, and an ATR(14) x 3.0 stop is used as the V5 safety overlay.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_noise_lookback_days` | 14 | 1-60 | Trading-day sample count for the average intraday move. |
| `strategy_winter_open_hhmm` | 1530 | 0000-2359 | Broker-time US cash session open outside US DST. |
| `strategy_winter_close_hhmm` | 2200 | 0000-2359 | Broker-time US cash session close outside US DST. |
| `strategy_usdst_open_hhmm` | 1430 | 0000-2359 | Broker-time US cash session open during US DST. |
| `strategy_usdst_close_hhmm` | 2100 | 0000-2359 | Broker-time US cash session close during US DST. |
| `strategy_use_us_dst_session` | true | true/false | Switches between winter and US-DST session windows by date. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the V5 safety stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.1-10.0 | ATR multiplier for the hard stop. |
| `strategy_max_spread_points` | 250 | 0-10000 | Maximum spread allowed for new entries; 0 disables this gate. |
| `strategy_copy_bars` | 2200 | 500-10000 | M30 bars copied once per closed-bar signal calculation. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - US large-cap index proxy required for parallel validation when SP500 live routing is unavailable.
- `WS30.DWX` - US large-cap index proxy required for parallel validation when SP500 live routing is unavailable.
- `SP500.DWX` - Canonical backtest-only DWX custom symbol for the card's SPY/SPX exposure.

**Explicitly NOT for:**
- `SPY.DWX`, `SPX500.DWX`, `ES.DWX` - not present in the DWX symbol matrix.
- Forex and commodities - the card is an equity-index intraday momentum rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | intraday, minutes to one cash session |
| Expected drawdown profile | Breakout losses are bounded by the ATR safety stop and session-close flatten. |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** paper
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4824172`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1045_zarattini-spy-intraday-momentum.md`

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
| v1 | 2026-05-28 | Initial build from card | 5ffbf9cc-f81f-4051-ab34-497a442cc7d3 |
