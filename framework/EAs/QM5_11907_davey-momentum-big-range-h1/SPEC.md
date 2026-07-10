# QM5_11907_davey-momentum-big-range-h1 — Strategy Spec

**EA ID:** QM5_11907
**Slug:** `davey-momentum-big-range-h1`
**Source:** `9e3c5b71-2d48-5a96-8f37-c1b4d7e2a5f9`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On each completed H1 bar, compare that bar's high-low range with the mean plus
two standard deviations of the preceding 50 completed H1 ranges. When the new
range exceeds that threshold, buy if its close is above the close ten bars ago
or sell if it is below. The initial stop is 1.5 ATR(14), the target is 3 ATR(14),
and any remaining position closes after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_range_lookback` | 50 | fixed by card | Prior H1 ranges used for the expansion threshold |
| `strategy_range_sigma_mult` | 2.0 | fixed by card | Standard deviations added to the mean range |
| `strategy_daysback` | 10 | fixed by card | Close-comparison lookback for trade direction |
| `strategy_atr_period` | 14 | fixed by card | ATR period for the initial stop and target |
| `strategy_atr_sl_mult` | 1.5 | fixed by card | Initial stop distance in ATR units |
| `strategy_target_atr_mult` | 3.0 | fixed by card | Take-profit distance in ATR units |
| `strategy_time_stop_bars` | 24 | fixed by card | Maximum position age in H1 bars |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, and `USDCHF.DWX` — liquid major FX pairs with long real-tick histories.
- `AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX` — additional liquid FX pairs that diversify the volatility-expansion test.

**Explicitly NOT for:**

- Non-FX instruments — the approved card ports Davey's entry specifically to the ten registered DWX currency pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 45 card-estimated signals before downstream filtering |
| Typical hold time | intraday, capped at 24 H1 bars |
| Expected drawdown profile | fixed-risk, one-position-per-magic with hard stop and target |
| Regime preference | volatility expansion with short-term directional continuation |
| Win rate target (qualitative) | medium-low, offset by asymmetric reward/risk |

---

## 6. Source Citation

**Source ID:** `9e3c5b71-2d48-5a96-8f37-c1b4d7e2a5f9`
**Source type:** webinar by Kevin J. Davey; supporting methodology in his Wiley-published book
**Pointer:** Kevin J. Davey, *My 5 Favorite Entries*, Entry #1 “Momentum and Big Range”
**R1–R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11907_davey-momentum-big-range-h1.md`

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
| v1 | 2026-07-10 | Q02 infrastructure recovery | Added missing magic registrations, canonical setfile slots, and strict-build documentation |
