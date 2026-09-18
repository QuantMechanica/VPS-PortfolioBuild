# QM5_41476_cash-open-mean-reversion-h1 - Strategy Spec

**EA ID:** QM5_41476
**Slug:** `cash-open-mean-reversion-h1`
**Source:** `QM-RESEARCH-2026-0006` (internal research; preregistration `8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d`, source_hash `1887b25e0fb0597f97a9a9ae9461333bc16d3b2b6e0a8bf96412cea55032bd19`)
**Author of this spec:** Kimi (interim strategy-engineering delegation)
**Last revised:** 2026-09-16
**STATUS: CRITIC_FIXES_APPLIED (2026-09-18)** — independent non-Kimi critique by Fable (Claude, fable-5.1) with verdict ACCEPT_WITH_FIXES; the blocking fixes (live news blackout via native MT5 calendar; entry window on the closed signal bar where applicable) are applied and compiled 0/0; deferred findings are listed in `docs/ops/evidence/2026-09-18_ftmo_candidate_critic_wave/RECEIPT.md`. Ready for seal → prescreen → enqueue-compile.
**REGISTRY STATUS: ALLOCATED** — active `ea_id_registry.csv` / `magic_numbers.csv` rows exist and `QM_MagicResolver.mqh` carries the tuples (magic = ea_id*10000 + slot, slots per approved-card symbol order). The earlier PENDING_ALLOCATION paragraph is historical (see the build receipt).

---

## 1. Strategy Logic

Session-flat cash-open index mean reversion on H1, fully mechanical per the mechanized H_MR card. The session is anchored in UTC hours (inputs). On each closed H1 bar the EA maintains the day's state: the opening range (max high / min low of the first `strategy_opening_range_bars` session bars) and its midpoint, the first-bar shock verdict, per-day spread samples and a rolling 20-day median of daily medians, and the daily/weekly circuit-breaker P&L. An entry fires on a closed bar strictly after the opening range when that bar pierces the range extreme by an ATR buffer and closes back inside the range on the same bar, stretched to the correct side of the EMA: long when the low pierced below and the close sits below the EMA, short when the high pierced above and the close sits above the EMA. Eligibility requires the midpoint reward to be at least `min_target_r` times the stop risk measured at the market price. The stop sits beyond the failed-breakout extreme plus `atr_stop_mult` x ATR; the take profit is the fixed opening-range midpoint. Exits: SL/TP, time stop after `time_stop_bars` H1 bars, or mandatory flat at `flatten_hour_utc` — whichever comes first. One entry per symbol per day; at most `max_positions_total` open positions across the EA family.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol_slot0..2` | NDX/GDAXI/SP500 `.DWX` | slot inputs | Symbol slots 0-2; the chart symbol must equal `strategy_symbol_slot<qm_magic_slot_offset>` or OnInit fails. |
| `strategy_opening_range_bars` | 3 | 2-4 | First N session H1 bars defining the opening range. |
| `strategy_ema_period` | 20 | 15-30 | H1 EMA defining the stretch side. |
| `strategy_breakout_buffer_atr` | 0.025 | 0.0-0.05 | ATR buffer the bar must pierce beyond the range extreme. |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop, shock filter and break-even. |
| `strategy_atr_stop_mult` | 1.0 | 0.5-1.5 | Stop distance beyond the failed extreme = mult x ATR. |
| `strategy_min_target_r` | 0.5 | 0.4-0.8 | Minimum reward:risk for entry eligibility (midpoint reward vs stop risk). |
| `strategy_time_stop_bars` | 6 | 4-8 | Time stop in full H1 bars after entry. |
| `strategy_risk_per_trade_pct` | 0.25 | 0.20-0.50 | Live fixed-fractional risk per trade (RISK_PERCENT basis; backtest uses RISK_FIXED). |
| `strategy_daily_stop_pct` | -1.0 | fixed | Day breaker: no new entries once day P&L <= this. |
| `strategy_weekly_stop_pct` | -2.0 | fixed | Week breaker: no new entries once week P&L <= this. |
| `strategy_shock_atr_mult` | 3.0 | 2.5-4.0 | Skip the day when the first session bar range exceeds mult x ATR. |
| `strategy_spread_median_mult` | 1.5 | 1.25-1.75 | Skip entries when spread exceeds mult x 20-day median spread. |
| `strategy_session_start_hour_utc` | 13 | 13-14 | First session hour (UTC). |
| `strategy_session_end_hour_utc` | 17 | 16-17 | Last entry hour (UTC, inclusive). |
| `strategy_flatten_hour_utc` | 20 | 20-21 | Mandatory flat hour (UTC). |
| `strategy_friday_cutoff_hour_utc` | 17 | 17-18 | No new Friday entries from this UTC hour. |
| `strategy_max_positions_total` | 2 | 1-3 | Max open positions across this EA's symbol slots. |
| `strategy_news_blackout_minutes` | 60 | 0-120 | High-impact news blackout around entry (fail-closed). |
| `strategy_spread_min_days` | 5 | impl. knob | Daily medians required before the spread filter enforces. |
| `strategy_breakeven_at_one_atr` | true | bool | Move stop to entry after +1.0 ATR in favour (never widens). |

