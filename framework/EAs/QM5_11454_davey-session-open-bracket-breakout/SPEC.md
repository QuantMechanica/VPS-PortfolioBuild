# QM5_11454_davey-session-open-bracket-breakout - Strategy Spec

**EA ID:** QM5_11454
**Slug:** davey-session-open-bracket-breakout
**Source:** 3831c272-c52f-57c3-a857-2ab252e33bb0
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA waits for the first completed H1 bar that contains the configured session open. It records that bar's high and low as the daily bracket, skips the day if the bracket is wider than the configured pip cap, then places a BUYSTOP one pip above the high and a SELLSTOP one pip below the low. When one pending order fills, the opposite pending order is cancelled. The stop is the opposite bracket edge plus the same pip offset, the target is 1.5 times D1 ATR(14), and any open position or unfilled pending order is closed or cancelled at the configured end-of-day time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_open_utc_hour | 8 | 0-23 | UTC hour of the session open used to define the H1 opening bar. |
| strategy_session_open_utc_minute | 0 | 0-59 | UTC minute of the session open; 0 for London, 30 for NY open variants. |
| strategy_session_close_utc_hour | 21 | 0-23 | UTC hour after which open positions are closed and pending orders cancelled. |
| strategy_session_close_utc_minute | 0 | 0-59 | UTC minute for the end-of-day time stop. |
| strategy_offset_pips | 1 | >=1 | Pip offset beyond the bracket high/low for entries and stops. |
| strategy_max_bracket_pips | 60 | >=1 | Maximum allowed opening-bar bracket width; wider days are skipped. |
| strategy_atr_period | 14 | >=1 | D1 ATR period used for the target distance. |
| strategy_tp_atr_mult | 1.5 | >0 | Multiplier applied to D1 ATR for take-profit placement. |
| strategy_spread_cap_pips | 20 | >=1 | Maximum real quoted spread allowed before placing the bracket. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 FX major with DWX matrix coverage.
- GBPUSD.DWX - Card-listed H1 FX major with DWX matrix coverage.
- USDJPY.DWX - Card-listed H1 FX major with DWX matrix coverage.
- AUDUSD.DWX - Card-listed H1 FX major with DWX matrix coverage.
- USDCAD.DWX - Card-listed H1 FX major with DWX matrix coverage.

**Explicitly NOT for:**
- Index `.DWX` symbols - the approved card specifies FX pairs and uses FX pip-based bracket caps.
- Metals and energy `.DWX` symbols - not part of the card's H1 FX test basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 ATR(14) for take-profit distance |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday; exits by TP, SL, or same-day session close. |
| Expected drawdown profile | Breakout system with losing days when the opening bracket fails. |
| Regime preference | Volatility expansion / session breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3831c272-c52f-57c3-a857-2ab252e33bb0
**Source type:** book / PDF
**Pointer:** Kevin J. Davey, "My 5 Favorite Entries", KJ Trading Systems; local PDF `374755020-My-5-Favorite-Entries.pdf`.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11454_davey-session-open-bracket-breakout.md`

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
| v1 | 2026-06-20 | Initial build from card | 38526c92-c334-45af-bf21-470bcda823ad |
