# Twenty pending rows were dead on arrival, and 19,160 setfiles can repeat it (2026-08-17)

## What started this

Codex delivered three Q04 recovery rows for `QM5_10413` bound to
`expected_ex5_sha256=e7cb954a…`. The binary on disk hashed `a9867e4a…` with mtime
**08:30:41Z** — rewritten about 90 seconds *after* the rows were sealed at 08:29Z.
`terminal_worker.py:2539-2549` compares the bound hash against the live source file and
raises `dispatch_ex5_source_sha256_mismatch`, so all three rows would have burned a
dispatch attempt and produced nothing. The batch reported "3 requeued" and delivered zero
runnable rows.

That raised the obvious question: **how many other pending rows are already dead?**

## Fleet census

Every pending row with a bound artifact hash, compared against the artifact on disk
exactly as the worker does at dispatch:

| Bucket | Before | After remediation |
|---|---:|---:|
| clean_bound | 71 | 85 |
| unbound (no hash in payload) | 911 | 910 |
| **ex5_drift** | **1** | **1** |
| **setfile_drift** | **17** | **2** |
| **mq5_drift** | **2** | **2** |
| ex5_missing / setfile_missing / ea_dir_missing | 0 | 0 |
| **would be refused at preflight** | **20** | **5** |

Census: `artifacts/pending_binding_drift_census_20260817.json`.

## Which byte form does a binding use? The question had to be settled first

Setfiles are UTF-16 and the repo converts LF↔CRLF on checkout, so a hash taken over git
blob bytes will never equal a hash of the working-tree bytes. Before touching 17 rows I
had to know which form the system actually binds. My first hypothesis — that the audit was
hashing the wrong form and the drift was a false positive — turned out to be **wrong**, and
the way it was refuted matters:

**Twelve consecutive rows that actually reached a verdict all bind the working-copy form
of their setfile.** A row that produced evidence proves the worker accepted its binding, so
the working copy is the authority. The drift is real.

| Artifact | Stored as | Binding form | Line-ending volatile? |
|---|---|---|---|
| `.ex5` | binary (blob bytes == working copy) | working copy | **no** — any drift is a real rebuild |
| `.mq5` | text, CRLF-renormalised | working copy | **yes** |
| `.set` | text, CRLF-renormalised | working copy | **yes** |

For `QM5_10413` the bound `e7cb954a…` matched *no* byte form of the current `.ex5` — not
raw, not LF-normalised, not the git blob — while the `.mq5` (`2abd66a6…`, mtime
2026-05-25) and all three setfile hashes matched exactly. Same source, same setfiles, a
different compile. **MQL5 compilation is not byte-reproducible**, so a second build of
identical source yields a different binary.

## Remediation, and what was deliberately not touched

Each drifted artifact was classified before anything was written:

- **`LINE_ENDINGS_ONLY`** — byte-identical after normalising CRLF/CR to LF. Content
  unchanged, so rebinding preserves the guarantee the binding exists to give. **15 rows
  rebound**, all setfile-only: the 06-27 XAUUSD cohort (`QM5_10201`, `10202`, `10217`,
  `10220`, `10221`, `10227`, `10307`, `10316`, `10461`, `10485`, `10503`, `10600`,
  `11118`) plus `QM5_1101` EURUSD and `QM5_10145` XAUUSD.
- **`CONTENT_CHANGED`** — differs beyond line endings. **Not rebound.** Five rows across
  four EAs, each carrying a `.mq5` that was genuinely edited after the row was sealed:

  | EA | Symbol | Phase | Drift | Pending since |
  |---|---|---|---|---|
  | `QM5_20181` | USDJPY.DWX | Q02 (×2 rows) | mq5 + setfile | 2026-07-29 |
  | `QM5_10649` | XAUUSD.DWX | Q04 | ex5 + mq5 + setfile | 2026-08-16 |
  | `QM5_10203` | XAUUSD.DWX | Q02 | mq5 | 2026-06-27 |
  | `QM5_1443` | EURUSD.DWX | Q04 | mq5 | 2026-08-16 |

  These must **not** be rebound. A row bound to one source silently running against
  edited source is exactly the evidence corruption the binding prevents. They need
  re-seeding from the current build through the governed path, per EA, with the repair
  context — not a hash patch.

`QM5_10413`'s three rows were repaired first and separately (`5740d811` GDAXI,
`8dc59e9a` NDX, `366b3b8a` XAUUSD), verified by reproducing the worker's exact comparison:
all three now report `ex5 OK, setfile OK, mq5 OK`.

## The systemic cause: 28 of 19,188 setfiles are protected

