# Review — Codex proposal on task 8236efbe (set-file strategy-param backfill)

Date: 2026-07-27
Reviewer: Claude
Subject: Codex proposal for the fleet-wide rollout of
`tools/strategy_farm/backfill_setfile_strategy_params.py`
Verdict: **APPROVE the hardened plan. Do NOT approve `--all`.**

## Summary

Codex was asked for a proposal, not an implementation, and specifically asked to
attack my safety claim first. It did, and it was right on both counts where we
disagreed. Two defects in my tool were caught that would have caused silent
strategy changes at fleet scale, and my headline root-cause figure was overstated.
Both are now fixed and the claim withdrawn.

## Where Codex was right and I was wrong

### 1. Serialization — the dangerous one

A set file stores **values**; MQL defaults are frequently symbolic. My first
version wrote them verbatim:

```
input ENUM_TIMEFRAMES strategy_tf   = PERIOD_H1;   -> "PERIOD_H1", not 16385
input string          strategy_host = "SP500.DWX"; -> quotes retained
input ENUM_MA_METHOD  strategy_ma   = MODE_SMA;    -> "MODE_SMA", not 0
```

MT5 parses those as 0. The strategy would have changed **silently** — precisely
what the tool asserts cannot happen. Measured across the EA tree: **335
occurrences in 55 distinct forms, 485 EAs affected.** It escaped notice on
QM5_9936 only because all nine of its parameters happen to be plain numbers.

Fixed: anything not a numeric literal or bool fails closed, and an EA with *any*
unserializable default is refused whole. A partial block is worse than none — the
baseline would declare some parameters and hide others, and 8.5 would perturb a
strategy that never ran.

### 2. My root-cause figure was inferred, not measured

I claimed this was "a plausible principal cause of the 163 farm-wide Q08
INFRA_FAIL rows (34% of all Q08 runs)". That came from a file count, never
checked against the failures. Codex disputed the scale. Measured directly:

| Q08 INFRA_FAIL rows | 204 |
|---|---|
| set file **does** carry `strategy_*` | 158 — other cause, undiagnosed |
| set file carries none | **46** — this defect |

So it explains roughly a fifth of Q08 INFRA_FAIL, not a third of every Q08 run.
**The remaining 158 have a different root cause that nothing here addresses.**
That is now the larger open question.

### 3. `.ex5` lineage

Codex requires verifying that the deployed binary was compiled from the `.mq5`
being read. This repo has known recompile debt, so "the EA's own defaults" could
be read from a source the running binary was never built from — which would
break the behaviour-identity claim at its root. I had not considered it. Accepted
as a precondition.

### 4. Verdict mapping — a better diagnosis than mine

I proposed "8.5 should have its own verdict". Codex located the actual break:

- `framework/scripts/q08_davey/aggregate.py:1379` **already** distinguishes a
  deterministic `baseline_setfile_defect` from retryable tooling;
- `tools/strategy_farm/farmctl.py:2474`, `:2480` then converts a dominant Q08
  `INVALID` back to `INFRA_FAIL`, discarding that distinction.

So the information exists and is thrown away at the aggregate-to-work-item
boundary. That is why a permanent defect has looked transient and been requeued
forever. Codex's two-verdict split is also sharper than mine:

- `NOT_APPLICABLE` / `NO_PERTURBABLE_STRATEGY_INPUTS` — EA genuinely declares no
  tunable parameter (the 56). Terminal, not retryable, not a merit verdict,
  excluded from aggregate weighting.
- `INVALID` / `BASELINE_SETFILE_DEFECT:MISSING_STRATEGY_INPUTS` — EA has inputs
  but the generated baseline omitted them. A build defect, terminal until repaired.

Endorsed as written.

## Where we agreed independently

Both of us found that editing a set file breaks the identity hash bound into
already-recorded evidence. I measured which gates store one: **Q04–Q07 store
none; Q08 and Q10 do.** For the target population the Q08 loss is nil — that
`INFRA_FAIL` is what we are clearing — but Q10 is the closing verdict, and **34
EAs in scope hold Q10 evidence, overwhelmingly PASS**, including 10128 and 10145
on XAUUSD (the only two `challenge_ready` sleeves) and 13036 and 13213 (two
accounts in the FTMO campaign). The tool now skips them and fails closed if the
farm DB is unreadable.

## Where I do not follow Codex

**Its count of 14 vs my 46.** Codex reported "only 14 existing Q08 INFRA_FAIL
`(EA, symbol, setfile)` groups matched". I measure 46 rows. The gap is probably
rows vs distinct groups, possibly compounded by scoping through 8.5's parser
rather than my regex. The direction of its argument is right either way — the
tranche is small, not fleet-scale — so this does not change the plan, but the
number should be reconciled before anyone cites either figure.

**Its evidence limitation.** Codex reports the 9936 aggregate path did not exist.
It did when I read it; my own requeue moved it, recorded in the work item payload
as `archived_report_root_on_requeue`. The citation was valid when made and the
path is now stale. Worth noting so the discrepancy is not read as a fabrication
by either of us.

## Decision

1. **Approved**: tool hardening (serialization fail-closed, Q10 guard, `.ex5`
   lineage precondition, manifest with old/new SHA + rollback text, re-run 8.5's
   own parser over each proposed file).
2. **Approved**: canary of 2 Q08 items, scalar-only, then bounded tranches of
   ≤5 with never more than 5 repaired Q08 items in flight while Q02 pending
   exceeds 2000.
3. **Approved**: the verdict redesign, to be implemented at
   `_derive_phase_runner_verdict` rather than by inventing a top-level Q08 merit
   verdict.
4. **Not approved**: `--all`. Not now, and not until the canary produces
   hash-correct neighborhood evidence.
5. **New work, higher value than the rest**: the **158** Q08 INFRA_FAIL rows whose
   set files are fine. That is the bigger share of the failure mode and is
   currently undiagnosed.

Current state: QM5_9936 is repaired and its Q08 is running. 10582 (1683 trading
days) Q08, 11063 and 10847 Q04, 10115 Q05 are also in flight.
