# QM5_11381_psar-ao-ac-trend-align-h1 — Strategy Spec

**EA ID:** QM5_11381
**Slug:** `psar-ao-ac-trend-align-h1`
**Source:** `875997e6-a398-5eb7-a5ee-75e75a020ad6` (see `strategy-seeds/sources/875997e6-a398-5eb7-a5ee-75e75a020ad6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

Three-indicator Bill Williams trend-alignment on H1. The EA reads the just-closed
signal candle and trades only when Parabolic SAR position, Awesome Oscillator
(AO), and Accelerator Oscillator (AC) all point the same way. AO = SMA(5) of hl2
minus SMA(34) of hl2; AC = AO minus SMA(5) of AO, both computed from `QM_SMA` on
`PRICE_MEDIAN`.

Long when the PSAR dot is below the signal candle, AO is rising (AO[1] > AO[2]),
and AC is rising (AC[1] > AC[2]). Short is the mirror: PSAR dot above the signal
candle, AO falling, and AC falling. Stop = signal-bar low (long) or high (short),
capped at 25 pips; take-profit = 1:1 reward:risk off the realised stop distance.
Discretionary exit closes the position when both AO and AC reverse color against
the open direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sar_step` | 0.02 | 0.01-0.05 | PSAR acceleration step |
| `strategy_sar_max` | 0.20 | 0.10-0.50 | PSAR acceleration maximum |
| `strategy_ao_fast` | 5 | 3-10 | AO fast SMA period on hl2 |
| `strategy_ao_slow` | 34 | 20-55 | AO slow SMA period on hl2 |
| `strategy_ac_sma` | 5 | 3-10 | AC = AO minus SMA(this) of AO |
| `strategy_sl_cap_pips` | 25 | 10-50 | Maximum stop distance in pips (P2 cap) |
| `strategy_tp_rr` | 1.0 | 0.5-3.0 | Take-profit reward:risk multiple |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Skip entry only if quoted spread exceeds this |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight spreads suit a 25-pip-capped H1 trend system.
- `GBPUSD.DWX` — liquid major with trend persistence; same H1 cadence.
- `USDJPY.DWX` — liquid major; pip-scaling handled via `QM_StopRules*` (JPY 3-digit aware).

**Explicitly NOT for:**
- Index/metal `.DWX` symbols — the 25-pip structural stop cap and BW oscillator
  tuning are calibrated to FX-major volatility, not index point ranges.

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
| Trades / year / symbol | `~120` |
| Typical hold time | `hours (intraday H1 swings)` |
| Expected drawdown profile | `moderate; 1:1 RR with structural stops, frequent small losers` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `875997e6-a398-5eb7-a5ee-75e75a020ad6`
**Source type:** `book` (anonymous trading guide PDF, fxmiracle.com "Winning Pips System 4")
**Pointer:** `strategy-seeds/sources/875997e6-a398-5eb7-a5ee-75e75a020ad6/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11381_psar-ao-ac-trend-align-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
| v2 | 2026-06-23 | Rebuild from approved card; implement literal PSAR position plus AO/AC color alignment | 1a440d81-04fe-4d51-bd2d-abe8e1bc7c56 |
