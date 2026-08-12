# FX cointegration frontier paced-capacity stop

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: no unbuilt 66-pair relationship; existing Q02 fallbacks preserved;
stopped at the paced backtest CPU ceiling

## Outcome

No Card, EA, registry row, basket manifest, setfile, or Q02 row was created or
changed. The deterministic relationship audit committed at `a80493291` covers
all 66 relationships from the sign-aware scan. The only later repository
change at preflight HEAD `f39b73a34` adds the distinct FX carry-unwind sleeve;
it does not expose an unbuilt cointegration relationship.

The requested anchor repair is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has logical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has logical Q02 PASS, followed by
  Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

With no unbuilt relationship, the highest-ranked unfinished exact identity
remains rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in
the approved `QM5_1257_lemishko-fx-cointpair` basket. Its sole logical Q02
work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains PENDING, unclaimed,
and at attempt zero. The second unfinished identity, rank 65
`USDCHF.DWX` / `AUDUSD.DWX` in `QM5_1156`, likewise remains PENDING,
unclaimed, and at attempt zero. Neither row was duplicated or reprioritized.

The already-enqueued structural FX fallback `QM5_20292_fx-carry-unwind` is
also PENDING at Q02, unclaimed, and at attempt zero. Advancing any of these
rows requires backtest capacity.

## Binding paced CPU ceiling

At `2026-08-12T12:31:33Z`, the configured paced launch maximum was `1`, while
the path-aware farm scan found two factory MT5 jobs running:

- T3: `QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1`, Q03, work item
  `493a64ad-c9ed-46f4-9d05-1444ef50e645`;
- T6: `QM5_11177`, XAUUSD Q07, work item
  `c6cbc52f-9472-4c37-874e-a01ecaab262f`.

Two running factory jobs exceed the active paced ceiling of one. `T_Live` and
the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled. Per the mission stop rule, no enqueue,
requeue, dispatch, reservation, tester launch, terminal action, or backtest
followed the capacity sample.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T123133Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, live artifact, AutoTrading state, or terminal state
  changed.
- Existing unrelated dirty-worktree files were left untouched and are not
  part of this handoff.
