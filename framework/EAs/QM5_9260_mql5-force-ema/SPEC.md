# QM5_9260_mql5-force-ema - Strategy Spec

**EA ID:** QM5_9260
**Slug:** `mql5-force-ema`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades closed H1-bar Force Index momentum filtered by EMA(13). It goes long when the H1 close is above EMA(13) and smoothed Force Index(13, EMA, tick volume) crosses from below zero to above zero. It goes short when the H1 close is below EMA(13) and Force Index crosses from above zero to below zero. Open positions exit when Force Index crosses back through zero against the trade, when close crosses the EMA against the trade, or after 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_force_period` | 13 | 2-200 | EMA smoothing period for Force Index built from H1 close changes and tick volume. |
| `strategy_ema_period` | 13 | 2-200 | Close-price EMA period used as the trend filter. |
| `strategy_atr_period` | 14 | 2-200 | ATR period used for initial stop placement. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple for the initial stop loss. |
| `strategy_rr_target` | 2.0 | 0.1-10.0 | Take-profit distance as an R multiple of initial stop risk. |
| `strategy_max_hold_bars` | 48 | 1-500 | Failsafe maximum holding time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with DWX tick volume and H1 history.
- `GBPJPY.DWX` - liquid cross FX pair with DWX tick volume and H1 history.
- `XAUUSD.DWX` - liquid metal CFD with DWX tick volume and H1 history.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical `.DWX` symbols.
- Symbols without tick volume history - Force Index requires tick volume for the card's signal.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `hours to 48 H1 bars maximum` |
| Expected drawdown profile | `ATR-bounded trend-following drawdowns from false zero-line crosses` |
| Regime preference | `momentum / trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/11269`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9260_mql5-force-ema.md`

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
| v1 | 2026-06-25 | Initial build from card | a7aa7a2e-1f79-457e-810b-fabfba16b6fb |
