# QM5_11294_cs-ichi-cloud — Strategy Spec

**EA ID:** QM5_11294
**Slug:** `cs-ichi-cloud`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each completed H4 bar, the EA reads the standard 9/26/52 Ichimoku cloud. It opens long when Leading Span A is above Leading Span B and the close is above Span A; it opens short under the mirrored bearish state. A position closes when the opposite cloud state appears, while a 3.0 × ATR(14) catastrophic stop limits risk. A reversal cannot enter on the exit bar and must wait for the next completed H4 bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_tenkan_period` | 9 | 1–200 | Ichimoku conversion-line period used in Leading Span A. |
| `strategy_kijun_period` | 26 | 1–300 | Ichimoku base-line period and cloud displacement convention. |
| `strategy_senkou_b_period` | 52 | 2–500 | Lookback used for Leading Span B. |
| `strategy_atr_period` | 14 | 1–200 | H4 ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.1–20.0 | Catastrophic stop distance in ATR multiples. |

Framework inputs, including risk, news, seed, stress, and Friday-close controls, are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX trend host.
- `GBPUSD.DWX` — liquid major-FX trend host with distinct volatility.
- `XAUUSD.DWX` — liquid metal host for persistent macro trends.
- `GDAXI.DWX` — canonical DWX DAX index host; this is the registered equivalent of the card body's GER40 label.
- `NDX.DWX` — liquid US technology-index trend host.

**Explicitly NOT for:**

- Unregistered symbols or non-H4 hosts — they have no card approval or active magic slot for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8 |
| Typical hold time | several H4 bars to several weeks |
| Expected drawdown profile | sparse trend losses bounded per trade by the 3 ATR catastrophic stop |
| Regime preference | persistent directional trends; flat clouds should remain untraded |
| Win rate target (qualitative) | medium-low, offset by holding sustained trends |

---

## 6. Source Citation

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`

**Source type:** public GitHub implementation

**Pointer:** `CryptoSignal/Crypto-Signal`, `app/analyzers/indicators/ichimoku.py`

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11294_cs-ichi-cloud.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | build task `ae61ab29-c83f-4cf3-a417-afffd6b2a25d` |
