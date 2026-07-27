# Codex brief — diagnose the five FRESH Q02 INFRA_FAIL failures. 814 pairs depend on it.

Date: 2026-07-27
Priority: highest. This directly determines the yield of a release that already happened.

## Why these five and not the other 44,000

A ten-pair canary was requeued today to test whether stranded Q02 pairs are recoverable.
Eight resolved: **2 PASS, 1 ZERO_TRADES, 5 fresh `INFRA_FAIL`**
(`docs/ops/evidence/2026-07-27_stranded_canary_update.md`). On that ~25% yield OWNER
decided to release the rest, and **814 pairs were requeued a few minutes ago**
(`docs/ops/evidence/2026-07-27_stranded_requeue_executed.md`). Pending went 2,039 → 2,853.

So these five are not a historical curiosity. They failed **today**, after the June
mass-failure cause was fixed and after today's failure-classification work landed. They
carry a **current, live fault** — and whatever it is, roughly 600 of the 814 just released
are expected to hit it too. Diagnosing five concrete cases is far cheaper and more useful
than letting 814 burn tester time discovering the same thing.

## The subjects

| work item | EA | symbol | status | prior reason before requeue |
|---|---|---|---|---|
| `49ab260f-da5c-4ad2-8ab2-a10152aea229` | QM5_9940 | SP500.DWX | failed | — |
| `5a6ce70f` | QM5_11072 | USDCAD.DWX | done | — |
| `93077cce-bac0-4d3a-aa77-70e9e9a99353` | QM5_10591 | GBPJPY.DWX | failed | `ACTIVE_TIMEOUT` |
| `9eefa526` | QM5_10792 | NDX.DWX | failed | — |
| `b0af005d-2565-44dc-8f9e-d3668f6f6583` | QM5_10485 | USDJPY.DWX | failed | `ACTIVE_TIMEOUT` |

Include as a sixth subject, because it is also a non-useful outcome:
`c5734bae` — **QM5_11062 / WS30.DWX → `ZERO_TRADES`**. An EA that runs and produces
nothing is a real verdict but not a usable sleeve, and if that outcome is common among the
released 814 it changes the expected yield again.

## What to establish

1. **The mechanism per case**, from row-bound evidence only: the work item's
   `evidence_path`, its aggregate, the run log, the tester journal, and the payload
   `verdict_reason`. Not inference, not pattern-matching to the historical classes.
2. **Do they share one cause or are they five distinct ones?** This is the decisive
   question. One shared mechanism is fixable and would lift the yield of all 814; five
   distinct ones means the population is simply heterogeneous debris and the ~25% is what
   it is.
3. **Is the cause in the terminal, the framework, the EA, or the data?** Note what has
   already been eliminated today: the news-calendar dependency is not currently active
   (`QM_News.mqh:287-297` falls back from the absolute path to `FILE_COMMON` and then to
   the bare basename, and the target file is present and current for all three users). Do
   not re-derive that; do check whether these specific runs took the fallback.
4. **For the `ZERO_TRADES` case specifically**: did the EA initialise correctly and simply
   find no signals in the window, or did something suppress entries — a news blackout, a
   session filter, a symbol mismatch, a warm-up failure? Those are very different findings.
5. **Is it fixable, and would fixing it change the yield?** Answer with a number: of the
   814 released, roughly how many carry the same signature? The population is queryable —
   do not guess.

## What NOT to do

- Do NOT requeue anything. 814 are already in flight; adding more before the diagnosis is
  exactly what this task exists to prevent.
- Do NOT stop the factory, and do not run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT mass-mutate work items. If the diagnosis implies rows should be reclassified,
  report it and let it be decided.
- Do not treat "it is INFRA_FAIL" as an answer. That label was shown today to conflate a
  terminal fault, a deterministic EA defect and a genuine transient — of 43,736 historical
  rows only 34 were truly transient.

## Constraints

- If a terminal is needed, reserve it (`farmctl.py reserve-terminal <T> --by codex
  --minutes <n> --reason "fresh infra diagnosis"`) and release it. **Never T5** (disabled),
  never `C:/QM/mt5/T_Live`. ~2,853 items are queued behind you.
- Do NOT re-import `.DWX` history.
- Evidence over claims: a path, a log line, or a query for every assertion. Write
  NOT ESTABLISHED rather than inferring.
- Commit with explicit pathspecs.

## Deliverable

`docs/ops/evidence/2026-07-27_fresh_infra_fail_diagnosis.md`: the mechanism per case, a
plain answer on whether they share a cause, the count of the 814 carrying the same
signature, and whether it is fixable.
