# TM_MODIFY / MON_SWEEP_BE_LOCK Retry-Storm Fix — Backoff + Hard Cap — 2026-08-22

Router task `e66bf234-433d-4cfa-bfca-898d11ff18e7` (claude). Framework-include only, no
EA `.mq5` touched, no recompile, no `T_Live` interaction, no terminal started.

## Trigger

`docs/ops/evidence/2026-08-22_tlive_ea_warn_classification.md` Finding 1: QM5_10706
(GBPUSD H1) produced 72,196 WARN lines (99.8% of all T_Live warn traffic) in a single
4.5h window on 2026-07-29 — one ticket (3169417771), its breakeven-lock sweep retrying
an [Invalid stops] rejection (retcode 10016) on effectively every tick, no backoff, no
give-up. Finding 1 flagged this as historical-but-unfixed: "nothing in the retry path
currently limits attempt frequency or gives up after N rejections."

## Root cause

`framework/include/QM/QM_TradeManagement.mqh` already had a 2026-07-20 hygiene fix: a
30s suppression window for **verbatim** repeat modifies (exact SL/TP match). It did not
help here because the BE-lock sweep recomputes its target from the live price every
tick, so each attempt's SL/TP differed from the last by fractions of a point — the
exact-match check (`MathAbs(diff) > 1e-10`) never matched, so the suppression never
engaged and every tick sent a fresh request the broker rejected for the same underlying
reason.

## Fix

`QM_TradeManagement.mqh`, `QM_TM_ModifySuppressed` / `QM_TM_RememberFailedModify`:

- Suppression is now **per-ticket**, independent of whether the target changed between
  attempts — the actual bug was that a drifting target could always dodge an
  exact-match check.
- Exponential backoff: `30s * 2^(attempts-1)`, capped at `QM_TM_MODIFY_BACKOFF_MAX_SECONDS`
  (900s / 15min). Never shrinks, never fully stops — a rejected modify can't create
  position risk, so retrying slowly forever is safe and still recovers a genuinely
  transient rejection (spread widening, requote) once it clears.
- Hard cap: at `QM_TM_MODIFY_GIVEUP_ATTEMPTS` (20) consecutive failures on one ticket,
  one `WARN TM_MODIFY_BACKOFF_CAP` alert line fires (ticket, attempt_count,
  backoff_seconds) — the "give-up" signal Finding 1 asked for — after which retries
  continue at the capped 900s cadence rather than stopping, so the position is never
  permanently orphaned from its BE lock.
- A successful modify still clears all state via the existing `QM_TM_ClearFailedModify`
  (unchanged), resetting `attempt_count` to 0 for the next distinct failure streak.

Both functions gained an optional trailing `datetime now = 0` parameter (defaults to
`TimeCurrent()`) purely for testability; production call sites are unaffected since they
don't pass it.

**Scope discipline:** this is a framework-include change only. It does not touch any
`.mq5`, does not recompile or redeploy `QM5_10706` or any other live EA, and does not
change `T_Live`. It takes effect only for EAs built against this framework going
forward (DL-089 Wave-1 rebuilds included) — recompiling an EA in active live inventory
is ROT and requires an explicit OWNER decision, not taken here.

## Verification (reject-simulation, no terminal required)

`framework/tests/test_tm_modify_backoff.py` — a Python reimplementation of the exact
backoff/suppression/give-up arithmetic (same pattern as
`framework/tests/test_ftmo_governor_policy_v2.py`'s golden-policy cross-check),
constants parsed directly out of `QM_TradeManagement.mqh` so the test cannot drift from
the shipped values:

- backoff grows monotonically and reaches the 900s cap
- the give-up alert fires exactly once per failure streak, retries continue afterward
- a success clears state and the next streak starts the backoff over
- a direct replay of the QM5_10706 incident window (4.5h, one tick-drifting-target
  rejection per second) collapses from the observed 36,098 `TM_MODIFY` WARN lines to
  under 40 broker round-trips under the new logic

```
python -m pytest framework/tests/test_tm_modify_backoff.py -q
5 passed in 0.09s
python -m pytest framework/tests/ -q
9 passed in 0.39s
```

Structural sanity check on the edited `.mqh` (brace/paren balance) passed; no MQL5
compiler was invoked — ad-hoc compiles are policy-refused while the factory is live
(`BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED`), and this task is explicitly framework-only
with no recompile authorized. Actual MQL5 compilation of this header happens the next
time any EA goes through the governed `Q02`/`COMPILE_EA` pipeline (e.g. the DL-089
Wave-1 rebuilds), which will surface any compiler-level issue through the normal gate.

## Not done here (out of scope)

- No live EA was recompiled or redeployed; QM5_10706's currently-deployed binary keeps
  running its pre-fix retry behavior until it is rebuilt through the normal pipeline
  (DL-089 covers it — see `docs/ops/evidence/2026-08-22_execution_contract_requal_flag_coverage.md`
  for the parallel EXECUTION_CONTRACT-flag coverage check on other live EAs).
- No gate threshold, news-staleness limit, or T_Live state changed.

## Sources

- `docs/ops/evidence/2026-08-22_tlive_ea_warn_classification.md` / `.csv` (Finding 1, trigger)
- `framework/include/QM/QM_TradeManagement.mqh` (fix)
- `framework/tests/test_tm_modify_backoff.py` (verification)
