# QM5_41441 WTI Winter NR2 Breakout - Build And Q02 CPU Stop

Date: 2026-09-11

Branch: `agents/board-advisor`

## Outcome

`QM5_41441_wti-winter-nr2-breakout` is a new low-frequency WTI sleeve. During November-May it
freezes the newest of two completed weeks as a breakout box only when that week's full range is
strictly narrower than its predecessor. It enters long or short on the first subsequent completed
D1 close strictly outside the box, uses a frozen `3.5*ATR(20,D1)` hard stop, and exits in the next
normalized week.

The edge is distinct from the certified `QM5_12567` XNG cumulative-RSI pullback. It also differs
from `QM5_41439` by carrier and calendar, from `QM5_41437` by the disjoint WTI August-October
hurricane window, and from `QM5_41440` by contraction, delayed breakout, and symmetric sides.
Realized decorrelation is not claimed; unchanged Q09 alone owns that verdict.

## Build Evidence

- Research approval commit: `b96bd3aaec`
- Magic allocation commit: `27a12bf18b`
- Source build commit: `c8b3881b5b`
- Set-hash repair commit: `4c048e43b0`
- Compiled-artifact binding commit: `2b93464080`
- EA identity / magic: `QM5_41441` / `414410000`
- Compile work item: `0098a350-46e7-4bef-b920-dbbf33aa264b`
- Compile verdict: `COMPILE_OK`; zero compiler errors and warnings; strict build check `PASS`
- MQ5 SHA-256: `2427271607d59930cdb3f96a04ca07a1edf5d1e3eeb1cbc2c08db696228986ac`
- EX5 SHA-256: `c90a3baf674d0a75014943da7db00bf931ce10f2f243feff05d2049bff313245`
- Q02 set SHA-256: `7cd14a281d9ad32d4ed6213af295499fda1665a36e8f266294fc04e6133e338b`

The binding PACER audit was run after source generation and before each compile submission. Every
run returned `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and hit count zero. The source locks
only strategy inputs, `qm_ea_id`, `qm_magic_slot_offset`, and fixed-risk backtest mode. RNG, news,
and Friday-close inputs are not compared; stress rejection receives finiteness and inclusive
`0..1` validation only.

Thirteen deterministic reference tests and card schema lint passed. The canonical set binds
`strategy_symbol=XTIUSD.DWX`, `RISK_FIXED=1000`, and `RISK_PERCENT=0`. The first governed compile
submission refused without enqueue because the cloned set carried a predecessor build hash; the
hash was cleared, committed, re-audited, and the next exact submission completed normally.

## Q02 Admission Stop

The governed `intake-first-q02` dry run returned `eligible=true`, `would_enqueue=true`, and selected
the one XTIUSD.DWX D1 fixed-risk set. The fresh five-sample whole-host CPU window was
`98.144725%`, `97.080872%`, `98.053099%`, `98.147511%`, and `98.553439%`: average `97.995929%`,
maximum `98.553439%`. Both measures violate the strict `<97.0%` admission rule.

The binding stop therefore fired before `intake-first-q02 --apply`. No Q02 row, dispatch, tester,
terminal reservation/control, manual backtest, or optimization was created.

## Safety

No portfolio gate, portfolio admission surface, `T_Live`, AutoTrading state, deploy/live manifest,
or live artifact was read or changed. Existing unrelated shared-worktree changes were preserved.

Machine-readable CPU receipt: `artifacts/qm5_41441_cpu_admission_20260911.json`.
