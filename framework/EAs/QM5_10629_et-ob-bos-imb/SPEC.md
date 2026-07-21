# QM5_10629_et-ob-bos-imb — Strategy Spec

**EA ID:** QM5_10629
**Slug:** `et-ob-bos-imb`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA waits for a completed H1 candle to run a stop hunt through the most recent 3-left/3-right swing, then close back inside the swept level. Within the next 12 H1 bars it requires a break of structure through the opposite swing, a displacement candle body of at least 0.75 ATR(14), and a same-direction fair value gap. It then places a limit order at the 50% level of the last opposite candle before the BOS impulse, with an ATR-buffered stop beyond the order block and sweep extreme. Exits are handled by 2.0R or the nearest opposing swing target, opposite structure break, the 36-bar time stop, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_width` | 3 | 1-10 | Left/right bars required to confirm a swing high or low. |
| `strategy_atr_period` | 14 | 1-100 | H1 ATR period for sweep depth, BOS body, OB height, and SL buffer. |
| `strategy_sweep_atr_mult` | 0.25 | 0.01-5.00 | Minimum stop-hunt pierce beyond the swing as an ATR multiple. |
| `strategy_bos_max_bars` | 12 | 1-100 | Maximum H1 bars after the sweep for the BOS confirmation. |
| `strategy_bos_body_atr_mult` | 0.75 | 0.01-5.00 | Minimum BOS candle body as an ATR multiple. |
| `strategy_ob_entry_fraction` | 0.50 | 0.00-1.00 | Entry level inside the order-block zone; 0.50 is the midpoint. |
| `strategy_ob_max_atr_mult` | 1.50 | 0.01-10.00 | Maximum allowed order-block height as an ATR multiple. |
| `strategy_sl_atr_buffer_mult` | 0.20 | 0.00-5.00 | Stop buffer beyond the OB and sweep extreme as an ATR multiple. |
| `strategy_rr_target` | 2.00 | 0.10-10.00 | R-multiple target before comparing to the nearest opposing swing. |
| `strategy_pending_bars` | 10 | 1-100 | H1 bars before an unfilled limit order expires. |
| `strategy_time_exit_bars` | 36 | 1-500 | Maximum H1 bars to hold an open position. |
| `strategy_structure_lookback` | 80 | 20-500 | H1 bars scanned for recent swings and opposing liquidity. |
| `strategy_max_spread_atr_fraction` | 0.20 | >0 | Execution-safety guard: block new orders when live spread exceeds this fraction of closed H1 ATR(14). The default deliberately matches the card's existing 0.20 ATR stop-buffer scale; it is not symbol/outcome calibrated. |

**Spread-guard provenance:** the explicit entry guard is required by the
QM5_10629 rework directive in
`D:\QM\strategy_farm\artifacts\verdicts\review_028ddeae-f90a-4b8f-a766-0eede693b995.json`.
That directive does not authorize a fixed symbol-point threshold.  The EA
therefore uses a dimensionless ATR fraction tied to the approved stop-buffer
default instead of inventing or outcome-tuning a USDJPY points value.

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair with clean H1 structure and stop-hunt behaviour.
- `GBPUSD.DWX` — liquid major FX pair suitable for order-block retests.
- `USDJPY.DWX` — liquid major FX pair with H1 sweep and BOS opportunities.
- `XAUUSD.DWX` — high-liquidity gold CFD with frequent H1 displacement swings.
- `GDAXI.DWX` — canonical DWX DAX symbol used in place of the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

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
| Trades / year / symbol | `30` |
| Typical hold time | Up to 36 H1 bars. |
| Expected drawdown profile | Moderate structure-break losses with fixed per-trade risk and no pyramiding. |
| Regime preference | Liquidity sweep, displacement, and retest regime. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/3-simple-smart-money-concepts-to-trading-order-blocks.366106/`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_10629_et-ob-bos-imb.md`

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
| v1 | 2026-06-13 | Initial build from card | 43c7efed-e638-4f73-a0de-6b00ab61ff2b |
| v2 | 2026-07-21 | Source-fidelity repair | Enforce distinct closed-bar sweep/BOS/FVG/order stages, deterministic restart reconstruction, spread gate, and closed-bar opposite-BOS exit. |
