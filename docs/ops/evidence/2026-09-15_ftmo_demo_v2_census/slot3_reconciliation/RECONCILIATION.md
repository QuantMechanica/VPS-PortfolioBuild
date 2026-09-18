# FTMO demo book v2 census — slot-3 second opinion and reconciliation

Ticket `42a437a4-9674-47ce-9ca9-80eba8a2bc91` (book sprint F4, due Wed 2026-09-16 18:00Z).

**Status: NOT a replacement for the committed census. Reconciliation input only.**

**Superseded 2026-09-18** by the orchestrator-directed RECYCLE merge in `../README.md` /
`../roster_ftmo_demo_v2.json` (base = `../slot1_census_v2/`, not this directory — see the
review verdict quoted there). This directory is preserved for the record only.

## Why this directory exists

The headless launcher `run_agent_orchestration_task.py --agent claude --max-sessions 3`
spawned three Claude sessions at 2026-09-15T09:45:04Z (worktrees
`claude-orchestration-1` opus, `-2` sonnet, `-3` opus) with **one identical generic
prompt and no task binding**, against exactly three IN_PROGRESS claude tasks. All three
sessions were therefore instructed to work all three tasks. Slot 1 and slot 3 both
executed this census independently.

Slot 1 finished first and committed `9a06adf9bd`
(`24 ADMIT / 4 EXCLUDE`). Slot 3 (this directory) produced `26 ADMIT / 2 EXCLUDE`.
The committed slot-1 artifact and `tools/strategy_farm/ftmo_demo_v2_census.py` are
**unmodified** by slot 3; slot 3's output is scoped here instead.

This is the sixth recurrence of the duplicate-session race class. See
*Launcher defect* below.

## The delta: 2 sleeves

| sleeve | slot-1 committed | slot-3 | root of the difference |
|---|---|---|---|
| 11132 `QM5_11132_tm-cum-rsi2` @ SP500.DWX | EXCLUDE — "no verified FTMO symbol name" | **ADMIT** as `US500.cash` | slot 1 did not read the terminal's attach map |
| 12567 `QM5_12567_cum-rsi2-commodity` @ XNGUSD.DWX | EXCLUDE — "no verified FTMO symbol name" | **ADMIT** as `NATGAS.cash` | same |

The `12969` / `41470` row is **not** a disagreement: both censuses ADMIT the USDJPY
sleeve, they merely key the row differently (slot 1 keys by the replacement id `41470`,
slot 3 keys by the roster id `12969` and carries `effective_ea_id: 41470`).

## Evidence for the two additional ADMITs

Source: `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/ftmo_demo_attach_map.json`
(sha256 `fd89f17f9a1d60d324f8a2ed581c8733a32c29e0dca4d1e72a9a2a3678d31d3a`), a file
written by **this FTMO demo terminal** recording `(slot, symbol, timeframe, expert,
preset, magic)` for a previous attach of these same EAs.

Because `magic == ea_id*10000 + slot` is the same identity the DXZ v2 roster assigns,
a magic match binds a logical sleeve to the FTMO raw symbol that sleeve actually ran on:

| magic | attach-map symbol | DXZ v2 roster sleeve | binding |
|---|---|---|---|
| `111320000` | `US500.cash` | 11132 @ `SP500.DWX` (slot 0) | SP500.DWX → **US500.cash** |
| `125670002` | `NATGAS.cash` | 12567 @ `XNGUSD.DWX` (slot 2) | XNGUSD.DWX → **NATGAS.cash** |

This is stronger than the alias registry for these two names, because the alias table's
`FTMO_TRIAL` venue is bound to account **1513845506**, whereas the attach map is from
the target account **1514536732** itself.

The same mechanism corroborates bindings both censuses already agree on — `109110003`→
`GER40.cash` (GDAXI), `104400003`→`US100.cash` (NDX), `111650002`→`AUDCAD`,
`114210003`→`AUDUSD`, `114210000`→`EURUSD`.

**Recommendation:** admit 11132@SP500 and 12567@XNGUSD, giving **26 ADMIT / 2 EXCLUDE**.
Both remaining exclusions (12778, 13117) are genuine and both censuses agree on them.

## Findings in the slot-3 census not present in the committed one

Full detail in `census_report_slot3.md` (§ Evidence caveats / residual risk).

1. **Ticket premise correction — 12778 and 13117 are not `.DWX`-literal EAs.** Both use
   proper per-slot symbol *inputs* under the OWNER 2026-09-06 rule
   (`QM5_13117_eurgbp-audjpy.mq5:50-53`,
   `QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5:90-93`); the `.DWX` strings are
   input *defaults*. They go dark on FTMO only because the DXZ v2 presets set **no**
   symbol overrides at all (those `.set` files contain `RISK_*` and nothing else). The
   exclusion is a preset + symbol-name gap, not a code defect — they become admissible
   once EURGBP / EURJPY / EURAUD have verified FTMO names and the presets override every
   slot. This matters for how the work is scheduled: it is preset work, not an EA rebuild.
