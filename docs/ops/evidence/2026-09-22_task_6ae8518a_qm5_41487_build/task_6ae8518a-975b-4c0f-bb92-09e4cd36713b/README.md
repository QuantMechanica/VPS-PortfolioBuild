# Build QM5_41487 ft-binhv45-v2 — evidence

Task: `6ae8518a-975b-4c0f-bb92-09e4cd36713b` (agent: claude, worktree
`agents/claude-orchestration-1`). Second-Chance v2 of `QM5_11211` (retired
2026-08-21, OWNER D1 disposition; original was never built), revision
`f05399de` (Antigravity, APPROVED). Card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41487_ft-binhv45-v2.md`
(repo mirror `artifacts/cards_approved/QM5_41487_ft-binhv45-v2.md`, identical
content, verified byte-for-byte modulo CRLF/LF — same `diff -tr '\r'`
check used for the sibling QM5_41486 build).

## No parent source to clone (confirmed, not assumed)

The task SOP said "clone ... byte-exact **if present** (else implement from
the card)". `git log --all --diff-filter=A --name-only -- '*11211*'` returns
no `framework/EAs/QM5_11211*` hits anywhere in history — only card/evidence
docs (`docs/ops/evidence/2026-09-20_task_f05399de_qm5_11211_retest_revision.md`,
`docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_task_f05399de_...md`).
The card itself confirms this: "The strategy was never built (0 work items, 0
metrics in farm database)." So this build **implements from the card**
(source: freqtrade-strategies `BinHV45.py`, commit
`dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`), not a clone — this is a genuinely
new lineage on M5 (the original was M1, rejected at G0 for implausible
cadence under the superseded §17 scalping doctrine).

## What changed

1. `framework/EAs/QM5_41487_ft-binhv45-v2/QM5_41487_ft-binhv45-v2.mq5` — new
   EA mechanising the card's BinHV45 capitulation-drop rules on M5, built on
   the current governed framework skeleton (same OnInit/OnTick wiring pattern
   as the sibling `QM5_41486` build and `QM5_10026_rw-fx-squeeze-mr`).
   Long-only Bollinger(40,2) band-pierce + bbdelta/closedelta/tail filter
   entry; TP = min(1.25% of entry, 1.5*ATR(14,M5)); SL = min(1.5*ATR(14,M5),
   5% of entry); no discretionary exit (source has none); no trailing/BE
   (card gives no trailing formula). See SPEC.md §1 for the documented TP/SL
   ambiguity-resolution judgment call (card states SL as an explicit `Min(...)`
   but states TP as a parenthetical "or" — read consistently as Min for both,
   flagged for Q02+/critic review, changeable via input params alone).
2. `framework/EAs/QM5_41487_ft-binhv45-v2/SPEC.md` — new spec: lineage,
   mechanism, parameter table, symbol universe, TP/SL interpretation note,
   identity/registry.
3. Setfiles generated via `framework/scripts/gen_setfile.ps1` (governed
   generator, not hand-written) for the four card-target symbols, TF=M5:
   - `sets/QM5_41487_ft-binhv45-v2_EURUSD.DWX_M5_backtest_s20260922-001.set` (slot 0)
   - `sets/QM5_41487_ft-binhv45-v2_GBPUSD.DWX_M5_backtest_s20260922-001.set` (slot 1)
   - `sets/QM5_41487_ft-binhv45-v2_USDJPY.DWX_M5_backtest_s20260922-001.set` (slot 2)
   - `sets/QM5_41487_ft-binhv45-v2_XAUUSD.DWX_M5_backtest_s20260922-001.set` (slot 3)
   `RISK_FIXED=1000` / `RISK_PERCENT=0` (Build Guardrail compliant, ENV=backtest).
   `qm_magic_slot_offset` correctly 0/1/2/3 per symbol (verified against the
   registry rows below). `build_hash` field is `pending` — no `.ex5` exists
   yet (governed compile not yet run; see Blocker below, same structural gap
   as the sibling QM5_41486 build).

## Identity / registry (already governed, not touched by this task)

| Field | Value |
|---|---|
| `qm_ea_id` | 41487 |
| Magic EURUSD.DWX (slot 0) | 414870000 |
| Magic GBPUSD.DWX (slot 1) | 414870001 |
| Magic USDJPY.DWX (slot 2) | 414870002 |
| Magic XAUUSD.DWX (slot 3) | 414870003 |
| Registry commit | `6ff6c70c94` (governed magic allocator; `framework/registry/magic_numbers.csv` + `QM_MagicResolver.mqh` regen) |
| `ea_id_registry.csv` row | `41487,ft-binhv45-v2,1580128f-e465-5454-bb97-a7572a6cfd6d,active,Fable,2026-09-21,,,` |

No edits were made to `magic_numbers.csv` or `ea_id_registry.csv` (constraint
honored; rows already existed at HEAD — this worktree's prior cycle already
carried the 2026-09-22 registry-sync merge documented in the QM5_41486
evidence, so no re-sync was needed this cycle).

## Hashes

```
source (.mq5) sha256:      290dff887aa88c37b7dbba1548fbc589b0cd4e2abb809cb593896a39b790e78b
set EURUSD.DWX sha256:     e2f1139a2ac0ab8aa16cf1a5e173baf2486e2ad883b562ddae07ab2ff41fbe5d
set GBPUSD.DWX sha256:     9ff30eb213c7e0fb58767287947c2b6aed47e7bd8619a59418026f04801dbce2
set USDJPY.DWX sha256:     43d203ad3a51e47b3999f7792867a187875d9a2edd113ac29cc06275bbdde9fb
set XAUUSD.DWX sha256:     d4bf2fbfef34c857b4c969338692099f64696afd6e253a2f070b2249877118da
```

## Syntax sanity (no compile available — see Blocker)

Brace/paren balance check on the new source: 18 open / 18 close braces, 155
open / 155 close parens. All framework helper call signatures
(`QM_StopATR`, `QM_TakeATR`, `QM_StopRulesStopFromDistance`,
`QM_StopRulesTakeFromDistance`, `QM_BB_Middle/Lower`, `QM_TM_OpenPositionCount`,
`QM_TM_OpenPosition`) were cross-checked against their declarations in
`framework/include/QM/QM_StopRules.mqh`, `QM_Indicators.mqh`,
`QM_TradeManagement.mqh` before use. This is not a substitute for a real
compile — flagged as such, not claimed as verified-by-compiler.

## Blocker: governed COMPILE_EA row not yet enqueued (same structural gap as QM5_41486)

Both attempted paths were refused, reproducing the exact class of blocker
already documented for the sibling task `67c45a2f-2b42-4813-a5c8-13704534cace`
(`docs/ops/evidence/2026-09-22_task_67c45a2f_qm5_41486_build/.../README.md`):

1. `farmctl.py enqueue-compile` is a state-mutating command and must run from
   the canonical checkout (`C:/QM/repo`), per CLAUDE.md. Even if run from
   there, `compile_work_items.enqueue_compile_eas` resolves the EA source/SPEC/
   setfiles/card relative to `REPO_ROOT` — this task's new files exist only on
   this worktree branch (`agents/claude-orchestration-1`), not in
   `C:/QM/repo`, so the canonical checkout cannot see them until this branch
   merges to `main`. Not attempted (known-refused per sibling precedent;
   re-running the identical failing command would not produce new evidence).
2. `framework/scripts/build_check.ps1 -EALabel QM5_41487_ft-binhv45-v2
   -SkipCompile` — attempted this cycle, refused:
   ```
   BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED: {"detail": "terminal64 processes
   are alive; ad-hoc compile/build_check is refused. Use the governed pipeline
   path: python tools/strategy_farm/farmctl.py enqueue-compile <EA label>. No
   retry was attempted.", "failure_class":
   "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED", ...}
   ```
   Confirmed 3 live `terminal64` processes at the time of the attempt
   (factory in active use). `-SkipCompile`'s bypass path additionally
   requires `-PresetRepairTemplatePath`/`-PresetRepairBuildHash`, which do not
   apply to a fresh build.

**Net effect:** source, SPEC, and setfiles are complete, committed, and ready
to build; the compile row and the resulting `.ex5` are pending main
integration of this branch (close-out step), after which
`enqueue-compile QM5_41487_ft-binhv45-v2` can run from `C:/QM/repo` and the
governed worker attaches Q02 canaries per the velocity pump.

## Verdict

BUILD_COMPLETE_COMPILE_PENDING_MAIN_INTEGRATION — source/SPEC/setfiles for
QM5_41487 (Second-Chance v2 of QM5_11211, new lineage M1->M5, implemented from
the card since no parent source ever existed) committed on
`agents/claude-orchestration-1`; TP/SL ambiguity in the card resolved and
documented (Min-combinator, consistent with the SL formula); governed
COMPILE_EA enqueue correctly deferred (same farmctl canonical-checkout guard +
EA-files-not-yet-in-`C:/QM/repo` structural gap as the sibling QM5_41486
build) to post-merge close-out.

## Router state left unchanged (IN_PROGRESS) — REVIEW dispatch gate expected to refuse

Per the sibling precedent, `agent_router.py update-task ... --state REVIEW`
with this README as `--artifact-path` is expected to be refused by
`_build_review_dispatch_gate` (`D6_BUILD_IDENTITY_MISSING` —
`build_identity_json_missing_review_dispatch_refused`): that gate requires a
`build_identity.json` compile receipt (`build_check_passed: true`,
hash-bound `mq5_path`/`mq5_sha256` **and** `ex5_path`/`ex5_sha256`,
git-tracked clean at HEAD, non-empty `setfiles_generated`), which cannot exist
before a real compile — and a real compile cannot run until this branch
merges to `main` (see Blocker above). This is the same structural
sequencing gap already flagged for OWNER/board-advisor attention in the
QM5_41486 evidence; not re-flagging it a second time as a new finding, just
recording that this task hits the identical, already-documented gate. Task
`6ae8518a-975b-4c0f-bb92-09e4cd36713b` therefore remains `IN_PROGRESS`, not
`REVIEW`, at the end of this cycle — this reflects real pipeline state, not
an oversight.
