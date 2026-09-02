# QM5_41280 card-faithful build and governed compile-pending checkpoint

- Recorded: `2026-09-02T05:56Z`
- Router task: `317b4d6a-3338-4603-8006-a4660ad6d5f1`
- Branch: `agents/board-advisor`
- EA: `QM5_41280_usdchf-ww-shift-tr`
- Strategy: `AI-CODEX-USDCHF-WW-SHIFT-20260902_S01`
- Checkpoint: `Q01_SOURCE_BUILT_COMPILE_RELEASED_PENDING_PRIORITY_CAPACITY`

## Outcome

Development implemented the OWNER-approved USDCHF weekly fixed-six-by-six
Mann-Whitney location-shift continuation card as a new V5 EA, authored its
locked D1 backtest set and pure reference fixtures, and released one exact
source-hash-bound compile work item through the reviewed resident-worker
rollout. The source and static verification are complete, but the resident
worker has not yet claimed the compile row. Consequently no EX5 exists and
this checkpoint does **not** assert Q01/build PASS or any pipeline verdict.

The compile remains pending, unheld, and bound to MQ5 SHA-256
`df9ca3e09733a4f9195f8fe57e8f0b83955987a8b99f04842d8b9f42fd6d8e00`.
No source edit was made after release.

## Approval and identity gates

- Approved card:
  `strategy-seeds/cards/approved/QM5_41280_usdchf-ww-shift-tr_card.md`
- Card and runtime copy SHA-256:
  `0973cffba70bf2b6abc25d425a103c868156e690420c1945aa29157d3a46555f`
- Card status and execution-contract status: `APPROVED`.
- G0 status: `APPROVED` under
  `decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md`.
- Durable source approval:
  `decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md`.
- Governed source packet:
  `strategy-seeds/sources/AI-CODEX-USDCHF-WW-SHIFT-20260902/source.md`.
- Registry: exact active `ea_id=41280`, slug `usdchf-ww-shift-tr`.
- Magic registry: exact active slot-0 row for `USDCHF.DWX`, magic
  `412800000`; resolver cardinality is one.
- Card lint: no missing fields and `ml_required=false`.

This card belongs to the approved general priority-3 diversity/funnel lane.
Its governing card and SPEC explicitly do not claim Edge Lab classification,
FTMO compliance, portfolio admission, deployment readiness, or live authority.

## Implemented contract

The MQ5 implementation mechanically binds:

- exact `USDCHF.DWX` host and D1 execution;
- one consumed framework-week attempt, persisted before every fallible entry
  gate, with a six-hour genuine-transition grace window;
- exactly completed D1 shifts 12 through 1 in chronological order;
- fixed older/newer blocks of six, pairwise no-tie rejection, all 36 strict
  cross-block comparisons, complementary U and rank-sum invariants;
- inclusive long/short boundaries `U_new >= 24` and `U_new <= 12`;
- one fixed-risk position with completed-bar ATR(20) times 3.0 normalized hard
  stop, no target, 50-point spread ceiling, and no signal-strength sizing;
- framework Friday close at broker hour 21 plus seven-calendar-day stale and
  malformed-position repair;
- Q08 MAE tracking before per-tick early-return gates;
- framework-only bar, indicator, sizing, margin, execution, close, news,
  calendar, and lifecycle helpers; no ML, external feed, grid, martingale,
  manual lot sizing, raw `CopyRates`, or raw indicator handle path.

The canonical backtest set fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, all news modes OFF per the approved general-lane card,
`qm_news_stale_max_hours=336`, and every strategy parameter to the approved
baseline. Its precompile `build_hash` remains `pending`; only successful
governed compile evidence may bind the final binary hash.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `df9ca3e09733a4f9195f8fe57e8f0b83955987a8b99f04842d8b9f42fd6d8e00` |
| SPEC | `47f1c2ebc3879cc68705806bee5d4756de274299949a92cc8a5c382ae4c7fade` |
| Reference fixtures | `389fcee9a969eab6d8188c7d3e11a99ee242f028bb813b1062eb7218b2a27259` |
| USDCHF.DWX D1 backtest set | `04829cc9e9e40109a621e3fd57e5f008d97bd2e0be784d32076abaf157d7483f` |
| Compile release dry run | `aa50284a46827403e4000522fa2e04c36c6c4d5d855358d80f47f6c9fef54b96` |
| Compile release apply receipt | `09d42fdc309fcab3f04208ca5bc90086749a09dcfd5c19ce3340f996736e780d` |

