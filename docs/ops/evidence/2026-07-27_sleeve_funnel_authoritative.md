# Sleeve funnel — the one authoritative count

- Date: 2026-07-27
- Author: Claude
- Status: authoritative; supersedes the funnel numbers in
  `docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md` (session notes / adversarial
  review C, claim 5) and reconciles them against Codex adversarial review C.
- Data: pinned read-only snapshot of `D:\QM\strategy_farm\state\farm_state.sqlite`,
  `snapshot_utc = 2026-07-27T04:31:06Z`. Streams:
  `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades` (189 `*.jsonl`).
- Reproduce: `docs/ops/evidence/2026-07-27_sleeve_funnel_authoritative.py`
  (reads the DB `mode=ro`; no `Factory_OFF/ON`; no writes).

## Bottom line

Two funnels disagreed. Codex was right on the load-bearing point and I was incoherent:
I listed **Q04 `PASS_LOWFREQ`** as a top *blocker* while my own production tool
(`challenge_final.py:46`) already treats it as pass-ish. The pipeline **routes**
`PASS_LOWFREQ` forward (farmctl.py:11369), so it is not a rejection and never belongs
in the blocker column. Correcting that — plus two refinements Codex's method did not
apply — gives:

| bucket | count |
|---|---:|
| Q08 trade streams (denominator) | **189** |
| distinct admission units (baskets are one unit) | 176 |
| **gate-clean (admissible)** | **63** |
|   — below 500 trading days (short) | 54 |
|   — **≥ 500 trading days → QUALIFYING** | **9** |
| **gate-rejected** | **126** |
|   — of those, blocked ONLY by `INFRA_FAIL` (unjudged, recoverable) | 16 |
| `PASS_LOWFREQ` blockers | **0** |

The decision-relevant layer — **9 qualifying, 16 infra-recoverable, 0 `PASS_LOWFREQ`
blockers** — is invariant across every reasonable resolution of the funnel and matches
Codex. The clean/rejected split differs from Codex by 6 for one reason only (basket
composite resolution, below); it does not touch the qualifying set.

## Reconciliation

| metric | Mine (review C, claim 5) | Codex review C | **Authoritative** |
|---|---:|---:|---:|
| streams | 189 | 189 | **189** |
| gate-rejected | 133 | 120 | **126** |
| gate-clean | ~56 | 69 | **63** |
| below 500 days | 51 | 60 | **54** |
| qualifying | 5–7 | 9 | **9** |
| blocked only by `INFRA_FAIL` | 20 | 16 | **16** |
| `PASS_LOWFREQ` blockers | **22** | 0 | **0** |

Why each number moved:

1. **`PASS_LOWFREQ` (the error that is mine).** My "133 rejected / `Q04 PASS_LOWFREQ 22`
   blocker" counted a Q04 `PASS_LOWFREQ` verdict as a rejection. The pipeline advances
   it (see the semantics table). Removing it from the blocker set is the single largest
   correction and is why my rejected count was inflated and my clean/qualifying counts
   were starved. This is exactly the incoherence flagged: naming a verdict a blocker
   while elsewhere arguing it is pass-ish. Codex is right.
2. **Qualifying 5–7 → 9.** The five `Q04:PASS_SOFT` + `Q08:FAIL_SOFT` sleeves (13213,
   10553, 10848, 12823, 13108) drop out of any funnel that mishandles either
   `PASS_SOFT`/`PASS_LOWFREQ` at Q04 or `FAIL_SOFT` at Q08. Handled per routing, they are
   admissible and the count is 9.
3. **Infra-only 20 → 16.** My 20 over-counted by treating basket **per-leg** `INFRA`
   rows as infra-only (e.g. 1058's `AUDUSD`/`NZDUSD` legs each carry a stray
   `Q02:INFRA_FAIL`) when the basket's **composite** verdict is `Q08:FAIL_HARD` — a real
   merit rejection. Resolving baskets to their composite moves them to rejected. 16.
4. **Codex 69/60/120 → my 63/54/126.** This is the only place I now differ from Codex,
   and it is not a verdict-semantics disagreement — it is basket handling. Codex used the
   stream-filename→symbol parse (identical to `challenge_final.py`), under which ~6 basket
   **per-leg** streams whose composite is `Q08:FAIL_HARD` have no matching per-leg
   work-item row and fall through as *clean-but-short*. The pipeline judges baskets as one
   unit under the `QM5_<id>_…` composite, so I resolve them there and they land in
   gate-rejected. `Q08 FAIL_HARD` blockers move 84 → 91 (the seven basket composites
   1058, 12781, 13117, 13140, 13144, 13147, 13151), which is the whole delta.

