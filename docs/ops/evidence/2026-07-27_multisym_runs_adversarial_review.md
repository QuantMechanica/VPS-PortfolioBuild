# Adversarial review — multi-symbol joint FTMO runs (steps 1–3)

Date: 2026-07-27 · Branch `agents/board-advisor` · Reviewer: Claude (adversary role)
Scope: the three EXECUTED artifacts —
`2026-07-27_joint_backtest_run_EXECUTED.md`,
`2026-07-27_multisym_step2_EXECUTED.md`,
`2026-07-27_multisym_step3_EXECUTED.md` — verified against the harvested artifacts on
`D:` and against the state DB, not against the claims.

## Bottom line

The three EXECUTED docs are **honest and reproduce against disk**. The single real
number in the whole set (`match_rate = 0.914741`) is a genuine **FAIL** against a
**void, cross-program, cross-vintage pair**, and it stopped there — no fabricated
fidelity, isolation, equity, or breach number survived into any claim. The
two-different-programs trap the adversary warned about **is present in the 0.914741
comparison**, but the pipeline caught it in steps 2–3 rather than publishing it as a
pass. Two real weaknesses remain: (i) the joint EXECUTED doc presents 0.914741 as its
own "fidelity gate" without stating in that same doc that the pair is cross-program and
cross-vintage (only the downstream docs say so); (ii) the diff-(b) vintage question is
not merely unresolved — its subject ("today's 9936") is a moving target with three
distinct EX5 builds on 2026-07-27 alone. One housekeeping issue: a held-but-idle T9
reservation.

Verdicts are ranked most-material first.

---

## RANK 1 — CONTROL: the 0.914741 pair is void (cross-program AND cross-vintage). CONFIRMED

**Claim under test:** the joint EXECUTED doc frames `match_rate = 0.914741` as the
"FIDELITY GATE" for the joint EA (`2026-07-27_joint_backtest_run_EXECUTED.md:6,13-24`).

**Verified from disk — the two operands are different programs built in different
sessions:**

- Joint replay operand — `D:/QM/reports/joint_20180/harvest/20180_s0.jsonl`
  (1,255 rows), produced by EA `QM5_20180_ftmo-joint-sim-backtest-only`,
  EX5 SHA-256 `c29da61f2aeb348d35a0dbbdc5b889c172df3332be1d51523c16e98de721e946`,
  mq5 source SHA-256 `f46d54c6e9bfe779aac82a77b45555d563727c7addda6a19d12e20e72fc1fc21`,
  built **2026-07-27 10:22Z**
  (`D:/QM/reports/joint_20180/s0/QM5_20180/20260727_122752/summary.json`,
  `execution_identity.expert_binary` / `mq5_source`).
- Gated operand —
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`
  (1,252 rows), produced by the standalone EA `QM5_9936_ff-range-breakout-gmt3-h1`,
  archived EX5 SHA-256 `a1de7a7be28a40b592400c1fa3631d1fbd3f7e45c03f4b1763b99acd44e868ca`,
  written **2026-07-14** (`2026-07-27_evidence_vintage_check.md:19-23`).

Different EA identity, different mq5 source, different EX5, compile sessions **13 days
apart**. Both SHA-256 pairs are recorded (joint in `summary.json`; archived in the
vintage-check doc), and they **prove the mismatch** rather than a match. This is exactly
the "same vintage" pairing the step-1 protocol required and that was never satisfied.

**Independent reproduction (desk-only, no terminal):** re-ran
`tools/strategy_farm/compare_joint_replay.py` against the two on-disk streams:

```json
{ "joint_trades": 1255, "gated_trades": 1252, "matched": 1148,
  "unmatched_joint": 107, "unmatched_gated": 104, "match_rate": 0.914741 }
