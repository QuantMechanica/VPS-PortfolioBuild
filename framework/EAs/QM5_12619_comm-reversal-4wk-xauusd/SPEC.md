# QM5_12619_comm-reversal-4wk-xauusd — Strategy Spec

**EA ID:** QM5_12619
**Slug:** `comm-reversal-4wk-xauusd`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Author of this spec:** Claude
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

At the start of each calendar week (first D1 bar = Monday open), the EA computes
the 20-bar D1 cumulative return: `ret_20d = (Close[1] - Close[21]) / Close[21]`.
If `ret_20d < -3%` and gold's 20-day ATR/Close ratio is below 2% (not in a
structural trend), the EA fades the drop by going long. If `ret_20d > +3%` under
the same volatility guard, it fades the rally by going short. The entry is a
market order at Monday's open with a hard ATR(14) × 1.8 stop. If an opposite
position is already open, it is closed before the new entry. Positions are held
for a maximum of 27 calendar days (≈ 20 trading days / 4 weeks); there is no TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 20 | 10–40 | D1 bars in the formation/return window (≈ 4 calendar weeks) |
| `strategy_return_threshold` | 0.03 | 0.02–0.06 | Minimum absolute 20D return to trigger reversal entry |
| `strategy_atr_period` | 14 | 10–20 | ATR period for hard SL computation |
| `strategy_atr_sl_mult` | 1.8 | 1.0–3.0 | SL = entry ± ATR(period) × mult |
| `strategy_hold_days_cal` | 27 | 20–35 | Calendar-day time-exit cap (≈ 20 trading days) |
| `strategy_vol_max_ratio` | 0.02 | 0.01–0.04 | ATR(20)/Close threshold; skip entry when gold is structurally trending |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Gold spot CFD; the paper (Yang et al. 2018) documents the
  short-term reversal anomaly specifically in metals futures (Table 2), and
  XAUUSD is the canonical DWX liquid gold instrument with 8-year history.

**Explicitly NOT for:**
- Other forex or index symbols — the reversal mechanism is specific to commodity
  overreaction/liquidity-provision in metals; sister EAs 12620 (NG) and
  12621 (crude) handle other commodities as separate registrations.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` + weekly cadence via `QM_CalendarPeriodKey(PERIOD_W1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~16 |
| Typical hold time | 5–20 trading days (up to 4 weeks) |
| Expected drawdown profile | ~16% MaxDD per card frontmatter |
| Regime preference | mean-revert (short-term commodity overreaction reversal) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** paper
**Pointer:** Yang, L., Goncu, A., & Pantelous, A. A. (2018). "Momentum and Reversal
Strategies in Chinese Commodity Futures Markets." *Quantitative Finance*, 18(8),
1373–1389. DOI: https://doi.org/10.1080/14697688.2018.1436534 — Table 2,
formation 4-week, holding 4-week metals reversal.
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12619_comm-reversal-4wk-xauusd.md`

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
| v1 | 2026-07-02 | Initial build from card | 57098a53-414a-4c1d-b40d-8f018ec64ebe |