`.gitattributes` holds **49 `-text` pins**, of which **28 are individual setfiles**. The
repo contains **19,188 setfiles** and there is **no generic `*.set` rule**. So 0.15% of
setfiles are protected against line-ending renormalisation and the rest are volatile —
any checkout, `git add`, or normalisation pass can silently invalidate every binding taken
over them, without changing a single parameter value.

The 28 pins are the shape of the problem: files were pinned one at a time, after each one
caused trouble. The 15 rows repaired here are the same class arriving again, and some had
been sitting since **2026-06-27 — seven weeks** of a queue slot that could never produce
evidence.

## What must change

1. **Detect drift before dispatch, not as a wasted attempt.** The census above is cheap
   and read-only. Run it on a schedule and treat a drifted pending row as a fault: hold it
   with a reason rather than letting the worker discover it. A row that cannot run should
   never look identical to a row that is merely waiting.
2. **Close the line-ending class generically.** A `*.set -text` rule (and the same for
   `*.mq5`) removes the whole failure mode. **This is not a safe drive-by change**: it
   alters how git stores and checks out 19,188 files and will produce a very large
   renormalisation diff, so it needs its own staged change with a before/after binding
   census proving no pending row was invalidated by the fix itself.
3. **Bind after the final compile, never rebuild after binding.** `QM5_10413` shows the
   ordering hazard: a verification rebuild after enqueue invalidates its own rows. Any
   build-then-enqueue flow must take the hash from the last compile that will happen.
4. **A "requeued" count is not a delivery.** The batch that started this reported three
   requeued rows and delivered zero runnable ones. Acceptance for a requeue must be that
   the row survives the preflight comparison, not that it exists as `pending`.

## Evidence

- `artifacts/pending_binding_drift_census_20260817.json` — full census, before and after
- Comparison implemented at `tools/strategy_farm/terminal_worker.py:2539-2549`
- Codex delivery reviewed and recycled: router task `e685432a`, verdict recorded there
- `.gitattributes` — 49 pins, 28 of them setfiles

## Number correction: 18 repaired + 5 parked against a base of 20

`15 + 3 + 5 = 23` against a census base of 20 looked like a subset exceeding its superset. It is
a sequencing artefact, verified against the payload markers in the database:

| Set | Count | Marker | Part of the census of 20? |
|---|---:|---|---|
| QM5_10413 rows repaired **before** the census ran | **3** | `ex5_rebind_reason` | **no** |
| line-endings-only rebinds | **15** | `binding_rebind_reason` | yes |
| parked, content genuinely changed | **5** | holds (below) | yes |

`15 + 5 = 20` ✓ — the census base. The three QM5_10413 rows were fixed first, then the audit ran
and found 20 *others*. So: **20 rows in the census, of which 15 rebound and 5 parked; plus 3
repaired beforehand; 18 repaired in total across 23 rows touched.** The 23 is not an error, it is
two actions summed against one action's base.

Verified counts: `binding_rebind_reason` appears on exactly **15** rows across 15 distinct EAs
(QM5_10201, 10202, 10217, 10220, 10221, 10227, 10307, 10316, 10461, 10485, 10503, 10600, 11118,
1101, 10145). `ex5_rebind_reason` appears on **4** rows — three are mine (`5740d811` GDAXI,
`8dc59e9a` NDX, `366b3b8a` XAUUSD, all QM5_10413) and one, `1c4f5354` QM5_11224/USDJPY, was
written by another actor and is already `done`. The key is shared; my count of three was correct.

## The fifth parked row, named

I listed four EA names for five parked rows and wrote "+1", which left a row without an
identity. **QM5_20181 contributes two rows**, not one:

| Row | EA | Symbol | Phase | Active hold |
|---|---|---|---|---|
| `824ca951` | QM5_20181 | USDJPY.DWX | Q02 | `FTMO_BOOK3_Q02_ISOLATED_ONLY` |
| `a0d6400a` | QM5_20181 | USDJPY.DWX | Q02 | `FTMO_BOOK3_Q02_ISOLATED_ONLY` |
| `c2ce418a` | QM5_10649 | XAUUSD.DWX | Q04 | `ARTIFACT_BINDING_CONTENT_CHANGED` |
| `8abafefb` | QM5_10203 | XAUUSD.DWX | Q02 | `ARTIFACT_BINDING_CONTENT_CHANGED` |
| `48f156eb` | QM5_1443 | EURUSD.DWX | Q04 | `ARTIFACT_BINDING_CONTENT_CHANGED` |

Five rows, four EAs, every one named and every one confirmed non-claimable. The two QM5_20181
rows sit under the **pre-existing OWNER isolation hold**, which was correctly not replaced.
