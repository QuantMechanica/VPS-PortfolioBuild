# BARS_ZERO closed at the generator, and four verdict classes reclassified

## The spike that wasn't

The 4-hour completion count read 242, of which 184 were `Q02 INVALID` — 76%, and on its face
a bleeding class. It is not one. 183 of the 184 carry `verdict_reason=poison_pill:*`,
`attempt_count=0` and `claimed_by=NULL`, all stamped in the single hour 10:00–11:00 UTC:
they are **my own poison-pill sealing from earlier today**, and `poison_pill_quarantine`
holds exactly 184 rows, so the 0→184 transition reconciles against them.

**Real 4-hour production is 59 completions, not 242.** The remaining one INVALID is a
pre-existing `malformed_host_symbol_binding` on QM5_12578.

I am recording this because the number would have been reported as an incident. Excluding
measurement error before classifying is the only reason it wasn't.

## BARS_ZERO: cause found, fixed at the generator, hold released

The chain, end to end:

1. `QM5_41033_wti-flow-dom.mq5:50` declares `input double strategy_reconcile_tolerance = 1.0e-10;`
   — valid MQL5, compiles correctly.
2. `gen_setfile.ps1` copied that source literal verbatim into the `.set` file.
   `Convert-EAInputValueForSetfile` special-cased `string` and `ENUM_TIMEFRAMES` and returned
   the bare value for everything else, `double` included.
3. **MT5's `.set` parser truncates the exponent**: `1.0e-10` is read as `1.0e-1` = 0.1. Nine
   orders of magnitude, silently.
4. The EA's own guard at `mq5:483`,
   `QM_InputRequireDouble("strategy_reconcile_tolerance", …, 0.0000000001, 1.0e-20)`,
   sees 0.1, rejects its own configuration, and `OnInit` returns `INIT_PARAMETERS_INCORRECT`.
5. The run dies before the first bar. The factory sees zero bars, labels it
   `cold_cache_retries_exhausted:BARS_ZERO`, and **retries three times** — against a defect no
   retry can fix, at up to 7200 s of reserved timeout per attempt.

So `BARS_ZERO` was never a cold-cache symptom on these rows. It was an OnInit rejection
wearing an infrastructure label, and the retry ladder was the cost of the mislabel.

**Fixed at the generator** (`3844c472a`), which is the layer that was actually wrong: doubles
and floats are now expanded to plain decimal. It fails closed rather than guessing, because
`[decimal]` flushes magnitudes under ~1e-28 to zero and *writing 0 for a tolerance is worse
than writing an exponent* — the expansion is round-tripped through `[double]` and refused if
inexact, with three self-describing rejections (`SETFILE_FLOAT_UNPARSEABLE`,
`SETFILE_FLOAT_NOT_REPRESENTABLE_IN_DECIMAL`, `SETFILE_FLOAT_EXPANSION_LOSSY`), each naming
input, value and type.

`framework/scripts/tests/test_setfile_float_serialization.ps1` — 15 assertions, all holding,
**three of them negative controls** (1e-30 must be refused because it would become 0; 1e40
must be refused; a malformed exponent must be refused). A detector that cannot fire is not a
detector. It also asserts ordinary values pass through byte-identical and that
int/string/ENUM_TIMEFRAMES are untouched, because an unscoped serialization change is how
9072 setfiles were mutated once before.

## A mutation I caused, and reverted

To satisfy the hold's own release condition ("the setfile is regenerated — not by
hand-editing") I ran `gen_setfile.ps1` directly for QM5_41033. **That degraded the file**:
the bare generator dropped `qm_rng_seed`, every `qm_news_*` line, `qm_friday_close_*` and
`qm_stress_reject_probability`, and wrote `build_hash: pending`. The committed setfile comes
from the fuller build path, not from `gen_setfile.ps1` alone.

Reverted via `git checkout` of that single path, verified by hash. Two things learned worth
keeping:

- **`gen_setfile.ps1` alone is not the regeneration path for a production setfile.** Anyone
  acting on a "regenerate the setfile" instruction by calling it directly will silently strip
  the news, seed and Friday-close blocks.
- `git checkout` restored the file with CRLF where the working copy had LF, changing its
  bytes. That matters because the binding chain hashes actual on-disk bytes.

## The binding chain was stale on all three legs

`expected_setfile_sha256` matched neither the LF nor the CRLF form — the drift **predates**
my checkout. Checking further: `expected_ex5_sha256` and `expected_mq5_sha256` were stale
too. The repair that fixed the exponent had changed mq5, recompiled the ex5 and rewritten the
setfile, and refreshed none of the three bindings.

Positive control before touching anything: **8 of 8 passing siblings bind the as-is on-disk
bytes and match.** So on-disk bytes are the canonical basis and QM5_41033 was the sole
mismatch — not a misunderstanding of the scheme.

Rebound all three and released the hold in one `BEGIN IMMEDIATE` transaction that revalidated
every precondition inside the transaction against freshly read DB state and freshly hashed
files — row still `pending`, all three hashes still the stale values the repair was computed
against, tolerance line still exactly `strategy_reconcile_tolerance=0.0000000001`, exactly one
active hold with the expected `hold_code` — and rolls back on any deviation.
`work_items.updated_at` was deliberately **not** bumped: it feeds the claim-ordering age term,
and a bookkeeping repair must not reorder the queue.

Acceptance checked against the real predicate rather than assumed: 0 active holds, 0
quarantine rows on `(QM5_41033, XTIUSD.DWX, Q02)`, `status=pending`, 0 blocking dependencies.
The row is claimable. Final acceptance is a verdict, which the factory will produce on its own.

## Energy symbols are healthy; the matrix line is not a coverage verdict

