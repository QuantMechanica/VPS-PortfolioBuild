# QM5_41475_cash-window-index-continuation-h1 - Strategy Spec

**EA ID:** QM5_41475
**Slug:** `cash-window-index-continuation-h1`
**Source:** `QM-RESEARCH-2026-0002` (internal research; preregistration `cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e`)
**Author of this spec:** Kimi (interim strategy-engineering delegation)
**Last revised:** 2026-09-15
**STATUS: REVIEW_PENDING** — independent non-Kimi critique pending (claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).
**REGISTRY STATUS: PENDING_ALLOCATION** — the governed magic allocator accepted this card (`action: allocate`, 3 rows, dry-run evidence) but its apply step fail-closed on an environmental guard: active magic rows for QM5_11924 / QM5_11941 reference EA directories that exist only as uncommitted content in the canonical worktree, so resolver regeneration from any clean worktree of `da1b4b4e0c` would drop them. No `ea_id_registry.csv` / `magic_numbers.csv` rows exist for 41475 and `QM_MagicResolver.mqh` has no 41475 tuples. **Do not pipeline, backtest, or deploy until the allocation is completed** (see `docs/ops/evidence/2026-09-15_kimi_hcw/magic_allocation_report.json`). Planned magic values: slot 0 NDX.DWX = 414750000, slot 1 GDAXI.DWX = 414750001, slot 2 SP500.DWX = 414750002.

---

## 1. Strategy Logic

Session-flat cash-window index continuation on H1, fully mechanical per the mechanized H_CW card. The session is anchored in UTC hours (inputs). On each closed H1 bar the EA maintains the day's state: the breakout reference (max high / min low of the first `strategy_breakout_window_bars` session bars), the first-bar shock verdict, per-day spread samples and a rolling 20-day median of daily medians, and the daily/weekly circuit-breaker P&L. An entry fires on a closed bar strictly after the breakout window when its close breaks the reference (plus optional ATR buffer) and is on the correct side of the EMA: long above, short below. Stop is 1.0xATR from the market fill; TP is `target_r` times the stop distance. Exits: SL/TP, time stop after `time_stop_bars` H1 bars, or mandatory flat at `flatten_hour_utc` — whichever comes first. One entry per symbol per day; at most `max_positions_total` open positions across the EA family.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol_slot0..2` | NDX/GDAXI/SP500 `.DWX` | slot inputs | Symbol slots 0-2; the chart symbol must equal `strategy_symbol_slot<qm_magic_slot_offset>` or OnInit fails. |
| `strategy_breakout_window_bars` | 3 | 2-4 | First N session H1 bars defining the breakout reference. |
| `strategy_ema_period` | 20 | 15-30 | H1 EMA confirming breakout direction. |
| `strategy_breakout_buffer_atr` | 0.025 | 0.0-0.05 | Extra ATR buffer beyond the reference required for entry. |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop, shock filter and break-even. |
| `strategy_atr_stop_mult` | 1.0 | 1.0 (fixed) | Stop distance = mult x ATR at signal. |
| `strategy_target_r` | 1.75 | 1.5-2.0 | TP distance = R x stop distance. |
| `strategy_time_stop_bars` | 6 | 4-8 | Time stop in full H1 bars after entry. |
| `strategy_risk_per_trade_pct` | 0.25 | 0.20-0.50 | Live fixed-fractional risk per trade (RISK_PERCENT basis; backtest uses RISK_FIXED). |
| `strategy_daily_stop_pct` | -1.0 | fixed | Day breaker: no new entries once day P&L <= this. |
| `strategy_weekly_stop_pct` | -2.0 | fixed | Week breaker: no new entries once week P&L <= this. |
| `strategy_shock_atr_mult` | 2.0 | 1.5-2.5 | Skip the day when the first session bar range exceeds mult x ATR. |
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
| Trades | At most 1 entry per symbol per day; ~18-22/month/symbol (card) |
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
7. New H1 bar: `Strategy_EntrySignal` — day state, breakout window, one-per-day, position-per-magic, entry window hours, Friday cutoff, breakers, shock, spread-vs-median, card news blackout, family capacity.

## 7. Risk Notes

- No martingale, no averaging, no grid; one entry per symbol per day; break-even only tightens.
- The framework kill-switch (3% daily) remains as a catastrophic backstop behind the card's strategy-level -1.0%/-2.0% breakers.
- `.DWX` zero modeled spread fails open in the spread filter (only genuinely wide spread blocks).
- PENDING_ALLOCATION: `QM_FrameworkMagic()` cannot resolve until magic rows exist; do not run.

## 8. Build Evidence

- Compile: MetaEditor 64 (`D:\QM\mt5\T1\metaeditor64.exe /compile`) against the worktree include tree staged at `artifacts/builds/inc_staging` (worktree `framework/include` + terminal stdlib): **0 errors, 0 warnings** (`artifacts/builds/compile/QM5_41475_local_wt_includes.log`).
- Symbol-literal lint: clean.
- Registry/magic tests: 21 passed (allocator + precheck + resolver strict-default).
- Full receipt: `docs/ops/evidence/2026-09-15_kimi_hcw/RECEIPT.md`.
