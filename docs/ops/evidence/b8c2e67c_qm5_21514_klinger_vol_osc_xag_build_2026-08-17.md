# QM5_21514 Klinger Volume Oscillator (XAGUSD D1) Build Evidence — 2026-08-17

**Task ID:** `b8c2e67c-773b-4698-913b-9de744f6317e` (priority 55, `build_ea`, agent `gemini`).  
**EA:** `QM5_21514_qs-klinger-vol-osc-xag`.  
**Slug:** `qs-klinger-vol-osc-xag`.  
**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c` (QuantifiedStrategies.com KVO Strategy).  
**Approved Card:** `artifacts/cards_approved/QM5_21514_qs-klinger-vol-osc-xag.md`.  
**Artifact Path:** `docs/ops/evidence/b8c2e67c_qm5_21514_klinger_vol_osc_xag_build_2026-08-17.md`.

---

## 1. Executive Summary

Completed the end-to-end build, canonical setfile authoring, compilation, build-check verification, and guardrail validation for `QM5_21514_qs-klinger-vol-osc-xag`:

1. **Strategy Specification & Architecture**:
   - Implements Scott Carney / QuantifiedStrategies Klinger Volume Oscillator (KVO) on completed D1 bars of `XAGUSD.DWX`.
   - Computes Volume Force from daily high-low range, day-over-day price direction trend, cumulative same-direction range, and MT5 tick volume.
   - Calculates fast (34) and slow (55) volume force EMAs, subtracting them to form KVO, then signals entries when KVO crosses its 13-period signal line EMA.
   - Exits on opposite KVO crossover, 2.5× ATR(14) hard stop, 60-bar time stop, or Friday session close.
2. **Session Offset & Metal Entry Clock Verification**:
   - Single-symbol scope is restricted to `XAGUSD.DWX` on `PERIOD_D1` via `Strategy_NoTradeFilter()`.
   - Cross-referenced `framework/registry/session_offset_minutes.csv` which documents the measured 60.0 min modal daily session offset for metals.
   - Bar gating uses standard closed-bar `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` to align with the first tradable tick of the new daily metal session.
3. **Canonical Setfile Authoring**:
   - Created `sets/QM5_21514_qs-klinger-vol-osc-xag_XAGUSD.DWX_D1_backtest.set` with `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`, `qm_news_stale_max_hours = 336`, and exact strategy defaults matching the approved card.
4. **Clean Strict Compilation & Framework Build Check**:
   - `build_check.ps1 -EALabel QM5_21514_qs-klinger-vol-osc-xag`: **PASS** (0 failures, 0 warnings).
   - `compile_one`: **PASS** (0 errors, 0 warnings).
   - `validate_build_guardrails.py`: **PASS** (0 findings).

---

## 2. Parameter Configuration & Setfile Contract

| Parameter | Value | Meaning |
|---|---:|---|
| `qm_ea_id` | `21514` | EA registry identity |
| `qm_magic_slot_offset` | `0` | Base slot for single-symbol XAGUSD (magic: `215140000`) |
| `RISK_FIXED` | `1000.0` | Fixed dollar risk per trade for backtest (HR4) |
| `RISK_PERCENT` | `0.0` | Percent risk disabled in backtest mode |
| `PORTFOLIO_WEIGHT` | `1.0` | Baseline sleeve allocation weight |
| `qm_news_stale_max_hours` | `336` | News calendar freshness threshold (14 days) |
| `qm_friday_close_enabled` | `true` | Weekly Friday risk mitigation |
| `strategy_kvo_fast_period` | `34` | Volume Force Fast EMA period |
| `strategy_kvo_slow_period` | `55` | Volume Force Slow EMA period |
| `strategy_kvo_signal_period` | `13` | KVO Signal Line EMA period |
| `strategy_atr_period` | `14` | Daily ATR period for structural stop |
| `strategy_atr_sl_mult` | `2.5` | ATR multiplier for stop loss |
| `strategy_max_hold_bars` | `60` | Time stop cap in completed D1 bars |
| `strategy_warmup_buffer` | `20` | Derived-series stabilization buffer |
| `strategy_max_spread_points` | `400` | Native points spread threshold on entry |

---

## 3. Verification & Sealed Artifact Hashes

| Artifact Path | SHA-256 Hash | Size | Status |
|---|---|---:|---|
| `framework/EAs/QM5_21514_qs-klinger-vol-osc-xag/QM5_21514_qs-klinger-vol-osc-xag.mq5` | `232e19fd5ff1b4e5c95ce142be8937a56ecd9134e93d59d9a44df6a2e3c9ab1a` | 21,148 B | Clean (0E/0W) |
| `framework/EAs/QM5_21514_qs-klinger-vol-osc-xag/QM5_21514_qs-klinger-vol-osc-xag.ex5` | `76929098ce1fe1eae74b43c6a9f861da57efd41ab6ce575d1611cb865bef8892` | 379,850 B | Compiled 0/0 |
| `framework/EAs/QM5_21514_qs-klinger-vol-osc-xag/sets/QM5_21514_qs-klinger-vol-osc-xag_XAGUSD.DWX_D1_backtest.set` | `0ced3190a5d37a7d3ea7caf6b7c031264b2e340c3fda87e7a40e5a98ba7167b3` | 1,109 B | Sealed |
| `framework/EAs/QM5_21514_qs-klinger-vol-osc-xag/SPEC.md` | `9d7b9ffdfb78e3820a45eaef3c5c56784d13a69715a3a2e3ce97b2ee93c8d35d` | 3,778 B | Verified |

- `validate_build_guardrails.py`: **PASS** (`max_news_stale_hours = 336`, `entry_grace_margin_minutes = 5.0`).
- `build_check.ps1`: **PASS** (`failures = 0`, `warnings = 0`).
- `compile_one`: **PASS** (`errors = 0`, `warnings = 0`).

---

## 4. Disposition & Hand-Off

- **Router Task ID:** `b8c2e67c-773b-4698-913b-9de744f6317e`
- **Assigned State:** `REVIEW` (per Hard Rule: Gemini code tasks remain in `REVIEW` for Codex/Claude audit; no self-approval or movement to `PIPELINE`).
- **Verdict:** `BUILD_COMPLETED_AND_VERIFIED_0_ERRORS_0_WARNINGS`
- **Next Steps:** Awaiting Codex review and subsequent Q02 backtest enqueue by deterministic pipeline pump.