`dwx_symbol_matrix.csv` records **both** XNGUSD.DWX and XTIUSD.DWX as verify-FAIL at import
(2026-04-27) with `bars_one_shot=0`, `bars_chunked=0`, `bars_drift=-100,000`. Read literally
that says the energy symbols have no accessible bars, which would make the `BARS_ZERO` rows a
symbol outage and every retry futile.

It is wrong to read it that way. Decided from outcomes instead:

| Symbol | Rows | Economic results (`pf_net`/`pooled_trades`) | Latest | `BARS_ZERO` |
|---|---:|---:|---|---:|
| XTIUSD.DWX | 2909 | **397** | 2026-08-17 | 32 (1.1%) |
| XNGUSD.DWX | 1110 | **191** | 2026-08-16 | 11 (1.0%) |
| XAUUSD.DWX | 9991 | 1144 | 2026-08-16 | 38 (0.4%) |
| **XCUUSD.DWX** | 20 | **0 — ever** | 2026-06-23 | 0 |

XTI and XNG produce economic verdicts routinely and as recently as today, so `BARS_ZERO` is a
**per-run condition at ~1%**, not a symbol property. The 2026-04-27 matrix line is a stale or
defective *probe* (`bars_one_shot_err=(-2, 'Terminal: Invalid params')`, and XTI shows
`mid_ticks_5min=997`, i.e. ticks are present) — **not** a coverage verdict, and it must not be
cited as one.

XCUUSD is the genuine outage: 20 rows, 19 INFRA_FAIL, zero economic results ever, nothing
since 06-23 — consistent with the XCU coverage trip. The same query separating a real outage
from a per-run transient is what makes either answer trustworthy.

## SYMBOL_SCOPE_LEAK is a correct rejection wearing an INFRA_FAIL label

Three of today's seven `Q02 INFRA_FAIL` rows are `compile_gate:SYMBOL_SCOPE_LEAK`
(QM5_41042, QM5_41032, QM5_41041 — all XTIUSD). The gate
(`farmctl.py:5824`, Q02/P2 only) refuses to dispatch a backtest whose EA references foreign
symbols. That is an **EA authoring defect caught before any tester time was spent** — the
system working exactly as intended — but it is filed as `INFRA_FAIL`, which pollutes infra
statistics and routes the row into infra recovery instead of a build fix.

The family then recovered: all three now validate `SINGLE_SYMBOL_OK` and all three show
`Q02 done PASS`. **QM5_410xx is producing, not bleeding** — 23 PASS, 12 economic FAIL, 6
ZERO_TRADES across 56 rows.

One exception: **QM5_41023 still leaks** (`foreign symbols referenced: XTIUSD.DWX`) and
produced a Q04 verdict today at 11:54 while leaking, because the compile gate runs only at
Q02/P2 and its Q02 passed on 08-16 before the leak mattered. Its Q04 verdict is an economic
FAIL (`F1 1.235 / F2 0.767 / F3 0.511`), so **no favourable verdict rests on the leak** — but
the gate's phase scope is a real hole: an EA can pass Q02 clean and then run Q04–Q10 ungated.

## Two live bleeders, one of them a new class

**QM5_11288's phantom binding is confirmed.** All 8 copies of the `.ex5` (repo + 7 terminals)
hash to `c9f20a0e…`; the bound `2ff35242…` exists nowhere. Today's Q08 row failed
`staged_ex5_preflight_failed` at 11:03 — the preflight caught it, fail-closed, as designed.
One row remains: `1bc0c677` USDJPY **Q09_NEWS, pending since 2026-08-06** — 11 days, which is
the Q09 news dam, not the phantom. Note its Q09_PORTFOLIO already reads `FAIL_PORTFOLIO`, so
re-running this pair was never going to produce an admission.

**QM5_20177 introduced `DRAFT_DEFECT`**, a class I had not seen: six Q02 rows voided at
03:22 UTC with *"confirmed early-target-at-fill implementation defect; raw strategy verdict
void for every Q02 row produced by this EX5"*. The fix landed first (`24e5bb90a`, 02:39), so
the voidings correctly retired pre-fix verdicts. Two problems remain:

1. **Five of the six voided pairs have no replacement row.** Only USDJPY re-ran. Voiding a
   verdict without enqueueing a replacement leaves the pair with *no verdict at all* rather
   than a pending one — the vacuum is invisible in every count that looks at verdicts.
2. **The one post-fix run returned ZERO_TRADES.** The fix rejects entries whose T1 target sits
   behind the fill price; if that rejection removes *every* entry, the plausible reading is
   that T1 is computed wrongly rather than that the entries are bad. Turning a
   wrong-verdict EA into a no-signal EA is not obviously progress. This is a rework
   candidate, and the question belongs with whoever made the fix — I am not requeueing five
   runs on a guess.

## Evidence

- `3844c472a` — generator fix + `framework/scripts/tests/test_setfile_float_serialization.ps1`
- `framework/EAs/QM5_41033_wti-flow-dom/QM5_41033_wti-flow-dom.mq5:50` (declaration), `:483` (guard)
- `tools/strategy_farm/compile_ea.py:17,255-265` — `SYMBOL_SCOPE_LEAK`; `farmctl.py:5818-5828` — gate scope
- `framework/registry/dwx_symbol_matrix.csv` — the XNG/XTI probe lines, superseded by outcomes
- work item `d062a748-ac59-4bcf-83cd-96b85b73e8d7` — rebinding + hold release recorded in payload
- related: `2026-08-17_setfile_exponent_notation_kills_runs_deterministically.md`,
  `2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md`,
  `2026-08-17_pending_binding_drift.md`, `2026-08-17_q09_news_gate_dammed_since_08-07.md`
