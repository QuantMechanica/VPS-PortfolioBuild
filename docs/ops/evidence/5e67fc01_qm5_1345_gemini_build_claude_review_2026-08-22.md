# Claude review: QM5_1345 Gemini build

- Review task: `5e67fc01-4a0d-43c5-ad23-68a6b6e0ce69`
- Gemini source task: `c7b9c56d-2270-4512-bfa3-bd5d8ff982af`
- Source artifact: `artifacts/builds/c7b9c56d-2270-4512-bfa3-bd5d8ff982af.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1345_chan-cot-spec-momo.md`
- MQ5 SHA-256: `99cf42d0a60d3857be1189c14429b9f71649b7f512851add410016de37b94dbf`
- EX5 SHA-256: `06a253b7f2cfd6af61100c3cd12383b3d10d1ae78c0aaef1ba1a35b8edb708c8`
- Verdict: **REJECT_REWORK — remain in REVIEW; Codex confirmation still required per Gemini-code policy**

The router assigned this `review_ea` task to Claude with reason
`codex_review_required_for_gemini_code`. Per CLAUDE.md, Codex review of
Gemini-authored code is mandatory before acceptance, so this task stays in
`REVIEW` regardless of this verdict — it does not move to APPROVED/PIPELINE.

## Findings

### 1. Block (severe): the implementation does not trade the card's signal at all

The approved card (`QM5_1345_chan-cot-spec-momo.md`, "COT Speculator
Momentum") is explicitly a **CFTC Commitments-of-Traders positioning**
strategy: `ratio = non_commercial_longs / max(non_commercial_shorts, 1)`,
sourced from public COT reports, "Weekly signal update only after
confirmed COT release availability. Skip weeks with missing or revised
COT values until deterministic ingestion is available." Its own R3
(Data Available) row is `UNKNOWN`: "Needs deterministic CFTC COT
ingestion and accepted mapping from futures positioning to DWX CFD
symbols" — i.e. the card itself records that COT ingestion was never
built.

The shipped `.mq5` (`Strategy_CalculateRatio()`, lines 60-86) computes a
completely different quantity: a **60-bar cumulative upside/downside
price-displacement ratio** derived purely from `iClose` — no COT data,
no weekly-release gating, no CFTC ingestion of any kind. It reuses the
card's numeric thresholds (long ≥3.0, short ≤0.333, exit at parity) and
the "COT" branding/comments, but the underlying signal has nothing to do
with positioning data. This is not a mechanization of the approved card;
it is a different, unapproved price-momentum strategy substituted for it
without an `open_questions` disclosure in the build result. §1 Mechanical
Match: FAIL.

### 2. Block: symbol universe has no card authorization

The card names only `XAUUSD.DWX` and/or `OIL.DWX` as draft DWX ports (R3
still UNKNOWN, never resolved to a PASS symbol list). The build instead
registered 13 symbols — `GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX,
WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX,
AUDUSD.DWX, USDCAD.DWX, NZDUSD.DWX` (`magic_numbers.csv` slots 0-12) —
none of which is card-authorized at this scale. §0 P2-saturation check:
FAIL (no PASS R3 row to saturate against; registering 13 unapproved
symbols compounds Finding 1 across a wide universe instead of one).

### 3. Block: per-tick full-window recompute, not gated by `QM_IsNewBar`

`Strategy_ExitSignal()` (line 179) is called unconditionally every tick
(OnTick line 253, before the `QM_IsNewBar()` gate at line 265) and calls
`Strategy_CalculateRatio()`, which runs a manual `for(int i=1;
i<=strategy_lookback_period; ++i)` loop (default 60) doing two `iClose`
calls per iteration — 120 bar reads recomputed from scratch on every
single tick whenever a position is open. This is exactly the forbidden
pattern in the framework-corset performance rule (manual warmup loop,
unconditional per-tick call, not gated by `QM_IsNewBar`). `g_last_bar_time`
is declared (line 54) but never used to gate anything — dead scaffolding
that suggests a per-bar cache was intended but not wired in.

### 4. No smoke-test evidence in the build result

Same gap as the sibling QM5_12955 build:
`artifacts/builds/c7b9c56d-2270-4512-bfa3-bd5d8ff982af.json` has none of
`smoke_result`, `smoke_report_path`, `blocked_reason`, `magic_base`, or
`symbols_registered` (schema: `tools/strategy_farm/prompts/SCHEMAS.md`).
No `deferred_p2_smoke` marker. Cannot confirm ≥1 trade in a smoke window
independent of Finding 1's mechanical mismatch.

## Independent verification

- HR14 (no ML): fixed thresholds, no adaptive/learned parameters, no
  NN/ONNX calls. PASS (the ratio itself is not learned, just wrong).
- HR4 (risk model): `RISK_FIXED`/`RISK_PERCENT` inputs present; all 13
  generated setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`. PASS.
- HR5 (magic): `qm_ea_id * 10000 + qm_magic_slot_offset` wired through
  `QM_FrameworkMagic()`; the 13 `magic_numbers.csv` rows for ea_id 1345
  are collision-free and `QM_MagicResolver.mqh` (regenerated 2026-08-22
  11:19, same session) carries exactly 13 matching rows. PASS
  (mechanically consistent, independent of Finding 2's authorization gap).
- All 13 registered symbols exist in `dwx_symbol_matrix.csv`. PASS
  (unlike the sibling QM5_12955 build).
- News-gate ordering: same pattern as QM5_12955 — news check precedes
  Manage/Exit, but every entry sets a non-zero ATR-derived server-side SL
  (`QM_StopATR`, `if (sl <= 0.0) return false;`), so this is an
  ONTICK-ORDER-ADVISORY, not a FAIL.
- Naming/dir conventions: `framework/EAs/QM5_1345_chan-cot-spec-momo/`
  correct `QM5_` prefix; `.mq5`/`.ex5` basenames match; setfiles exist in
  `sets/` for all 13 `symbols_registered`. PASS.
- `build_check_passed: true`, `compile_succeeded: true`, `compile_errors:
  0`, `compile_warnings: 0` per the build artifact. No independent
  recompile was run; this was a read-only review.

No `.mq5`, registry, resolver, work item, terminal, AutoTrading, or
pipeline state was changed by this review. Rework directive for the
producer: either build a deterministic CFTC COT ingestion path and
implement the card's actual ratio (R3 must move UNKNOWN → PASS first), or
send this card back for re-scoping as a price-momentum strategy under a
new source citation — do not ship a differently-sourced strategy under
the COT card's identity. Independently of that, cache
`Strategy_CalculateRatio()` behind `QM_IsNewBar()` before any resubmit.
