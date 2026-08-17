# QM5_40002_quantpedia-fx-momentum-volatility-parity — Strategy Spec

**EA ID:** QM5_40002
**Slug:** `quantpedia-fx-momentum-volatility-parity`
**Source:** `quantpedia-fx-momentum-volatility-parity-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On every completed D1 bar, the EA calculates the 63-trading-day return from
closed prices, EMA(50), ATR(14), and annualized standard deviation of 21 daily
log returns. It enters long when the 63-day return is positive and Close[1] is
above EMA(50)[1]. It enters short when the return is negative and Close[1] is
below EMA(50)[1]. All signal inputs use shift 1 or older data.

The initial stop is 2.0 × ATR(14)[1]. The take profit is twice the initial risk
distance. A position that survives into a new UTC calendar month is closed so
the next qualifying entry refreshes volatility-normalized sizing. Broker-side
SL/TP, the V5 Friday sweep, and that month-boundary rebalance are the only exits;
the approved card provides no numerical break-even or trailing-stop thresholds.

The card defines a six-pair normalized inverse-volatility weight. V5 runs one
symbol instance per registered magic and sizes from a fixed dollar risk budget
and its volatility-scaled stop. The EA therefore computes 21-day realized
volatility for signal evidence, obtains inverse-volatility notional through the
2×ATR stop under `RISK_FIXED`, and refreshes it monthly. It does not invent a
cross-instance mutable weight or bypass the central risk sizer.

Entry is suppressed during 23:55–00:05 UTC, when spread exceeds 1.8 × the
cached D1 ATR, or when the same magic already owns a position. The central V5
kill switch supplies the account loss guards; no per-EA account-history risk
engine is duplicated.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_momentum_lookback_d1` | 63 | 30–120 | Closed D1 bars used for the momentum return |
| `strategy_volatility_lookback_d1` | 21 | 10–40 | Daily log returns used for annualized realized volatility |
| `strategy_ema_period` | 50 | 20–100 | D1 EMA direction-confirmation period |
| `strategy_atr_period` | 14 | 5–50 | D1 ATR period used for stops and spread normalization |
| `strategy_stop_atr_mult` | 2.0 | 0.5–5.0 | Initial stop distance in ATR units |
| `strategy_reward_risk` | 2.0 | 0.5–5.0 | Take-profit multiple of initial risk |
| `strategy_spread_atr_mult` | 1.8 | 0.1–3.0 | Maximum entry spread in D1 ATR units |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair and primary card symbol; magic slot 0.
- `GBPUSD.DWX` — liquid major FX pair; magic slot 1.
- `AUDUSD.DWX` — liquid major FX pair; magic slot 2.
- `NZDUSD.DWX` — liquid major FX pair; magic slot 3.
- `USDCAD.DWX` — liquid major FX pair; magic slot 4.
- `USDJPY.DWX` — liquid major FX pair; magic slot 5.

**Explicitly NOT for:**

- Index, metal, energy, rates, equity, and crypto symbols — they are outside
  this approved FX card and have no allocated symbol slot in QM5_40002.
- FX crosses not listed above — cross-sectional comparability and a governed
  magic slot have not been approved for this variant.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the host D1 chart; all calculations use closed D1 bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 25; Q02 measures the realized count |
| Typical hold time | several days, capped naturally by SL/TP or month-end rebalance |
| Expected drawdown profile | low-frequency fixed-dollar losses with at most one position per symbol instance |
| Regime preference | persistent directional FX trends |
| Win rate target (qualitative) | medium; source performance claims are not gate evidence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `quantpedia-fx-momentum-volatility-parity-official-source`
**Source type:** verified quantitative-model research
**Pointer:** Quantpedia Strategy #14, “FX Momentum & Volatility Parity Factor Suite”; approved card at `strategy-seeds/cards/approved/QM5_40002_quantpedia-fx-momentum-volatility-parity.md`
**R1–R4 verdict (Q00):** all PASS per the OWNER-approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent, only after downstream approval |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio governance |

The six canonical build setfiles explicitly set `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This build does not authorize live
use and does not touch any live manifest.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from card | build task `077f3f7d-5068-4e20-836e-93e026db6998` |
