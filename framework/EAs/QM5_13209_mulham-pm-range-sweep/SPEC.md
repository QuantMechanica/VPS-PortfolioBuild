# QM5_13209_mulham-pm-range-sweep — Strategy Spec

**EA ID:** QM5_13209
**Slug:** `mulham-pm-range-sweep`
**Source:** `YT-MULHAM-2026-07` (see `strategy-seeds/sources/YT-MULHAM-2026-07/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-21

---

## 1. Strategy Logic

The prior day's PM session (20:30-23:00 broker, i.e. 13:30-16:00 ET) high/low
is treated as institutional reference liquidity. Once per day, a D1 EMA(9) vs
EMA(18) bias is set: bullish bias only looks for low-side sweeps (long),
bearish bias only looks for high-side sweeps (short). Within the 16:30-18:00
broker morning window (9:30-11:00 ET), the EA watches for an M5 bar that
trades beyond the bias-aligned PM extreme and closes back inside the PM range
(v-shape fakeout sweep). The very next closed M5 bar is the one displacement
candidate: it must close back through the sweep bar's opposite extreme with a
range >= 1.5x ATR(14, M5), leaving an M5 gap (FVG) between the two bars. Entry
is a limit order at 50% of that FVG, cancelled if unfilled by 19:00 broker.
Stop loss sits beyond the sweep extreme by a 0.1xATR buffer; take profit is
the opposite PM-range extreme (a fixed-2.5R variant is available via
`strategy_tp_mode` for Q03 sweeps). The setup is skipped if the PM session
was strongly trending (net move > 75% of its range), if reward-to-risk to the
opposite extreme is below 1.5R, or if displacement fails to confirm — at most
one setup is evaluated per symbol per day, with no re-scan for a fresh sweep
if that single evaluation misses.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `pm_start_hour` / `pm_start_min` | 20 / 30 | broker clock | PM reference-session window start |
| `pm_end_hour` / `pm_end_min` | 23 / 0 | broker clock | PM reference-session window end |
| `pm_trend_max_frac` | 0.75 | 0-1 | Skip the day if PM net move > this fraction of the PM range |
| `ema_fast_period` | 9 | >=1 | D1 EMA fast period for the bias gate |
| `ema_slow_period` | 18 | >=1 | D1 EMA slow period for the bias gate |
| `sweep_start_hour` / `sweep_start_min` | 16 / 30 | broker clock | Sweep/entry window start |
| `sweep_end_hour` / `sweep_end_min` | 18 / 0 | broker clock | Sweep window end (displacement bar may close slightly after) |
| `atr_period` | 14 | >=1 | ATR(period, M5) used for displacement and SL buffer |
| `displacement_atr_mult` | 1.5 | >0 | Minimum displacement-bar range as a multiple of ATR |
| `sl_buffer_atr_mult` | 0.1 | >=0 | Extra buffer beyond the sweep extreme for the stop loss |
| `rr_floor` | 1.5 | >0 | Minimum reward:risk to the opposite-extreme target |
| `entry_cancel_hour` | 19 | broker hour | Cancel the unfilled FVG limit order at this hour |
| `flatten_hour` | 20 | broker hour | Time-flatten any open position at this hour |
| `strategy_tp_mode` | STRATEGY_TP_OPPOSITE_EXTREME | enum | `OPPOSITE_EXTREME` (primary) or `FIXED_RR` (Q03 variant) |
| `tp_rr_multiple` | 2.5 | >0 | RR multiple used when `strategy_tp_mode=FIXED_RR` |
| `spread_cap_pips` | 50 | >0 | Spread guard (never fires on .DWX's 0 modeled spread) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `SP500.DWX` — card-frontmatter `US500.DWX` is not in `dwx_symbol_matrix.csv`;
  ported to the canonical S&P 500 Custom Symbol per build-handoff DWX symbol
  discipline (backtest-only; live orders route on broker symbol `SP500`).
- `NDX.DWX` — named directly in the card's target_symbols; source author's
  own tested basket (SPX/NDX/DJI).

**Explicitly NOT for:**
- `US500.DWX` — not a registered Custom Symbol; see port note above.
- Non-index symbols — the PM-range / NY-morning-sweep mechanism is
  index-specific per the card thesis (author found S&P "by far the best").

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | D1 (EMA9/EMA18 bias gate, shift=1 closed bar) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday, ~1-3.5 hours (entry ~16:30-19:00 broker, flatten 20:00 broker) |
| Expected drawdown profile | ~12% (card `expected_dd_pct`) |
| Regime preference | Mean-revert / liquidity-sweep reversal, NY-morning session |
| Win rate target (qualitative) | Medium (RR-floor-gated reversal, PF target 1.15) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `YT-MULHAM-2026-07`
**Source type:** `video`
**Pointer:** `docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md`;
`D:\QM\reports\research\mulham_trading_channel_2026-07-13\extractions\cluster1_session_window.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13209_mulham-pm-range-sweep.md`

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
| v1 | 2026-07-21 | Initial build from card | d54ae7b2-bed6-4c7d-85a2-5030944f3127 |
