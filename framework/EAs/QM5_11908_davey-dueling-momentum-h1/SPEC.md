# QM5_11908_davey-dueling-momentum-h1 — Strategy Spec

**EA ID:** QM5_11908  
**Slug:** `davey-dueling-momentum-h1`  
**Source:** `9e3c5b71-2d48-5a96-8f37-c1b4d7e2a5f9`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On each completed H1 bar, compare the latest close with the closes five and
thirty bars earlier. Buy when five-bar momentum is positive while thirty-bar
momentum remains negative; sell for the mirrored condition. The initial stop is
1.5 ATR(14), the target is 2 ATR(14), and any remaining position closes when
long-term momentum aligns with the trade or after 50 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_short_lookback` | 5 | fixed by card | Short close-to-close momentum lookback |
| `strategy_long_lookback` | 30 | fixed by card | Long close-to-close momentum lookback |
| `strategy_atr_period` | 14 | fixed by card | ATR period for stop and target |
| `strategy_atr_sl_mult` | 1.5 | fixed by card | Initial stop distance in ATR units |
| `strategy_atr_tp_mult` | 2.0 | fixed by card | Take-profit distance in ATR units |
| `strategy_time_stop_bars` | 50 | fixed by card | Maximum position age in H1 bars |
| `strategy_align_exit` | true | fixed by card | Exit when long-term momentum aligns |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, and `USDCHF.DWX` — liquid major FX pairs with long real-tick histories.
- `AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX` — additional liquid FX pairs for cross-pair diversification.

**Explicitly NOT for:**

- Non-FX instruments — the approved card ports Davey's entry specifically to the ten registered DWX currency pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the attached H1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 80 card-estimated signals before downstream filtering |
| Typical hold time | low-frequency swing/intraday, capped at 50 H1 bars |
| Expected drawdown profile | fixed-risk, one-position-per-magic with hard stop and target |
| Regime preference | short-term reversal inside an opposing longer-term move |
| Win rate target (qualitative) | medium, subject to Q02 real-tick evidence |

---

## 6. Source Citation

**Source ID:** `9e3c5b71-2d48-5a96-8f37-c1b4d7e2a5f9`  
**Source type:** webinar by Kevin J. Davey; supporting methodology in his Wiley-published book  
**Pointer:** Kevin J. Davey, *My 5 Favorite Entries*, Entry #5 “Dueling Momentum”  
**R1–R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11908_davey-dueling-momentum-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%–0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Q02 infrastructure recovery | Added missing magic registrations, canonical setfile slots, and strict-build documentation |
