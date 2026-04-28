# QUA-392 CTO Review Handoff — 2026-04-28

Issue: `QUA-392`  
Strategy Card: `SRC04_S02b` (`lien-dbb-trend-join`)  
EA: `QM5_1008_lien_dbb_trend_join`

## Delivered Files

- `framework/EAs/QM5_1008_lien_dbb_trend_join/QM5_1008_lien_dbb_trend_join.mq5`
- `strategy-seeds/cards/lien-dbb-trend-join_card.md` (updated `ea_id: 1008`)
- `framework/registry/ea_id_registry.csv` (contains `1008,lien-dbb-trend-join,SRC04_S02b`)
- `framework/registry/magic_numbers.csv` (contains reserved magic `10080000`)

## Compile Evidence

- Compiler: `D:\QM\mt5\T1\MetaEditor64.exe`
- Log: `artifacts/qua-392/QM5_1008_compile.log`
- Result: `0 errors, 0 warnings`

## Card-vs-EA Trace Map (line references)

1. Framework + hard-rule inputs
- EA ID + framework group: `...mq5:11-12`
- Risk inputs (`RISK_PERCENT`, `RISK_FIXED`): `...mq5:15-16`
- News group: `...mq5:20`
- Friday Close default ON: `...mq5:23`

2. Entry rules (Card §4, PDF pp. 107-108)
- Core signal function: `...mq5:142`
- 2-bar opposite-side dwell check loop: `...mq5:157-173`
- Reclaim triggers (`close[1]` across inner band): `...mq5:175-186`
- Entry placement with fixed 65 pip stop + fixed 195 pip target: `...mq5:260-267`

3. Co-regime suppression (Card §6)
- Guard input: `...mq5:34`
- Outer-band-zone helper: `...mq5:84-99`
- Same-bar overlap suppression checks: `...mq5:177-184`

4. Trade management (Card §5)
- Management function: `...mq5:193`
- TP1 half-close @ +50 pips and BE move: `...mq5:213-240`

5. Exit module (Card §5 + §7)
- No discretionary exit signal (SL/TP/framework handles exits): `...mq5:243-247`

6. Framework lifecycle + no-trade gates
- Framework init call: `...mq5:280-289`
- Kill-switch/news/friday-close gating in `OnTick`: `...mq5:304-309`

## Registry / Magic Evidence

- `framework/registry/ea_id_registry.csv:9` → `1008,lien-dbb-trend-join,SRC04_S02b,active,CTO,2026-04-28`
- `framework/registry/magic_numbers.csv:5` → `1008,lien-dbb-trend-join,0,EURUSD.DWX,10080000,2026-04-28,CTO,active`

## CTO Action Requested

Run EA-vs-Card review gate for `SRC04_S02b` and either:
1. Approve for Pipeline-Operator continuation under parent `QUA-390`, or
2. Return exact required deltas for Development.
