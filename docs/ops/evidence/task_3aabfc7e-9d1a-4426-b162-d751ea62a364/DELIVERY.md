# HYP-2 oil-vol sizing: corrected causal implementation (engineering delivery)

Task `3aabfc7e-9d1a-4426-b162-d751ea62a364`. Claude is the code creator here, not
its independent approver -- this delivery explicitly requests the separate
creator-independent code/protocol review the task payload requires before any
new outcome calculation. Worktree `C:\QM\worktrees\claude-orchestration-2`
(branch `agents/claude-orchestration-2`). No empirical HYP-2 price/outcome
payload was opened; no book metric, allocation or admission changed; D2g6
stays frozen; no 2025+ data was read.

## What this delivers

The "single corrected feature/state design" that
`docs/ops/evidence/2026-09-26_astra_takeover/hyp2_mechanization/REVIEW.md`
asked for, plus its named synthetic tests, implemented per REVIEW.md's exact
corrections (REVIEW.md governs over `AUTHOR_DELIVERY.md`/its JSON wherever
they disagree):

* `tools/strategy_farm/research/hyp2_oilvol_sizing.py` -- RV20 (RMS of 20
  completed log returns, not a demeaned standard deviation), the exclusive
  prior MEDIAN60, strict HIGH/LOW thresholds (1.5x / 1.0x) with equality
  neutral, the 81-close warmup (first eligible index 80), and the "HYS-C"
  daily state machine: a HIGH signal always resets `age=0` (including a
  retrigger while already active); otherwise, while active, `age` advances
  (capped at 5) and only a LOW signal at `age==5` releases the floor; a
  neutral (NORMAL) signal can hold the floor past five intervals without
  releasing it. UNAVAILABLE/CLOSED days retain the latent `(active, age)`
  pair and its implied multiplier unchanged -- REVIEW.md Section 3 explicitly
  rejects the author's "no modifier applied (default 1.0x)" framing for a
  latent-active floor; this mirrors `hyp1_causal_tags.evaluate`'s own
  already-reviewed carry-through of its countdown counter across gaps.
* `tools/strategy_farm/research/tests/test_hyp2_oilvol_sizing.py` -- 24
  synthetic tests, all against fabricated price paths (no real archive or
  outcome payload opened anywhere in the file), covering every case
  REVIEW.md's closing paragraph names: 81-close warmup, equality (both
  boundaries) and zero-median cases, RMS-vs-stdev and median-30/31
  verification, HIGH precedence/retrigger, five-valid-interval release on LOW
  vs. hold on NORMAL, neutral hysteresis beyond five intervals, multiple
  same-day entries, missing-state retention (including that the latent floor
  survives a gap that would otherwise have released it), a known market
  CLOSED day not consuming a stand-down interval, DST (both seasons) and
  strict-cutoff/exact-boundary entries, future-data perturbation (no
  lookahead), and winner-retention/unresolved-cohort census via the reused
  generic trade-stream projector.
* `tools/strategy_farm/research/hyp2_identity_verify.py` -- a read-only
  script that re-derives the identity claims in
  `hyp2_mechanization/input_availability.json`: the sealed 11422 stream's Git
  blob SHA256 (via the reused `hyp1_inputs.read_git_blob`) and the 14
  declared XTIUSD/USDCAD HCC archive existence+sizes. It never decodes HCC
  OHLC bytes and never parses a JSONL record; see
  `identity_verify_receipt.json` in this directory for the executed receipt
  (`all_match: true`, `price_payload_read: false`, `new_outcomes_computed:
  false`).

## Reuse, not duplication (no second engine)

Per the task's "reuse existing HCC/time/stream readers without duplicate
engines or conflicting edits," the following files are vendored **byte-for-
byte** from the already statically-reviewed HYP-1 engineering task
(`d4f0b5c5-b65b-426b-aa49-739014353375`, commit `2f5cf27263a6cfb38bc263016345492ed62c74df`
on branch `agents/astra-hyp1-tagging-20260927`) and are **not modified** here;
`hyp2_oilvol_sizing.py` imports `DailyClose`/`server_to_utc`/`bar_available_at`
from `hyp1_causal_tags` (same NY+7 clock, same window constants) rather than
re-deriving a second one, and the test file reuses
`hyp1_trade_projection.project_stream` directly rather than writing a second
JSONL metadata scanner. HYP-2's own `classify`/`transition`/`evaluate`/
`tag_entry` are new because HYP-2's hysteresis design is explicitly a
different, non-duplicate state machine from HYP-1's countdown
(`hyp1_causal_tags.transition`) -- that divergence is deliberate and
sanctioned by REVIEW.md's closing paragraph.