```

Exit code 2 (fail). `0.914741` reproduces bit-for-bit; `mismatch_categories` =
`{exact:716, shifted:51, different_entry:485, extra:3, missing:0}`.

**Verdict — CONFIRMED.** As diff (a) the number is **void** (mismatched pair) and it is
also a **FAIL** (`0.914741 < 1.0`). The doubly-void nature means it cannot be salvaged
by tuning. The joint EXECUTED doc's own conclusion (`:29-31,121-124`) correctly stops
and refuses to tune. Steps 2–3 (`step2:62-81`, `step3:43-49`) correctly recharacterize
it as "wrong EA (20180 not repaired 20181), wrong control (2026-07-14 archive, not a
same-vintage standalone), failed anyway." **Residual defect:** the joint doc itself does
not carry that cross-program/cross-vintage caveat inline — a reader of that file alone
could mistake 0.914741 for a legitimate-pair fidelity metric. Fix downstream:
annotate the joint doc, or treat it as superseded by step 2.

## RANK 2 — VINTAGE (diff b): unresolved AND the subject drifts. CONFIRMED unresolved

**Claim under test:** does diff (b) settle whether today's 9936 matches the archived
stream, and is the bisect candidate named?

**Verified:**

- The current-tree 9936 control **never completed**: two documented attempts died at
  **19% progress** with `"some error after pass finished"`, no report, T2 reclaimed by
  its worker within ~3 min (`2026-07-27_evidence_vintage_check.md:54-58`;
  `2026-07-27_timer_fidelity_curve.md:39-51`). Every requested measure in the
  vintage-check comparison table is `NOT ESTABLISHED` (`:62-74`). So diff (b) has **no
  operand for "today's 9936"** and does **not** settle equivalence.
- **The subject is a moving target.** Three distinct 9936 EX5 builds exist on
  2026-07-27 alone:
  - archived (gated-stream source): `a1de7a7b…`, 330,340 B, 2026-07-14;
  - vintage-check "current": `7ea6234d772aa161f00c66ebb06eb8df5f592251f143ca119fea64e4bed0929f`,
    363,810 B, compiled 18:37:50 (`2026-07-27_evidence_vintage_check.md:40-42`);
  - **on disk NOW**:
    `C:/QM/repo/framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/QM5_9936_ff-range-breakout-gmt3-h1.ex5`
    = `b6912f1cbccf4fa2dbe777a50d9275a1f09888224df37797d81a46c30361f5fc`, **364,194 B,
    mtime 2026-07-27 22:19:27+02:00** — a **third** vintage, already diverged from the
    SHA the vintage-check doc calls "current."
- **Bisect candidate:** not named, and correctly so — the vintage doc defers it ("only
  bisect if the resulting trade stream diverges," `:83`) and no divergence was ever
  observed because the control never produced a stream. This is honest, not
  hand-waving, but it means the question stays open.

**Verdict — CONFIRMED NOT ESTABLISHED.** diff (b) does not settle equivalence; no
bisect candidate is (or can yet be) named; and because the archived 2026-07-14 stream is
the very reference behind the RANK-1 0.914741, this open vintage gap directly
contaminates interpretation of that number (the 8.5 pp shortfall could be joint-wrapper,
vintage drift, or both — inseparable). A valid retry must pin one 9936 EX5 SHA, hold a
reservation its worker honors, and run the current-tree control to completion **before**
any joint fidelity claim is trusted.

## RANK 3 — ISOLATION: held-but-idle T9 reservation. FLAG (housekeeping)

`D:/QM/strategy_farm/state/terminal_reservations.json` at review time holds:

```json
"T9": { "reserved_by": "claude-board-advisor",
        "reason": "FTMO multisym step1 ad-hoc fidelity run 9936-vs-20181-runner",
        "created_at_utc": "2026-07-27T20:07:16Z", "until_utc": "2026-07-27T22:37:16Z" }
