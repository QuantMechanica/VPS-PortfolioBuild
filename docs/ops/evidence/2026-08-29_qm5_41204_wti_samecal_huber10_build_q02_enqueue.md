# QM5_41204 WTI same-calendar Huber build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED`

## Delivered edge

`QM5_41204_wti-samecal-huber10` is a new low-frequency direct-WTI sleeve.
At the first normalized D1 broker-month transition it requires the completed
XTI log return for the same calendar month in exact years `Y-1..Y-10`.
It forms the even median and raw even MAD, freezes
`scale=1.4826*MAD` and `delta=1.5*scale`, runs exactly 32 Huber
reweighted-location updates, and follows the final sign beyond the inclusive
`1e-12` flat band until the next month.

The approved fixed disagreement vector makes the Huber rule SELL at
`-0.00031225666666666747`, while the raw mean is positive and the centered
signed-rank score is `+3`; both neighbors BUY. Canonical preallocation dedup
found no exact identity and only the expected raw-mean fuzzy neighbor. The
candidate also differs from the existing XNG cumulative-RSI pullback and adds
direct crude-oil exposure absent from the stated XAU/SP500/NDX/XNG book.
Realized decorrelation is not claimed; Q09 remains authoritative.

## Governance and implementation

- Source packet:
  `strategy-seeds/sources/KELOHARJU-HUBER-WTI-SAMECAL10-2026/source.md`
  (`3eb1889c...`), backed by Keloharju et al. (same-calendar crude-oil
  evidence), Moskowitz et al. (WTI own-return/monthly lineage), and Huber
  (bounded-influence location).
- Durable source approval commit: `480eace0a`.
- Approved G0 card and deterministic ID commit: `68ac7c013`.
- EA/magic/source package commit: `d30a3b6a6`.
- Precompile unbound-preset correction: `a5b72673c`.
- Active identity: `QM5_41204`, `XTIUSD.DWX`, D1, slot 0, magic
  `412040000`.
- Sole baseline risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The reference suite passed 10/10 deterministic fixtures. Card-schema, G0,
execution-contract, spec, symbol-scope, array-bounds, MAE-hook, and static
build gates passed with no candidate-specific findings.

## Governed compile

Build task `1f26f61b-40af-43d2-854b-1772c9af4f27` bound the source to
compile item `50540d6c-81b9-42ac-9879-012d8573c133`. A target-only dry run
and apply released only its rollout hold after matching the expected and
actual MQ5 SHA-256:
`42a2c048f584901fa26770657a1229b6ec446dfe4c7eca7ca90c4a05e833bb4b`.

The resident T3 worker claimed the item in compile-only mode and returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `5f98d908c660794cd2d84bc9d1ef8f6c8051d94c17e1455750febf38a311c7e8`;
- evidence:
  `D:/QM/reports/work_items/50540d6c-81b9-42ac-9879-012d8573c133/QM5_41204/COMPILE_EA/compile_evidence.json`.

No ad-hoc compile, tester launch, terminal control, or retry bypass was used.

## Q02 enqueue and capacity

A five-sample pre-enqueue CPU window averaged `62.08%` and peaked at
`79.31%`, below the hard `97%` ceiling. A post-enqueue confirmation
averaged `46.72%` and peaked at `54.77%`; the ceiling never bound.

Recording the successful build atomically appended exactly one priority-track
Q02 item:

- work item: `24f492cd-89e3-4040-b207-d14d3fd4bf46`;
- symbol/timeframe: `XTIUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41204_wti-samecal-huber10/sets/QM5_41204_wti-samecal-huber10_XTIUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed;
- custom-history admission: ACTIVE, 108 selected XTI archive rows.

The item was enqueued only. It was not manually dispatched or backtested by
this mission.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress preset, T_Live/deploy manifest,
portfolio gate, portfolio admission, or correlation waiver was touched.
Neither certification nor diversification is claimed before downstream
evidence.

Machine-readable receipt:
`artifacts/qm5_41204_build_q02_enqueue_20260829.json`.
