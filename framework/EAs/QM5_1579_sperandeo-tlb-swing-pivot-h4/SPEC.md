# QM5_1579_sperandeo-tlb-swing-pivot-h4 - Strategy Spec

**EA ID:** QM5_1579
**Slug:** `sperandeo-tlb-swing-pivot-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA rebuilds a close-only three-line-break state once per closed H4 bar. A continuation line forms when the close extends in the current line direction; a reversal line forms only after the close crosses the prior three-line block extreme. After a TLB reversal, the EA waits up to three H4 bars for a Sperandeo 2B failed-break confirmation: a downside TLB flip must see price trade back above the flip reference and close below it for a short, while an upside flip must see price trade below the flip reference and close back above it for a long.

Entries use market orders on the confirming closed H4 bar. Stops use the tighter of a structural stop beyond the failed-break bar and a 2.2xATR cap. There is no fixed take-profit; open risk is managed by a TLB-level ATR trail when the current TLB direction agrees with the position. Positions close on an opposite confirmed 2B signal or framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tlb_lines` | 3 | 2-5 | Number of prior TLB lines required for reversal confirmation |
| `strategy_tlb_window_bars` | 260 | 120-520 | H4 warmup bars used to rebuild TLB state |
| `strategy_2b_window_bars` | 3 | 1-5 | Maximum bars after a TLB flip for 2B confirmation |
| `strategy_atr_period` | 14 | 10-30 | ATR period for stop, spread, and trail sizing |
| `strategy_sl_atr_mult` | 2.2 | 1.5-3.5 | Absolute ATR stop cap from market entry |
| `strategy_struct_stop_atr_mult` | 0.25 | 0.10-0.60 | Stop buffer beyond the 2B confirmation bar |
| `strategy_trail_atr_mult` | 1.0 | 0.5-2.0 | ATR buffer around the active TLB level for trailing stops |
| `strategy_use_adx_filter` | true | true/false | Require minimal directional movement before entry |
| `strategy_adx_period` | 14 | 10-30 | ADX period |
| `strategy_adx_min` | 16.0 | 10-25 | Minimum ADX on the confirming H4 bar |
| `strategy_max_spread_points_fx` | 25 | 10-60 | Hard spread cap for FX symbols |
| `strategy_max_spread_points_cfd` | 50 | 20-120 | Hard spread cap for index, metal, and energy CFDs |
| `strategy_spread_atr_mult` | 0.25 | 0.10-0.50 | Dynamic spread cap as a fraction of H4 ATR |

---

## 3. Symbol Universe

Registered symbols:

| Slot | Symbol | Rationale |
|---:|---|---|
| 0 | `EURUSD.DWX` | Liquid FX major explicitly listed in the approved card |
| 1 | `GBPUSD.DWX` | Liquid FX major explicitly listed in the approved card |
| 2 | `USDJPY.DWX` | Liquid FX major explicitly listed in the approved card |
| 3 | `NDX.DWX` | Index CFD explicitly listed in the approved card |
| 4 | `WS30.DWX` | Index CFD explicitly listed in the approved card |
| 5 | `XAUUSD.DWX` | Metal CFD explicitly listed in the approved card |
| 6 | `XTIUSD.DWX` | Energy CFD included from the approved R3 portability row |

The card body lists six direct target symbols and the approved R3 portability row also names `XTIUSD.DWX`. Slot 6 is therefore included to increase sleeve diversity without changing the structural rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)`; TLB state and entry decisions only rebuild once per closed H4 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 4-12; TLB reversals plus 2B confirmation are intentionally selective |
| Typical hold time | 1-10 trading days |
| Drawdown profile | Moderate; per-trade risk is bounded by RISK_FIXED sizing and ATR/structure stops |
| Regime preference | Swing regimes with false breaks after structural line reversals |
| Failure mode | Zero or sparse trades in quiet monotonic markets |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book / thread cluster
**Pointer:** Steve Nison line-break rules and Victor Sperandeo / Trader Vic 2B failed-break reversal concepts, as cited by the approved strategy card.
**R1-R4 verdict:** all PASS in `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1579_sperandeo-tlb-swing-pivot-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live | RISK_PERCENT | Allocated by portfolio gate after certification |

ENV to mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial V5 build from approved card | Task `1b55b916-5958-4d3e-8089-39dd42fc50d5` |