## Per-gate verdict semantics — derived from where the pipeline ROUTES

Not from `ftmo_qualification.py:348` (`verdict != "PASS"` → blocker), which is a
deliberately-stricter fail-closed contract for a **paid** challenge ("useful for
portfolio research but not sufficient evidence for a paid prop challenge", its own
docstring). Admission for the funnel is what actually advances a work-item to the next
phase:

- **Auto-pump cascade**: `farmctl.py:11367` `cascade_pass_verdicts`
- **Enqueue-next-phase**: `farmctl.py:12886` `phase_prev_verdicts`

| gate | ADVANCING (routes forward) | source | non-advancing verdicts seen in DB |
|---|---|---|---|
| Q02 | `PASS` | prev-verdict `Q04←Q02`={PASS} | `FAIL`, `INFRA_FAIL`, `ZERO_TRADES`, `RETIRED_LOW_FREQ`, `SUPERSEDED*`, `DRAFT_DEFECT`, `INVALID` |
| Q03 | `PASS` | cascade `Q03`={PASS} | `FAIL`, `INFRA_FAIL`, `RETIRE`, `INVALID` |
| **Q04** | `PASS`, **`PASS_SOFT`**, **`PASS_LOWFREQ`** | cascade `Q04`={PASS,PASS_SOFT,PASS_LOWFREQ} (DL-071 + DL-076), farmctl.py:11369 | `FAIL`, `INFRA_FAIL`, `PENDING_RUNNER`, `RETIRE` |
| Q05 | `PASS` | cascade `Q05`={PASS} | `FAIL`, `INFRA_FAIL`, `FAIL_DD_PORTFOLIO_REVIEW` |
| Q06 | `PASS` | cascade `Q06`={PASS} | `FAIL`, `INFRA_FAIL` |
| Q07 | `PASS`, `MULTI_SEED_PASS` | prev-verdict `Q08←Q07`={PASS,MULTI_SEED_PASS} | `FAIL`, `INFRA_FAIL` |
| Q08 | `PASS` → Q10 (main line); **`FAIL_SOFT`** → Q09_PORTFOLIO (branch) | farmctl.py:9637 / :12893 | `FAIL_HARD`, `INFRA_FAIL`, `INVALID` |
| Q09_PORTFOLIO | `PASS_PORTFOLIO` | portfolio gate | `FAIL_PORTFOLIO`, `NEED_MORE_DATA` |
| Q10 | `PASS` (closing per-(EA,symbol) verdict) | — | `FAIL` |

Classification used per sleeve: **advancing** (pass-ish), **branch** (Q08 `FAIL_SOFT`,
admissible for the separate-account campaign), **infra** (`INFRA_FAIL`/`PENDING_RUNNER`
— unjudged, not a merit verdict), **reject** (everything else). A sleeve is **gate-clean**
iff it has real gate evidence and every present Q02–Q08 verdict is advancing-or-branch
with no infra; **gate-rejected** otherwise; **infra-only** iff its only non-advancing
verdicts are infra.

Two empirical facts that make this robust:
- Q05/Q06/Q07 **only ever emit** `PASS`/`FAIL`/`INFRA_FAIL` (Q05 also
  `FAIL_DD_PORTFOLIO_REVIEW`). There is no `PASS_SOFT`/`PASS_LOWFREQ` downstream of Q04,
  so `challenge_final.py`'s looser `EARLY_OK` at Q05–Q07 and the strict routing agree on
  real data. The **only** pass-ish-beyond-`PASS` verdicts anywhere are Q04 `PASS_SOFT`
  (52) / `PASS_LOWFREQ` (24) and Q08 `FAIL_SOFT` (67).
- `RETIRED_LOW_FREQ` is a **Q02** verdict (the freq-floor retire) and is correctly a
  rejection. It is a different animal from Q04 `PASS_LOWFREQ` (pooled low-frequency
  *pass*). Conflating the two names is likely what seeded my original error.

## Corrected blocker / advancing tallies (latest verdict, all 189)

Merit rejections (the real funnel walls):

