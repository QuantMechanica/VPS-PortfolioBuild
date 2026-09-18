# QM5_41477_fx-session-mean-reversion-m15 - Strategy Spec

**EA ID:** QM5_41477
**Slug:** `fx-session-mean-reversion-m15`
**Source:** `QM-RESEARCH-2026-0005` (internal research; preregistration `c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475`)
**Author of this spec:** Kimi (interim strategy-engineering delegation)
**Last revised:** 2026-09-16
**STATUS: CRITIC_FIXES_APPLIED (2026-09-18)** — independent non-Kimi critique by Fable (Claude, fable-5.1) with verdict ACCEPT_WITH_FIXES; the blocking fixes (live news blackout via native MT5 calendar; entry window on the closed signal bar where applicable) are applied and compiled 0/0; deferred findings are listed in `docs/ops/evidence/2026-09-18_ftmo_candidate_critic_wave/RECEIPT.md`. Ready for seal → prescreen → enqueue-compile.
**REGISTRY STATUS: ALLOCATED** — active `ea_id_registry.csv` / `magic_numbers.csv` rows exist and `QM_MagicResolver.mqh` carries the tuples (magic = ea_id*10000 + slot, slots per approved-card symbol order). The earlier PENDING_ALLOCATION paragraph is historical (see the build receipt).

---

## 1. Strategy Logic