## Focused verification

- Pure reference fixtures: `7 passed`.
- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336`.
- Pre-enqueue `build_check.ps1 -SkipCompile`: zero failures; three
  non-fatal card-discovery warnings only.
- Scoped `git diff --check`: `PASS`.
- Approved card/runtime-copy hash identity: exact match.
- Registry/magic/resolver identity: exact cardinality and values.

The strict ad-hoc compile path was attempted once as the skill preflight and
correctly refused with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because the
resident factory had active terminal64 processes. No bypass or manual terminal
launch was attempted.

## Governed compile state

The canonical enqueue created exactly one work item:

```text
work_item_id = 7952c185-f0d0-4d38-8d66-e08b1f49f477
ea_id        = QM5_41280
phase        = COMPILE_EA
status       = pending
mq5_sha256   = df9ca3e09733a4f9195f8fe57e8f0b83955987a8b99f04842d8b9f42fd6d8e00
risk         = RISK_FIXED 1000 / RISK_PERCENT 0
```

The source-hash-pinned release dry run matched exactly one row. The apply step
released exactly that row at `2026-09-02T05:39:41+00:00`, after writing the
mandatory database backup:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260902T052506Z_0c2578e7.sqlite
sha256=83da78feb244779f1299c3640345b99559a6cda05f8a4088057093b37019d3a3
```

The release receipt records expected and actual MQ5 hashes as identical and
`applied=1`. Subsequent `compile-status` checks report `pending=1`,
`activation_held=0`, `active=0`, `compiled=0`, and `failed=0`.

At `2026-09-02T05:54Z`, the canonical read-only worker selector placed a
separately authorized source-repair compile first, followed by a large set of
OWNER-priority measurement rows; QM5_41280 was not in the first 150 eligible
rows. All T1-T10 workers were active or atomically claimed. This is a governed
priority/capacity defer, not compile evidence and not authorization to change
queue priority.

## Review-dispatch gate and router disposition

After committing the source checkpoint, an exact requested transition to
`REVIEW` with this evidence was deterministically refused by the canonical
router:

```text
gate_code=D6_BUILD_IDENTITY_MISSING
reason=build_identity_json_missing_review_dispatch_refused
updated=false
```

That refusal is correct. Build tasks may enter REVIEW only with a committed
JSON packet proving strict-build PASS and binding the exact MQ5, EX5, and
final-hash setfile bytes. This compile has not run, there is no EX5, and the
setfile intentionally remains at its precompile `build_hash: pending` state.
No build-identity JSON was fabricated.

The truthful task disposition is therefore `BLOCKED` on the already released
resident-worker compile work item. This is not a request for a queue-priority
override, another compile row, an ad-hoc compile, or a pipeline action.

## Continuation boundary

The resident worker may compile only the released, source-hash-matching row.
A continuation must inspect its durable compile evidence, require zero compile
errors and an EX5 bound to this exact source, rerun strict build checks against
the final set binding, and submit the completed generation for independent
review. Until then:

- no EX5 or Q01/build PASS may be claimed;
- no Q02 or later Q-only phase may be enqueued;
- no pipeline, portfolio, deploy, T6, `T_Live`, or AutoTrading action is
  authorized;
- the MQ5 must not be edited underneath the released hash-bound work item.

## Verdict

`Q01_SOURCE_BUILT_COMPILE_RELEASED_PENDING_PRIORITY_CAPACITY`: approved-card
source, SPEC, locked set, fixtures, static checks, and exact controlled compile
release are complete; the resident worker has not claimed the unheld row, so
there is no EX5 and no build or pipeline PASS. Canonical D6 correctly refused
REVIEW; the task is blocked pending that governed compile evidence.
