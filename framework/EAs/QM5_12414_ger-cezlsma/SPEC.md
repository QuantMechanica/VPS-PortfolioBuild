# QM5_12414_ger-cezlsma — Strategy Spec

**EA ID:** QM5_12414
**Slug:** ger-cezlsma
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed M15 bars. It goes long when the Chandelier Exit state is bullish and the completed Heikin Ashi close is above the ZLSMA line; it goes short when the Chandelier Exit state is bearish and the completed Heikin Ashi close is below the ZLSMA line. The entry stop is the current Chandelier Exit stop adjusted by `sl_dev_points`, with an ATR(14) catastrophic fallback if that stop is invalid. It exits when a profitable open position crosses back through ZLSMA, or when the configured 96-bar time stop is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `ce_atr_period` | 1 | 1-250 | ATR/lookback period used by the Chandelier Exit state and stop. |
| `ce_atr_mult` | 0.75 | >0 | ATR multiplier used by the Chandelier Exit state and stop. |
| `zl_period` | 50 | 2-250 | ZLSMA period applied to Heikin Ashi close. |
| `time_stop_bars` | 96 | >=1 | Maximum bars to hold before V5 time-stop exit. |
| `sl_dev_points` | 650 | >=0 | Points added beyond the Chandelier Exit stop. |
| `catastrophic_atr_mult` | 2.0 | >0 | ATR(14) multiplier used only if the indicator-derived stop is invalid. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` — card primary source pair and present in the DWX matrix.
- `EURUSD.DWX` — R3 portable major FX pair with DWX coverage.
- `GBPUSD.DWX` — R3 portable major FX pair with DWX coverage.

**Explicitly NOT for:**
- Non-FX index or commodity symbols — the approved card's R3 basket is limited to the three listed major FX pairs.

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
| Trades / year / symbol | `70` |
| Typical hold time | M15 trend hold with maximum 96 bars, about 24 hours on continuous time. |
| Expected drawdown profile | Trend-following whipsaw risk during sideways FX regimes, bounded by CE-derived stop. |
| Regime preference | Trend-following / Heikin Ashi trend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** code
**Pointer:** Geraked / Rabist, CEZLSMA.mq5 in the geraked/metatrader5 GitHub repository
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12414_ger-cezlsma.md`

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
| v1 | 2026-06-11 | Initial build from card | 6fdfc989-8e94-49fd-84de-48ce7458af16 |