| count | gate · verdict |
|---:|---|
| 91 | Q08 `FAIL_HARD` |
| 18 | Q04 `FAIL` |
| 12 | Q05 `FAIL` |
| 9 | Q07 `FAIL` |
| 5 | Q06 `FAIL` |
| 4 | Q02 `FAIL` |
| 2 | Q03 `FAIL` |

Infrastructure / unjudged (NOT rejections): Q08 12, Q05 9, Q04 8, Q07 4, Q02 2, Q03 1
`INFRA_FAIL`.

Non-`PASS` **advancing** verdicts — pass-ish, explicitly NOT blockers: **Q08 `FAIL_SOFT`
67, Q04 `PASS_SOFT` 52, Q04 `PASS_LOWFREQ` 24.** The 24 is my old "22 blocker" line,
correctly relocated to the advancing side.

## The qualifying sleeve set (gate-clean AND ≥ 500 trading days)

Latest verdict at every gate; `Q09P` = Q09_PORTFOLIO; `-` = no completed row.
Trading days = distinct trade-close dates in the Q08 baseline stream.

| # | EA · symbol | tdays | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09_PORTFOLIO | Q10 |
|---|---|---:|---|---|---|---|---|---|---|---|---|
| 1 | 10582 · XAUUSD.DWX | 1683 | PASS | PASS | PASS | PASS | PASS | PASS | *(active)* | – | – |
| 2 | 13213 · USDJPY.DWX | 1596 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | FAIL_SOFT | FAIL_PORTFOLIO | PASS |
| 3 | 10553 · XAUUSD.DWX | 1498 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | FAIL_SOFT | FAIL_PORTFOLIO | – |
| 4 | 13036 · GDAXI.DWX | 1352 | PASS | – | PASS | PASS | PASS | PASS | PASS | FAIL_PORTFOLIO | PASS |
| 5 | 9936 · USDJPY.DWX | 1252 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | *(active)* | – | – |
| 6 | 10848 · XAUUSD.DWX | 1159 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | FAIL_SOFT | FAIL_PORTFOLIO | – |
| 7 | 12823 · USDJPY.DWX | 933 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | FAIL_SOFT | FAIL_PORTFOLIO | – |
| 8 | 13301 · GDAXI.DWX | 551 | PASS | PASS | PASS | PASS | PASS | PASS | PASS | *(pending)* | PASS |
| 9 | 13108 · XTIUSD.DWX | 523 | PASS | PASS | PASS_SOFT | PASS | PASS | PASS | FAIL_SOFT | FAIL_PORTFOLIO | – |

Read carefully, the 9 are three different states, not one:

- **Q08 `PASS` + Q10 `PASS` (fully main-line confirmed): 13036/GDAXI, 13301/GDAXI (2).**
  13036's Q03 shows no completed row (Q03 was skipped in its history) but Q04–Q08 and Q10
  are all done `PASS`; 13301's Q09_PORTFOLIO was reset to `pending` by the pump at
  04:28:10Z (see snapshot note) and is a branch gate, not part of admissibility.
- **Q08 `FAIL_SOFT` (portfolio branch, campaign-admitted): 13213, 10553, 10848, 12823,
  13108 (5).** All carry `Q09_PORTFOLIO = FAIL_PORTFOLIO`. The campaign's central claim
  is that this verdict judges sleeves sharing one equity curve and one 10% cap and does
  not transfer to separate accounts. That claim governs whether these 5 belong in a book;
  it does not change their funnel classification.
- **Q08 in-flight / `active` — pending, not passed: 10582/XAUUSD, 9936/USDJPY (2).** Both
  are gate-clean Q02–Q07 with a Q08 work-item currently `active` (10582 at 03:49:44Z,
  9936 at 03:55:05Z). 9936 is the campaign's known-pending strongest member; **10582 is a
  find** — gate-clean with 1,683 trading days but no completed Q08 ever, worth finishing.

So of the 9 qualifying, **only 7 have a settled Q08** (2 `PASS`, 5 `FAIL_SOFT`) and 2 are
mid-Q08. The campaign book (10553, 10848, 13036, 13108, 13213, 13301) is a 6-sleeve subset
of these 9; the other three are 9936 (pending), 12823 (`FAIL_SOFT`, USDJPY, the fourth-
account candidate), and 10582 (pending, uninvestigated).

## The 16 infra-only sleeves (unjudged, recoverable — not rejected)

