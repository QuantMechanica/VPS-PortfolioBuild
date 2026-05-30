# QM5_10369_et-magnet-limits - Strategy Spec

**EA ID:** QM5_10369
**Slug:** et-magnet-limits
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA builds one intraday bracket around the 08:30 Chicago-equivalent broker open. It places a buy limit 0.35% below that open and a sell limit 0.35% above it, with the midpoint at the open as the full-position target. First fill wins: when one side becomes a position, the opposite pending order is cancelled. Unfilled entries are cancelled at 11:00 Chicago-equivalent broker time, and any open position is closed at 15:00 Chicago-equivalent broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_M1 | PERIOD_M1 or PERIOD_M5 | Bar timeframe used for the session-open bar and ATR stop calculation. |
| strategy_open_hour_broker | 16 | 0-23 | Broker-hour equivalent of the 08:30 Chicago regular-session open. |
| strategy_open_minute_broker | 30 | 0-59 | Broker-minute equivalent of the Chicago open. |
| strategy_cancel_hour_broker | 19 | 0-23 | Broker-hour equivalent of the 11:00 Chicago unfilled-order cancellation. |
| strategy_cancel_minute_broker | 0 | 0-59 | Broker-minute for unfilled-order cancellation. |
| strategy_exit_hour_broker | 23 | 0-23 | Broker-hour equivalent of the 15:00 Chicago time exit. |
| strategy_exit_minute_broker | 0 | 0-59 | Broker-minute for the time exit. |
| strategy_bracket_pct | 0.35 | 0.25-0.50 test range | Percent distance above and below the session open for limit entries. |
| strategy_atr_period | 14 | >=1 | ATR lookback for the hard stop and bracket-width filter. |
| strategy_stop_atr_mult | 0.30 | 0.20-0.40 test range | Stop distance as a multiple of ATR(14). |
| strategy_max_bracket_atr_mult | 1.20 | >0 | Skip the setup when full bracket width is greater than this ATR multiple. |
| strategy_min_spread_width_mult | 4.0 | >=0 | Skip the setup when bracket width is less than this multiple of current spread. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - closest ES/S&P 500 proxy and explicitly approved for backtest-only use.
- NDX.DWX - live-tradable US large-cap index CFD in the approved R3 basket.
- WS30.DWX - live-tradable Dow 30 index CFD in the approved R3 basket.
- GDAXI.DWX - matrix-available DAX proxy used for the card's GER40.DWX exposure.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.
- SPX500.DWX, SPY.DWX, ES.DWX - not canonical DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from morning fill until midpoint target, stop, or 15:00 Chicago-equivalent exit |
| Expected drawdown profile | Sensitive to trend days that continue through both bracket and stop. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** WhiteWolf, "Magnet" test system, Elite Trader, 2005-10-16, https://www.elitetrader.com/et/threads/magnet-test-system.57181/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10369_et-magnet-limits.md`

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
| v1 | 2026-05-25 | Initial build from card | d476876b-7781-49f5-ac94-1a275b00917d |
