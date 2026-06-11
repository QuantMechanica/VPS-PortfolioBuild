# QM5_9638_demark-td-termination-active-h4 — Strategy Spec

**EA ID:** QM5_9638
**Slug:** `demark-td-termination-active-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude (build agent)
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed H4 bar the EA maintains two independent sequential counts — one
for bullish exhaustion (buy termination) and one for bearish exhaustion (sell
termination). A buy-termination bar qualifies when its close is below the close
four bars earlier AND its low is below the lows of both of the two most recently
counted bars; a sell-termination bar mirrors this with close above and highs
above. When the count reaches 9 within a 30-bar window and the final bar "snaps
back" (buy: bar 9 close > bar 8 close; sell: bar 9 close < bar 8 close), an
active-termination event fires provided the sequence range spans at least 1.5×
ATR(14). The EA enters at market on the next bar open with a stop below the
lowest sequence low minus 0.25×ATR (long) or above the highest sequence high
plus 0.25×ATR (short), and targets 2×R. A 16-bar time stop and an opposite
termination event also close the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5–50 | ATR lookback for SL buffer and range filter |
| `strategy_sl_atr_buffer` | 0.25 | 0.1–1.0 | SL distance beyond sequence extreme, in ATR units |
| `strategy_tp_r_multiple` | 2.0 | 1.0–5.0 | Take profit as multiple of initial risk (R) |
| `strategy_time_stop_bars` | 16 | 4–50 | Maximum H4 bars to hold open position |
| `strategy_max_span_bars` | 30 | 15–60 | Maximum bars from count-1 to count-9 before reset |
| `strategy_min_range_atr` | 1.5 | 0.5–4.0 | Sequence range must exceed N×ATR(14) to fire signal |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity, tight spread; H4 exhaustion sequences well-documented
- `GBPUSD.DWX` — sufficient volatility for meaningful 9-count sequences on H4
- `USDJPY.DWX` — trend/risk-off cycles produce clean exhaustion patterns
- `XAUUSD.DWX` — gold shows pronounced TD-style exhaustion on H4 due to sentiment-driven moves

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — not in card basket; different volatility profile

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 (range 20–45 per card) |
| Typical hold time | 1–16 H4 bars (~4 hours to ~2.7 days) |
| Expected drawdown profile | Moderate; 2R targets with fixed $1k risk per trade |
| Regime preference | exhaustion-reversal; performs in range-bound or overextended trending markets |
| Win rate target (qualitative) | medium (reversal entries often have 40–50% hit rate) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/316616-demark-indicator-trading-setups (Thomas DeMark publication lineage)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9638_demark-td-termination-active-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 670f270b-fb96-49bc-afdd-382f6e7a1dea |