2. **EA 1537 is correct on FTMO only because its preset pins a logical name.**
   `QM1537_HostSymbol()` returns `_Symbol` when `strategy_calendar_symbol` is empty, and
   the sealed monthly-sleeve CSV is keyed by `XAGUSD.DWX` and compared with `==`
   (`QM5_1537_MonthlySleeveCalendar.mqh:289`, `:312`). With a bare `XAGUSD` chart and an
   empty input, **every calendar row is skipped and the bundle-SHA integrity guard never
   fires**. Live `chart08.chr` and the DXZ v2 preset both set
   `strategy_calendar_symbol=XAGUSD.DWX`, so it holds today — it must not be dropped in
   any regenerated preset.
3. **`US30.cash` (EA 9641) rests on the weakest binding in the book.** It appears in no
   tick dir, history dir, chart profile, attach map or native snapshot of the target
   account — only in the alias table, which is scoped to a different account. Both
   censuses ADMIT it. Confirm the name in Market Watch before deploying 9641.
4. **EA 1567 cannot honour FTMO news mode 2.** It exposes only legacy `qm_news_mode`
   (`QM_NEWS_PAUSE`) and has no `qm_news_compliance` input. Recorded, not excluding
   (demo burn-in), per the ticket.
5. **Symbol-handling class cannot be read out of the binaries.** The deployed `.ex5`
   files are compressed and expose no readable string constants, so classification comes
   from source at current `C:/QM/repo` HEAD and *assumes* each `.ex5` was built from the
   source now in the tree. Binaries are sha256-bound in the roster JSON so the assumption
   is auditable, but it is an assumption, not a decompilation.

## Launcher defect (root cause of the duplicate work)

`tools/strategy_farm/run_agent_orchestration_task.py` fans out N sessions that differ
**only** by worktree slot and model tier (`worktree_path(agent, slot)`, `--max-sessions`,
`claude_budget_check`). It passes no task id, no task filter and no work partition, while
the prompt each session receives instructs it to drain *every* IN_PROGRESS task for the
agent. The per-task rows in `spawn_leases` are written by the router with
`owner_pid = NULL`, so they authorise "the router path" collectively and cannot
distinguish one spawned session from another.

Consequence: with N sessions and M tasks the fleet performs up to N×M task executions
instead of M. Today N=3, M=3.

Slot 3 mitigated locally by taking an exec-scoped lease
`agent_task_exec:42a437a4-...` (`owner_pid=7576`) before starting, but a
self-chosen key only excludes sessions that independently choose the same key, so this
is a convention, not a fix.

**Proposed fix (not implemented — outside this ticket's scope):** have the launcher
claim `agent_task:<task_id>` per spawned session with a real `owner_token`/`owner_pid`
and pass the won task id into the session prompt, so each session is bound to exactly
one task and unclaimed tasks are simply not spawned for.

## Files here

- `roster_ftmo_demo_v2_slot3.json` — full slot-3 census, schema
  `qm.ftmo-demo-v2-admission-census/v1`, 28 rows, deterministic (byte-identical across
  two runs).
- `census_report_slot3.md` — the slot-3 README: ADMIT/EXCLUDE tables, symbol bindings,
  magic collision check, caveats, governor input delta proposal.
- `ftmo_demo_v2_census_slot3.py` — re-runnable generator for the two files above.

## Governor input delta (PROPOSAL — not applied)

Governor `QM5_13206`, policy `FTMO_2S_P1_100K_V2`, is untouched. Under the slot-3
26-ADMIT result:

- today: `allowed_magics_csv=107060001,114210000,114220004,119100006,130540000,15370001,200480000,215050000`
- proposed (ADMITted roster sleeves): `15370001,15560004,15670007,96410002,104030002,104400003,105130003,107000003,107060001,109110003,109190001,109390001,111320000,111650000,111650002,114210000,114210003,117080000,125670002,125670003,129890003,130130000,131280000,132130000,133010010,414700000`
- proposed `governed_symbols_csv=AUDCAD,AUDUSD,EURUSD,GBPUSD,GER40.cash,NATGAS.cash,US100.cash,US30.cash,US500.cash,USDJPY,USOIL.cash,XAGUSD,XAUUSD`
- `114220004,119100006,130540000,200480000,215050000` belong to the current 8-sleeve demo
  book and are **not** in the roster — union them in if those sleeves stay.

No magic is shared by two roster sleeves, no roster magic collides with the five retained
demo-book magics, and every ADMIT row satisfies `magic == ea_id*10000 + slot`.

## Constraints honoured

No terminal started, no chart attached, no write into the FTMO or T_Live data dirs, no
recompile, no governor policy change, no AutoTrading change. All writes are confined to
this directory. `main` and `C:/QM/worktrees/cto_main` untouched.
