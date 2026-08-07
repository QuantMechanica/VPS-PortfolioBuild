# QM5_12552_ema-stretch-mr-bounded-grid — Strategy Spec

**EA ID:** QM5_12552
**Slug:** `ema-stretch-mr-bounded-grid`
**Source:** `owner-yt-ioynBnSofU4-2026-06-16`
**Author of this spec:** Codex
**Last revised:** 2026-08-04

---

## 1. Strategy Logic

On each completed H1 bar, the EA buys when the ask is more than 10 long-ATR units below EMA(200) and RSI(14) is below 35; it sells on the mirrored stretch above the EMA with RSI above 65. A basket may contain at most five same-direction fills, separated by a volatility-adjusted ATR distance and a minimum number of completed bars. Every fill shares one catastrophic stop beyond the full ladder, while the framework splits one fixed or percentage risk budget backward across all planned levels so the complete ladder remains capped at 1% of equity. The basket exits on an EMA cross, RSI recovery, a VWAP-plus-pips or VWAP-plus-ATR target, an optional time limit, its shared stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `M_entry` | 10.0 | 6.0–12.0 | Long-ATR multiples required between price and EMA(200). |
| `rsi_offset` | 15 | 10–20 | Offset around RSI 50; default thresholds are 35 and 65. |
| `ema_period` | 200 | fixed | Slow EMA used as the mean-reversion anchor. |
| `rsi_period` | 14 | fixed | Wilder RSI period used for entry and recovery exits. |
| `atr_long_period` | 100 | fixed | Long ATR used for entry stretch, stop span, and ATR TP. |
| `atr_short_period` | 14 | fixed | Short ATR used in the volatility-adjusted grid spacing. |
| `grid_levels` | 5 | 3–5 | Maximum total fills, including level 1. |
| `lot_mult` | 1.15 | 1.0–1.3 | Fixed geometric lot-ladder ratio used in the backward risk split. |
| `grid_base_atr_mult` | 1.0 | 0.5–1.5 | Multiplier in the short-ATR grid-distance formula. |
| `grid_min_pips` | 5 | symbol-specific, >0 | Scale-correct minimum distance between planned levels. |
| `grid_min_bars` | 1 | ≥0 | Minimum completed H1 periods between successful fills. |
| `stop_span_atr` | 14.0 | 10.0–18.0 | Long-ATR distance from level 1 to the shared catastrophic stop. |
| `risk_budget_pct` | 1.0 | (0, 1.0] | Absolute equity cap for the whole fully filled ladder. |
| `tp_mode` | `TP_SLOW_MA` | four declared modes | EMA, RSI, VWAP-pips, or VWAP-ATR whole-basket exit. |
| `vwap_target_pips` | 20 | >0 | Scale-correct distance beyond basket VWAP in pips mode. |
| `vwap_atr_mult` | 1.0 | >0 | Long-ATR distance beyond basket VWAP in ATR mode. |
| `max_hold_hours` | 0 | ≥0 | Optional whole-basket time stop; zero disables it. |
| `use_trailing` | false | true/false | Enables shared-stop tightening toward basket break-even. |
| `trail_step_pips` | 10 | >0 | Scale-correct favorable-price step for optional trailing. |
| `max_spread_pips` | 8 | >0 | Blocks only a genuinely positive spread wider than this cap. |

Framework-level risk, news, random-seed, stress, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — primary liquid, range-prone FX-major baseline from the card.
- `GBPUSD.DWX` — primary liquid FX-major portability cell.
- `USDCHF.DWX` — range-prone defensive FX-major cell.
- `AUDUSD.DWX` — liquid commodity-linked FX-major cell.
- `USDCAD.DWX` — liquid commodity-linked FX-major cell.
- `EURGBP.DWX` — range-prone cross specifically named by the card.
- `USDJPY.DWX` — secondary FX-major parameter-sweep cell.
- `EURJPY.DWX` — secondary liquid cross parameter-sweep cell.
- `XAUUSD.DWX` — non-FX volatility portability cell named by the card.
- `NDX.DWX` — strongly trending index falsification cell.
- `WS30.DWX` — strongly trending index falsification cell.
- `GDAXI.DWX` — European index falsification cell.

**Explicitly NOT for:**

- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — the broker/tester has no canonical data contract for them.

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
| Trades / year / symbol | 24 |
| Expected trade frequency | approximately two completed baskets per month, derived from the card's annual expectation |
| Typical hold time | not specified by the card; until mean recovery, hard TP/SL, optional time stop, or Friday close |
| Expected drawdown profile | about 12% expected drawdown, with clustered basket losses during persistent trends |
| Regime preference | ranging and mean-reverting FX; index registrations are deliberate falsification cells |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `owner-yt-ioynBnSofU4-2026-06-16`
**Source type:** OWNER-provided video
**Pointer:** `https://www.youtube.com/watch?v=ioynBnSofU4`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_12552_ema-stretch-mr-bounded-grid.md`.

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
| v1 | 2026-08-04 | Initial build from card | e3cae802-397c-4986-b950-02c8bc62d05a |
