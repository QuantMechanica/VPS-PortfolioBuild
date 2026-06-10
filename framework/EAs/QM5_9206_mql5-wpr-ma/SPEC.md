# QM5_9206_mql5-wpr-ma — Strategy Spec

**EA ID:** QM5_9206
**Slug:** `mql5-wpr-ma`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On every closed H1 bar, the EA reads Williams %R(14), EMA(50), and ATR(14). A long entry fires when WPR crosses from below -50 to above -50 on the last closed bar AND the close is above EMA(50), signalling momentum in a bullish trend. A short entry fires on the reverse cross (WPR below -50) with close below EMA(50). Stop loss is placed at ATR(14) × 1.5 from entry; take profit targets 2R. Positions are closed when WPR crosses back through -50 in the opposite direction, when the close moves to the other side of EMA(50), or after 40 H1 bars as a failsafe time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_period` | 14 | 5-50 | Lookback period for Williams %R |
| `strategy_ema_period` | 50 | 20-200 | Period for the EMA trend filter |
| `strategy_atr_period` | 14 | 5-30 | ATR period for stop/target sizing |
| `strategy_sl_atr_mult` | 1.5 | 0.5-4.0 | ATR multiplier for initial stop loss |
| `strategy_tp_rr` | 2.0 | 1.0-5.0 | Reward-to-risk ratio for take profit |
| `strategy_max_hold_bars` | 40 | 10-200 | Maximum H1 bars before time exit |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major forex pair; H1 trend/momentum well-captured by WPR+EMA
- `GBPUSD.DWX` — major forex pair with similar structural trend behaviour
- `GDAXI.DWX` — DAX 40 index; directional momentum on H1 suits WPR crossover (card listed GER40.DWX which is not in DWX matrix; ported to GDAXI.DWX)

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX symbol; GDAXI.DWX is the canonical DAX representation

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~85 |
| Typical hold time | 5–20 hours (exit via signal or 40-bar time stop) |
| Expected drawdown profile | Medium frequency trend-follower; moderate consecutive losses during ranging markets |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium (trend-follow with 2R target) |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum / article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Williams PR", MQL5 Articles, 2022-07-05
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9206_mql5-wpr-ma.md`

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
| v1 | 2026-06-10 | Initial build from card | 4951a262-1e5f-4119-959c-2f117e4a4e97 |