All below the 500-day bar, so none are qualifying today, but their block is an
infrastructure artifact and a requeue can flip them:

| EA · symbol | tdays | INFRA at | latest Q08 |
|---|---:|---|---|
| 10847 · GDAXI.DWX | 469 | Q05, Q08 | INFRA_FAIL |
| 10911 · GDAXI.DWX | 283 | Q03, Q04, Q05 | PASS |
| 10287 · XAUUSD.DWX | 233 | Q08 | INFRA_FAIL |
| 10403 · XAUUSD.DWX | 209 | Q05 | FAIL_SOFT |
| 9573 · USDCHF.DWX | 152 | Q08 | INFRA_FAIL |
| 1230 · AUDJPY.DWX | 112 | Q08 | INFRA_FAIL |
| 9999 · EURUSD.DWX | 110 | Q04 | *(none)* |
| 1230 · XAUUSD.DWX | 108 | Q08 | INFRA_FAIL |
| 10939 · XAUUSD.DWX | 87 | Q08 | INFRA_FAIL |
| 1567 · EURUSD.DWX | 78 | Q07, Q08 | INFRA_FAIL |
| 10771 · GDAXI.DWX | 73 | Q08 | INFRA_FAIL |
| 13013 · NDX.DWX | 68 | Q07 | PASS |
| 10815 · GDAXI.DWX | 66 | Q04 | FAIL_SOFT |
| 1328 · USDCAD.DWX | 46 | Q08 | INFRA_FAIL |
| 10940 · XAUUSD.DWX | 35 | Q02 | FAIL_SOFT |
| 10771 · USDJPY.DWX | 28 | Q08 | INFRA_FAIL |

## Two methodological refinements this pass adds

1. **Baskets are judged as one unit.** Cointegration/spread EAs (`QM5_<id>_…` composite
   symbol) emit per-leg trade streams keyed by a real broker leg. Those legs either have
   no work-item row or carry a stray isolated row (a leg's `Q10` export, a leg's `Q02`
   INFRA). The pipeline routes and judges the basket under the composite, so every per-leg
   stream is resolved to the composite chain. 13 per-leg streams collapse onto their
   shared composite (189 streams → 176 distinct admission units). Without this, 13117's
   `EURGBP` leg (`Q10:PASS` only) hides a composite `Q08:FAIL_HARD`, and 1058's legs read
   as infra-only while the composite is a hard reject. This is a latent bug in
   `challenge_final.py` / `intraday_pass.py` too: their filename parse admits unmatched
   basket per-leg streams as gate-clean.
2. **The live DB mutates under the read.** The factory pump rewrites `Q09_PORTFOLIO` rows
   continuously (13301's flipped `FAIL_PORTFOLIO`→`pending` mid-analysis at 04:28:10Z).
   All numbers here are computed against a pinned `mode=ro` snapshot
   (`snapshot_utc 2026-07-27T04:31:06Z`) so they are reproducible; re-running the
   companion script against the live DB will drift by a sleeve or two in the sub-500-day
   population but never in the 9 / 16 / 0 decision layer.

## Risks / caveats

- `≥ 500 trading days` is a coverage bar on the historical Q08 baseline stream, chosen in
  the campaign (`challenge_final.py:42`) to admit 13301/GDAXI as a diversifier. It is not
  a gate; it is a sample-size floor. Streams predate the current binary in some cases.
- Q08 `FAIL_SOFT` admissibility is a **campaign** judgement (separate accounts, no shared
  cap), not a pipeline pass. The FTMO-strict `ftmo_qualification.py` contract
  (`verdict == PASS` at every strict gate) would admit only 13036 and 13301 of the 9, and
  even those carry the paid-challenge caveats already recorded in the campaign doc.
- The `Q08 FAIL_HARD 91` wall (72% of all merit rejections) restates review-C claim 6:
  only 18 of 477 Q08 rows are `PASS`. Whether Q08 is over-tight or correctly rejecting an
  edgeless population is a separate open question and is not settled here.

## Recommended next step

Adopt these numbers as the funnel of record. Finish Q08 on the two pending qualifiers
(9936, 10582) — 10582 especially, as it is a gate-clean 1,683-day XAUUSD sleeve with no
completed Q08 on record — and fix the `challenge_final.py` / `intraday_pass.py` sleeve
parse to resolve basket per-leg streams to their composite so the pool filter stops
silently admitting unmatched legs.
