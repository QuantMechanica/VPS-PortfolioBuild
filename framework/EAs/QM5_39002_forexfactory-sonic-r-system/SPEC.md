# QM5_39002_forexfactory-sonic-r-system — Strategy Spec

**EA ID:** QM5_39002
**Slug:** `forexfactory-sonic-r-system`
**Source:** `forexfactory-sonic-r-system-official-source` (see `strategy-seeds/sources/forexfactory-sonic-r-system-official-source/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_39002_forexfactory-sonic-r-system.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_39002_forexfactory-sonic-r-system.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

Long and short stops use the respective outer Dragon edge plus the card's exact
3-pip buffer. Invalid stop geometry rejects the entry; ATR is used only for the
spread ceiling and is never substituted for the card stop. The target is 2.5R,
and an open position moves to exact break-even once price reaches its original
1R distance. Active management runs before entry-only rollover, spread, daily
loss, and news admission checks.

The card thesis mentions volume-rejection pinbars and lists RSI as context, but
its exact deterministic entry rules in §§3.2–3.3 define no volume, pinbar, or
RSI predicate. The EA therefore implements the closed-form Dragon/TrendWave
conditions verbatim and does not invent an additional entry filter.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_M15 | M15 only | Card signal timeframe |
| `strategy_dragon_period` | 34 | 21–50 | EMA period for Dragon High/Low |
| `strategy_trendwave_period` | 89 | 55–144 | EMA period for the close-based trend wave |
| `strategy_atr_period` | 14 | 14 (sealed) | ATR period for the spread ceiling |
| `strategy_sl_buffer_pips` | 3.0 | 3.0 (sealed) | Stop buffer beyond the outer Dragon edge |
| `strategy_tp_rr_mult` | 2.5 | 2.5 (sealed) | Take-profit multiple of initial risk |
| `strategy_be_enabled` | true | true (sealed) | Enables the card-required break-even move |
| `strategy_be_trigger_r` | 1.0 | 1.0 (sealed) | Profit multiple that triggers break-even |
| `strategy_rollover_start_hhmm` | 2355 | 2355 (sealed) | GMT rollover blackout start |
| `strategy_rollover_end_hhmm` | 5 | 0005 (sealed) | GMT rollover blackout end |
| `strategy_spread_filter_mult` | 1.8 | 1.8 (sealed) | Maximum spread as a multiple of ATR(14) |
| `strategy_max_slippage_ticks` | 3 | 1-3 | Maximum market-order deviation in trade ticks |
| `strategy_daily_loss_halt_pct` | 2.0 | >0-2.0 | Realized daily loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.5 | >0-2.5 | Kill-switch daily drawdown ceiling |
| `strategy_total_dd_halt_pct` | 5.0 | >0-5.0 | Kill-switch total drawdown ceiling |
| `strategy_per_trade_risk_cap_pct` | 0.5 | >0-0.5 | Per-trade percentage-risk ceiling |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_temporal, qm_news_compliance, qm_news_mode_legacy, qm_rng_seed,
> qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` (`PERIOD_M15`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | see card body |
| Expected drawdown profile | 2.0% daily entry halt, 2.5% daily hard stop, 5.0% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-sonic-r-system-official-source`
**Pointer:** `strategy-seeds/sources/forexfactory-sonic-r-system-official-source/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_39002_forexfactory-sonic-r-system.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

Risk-sizer configuration is enforced by the scoped build gate
(`EA_RISK_SIZER_UNCONFIGURED`). Backtest setfiles bind `RISK_FIXED=1000` and
`RISK_PERCENT=0`; live packaging must invert those modes under its separate
governed workflow.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial spec (ex-post, generated by gen_spec_md.py) | post-PT15 remediation |
| v2 | 2026-08-23 | Card-contract remediation | Exact Dragon stop, UTC rollover, risk rails, slippage cap, and restart-safe BE ordering |
| v3 | 2026-08-24 | Review-fix closure | Strict raw-series annotations and corrected current framework risk/news terminology |
| v4 | 2026-08-24 | Burn-window build audit | Added approved-card mirror, exact parameter documentation, and governed registry/setfile regeneration |
