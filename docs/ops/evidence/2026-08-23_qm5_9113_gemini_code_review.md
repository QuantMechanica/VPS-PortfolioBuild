# QM5_9113 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `2b3b4331-a51c-4677-934f-92626144b18f`

Source task: `9c481197-288f-4c07-9714-637ecc8bd624` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9113_aa-ab-velocity/build_identity.json`

Verdict: **REQUEST_CHANGES — the recursive D1 filter and risk-exit ordering do not implement the approved contract; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. Critical — news and spread entry gates suppress Friday and strategy exits

`OnTick()` returns on the mandatory news decision before Friday-close handling,
position management, and the opposite-zero-cross exit (source lines 270-282).
It then returns on `Strategy_NoTradeFilter()` before the same exit (lines
277-282); that filter contains timeframe, history, and spread entry
eligibility. During a news blackout, wide/invalid spread, missing history, or a
wrong chart timeframe, the EA can leave an open position unmanaged even though
the card requires the completed-D1 opposite-zero-cross close.

Required correction: keep Friday close, management, and strategy exits
reachable independently of every new-entry filter. Apply news and spread gates
only immediately before constructing a new entry request.

### 2. High — the mandatory 20-day median-spread rule fails open

The card requires a 20-day completed-D1 median and says to skip entries above
`2.5 x` that value (card line 57). `Strategy_MedianSpreadD1()` accepts any
positive partial `CopyRates` result instead of exactly 20 observations (source
lines 69-87). `Strategy_SpreadAllowsEntry()` then permits entry when `ask <=
bid`, when rounded current spread is non-positive, or when the median is zero or
unavailable (lines 90-112). Invalid or incomplete evidence is therefore
converted into permission to trade.

Required correction: require exactly 20 valid completed-D1 spread observations,
positive bid/ask ordering, positive current spread and a positive median before
entry admission can pass.

### 3. High — a moving-window reset replaces the approved recursive state

The card initializes the alpha-beta state from the first available close
sequence and updates that state once per completed D1 close (card lines 35-37).
`Strategy_CalculateABVelocity()` instead reads only the most recent
`warmup + 10` bars, seeds position/velocity from the oldest bar in that moving
window, and rebuilds the state from scratch on every call (source lines
115-156). When the window advances, its initial condition also changes. That is
not the same deterministic recursive state authorized by the card and can move
zero-cross timing.

Required correction: maintain/reconstruct one canonical recursive state from a
sealed initial history and advance it exactly once for each newly completed D1
bar, with restart reconstruction and reference vectors.

### 4. High — the full history walk runs on every market tick

The card says to re-evaluate only after a completed D1 bar (card line 44), but
`Strategy_ExitSignal()` calls the `CopyRates` plus 130-bar default state walk
before the `QM_IsNewBar()` gate on every tick (source lines 222-238 and
282-294). This is both the wrong decision cadence and a material tester-timeout
risk. Exit retries may remain per-tick, but the immutable completed-D1 signal
snapshot must not be recomputed per tick.

Required correction: calculate and cache the complete filter snapshot on one
explicit D1 boundary, then let per-tick risk handling read only that snapshot.

### 5. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success after `QM_FrameworkInit()` without calling
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines 250-257).
The later `_Period != PERIOD_D1` check is only an entry filter and, because of
finding 1, also suppresses exits. It is not the current framework's fail-closed
initialization contract.

Required correction: declare the approved D1 timeframe and intended
Friday-close mode immediately after framework initialization.

### 6. Medium — the durable SPEC is control-byte corrupted

`SPEC.md` contains seven non-whitespace control bytes: `0x07` at byte offsets
75, 428, and 3166; `0x1B` at 102 and 2949; `0x08` at 448; and `0x0C` at 1915.
They corrupt the slug, source ID, equations, paths, and fixed-risk text. The
current `validate_spec_doc.py` still reports `PASS`, demonstrating that its
structural check does not authenticate clean text.

Required correction: regenerate the SPEC from literal text, verify zero control
bytes, and add a focused validator regression.

## Checks that passed

- The canonical approved card exists with `g0_status: APPROVED`.
- EA registry row `9113 / aa-ab-velocity` is active.
- Thirteen active magic rows exist at slots 0-12 with no global magic
  collisions, and all 13 exact rows are present in `QM_MagicResolver.mqh`.
- All 13 delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- All 13 backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings for the EA.
- The MQ5 SHA-256 matches `build_identity.json`:
  `bda4cd05d61af5e028da784541e61e2025dc45c88698862268169c309f83fb63`.
- The EX5 SHA-256 matches `build_identity.json`:
  `e027ee251d422683cb8167d7047fc8902bcbe9d1f06194020acff9d46c1b1b8d`.
- The focused forbidden scan found no raw indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, ML, martingale, grid, or HFT mechanism.

The resolver dry-run itself refused globally because unrelated active rows
`1001`, `1015`, and `1016` have no materialized EA directories. No resolver or
registry mutation was attempted; the target rows were verified directly in the
current generated arrays.

These passes establish artifact identity and baseline hardening only. No smoke
report or pipeline evidence was supplied, so no runtime or pipeline verdict is
inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a
fresh mandatory Codex review before acceptance or enqueue.
