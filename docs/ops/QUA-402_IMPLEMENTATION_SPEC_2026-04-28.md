# QUA-402 Implementation Spec Draft (Awaiting EA ID Allocation)

Issue: `QUA-402`  
Card: `QUA-342` (`SRC04_S03`, `lien-fade-double-zeros`)  
Date: 2026-04-28

## Purpose
Pre-map card rules to V5 EA function boundaries while blocked on `ea_id` allocation. This is a no-code prep artifact to minimize latency after CTO allocation.

## Target File (post-unblock)
- `framework/EAs/QM5_<ea_id>_lien_fade_double_zeros/QM5_<ea_id>_lien_fade_double_zeros.mq5`

## Required Includes
- `#include <QM/QM_Common.mqh>` (framework mandatory)
- `#include <Trade/Trade.mqh>`
- Add `QM_StopRules` include only if needed for stop helper interoperability.

## Required Input Groups
1. `QuantMechanica V5 Framework`
2. `Risk`
3. `News`
4. `Friday Close`
5. `Strategy`

## Strategy Inputs (Card-mapped defaults)
- `strategy_trend_ma_period = 20` (Card §4)
- `strategy_entry_offset_pips = 12` (Card §4, 10-15 midpoint)
- `strategy_stop_offset_pips = 20` (Card §4)
- `strategy_proximity_pips = 50` (Card §4 staging bound, implementation default)
- `strategy_partial_close_fraction = 0.5` (Card §5)
- `strategy_enable_triple_zero_priority = false` (Card §6 optional optimization)
- `strategy_trail_mode = two_bar_extreme` (Card §5 default behavior)

## Function Boundary Mapping

### `Strategy_EntrySignal`
- Determine 20-SMA regime on M15-equivalent runtime timeframe (Card §4).
- Compute nearest round-number anchor by symbol precision:
  - non-JPY majors -> `x.xx00` grid
  - JPY pairs -> `xx.00` grid
  (Card §4 definition)
- Long setup when close < SMA and anchor above price within proximity (Card §4 long).
- Short setup when close > SMA and anchor below price within proximity (Card §4 short).
- Stage stop-entry anchored to round number:
  - long entry = `round + entry_offset`
  - short entry = `round - entry_offset`
- Use `QM_Magic(ea_id, slot)` path via framework only.

### `Strategy_ManageOpenPosition`
- Calculate initial risk in pips from round-anchor geometry (Card §4/§5).
- At +1R, close half and move SL to breakeven (Card §5).
- Trail remainder with two-bar extreme default:
  - long -> two-bar low
  - short -> two-bar high
  (Card §5; MA+10 trail remains optional axis, not default)

### `Strategy_ExitSignal`
- Respect hard stop and framework-level risk exits.
- Optional explicit exit signal returns none unless additional deterministic close rule needed.
- Friday close must remain enabled by default via framework group.

## No-Trade / Guardrails
- News gating via framework input (`qm_news_mode`).
- Friday close enabled default true.
- Single-position discipline for this EA magic+symbol.
- No hardcoded symbols; all logic keyed off `_Symbol`.

## Comment/Citation Plan for Code
Inline comments must cite card references at each non-obvious rule boundary:
- Round-number anchor construction -> Card §4
- Entry offsets/stops relative to figure -> Card §4
- 1R half-close + BE move -> Card §5
- Two-bar trailing default -> Card §5
- Optional triple-zero/confluence flags left off by default -> Card §6

## Compile/Handoff Checklist (post-unblock)
1. Build target EA only; zero warnings.
2. Run V5 build_check scope for target EA; no violations.
3. Produce CTO handoff note with EA-vs-card mapping and line references.
4. Do not dispatch Pipeline-Operator.