| Path | SHA256 | Provenance |
|---|---|---|
| `tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` | `eec4d6d15cec19b5d6ef5838023f931d07ffa2e6b118379844d67fdd4eed6fe4` | Vendored verbatim, HYP-1-review-bound version |
| `tools/strategy_farm/research/hyp1_causal_tags.py` | `e7c7d146b97bcc74148ee5c829509c0bb8fab71b73ea95a5fc132f0acbcb1c9f` | Vendored verbatim |
| `tools/strategy_farm/research/hyp1_inputs.py` | `eb609b08967e2dd6f922caeaab374bee827551bf400b4427ac3de35f0c37b949` | Vendored verbatim |
| `tools/strategy_farm/research/hyp1_trade_projection.py` | `e3f87ab341fbbb7348659d1870754767be55eb112cb37cbe40053dbe611e76e9` | Vendored verbatim |
| `tools/strategy_farm/research/tests/test_hyp1_causal_tags.py` | `b04498ae82979e18653aaa2a2774cc8102d09399c5268af9aa974d48ec1d0ec2` | Vendored verbatim, re-run here as a regression check |
| `tools/strategy_farm/research/__init__.py` | `7c0f6137c25e9f093791c11c8505deb93b592653200fa58857831de71b55517c` | Vendored verbatim |
| `tools/strategy_farm/research/hyp2_oilvol_sizing.py` | `7cffef1058c1c408e26621e72967cc772f34e7964a83cf94d05045945ed3f9ac` | **New (this delivery)** |
| `tools/strategy_farm/research/hyp2_identity_verify.py` | `46a1069df06cd5bc9c1dea1d39b64e3af2ba1daff704e20f213f181ad1e70597` | **New (this delivery)** |
| `tools/strategy_farm/research/tests/test_hyp2_oilvol_sizing.py` | `7e7b76ec77d77dfb880cb95b5bee7686f596e3965e8fc6c1d3c81eee3998d28d` | **New (this delivery)** |
| `tools/strategy_farm/session_tools/__init__.py` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | New, empty (package marker) |

Hashes above are of the LF git-blob content (`git cat-file -p <commit>:<path> \| sha256sum`),
verified identical to `git show`'s staged object before commit. This repo has
`core.autocrlf=true`, so a future checkout's on-disk bytes may be CRLF and
hash differently; this is the same checkout-vs-sealed-bytes distinction
`input_availability.json`/`hyp1_inputs.read_git_blob` already document and
work around by hashing the Git blob, never the working-tree file.

## A drift finding worth independent attention

`tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` has **diverged on
`agents/board-advisor`** since HYP-1's review bound it: the canonical
checkout's current version (`sha256 3b88153733b302ed9cfc5d2b533cdc43c0e5051a0170979b8a988e66f42ba74e`)
inlined and removed the standalone `iter_m1_bytes(b, *, label, allowed_year)`
function that both `hyp1_inputs.read_hcc` and this delivery's design rely on
as the pure, hash-bindable byte decoder. Vendoring the current board-advisor
version instead of the HYP-1-review-bound one would silently break
`hyp1_inputs.read_hcc` with an `AttributeError`. This delivery vendors the
HYP-1-review-bound version (hash above) to keep the already-accepted contract
working; HYP-1's own task and whoever reconciles `session_tools` on
board-advisor should be made aware of this API drift independently of HYP-2.

## Verification run (this delivery)

```
python -m pytest tools/strategy_farm/research/tests/ -v
```
46 passed (22 vendored HYP-1 regression tests unchanged + 24 new HYP-2 tests).
Full output: `pytest_output.txt` in this directory.

```
python -m tools.strategy_farm.research.hyp2_identity_verify
```
`all_match: true` across the sealed-stream blob hash and all 14 HCC archive
existence/size checks; `price_payload_read: false`; `new_outcomes_computed:
false`. Full receipt: `identity_verify_receipt.json` in this directory.

## Exact continuation commands

```
cd C:/QM/worktrees/claude-orchestration-2
python -m pytest tools/strategy_farm/research/tests/test_hyp2_oilvol_sizing.py -v
python -m tools.strategy_farm.research.hyp2_identity_verify
```

No runner/manifest script analogous to `hyp1_measure.py` is included: building
one would require a reviewed daily `DayCoverage` calendar authority for
XTIUSD.DWX/USDCAD.DWX (coverage/timestamp authentication is explicitly still
unresolved per `OIL_SERIES_PROVENANCE.md`) and would be the first step that
actually opens price bytes toward an outcome -- exactly the step this task
requires independent approval for *before* it happens. That manifest/runner
and the state-to-trade pairing (which must still never read the `profit`
field) are the next engineering step, gated on review of this delivery.

## Data-provenance limits (carried forward, not resolved here)

* XTIUSD.DWX contract-roll provenance remains UNRESOLVED (no back-adjustment,
  deletion or jump-threshold choice has been made or implied).
* No daily coverage/timestamp authority has been reviewed for XTIUSD.DWX or
  USDCAD.DWX; `aggregate_daily`'s `DayCoverage` contract (reused unmodified)
  requires one before any real HCC bytes are aggregated into `DailyClose`
  rows.
* The sealed 11422 stream's own identity is confirmed (byte-exact at the
  documented Git blob), but its trade-timestamp provenance (server-clock vs.
  NY+7 authentication) is still an engineering precondition, not verified by
  this delivery.
* No descriptive measurement, DELTA_P80/P50/P90, payout-ever LCB, or any
  other outcome metric is computed anywhere in this delivery. `tag_entry`
  never reads a trade's P&L; the test asserting winner retention explicitly
  checks that non-CLOSED rows carry no decoded `gross_profit`.

## Request

Independent creator-outside code/protocol review of this delivery is
requested before any new outcome calculation proceeds, per the task's mandate
("Independent approval BEFORE any new outcome calculation is mandatory. A
working implementation alone is not economic success.").
