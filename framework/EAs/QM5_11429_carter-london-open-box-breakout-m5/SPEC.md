# QM5_11429_carter-london-open-box-breakout-m5 - Strategy Spec

**EA ID:** QM5_11429
**Slug:** carter-london-open-box-breakout-m5
**Source:** ec63ff86-b6dd-522b-ac8e-d90de82e2dee
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a London-open box breakout on M5 forex symbols. It converts broker time to US Eastern time, builds the box from the 07:00-08:00 ET M5 highs and lows, and only accepts boxes between 5 and 60 pips high. During the 08:00-09:00 ET entry window, a closed M5 bar that breaks above `box_high + 0.20 * box_height` places a `QM_BUY_STOP` at that level, while a break below `box_low - 0.20 * box_height` places a `QM_SELL_STOP`. The stop is on the opposite box side plus a 1-pip buffer, TP is four box heights from the box boundary, pending orders expire at 09:00 ET, open trades are time-stopped at 10:00 ET, and SL trails by one box height once price moves two box heights beyond the boundary.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_box_end_et_hhmm` | 800 | 0000-2359 | Eastern-time box close and London-open trigger time. |
| `strategy_box_minutes` | 60 | >0 | Minutes scanned before box end to form the range. |
| `strategy_entry_window_minutes` | 60 | >0 | Minutes after box end during which breakout entries are valid. |
| `strategy_position_stop_minutes` | 120 | >0 | Minutes after box end when open trades are closed by time stop. |
| `strategy_entry_buffer_mult` | 0.20 | >=0 | Fraction of box height added beyond the box for stop entry triggers. |
| `strategy_tp_box_mult` | 4.00 | >0 | TP distance from the box boundary in box-height multiples. |
| `strategy_trail_trigger_mult` | 2.00 | >0 | Box-height multiple beyond the boundary that activates trailing. |
| `strategy_trail_distance_mult` | 1.00 | >0 | Trailing SL distance in box-height multiples. |
| `strategy_min_box_pips` | 5 | >=1 | Minimum valid box height. |
| `strategy_max_box_pips` | 60 | >=1 | Maximum valid P2 box height cap. |
| `strategy_sl_buffer_pips` | 1 | >=0 | Stop-loss buffer beyond the opposite box side. |
| `strategy_spread_cap_pips` | 15 | >=0 | Entry spread cap; zero modeled spread is allowed. |
| `strategy_box_scan_bars` | 96 | >=12 | Bounded M5 scan depth used to locate the ET box bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - Carter primary FX pair with London-session liquidity and M5 DWX data.
- `GBPUSD.DWX` - Carter primary FX pair with London-session liquidity and M5 DWX data.
- `EURUSD.DWX` - Card-approved portable FX expansion with deep London-session liquidity and M5 DWX data.

**Explicitly NOT for:**
- Non-FX index symbols - the card's R3 pass section is specific to M5 DWX FX pairs.
- FX symbols not registered for QM5_11429 - the EA relies on the registered magic slot for each approved symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Pending order valid up to 1 hour; filled trades time-stop by 10:00 ET, about 0-2 hours after box close. |
| Expected drawdown profile | Breakout profile with small fixed-risk losses when false London breaks reverse through the box. |
| Regime preference | London-session volatility expansion / breakout. |
| Win rate target (qualitative) | Low-to-medium, offset by 4x box-height TP. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ec63ff86-b6dd-522b-ac8e-d90de82e2dee
**Source type:** book / local PDF archive
**Pointer:** John Carter, "20 Strategies for the 5-Minute Timeframe", local PDF in strategy archive.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11429_carter-london-open-box-breakout-m5.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | c2cfeef6-9bca-4e66-94ac-4b249bd14c09 |
