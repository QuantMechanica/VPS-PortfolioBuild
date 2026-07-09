# QM5_11913_crue-ichimoku-5line-alignment-d1 — Strategy Spec

**EA ID:** QM5_11913
**Slug:** `crue-ichimoku-5line-alignment-d1`
**Source:** `f9b3c7a4-2e58-5d63-9c47-a1d6e4b7f2c8`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On each new D1 bar, the EA reads the closed bar's canonical 9/26/52 Ichimoku values. It buys when Tenkan, Kijun, the displaced Senkou A and Senkou B, and the card's lagged-close Chikou proxy are strictly ordered from highest to lowest; it sells on the exact reversed ordering. It exits when that strict ordering breaks, after 180 D1 bars, at the 3 ATR protective stop, or through the framework Friday-close and kill-switch controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_tenkan_period` | 9 | fixed by card | Tenkan-sen lookback |
| `strategy_kijun_period` | 26 | fixed by card | Kijun-sen lookback |
| `strategy_senkou_b_period` | 52 | fixed by card | Senkou Span B lookback |
| `strategy_shift` | 26 | fixed by card | Cloud displacement and Chikou proxy lag |
| `strategy_atr_period` | 14 | fixed by card | D1 ATR stop lookback |
| `strategy_atr_sl_mult` | 3.0 | fixed by card | Initial stop distance in ATR units |
| `strategy_time_stop_bars` | 180 | fixed by card | Maximum D1 holding period |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` — liquid FX majors with long D1 histories.
- `USDCAD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX` — additional liquid dollar pairs that diversify trend episodes.
- `EURJPY.DWX`, `GBPJPY.DWX`, `AUDJPY.DWX` — JPY crosses with distinct macro trend regimes.

**Explicitly NOT for:**

- Index, metal, and energy CFDs — excluded from this approved FX-only card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; alignment cached by `QM_CalendarPeriodKey(PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 |
| Typical hold time | days to several months, capped at 180 D1 bars |
| Expected drawdown profile | infrequent full-risk losses during false trend alignment |
| Regime preference | persistent directional trends |
| Win rate target (qualitative) | low to medium, with positively skewed winners |

---

## 6. Source Citation

**Source ID:** `f9b3c7a4-2e58-5d63-9c47-a1d6e4b7f2c8`
**Source type:** project paper / published indicator system
**Pointer:** Emeric Cruë, “Back-Testing: Ichimoku Trading Strategy Using Python,” Python in Quantitative Finance, May 2019; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11913_crue-ichimoku-5line-alignment-d1.md`.
**R1–R4 verdict (Q00):** all PASS; see the approved card above.

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
| v1 | 2026-07-10 | Q02 infrastructure recovery | Add Q01 spec and document the approved card mapping |