```

At `scanned_at 2026-07-27T20:52:59Z`, `running_mt5_terminals` = `[T1,T10,T3,T4,T6,T8]` —
**no T9 terminal is running** — and `D:/QM/reports/joint_20181/` still has **no step-1
output** (only a stray control `tester.ini`, 473 B, 17:13). So the reservation is held
with no active run and no product: the step-1 runner-fidelity measurement (the operand
steps 2–3 wait on) is **not in flight** and has produced nothing.

**Verdict — FLAG.** The reservation is *properly formed* (owner, reason, expiry all
present) so it is not a rule breach, but a held-but-idle exclusive lock on T9 is a squat
risk if abandoned. It belongs to the step-1 lane (same `claude-board-advisor` role) and
is inside its window, so I did **not** release it. Recommend: if step-1 is not about to
launch, release T9 so the factory can reclaim it.

## RANK 4 — GATES: no step was taken on top of a failed gate. CONFIRMED (protocol honored)

- Joint run: sleeve 0 replayed, gate failed at 0.914741, **stopped** — sleeve 1 and the
  two-sleeve joint were **not** run (`joint…EXECUTED.md:29-31,107-120`).
- Step 2 (10145:XAUUSD): gate = step-1 diff (a) == 1.0. diff (a) has no operands (no
  runner-only joint stream, no same-vintage standalone; `step2:35-49,84-88`). **Stopped
  before touching a terminal** — no satellite enabled (`step2:6-7,97-112`).
- Step 3 (13301:GDAXI + full book): gate = step 2 admitted 10145 at 1.0 with the runner
  unperturbed. Step 2 was itself a gate stop (`step3:23-33`). **Stopped** — runs E and F
  never launched (`step3:128-148`).

Cross-checked live: the step-1 worklist is genuinely incomplete — task **#9 "Reserve
terminal, run both EAs… harvest Q08 streams"** is `in_progress` and task **#10 "Diff…
write step1 evidence doc"** is `pending` (router task list, this session), so `step2:29-32`
is accurate. `docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md` does not exist
(`step2:24-27`, `step3:37`) — confirmed absent on disk.

**Verdict — CONFIRMED.** Every gate stopped where it should; nothing was stacked on an
unproven scaffold. This is the ladder in `2026-07-27_multisymbol_timer_ea_plan.md:374-429`
working as designed.

## RANK 5 — ISOLATION (runs B/D/F bit-equality): not claimed. CONFIRMED not-established

Runner-trade invariance across runs B (runner-only joint), D (runner+10145), and F
(all three) requires those runs to exist. They do not: `step2:108` and `step3:140`
record run-B/D/F invariance as **NOT RUN**, and `D:/QM/reports/joint_20181/{s0_runner,
harvest}` are **empty** (verified: `find /d/QM/reports/joint_20181 -type f` returns only
the stray `control_9936/.../tester.ini`). A repo-wide `*20181*` search yields **zero**
real 20181 streams (apparent hits are timestamp substrings of unrelated EAs, as
`step3:60-62` states).

**Verdict — CONFIRMED NOT ESTABLISHED, honestly.** No isolation number was fabricated or
asserted; the streams simply do not exist to compare.

## RANK 6 — THE EQUITY PATH: absent on disk, no proxy substitution. CONFIRMED clean

The joint account-equity path (per-bar equity + intraday lows) and the −5% daily-breach
count are the classic place a proxy gets smuggled in. This round:

- **No equity/intraday-low artifact exists** for either joint EA:
  `find /d/QM/reports/joint_20180 /d/QM/reports/joint_20181 -iname '*equity*' -o -iname
  '*intraday*' -o -iname '*low*'` → nothing. The only joint_20180 products are the
  tester report, the runner log sample, and the 1,255-row trade stream.
- The joint doc marks the true account-equity path, observed max daily loss, max
  drawdown, and the intraday `EQUITY_LOW` −5% breach count all **NOT ESTABLISHED**
  (`joint…EXECUTED.md:114-119`); step 3 does likewise (`step3:141-147`).
- The `−5%` breach count is **not computed from any proxy** this round. The doc even
  distinguishes the prior stream-stitched proxy explicitly: step 3 lists "JOINT-equity
  FUND_SCORE … vs the stream-stitched 0.641: NOT ESTABLISHED" (`step3:146`) — i.e. the
  0.641 is labelled a stitched proxy, and the real joint-equity figure is left open, not
  back-filled from it.

**Verdict — CONFIRMED CLEAN.** The equity path does not exist at the claimed granularity
(or any granularity) and, correctly, no breach count was produced from a proxy. This is
the specific regression from earlier attempts that did **not** recur.

## RANK 7 — REAPER / TERMINAL / T5 / T_Live discipline. CONFIRMED clean

- **No work-item-queue run.** The one completed run (joint 20180) was launched via
  `framework/scripts/run_smoke.ps1` (`summary.json execution_identity.run_smoke`), its
  products live under the ad-hoc tree `D:/QM/reports/joint_20180/…` (not
  `D:/QM/reports/work_items/<uuid>/…`), and its INI has `ShutdownTerminal=1`
  (`…/raw/run_01/tester.ini`). It completed in 16m43s (`…/20260727.log` tail: "Test
  passed in 0:16:43") — an ad-hoc run the reaper cannot touch. The two failed 9936
  controls were also `run_smoke.ps1` ad-hoc, not queued; they died to reservation
  non-honor + "some error after pass finished", **not** a reaper kill.
- **No T5.** `terminal_workers` = T1,T2,T3,T4,T6,T7,T8,T9,T10 — **T5 absent** (DISABLED),
  untouched.
- **No T_Live.** The only T_Live process is the live terminal (`C:\QM\mt5\T_Live\
  MT5_Base\terminal64.exe`, `pipeline=false`, `work_item=null`) — observed, not touched.
- **No collision.** `git status` shows `tools/strategy_farm/farmctl.py` and
  `terminal_worker.py` clean (no uncommitted changes); last touched by Codex's reaper
  commit `850784f97`. This review edited neither; steps 2–3 explicitly did not either
  (`step3:134-135`).

**Verdict — CONFIRMED CLEAN** on reaper exposure, terminal discipline, T5, and T_Live —
subject only to the RANK-3 idle-reservation housekeeping note.

---

## Provenance of this review (no state touched)

Desk verification only: read the three EXECUTED docs and their cited support docs;
re-ran `compare_joint_replay.py` on two existing on-disk streams; hashed the current
9936 EX5; inspected `joint_20180/`, `joint_20181/`, `terminal_reservations.json`, and
`farmctl mt5-slots`. No `terminal64.exe` was started, no terminal was reserved by this
review, no work item was queued, and T5, T_Live, AutoTrading, Factory OFF/ON and `.DWX`
history were untouched. The three EXECUTED docs are committed
(`e808e2d9c` joint, `da6712c2d` step 2, `939e6e6dc` step 3).