Session-flat FX session mean reversion on M15, fully mechanical per the mechanized H_FXMR card. The session is anchored in UTC hours (inputs) and split into two entry windows — London (default 07:00-11:00) and New York (default 12:00-16:00). On each closed M15 bar the EA maintains the day's state: per-window first-bar shock verdicts, the per-day entry counter, the per-window traded flags, per-day spread samples and a rolling 20-day median of daily medians, and the daily/weekly circuit-breaker P&L. An entry fires on a closed bar inside a window when the prior bar (shift 2) was stretched — a run of `stretch_bars` or more consecutive same-direction closes, or a close-vs-EMA distance beyond `stretch_atr_mult` x ATR — and the just-closed bar (shift 1) closes back through the `ema_period` EMA in the reversion direction: long above, short below. Stop = stretch extreme (highest high / lowest low of the last `stretch_bars` stretch bars, bars 2..stretch_bars+1) buffered by `stop_buffer_atr` x ATR at signal; trades whose stop distance exceeds `max_stop_atr` x ATR are skipped. TP is `target_r` times the stop distance. Exits: SL/TP, time stop after `time_stop_bars` M15 bars, mandatory flat at the window's flat minute (`london_flat_min_utc` 11:30 / `ny_flat_min_utc` 16:30), the lunch-gap flat (nothing held between windows) and the end-of-day backstop — whichever comes first. One entry per symbol per session window; at most `max_trades_per_day` entries per symbol per UTC day; at most `max_positions_total` family positions. No trailing / break-even management (card: none — the stretch extreme is the thesis invalidation point).

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol_slot0..2` | EURUSD/GBPUSD/USDJPY `.DWX` | slot inputs | Symbol slots 0-2; the chart symbol must equal `strategy_symbol_slot<qm_magic_slot_offset>` or OnInit fails. |
| `strategy_stretch_bars` | 3 | 2-4 | Consecutive same-direction closes defining the stretch (and the stop-anchor window). |
| `strategy_ema_period` | 14 | 10-20 | Short M15 EMA defining the reclaim. |
| `strategy_stretch_atr_mult` | 1.0 | 0.5-1.5 | Close-vs-EMA stretch distance (x ATR) as the alternative stretch definition. |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stretch, buffer, shock and stop cap. |
| `strategy_stop_buffer_atr` | 0.25 | 0.1-0.5 | ATR buffer beyond the stretch extreme for the stop. |
| `strategy_max_stop_atr` | 2.0 | 1.5-2.5 | Stop-distance cap (x ATR); wider candidates are skipped. |
| `strategy_target_r` | 1.25 | 1.0-1.5 | TP distance = R x stop distance. |
| `strategy_time_stop_bars` | 10 | 8-16 | Time stop in full M15 bars after entry. |
| `strategy_risk_per_trade_pct` | 0.25 | 0.20-0.50 | Live fixed-fractional risk per trade (RISK_PERCENT basis; backtest uses RISK_FIXED). |
| `strategy_daily_stop_pct` | -1.0 | fixed | Day breaker: no new entries once day P&L <= this. |
| `strategy_weekly_stop_pct` | -2.0 | fixed | Week breaker: no new entries once week P&L <= this. |
| `strategy_shock_atr_mult` | 2.0 | 1.5-2.5 | Skip the window when its first bar range exceeds mult x ATR. |
| `strategy_spread_median_mult` | 1.5 | 1.25-1.75 | Skip entries when spread exceeds mult x 20-day median spread. |
| `strategy_london_start_hour_utc` | 7 | 7-8 | London entry window start hour (UTC). |
| `strategy_london_end_hour_utc` | 11 | 10-12 | London entry window end hour (UTC, exclusive). |
| `strategy_ny_start_hour_utc` | 12 | 12-13 | NY entry window start hour (UTC). |
| `strategy_ny_end_hour_utc` | 16 | 15-16 | NY entry window end hour (UTC, exclusive). |
| `strategy_london_flat_min_utc` | 690 | 660-720 | Mandatory flat minute for the London window (11:30). |
| `strategy_ny_flat_min_utc` | 990 | 960-1020 | Mandatory flat minute / day backstop (16:30). |
| `strategy_friday_cutoff_min_utc` | 840 | 780-900 | No new Friday entries from this UTC minute (14:00). |
| `strategy_skip_first_minutes` | 15 | 0-30 | Skip entries in the first N minutes after a window opens (also the flat-proximity margin). |
| `strategy_max_positions_total` | 3 | 2-4 | Max open positions across this EA's symbol slots. |
| `strategy_max_trades_per_day` | 4 | 2-6 | Max entries per symbol per UTC day (density cap). |
| `strategy_news_blackout_minutes` | 30 | 0-120 | High-impact news blackout around entry (fail-closed). |
| `strategy_spread_min_days` | 5 | impl. knob | Daily medians required before the spread filter enforces. |

Session hours are UTC inputs; broker time is mapped via `QM_DSTAware` (`QM_BrokerToUTC` / `QM_UTCToBroker`) — no hand-rolled DST. Ranges are enforced as locked-configuration guards in `Strategy_NoTradeFilter`, plus window-coherence guards (London flat inside the lunch gap before NY opens; NY flat not before the NY window end).

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - slot 0, card-listed FX major with DWX data.
- `GBPUSD.DWX` - slot 1, card-listed FX major with DWX data.
- `USDJPY.DWX` - slot 2, card-listed FX major with DWX data.

**Explicitly NOT for:**
- Indices, metals, energy — the card names FX majors only.
- Live charts: the EA resolves its slot by exact `_Symbol` match against the slot inputs; deploy packaging must rewrite the inputs to the bare broker symbol names (`.DWX` stripping is a deploy-time step only).

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` (hard gate: any other chart timeframe blocks trading) |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)`; entry reads closed bars shift 1 (reclaim) and shift 2 (stretch) |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades | Max 1 entry per symbol per session window, capped by `max_trades_per_day`; ~18-28/month/symbol (card) |
| Overnight exposure | None — mandatory flat 16:30 UTC (NY backstop), 11:30 lunch flat, no weekend carry |
| Breakers | Day -1.0%, week -2.0% block new entries (cached, new-bar computed) |
| News | High-impact blackout 30 min around entry, fail-closed |
| Trailing | None (card) — stop placed once at stretch extreme + buffer, never widened |

## 6. Filters and Gates (execution order)

1. `QM_KillSwitchCheck` (framework, 3% catastrophic backstop stays intact).
2. Friday-close sweep (framework).
3. `Strategy_NoTradeFilter` — static config + timeframe + slot + window-coherence guards only; never blocks exits.
4. `Strategy_ManageOpenPosition` — card-mandated no-op (no trailing/BE).
5. `Strategy_ExitSignal` — lunch-gap flat, NY-flat day backstop, time stop (per tick, ungated).
6. Framework 2-axis news check (at OFF/DXZ defaults; entry gate only).
7. New M15 bar: `Strategy_EntrySignal` — session window, skip-first-minutes, one-per-window, day-trade cap, position-per-magic, flat proximity, Friday cutoff, breakers, per-window shock, spread-vs-median, card news blackout, family capacity, stretch + reclaim logic, stop-cap check.

## 7. Risk Notes

- No martingale, no averaging, no grid, no pyramiding; one entry per symbol per window; day-trade and family caps bound density; the stop is never widened.
- The framework kill-switch (3% daily) remains as a catastrophic backstop behind the card's strategy-level -1.0%/-2.0% breakers.
- `.DWX` zero modeled spread fails open in the spread filter (only genuinely wide spread blocks).
- PENDING_ALLOCATION: `QM_FrameworkMagic()` computes the magic by formula but `QM_MagicChecked` cannot confirm registry membership until the governed allocator writes the rows; do not run.

## 8. Build Evidence

- Compile: MetaEditor 64 (`D:\QM\mt5\T1\metaeditor64.exe /compile`) against the worktree include tree staged at `artifacts/builds/inc_staging` (worktree `framework/include` + terminal stdlib): **0 errors, 0 warnings** (`artifacts/builds/compile/QM5_41477_local_wt_includes.log`).
- `.ex5` sha256 `4e07143ac4e07ed644ba7865a7b1d8a7b262f16696386bb2f7e1248117c1219b` (not committed — EX5_COMMIT_GUARD requires a governed COMPILE_EA receipt).
- Full receipt: `docs/ops/evidence/2026-09-16_kimi_fxmr/RECEIPT.md`.