Session hours are UTC inputs; broker time is mapped via `QM_DSTAware` (`QM_BrokerToUTC` / `QM_UTCToBroker`) — no hand-rolled DST. Ranges are enforced as locked-configuration guards in `Strategy_NoTradeFilter`.

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - slot 0, card-listed index CFD with DWX data.
- `GDAXI.DWX` - slot 1, card-listed index CFD with DWX data.
- `SP500.DWX` - slot 2, card-listed index CFD with DWX data.

**Explicitly NOT for:**
- FX, metals, energy — the card names index CFDs only.
- Live charts: the EA resolves its slot by exact `_Symbol` match against the slot inputs; deploy packaging must rewrite the inputs to the bare broker symbol names (`.DWX` stripping is a deploy-time step only).

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` (hard gate: any other chart timeframe blocks trading) |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)`; entry reads closed bar shift 1 |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades | At most 1 entry per symbol per day; ~2-5/month/symbol (card pilot: 2.9 on an NDX-class feed) |
| Overnight exposure | None — mandatory flat 20:00 UTC, no weekend carry |
| Breakers | Day -1.0%, week -2.0% block new entries (cached, new-bar computed) |
| News | High-impact blackout 60 min around entry, fail-closed |

## 6. Filters and Gates (execution order)

1. `QM_KillSwitchCheck` (framework, 3% catastrophic backstop stays intact).
2. Friday-close sweep (framework).
3. `Strategy_NoTradeFilter` — static config + timeframe + slot guards only; never blocks exits.
4. `Strategy_ManageOpenPosition` — break-even at +1.0 ATR (per tick).
5. `Strategy_ExitSignal` — flatten hour + time stop (per tick, ungated).
6. Framework 2-axis news check (at OFF/DXZ defaults; entry gate only).
7. New H1 bar: `Strategy_EntrySignal` — day state, opening range, one-per-day, position-per-magic, entry window hours, Friday cutoff, breakers, shock, spread-vs-median, card news blackout, family capacity, pierce-and-reclaim + EMA stretch + min-R eligibility.

## 7. Risk Notes

- No martingale, no averaging, no grid; one entry per symbol per day; break-even only tightens.
- The framework kill-switch (3% daily) remains as a catastrophic backstop behind the card's strategy-level -1.0%/-2.0% breakers.
- `.DWX` zero modeled spread fails open in the spread filter (only genuinely wide spread blocks).
- PENDING_ALLOCATION: `QM_FrameworkMagic()` cannot resolve until magic rows exist; do not run.

## 8. Build Evidence

- Compile: canonical `framework/scripts/build_check.ps1 -EALabel QM5_41476_cash-open-mean-reversion-h1` → `compile_one.result=PASS`, **0 errors, 0 warnings** (`build_check.result=PASS`, 0 failures, 4 documented warnings: event-vocabulary unknown `INIT_SLOT_MISMATCH` — same bespoke event as the H-CW sibling; 3 card-undecidable warnings expected under PENDING_ALLOCATION). First-pass manual MetaEditor 64 compile against the staged worktree include tree (`artifacts/builds/inc_staging`, worktree `framework/include` + terminal stdlib) also **0 errors, 0 warnings** (`docs/ops/evidence/2026-09-16_kimi_hmr/compile_log_local_wt_includes.txt`).
- Symbol-literal lint (`lint_ea_symbol_literals.py --ea-root framework/EAs/QM5_41476_cash-open-mean-reversion-h1`): **OK** (no hardcoded .DWX literals in logic; the 3 occurrences are the sanctioned slot input defaults).
- Registry/magic tests: 21 passed (allocator + precheck + resolver strict-default); registry untouched by this build.
- `.ex5` sha256 (canonical build_check binary) **89d1107a…3a702** — intentionally not committed (EX5_COMMIT_GUARD requires a governed COMPILE_EA receipt); recorded in `docs/ops/evidence/2026-09-16_kimi_hmr/setfile_and_ex5_sha256.txt`.
- Card prescreen: recorded verbatim in `docs/ops/evidence/2026-09-16_kimi_hmr/card_prescreen_report.json` (REJECT with the critic-pending reason and a documented near-duplicate false positive; see RECEIPT.md).
- Full receipt: `docs/ops/evidence/2026-09-16_kimi_hmr/RECEIPT.md`.
