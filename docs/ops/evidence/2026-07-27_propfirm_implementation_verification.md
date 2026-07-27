# Prop-firm phase implementation — adversarial verification

**Date:** 2026-07-27
**Verifier:** Claude (board-advisor worktree)
**Method:** Verified against committed source + build artifacts, NOT against the
implementation note's claims. Every assertion cites file:line, a command, or a query.
**Subject of review:** `docs/ops/evidence/2026-07-27_propfirm_phase_implementation.md`
(the note), against `framework/include/QM/QM_PropFirm.mqh`,
`framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/*`, `framework/include/QM/QM_Common.mqh`,
`framework/include/QM/QM_RiskSizer.mqh`, `framework/include/QM/QM_Entry.mqh`, the two
compile logs, and git history on branch `agents/board-advisor` (HEAD a25caf12e).

Verdicts use the convention: **CONFIRMED = the safety property holds** (implementation
is correct); **REFUTED = a defect or unclosed gap was found**. Ranked most-severe first.

---

## Verdict summary

| # | Check | Verdict |
|---|---|---|
| 4 | Phase-1 cap cannot reach a live/Funded account | **REFUTED** (documented residual; procedural mitigation only) |
| — | Change provenance / evidence trail is accurate | **REFUTED** (framework header landed via a build auto-commit; note's git-status claim is false) |
| 1 | Risk cap actually takes effect at runtime | **CONFIRMED** |
| 2 | Default behaviour unchanged for non-opting EAs | **CONFIRMED** |
| 3 | 5.0 ceiling enforced; above-ceiling refused not clamped | **CONFIRMED** |
| 5 | Set files respect RISK_FIXED (backtest) / RISK_PERCENT (live) | **CONFIRMED** |
| 6 | It actually compiled (fresh, 0/0) | **CONFIRMED** |

Two items are not clean. Neither is a runtime-correctness defect in the sizing math; the
cap itself is wired correctly and provably takes effect. The two REFUTED items are (a) a
design gap in fail-closed account binding that is mitigated only by the manual T_Live
gate, and (b) an evidence-trail defect in how the change was committed.

---

## FINDING 1 (severity HIGH — live-capital safety, mitigated) — Check #4 REFUTED

**Claim under test:** a Phase-1 (or Phase-2) risk cap cannot reach a live or Funded
account through any path.

**REFUTED.** The phase selector provides no fail-closed barrier, as shipped, against a
Phase-1 set file being loaded onto a Funded/live account. Trace:

- `QM_PropPhaseValidateCap` validates the cap against the phase the OPERATOR selected,
  not against the account's real type. For `prop_phase==PHASE_1` a 3% cap is legal
  (`QM_PropFirm.mqh:209-241`, band `(0,5.0]`). The EA cannot read "this is an FTMO
  Funded account" from MT5, so nothing downgrades the phase.
- The only in-code account binding is `prop_expected_login` (`QM_PropFirm.mqh:133`,
  enforced at `:406-414`). It **defaults to 0 = off**, and both shipped phase sets
  ship it unset (absent from `..._ftmo_phase1.set` / `..._ftmo_phase2.set`; grep returns
  no `prop_expected_login` line). So `QM_PropInit` never runs the login check for the
  shipped sets.

**Concrete failure scenario:** operator loads
`QM5_9936_..._USDJPY.DWX_H1_ftmo_phase1.set` (prop_phase=1, qm_risk_cap_pct=3,
prop_expected_login absent) onto an FTMO **Funded** account and skips the manifest
step. `QM_PropPhaseValidateCap(3.0)` returns true (phase-1 band), `QM_FrameworkSetRiskCapPct(3.0)`
returns true (3.0 ≤ 5.0), `QM_PropInit` finds `prop_expected_login==0` and arms. The
Funded account then trades a 3% per-trade cap against FTMO's –5% daily / –10% total
Funded limits — the very over-sizing the FUNDED band `(0,1.0]` at `QM_PropFirm.mqh:245`
was meant to prevent, bypassed because the account never actually declared itself FUNDED.

**Mitigation that makes this survivable (why HIGH not CRITICAL):**
- There is **no automated path to live**. T_Live AutoTrading is OWNER+Claude only
  (CLAUDE.md Hard Rules); live deploy requires the manual manifest/SHA/phase-vs-account
  verification. No factory process pushes these demo sets to a live/funded terminal.
- The note discloses this honestly as the "H3 residual" (implementation note §8.6,
  §H3) and states the T_Live manifest gate is the authoritative cross-deploy control.
- FTMO is OWNER-parked (MEMORY), so no Funded account is in play today.

**Required to close:** the deploy protocol MUST set `prop_expected_login` to the real
challenge login in the set file before any live/demo consideration, AND the T_Live-style
manifest must assert `prop_phase` matches the account's true FTMO stage. Until the
generated sets carry a non-zero `prop_expected_login`, the phase feature's own account
guard is inert and the barrier is 100% procedural.

---

## FINDING 2 (severity MEDIUM — evidence trail / Hard Rule) — provenance REFUTED

**Claim under test (implementation note §1):** "Two files, verified via
`git status --porcelain`: `framework/include/QM/QM_PropFirm.mqh` — the only framework
header changed. `framework/tests/mql5/QM_PropFirm_compile_probe.mq5` …". §2/§5 repeat
that the header is the sole framework change of this work.

**REFUTED as a provenance record.** The header content is correct in HEAD (verified:
`git diff HEAD -- framework/include/QM/QM_PropFirm.mqh` is empty; `git show
HEAD:...QM_PropFirm.mqh` contains the `QM_PropPhase` enum, `prop_phase` input, and all
validators). But the actual 383-line rewrite of the framework header was committed under:

```
a35c08338 build: pump auto-commit 1 factory artifact path(s)
 framework/include/QM/QM_PropFirm.mqh | 383 +++++++++----- (336 insertions, 47 deletions)
```

— a **factory artifact auto-commit** — while the labeled feature commit contains no
header change at all:

```
622299a45 feat(framework): prop-firm phase selector (Phase 1/2/Funded) in QM_PropFirm
 docs/ops/evidence/2026-07-27_propfirm_phase_implementation.md | 301 +
 framework/tests/mql5/QM_PropFirm_compile_probe.mq5            |  15 +
 (2 files changed — QM_PropFirm.mqh NOT among them)
```

(`git show a35c08338 -- framework/include/QM/QM_PropFirm.mqh` shows the
`prop_enabled`→`prop_phase` diff lines; `git log -- framework/include/QM/QM_PropFirm.mqh`
names a35c08338 as the last commit to touch it, and it predates 622299a45.)

**Why this matters:** (a) it violates evidence-over-claims — the note's stated
`git status --porcelain` provenance did not match the tree at commit time; a reviewer
auditing the labeled feature commit sees an empty framework change. (b) It repeats the
"pump committet nur Artifacts" hazard (MEMORY, dirty-guard notes): the build pump swept
a hand-authored framework-source edit into an artifact commit. **No runtime consequence**
— HEAD is correct and the binary was built from it — so this is a traceability/discipline
defect, not a behaviour defect.

**Concrete failure scenario:** a future `git revert 622299a45` (to "undo the phase
selector") reverts only the doc + probe and silently leaves the live enum/validators in
the header, because the header change is owned by an unrelated build commit. Bisecting a
regression to "the prop-firm feature" would land on a "build: pump auto-commit" with no
semantic label.

---

## FINDING 3 (Check #1) — CONFIRMED: the cap takes effect at runtime

Full path from input to the value the sizer clamps against, for the shipped
`ftmo_phase1.set` (RISK_PERCENT=3, RISK_FIXED=0, qm_risk_cap_pct=3, prop_phase=1):

1. `QM_FrameworkInit` selects `QM_RISK_MODE_PERCENT` (risk_fixed=0, so `:172` false),
   configures the sizer, then unconditionally sets the cap to 1% at
   `QM_Common.mqh:182` (`QM_RiskSizerSetCapPct(1.0)`), and sets `g_qm_fw_initialized=true`
   (`:238`) before returning true.
2. EA `OnInit` calls, as a **separate statement after** init returns
   (`QM5_9936_....mq5:463-467`): `QM_PropPhaseValidateCap(3.0)` (passes; not the 1.0
   sentinel, not >5.0) → `QM_FrameworkSetRiskCapPct(3.0)`.
3. `QM_FrameworkSetRiskCapPct` (`QM_Common.mqh:315-330`): guard `g_qm_fw_initialized`
   true; band `(0,5.0]` passes; sets `g_qm_risk_per_trade_cap_money = equity*0.03`
   (`:323-324`) and calls `QM_RiskSizerSetCapPct(3.0)` (`:325`) → sets the global
   `g_qm_risk_per_trade_cap_pct = 3.0` (`QM_RiskSizer.mqh:68-71`). Emits
   `RISK_CAP_OVERRIDE` because 3.0≠1.0 (`:326-328`).
4. **Clamp site.** Sizing runs through `QM_RiskSizerRiskMoney(equity)`
   (`QM_RiskSizer.mqh:91-117`): PERCENT base_risk = equity·3/100; the ceiling it clamps
   against is `QM_RiskSizerPercentCap(equity)` (`:108-109` → `:84-88`) =
   equity·(g_qm_risk_per_trade_cap_pct/100) = equity·0.03. base==ceiling ⇒ **no clamp**;
   3% flows. Had the override not run (cap left at 1.0), the ceiling would be equity·0.01
   and the 3% would be clamped to 1% at `:111-114` — the exact 79.5→4.7 fiction. The
   override is what prevents it, and it is proven to run.
5. **Runtime path the EA actually uses.** Strategy calls `QM_TM_OpenPosition(req, ticket)`
   with defaults (`QM5_9936_....mq5:312,550`); `QM_TM_OpenPosition`
   (`QM_TradeManagement.mqh:276-285`, defaults explicit_magic=0, explicit_risk_percent=0)
   routes to `QM_Entry`, which with `explicit_risk_percent==0.0` takes the **global**
   `QM_LotsForRiskAtEntry(_Symbol, sl_points, order_type, entry_price)`
   (`QM_Entry.mqh:297-301`) → `QM_RiskSizerRiskMoney(equity)` (the capped global path,
   `QM_RiskSizer.mqh:681`). So the 3% global cap governs the EA's real orders.

**Init log event that reports the effective cap — exists in code:**
`QM_PropLogEffectiveCap(qm_risk_cap_pct, g_qm_risk_per_trade_cap_pct)` at
`QM5_9936_....mq5:467` → `QM_PropFirm.mqh:317-326` emits `PROP_EFFECTIVE_CAP` with
`effective_cap_pct` **read back from the sizer global** (not an echo of the input) and a
`matched` boolean logged at ERROR if they diverge. Plus `RISK_CAP_OVERRIDE`
(`QM_Common.mqh:327`). The effective value is genuinely the same global the clamp reads
(`QM_RiskSizer.mqh:86`), so the log proves the ceiling from a log, as required.

**Scope honesty (inherited from note H1):** the log proves the CEILING is 3%, not that
realised position size is 3%. Realised size is set by RISK_PERCENT/RISK_FIXED and needs
the demo observable-size check (lots × stop-money == 3% of anchored balance) before live.
That check is correctly deferred to the demo protocol, not asserted here.

---

## FINDING 4 (Check #2) — CONFIRMED: default behaviour unchanged for non-opting EAs

- **No core-chain file changed.** `git diff --stat HEAD -- framework/include/QM/QM_Common.mqh
  framework/include/QM/QM_RiskSizer.mqh` is empty. The unconditional `QM_RiskSizerSetCapPct(1.0)`
  at `QM_Common.mqh:182` and the sizer clamp are byte-identical to before.
- **Only one EA opts in.** `git grep -l QM_PropFirm.mqh -- 'framework/**'` returns only
  the 9936 `.mq5`, its two phase `.set` files, and the compile probe;
  `git grep -lE 'prop_phase|QM_PropInit|QM_PropEntryAllowed|prop_enabled' -- 'framework/EAs/**'`
  returns only 9936. `QM_Common.mqh:4-25` does not include `QM_PropFirm.mqh`. Every EA
  that does not `#include <QM/QM_PropFirm.mqh>` compiles byte-for-byte identically → the
  other 485 EAs are unaffected.
- **9936's own OFF path is behaviourally identical.** With `prop_phase=OFF` and
  `qm_risk_cap_pct=1.0` (the compiled defaults, used by the backtest set):
  `QM_PropPhaseValidateCap(1.0)` returns true (OFF, `:206-207`); `QM_FrameworkSetRiskCapPct(1.0)`
  re-sets cap to 1.0 and emits **no** `RISK_CAP_OVERRIDE` (`:326` guard); `QM_PropInit`
  early-returns at `:399-400`; `QM_PropEntryAllowed` returns true at `:525-526`, so the
  OnTick short-circuit `if(qm_prop_entry_allowed && Strategy_EntrySignal(req))`
  (`:547`) reduces to the original call. Trades and results unchanged; the only delta is
  one extra INFO log line (`PROP_EFFECTIVE_CAP matched:true`) at init.

**Caveat (correctly disclosed, not a code defect):** 9936's parameter surface grew
(new `qm_risk_cap_pct` + prop inputs), so its Q08 8.5-neighborhood and set-file
parameter-identity owe re-confirmation before admission (note §6/§8.6). Trading behaviour
of the existing backtest set is preserved; the gate-evidence surface is not.

---

## FINDING 5 (Check #3) — CONFIRMED: 5.0 ceiling enforced; above-ceiling refused, not clamped

- Sprint phase, cap=6.0: `QM_PropPhaseValidateCap` hits `cap_pct > 5.0`
  (`QM_PropFirm.mqh:212`) → logs `PROP_PHASE_CAP_REJECT` at ERROR → returns false →
  `OnInit` returns `INIT_FAILED` (`QM5_9936_....mq5:463-464`). **Refused, logged, EA
  does not arm.** No clamp anywhere.
- FUNDED, cap=1.5: `:245` `cap_pct > 1.0` → `PROP_PHASE_CAP_REJECT` → false →
  INIT_FAILED. Funded band `(0,1.0]` enforced.
- Framework backstop independent of the validator: even if `prop_phase=OFF` (validator
  abstains, `:206-207`) with `qm_risk_cap_pct=7.0`, `QM_FrameworkSetRiskCapPct(7.0)`
  fails the `cap_pct > 5.0` test at `QM_Common.mqh:319` → returns false → INIT_FAILED.
  The OWNER-ratified 5.0 ceiling (`:319`) is untouched (git diff empty) and is a
  hard refuse, never a clamp-into-acceptance.
- Sprint cap==1.0 default: rejected by the H2 guard (`:223-231`,
  `unit_risk_default_in_sprint_phase`) unless `prop_allow_unit_risk=true` — closes the
  silent-1× arming case.

---

## FINDING 6 (Check #5) — CONFIRMED: set files respect RISK_FIXED (backtest) / RISK_PERCENT (live)

Read from the actual `.set` files (not the note's table):

| set | RISK_FIXED | RISK_PERCENT | qm_risk_cap_pct | prop_phase | environment | risk_mode |
|---|---|---|---|---|---|---|
| `..._H1_backtest.set` | 1000 | 0 | (unset→1.0) | (unset→OFF) | backtest | FIXED |
| `..._H1_ftmo_phase1.set` | 0 | 3 | 3 | 1 | demo | PERCENT |
| `..._H1_ftmo_phase2.set` | 0 | 3 | 3 | 2 | demo | PERCENT |

Backtest = RISK_FIXED only (RISK_PERCENT=0). Demo/challenge phase sets = RISK_PERCENT
only (RISK_FIXED=0), never mixed — Hard Rule honoured. `qm_risk_cap_pct=3` matches
RISK_PERCENT=3 in the phase sets, which is what makes the 3% survive the clamp (Finding 3).
`prop_phase` (1 vs 2) is the only line differing between the two phase sets.

**Informational (not a regression of this change):** all three sets carry
`qm_filter_news_enabled=1` / `qm_filter_news_mode=3`, which are **not EA inputs** (the EA
uses `qm_news_temporal`/`qm_news_compliance`/`qm_news_mode_legacy`); MT5 ignores unknown
keys. This is inherited verbatim from the pre-existing backtest set — present in all 9936
sets, not introduced here — and news remains active via the EA default
`qm_news_temporal=PRE30_POST30`. No action required against this change.

---

## FINDING 7 (Check #6) — CONFIRMED: it compiled, fresh, 0 errors / 0 warnings

- **9936 EA:** `framework/build/compile/20260727_083910/QM5_9936_ff-range-breakout-gmt3-h1.compile.log`
  line 72: `Result: 0 errors, 0 warnings, 5739 ms elapsed`. Line 36 shows
  `QM_PropFirm.mqh` was actually included; lines 37-71 show code generation ran to 100%
  (`code generated`) — a real build, not a header-parse-only pass.
  `D:/QM/reports/compile/QM5_9936_ff-range-breakout-gmt3-h1/result.json`:
  `"verdict":"COMPILED","compile_one_errors":0,"compile_one_warnings":0,"cached":false`,
  `ex5_size_bytes:363842`. The `.ex5` exists on disk at 363842 bytes, mtime 2026-07-27
  10:39, mq5 mtime 10:37 (binary newer than source ⇒ genuine rebuild).
- **Header standalone:** `framework/build/compile/20260727_082443/QM_PropFirm_compile_probe.compile.log`
  line 49: `Result: 0 errors, 0 warnings, 1527 ms elapsed`. The probe
  (`framework/tests/mql5/QM_PropFirm_compile_probe.mq5`) references every exported symbol
  — `QM_PropPhaseValidateCap/Weekend`, `QM_PropTargetPct`, `QM_PropFlattenEnabled`,
  `QM_PropPhaseName`, `QM_PropLogEffectiveCap`, `QM_PropInit`, `QM_PropEntryAllowed`,
  `QM_PropRiskBasis`, `QM_PropRiskScale`, `QM_PropDayKey`, `QM_PropSaveState` — so
  unused-code elision could not hide a signature error. The probe `.ex5` is not committed
  (no `framework/tests/mql5/*.ex5`).
- Count not trusted: both logs read directly; both say 0/0.

---

## Residuals carried (documented in the note; not defects of the sizing logic)

- **RISK_PERCENT equity drift (note L2):** `QM_PropRiskBasis` (`QM_PropFirm.mqh:469-474`)
  is defined but **not wired** into `QM_Entry`, so deployed size follows live equity and
  drifts up as the challenge gains — it does not reproduce the RISK_FIXED backtest.
  `QM_PropInit` emits `prop_anchor_not_wired` (WARN, `:443-446`) so the log does not lie
  about it. Real fidelity gap between measured (FIXED) and deployed (PERCENT); the cap
  correctness (Finding 3) is unaffected.
- **Dormancy telemetry not implemented (note M4/L1):** confirmed absent — no
  `last_open_epoch`, `QM_PropNoteOpen`, or dormancy event in the header; state file is the
  3-field `login;balance;target` (`:352-355`). Out of scope, correctly.
- **Funded weekend guard is partial (note M1):** `QM_PropPhaseValidateWeekend`
  (`:266-308`) accepts friday-close for FUNDED but only WARNs that it does not cover
  >2h daily/holiday breaks or gap windows. Loud, not silently blessed — acceptable, but a
  full >2h-break flattener remains unbuilt.

---

## Bottom line

The sizing mechanism is correct and provably takes effect: the 3% cap flows to the
clamp, an init log proves the effective ceiling, the 5.0 ceiling refuses (not clamps)
above-band values, defaults are unchanged for the 485 non-opting EAs, the set files honour
the FIXED/PERCENT split, and it compiled fresh at 0/0. The previous campaign's 1×-fiction
defect is specifically defended (H2 rejects the silent-1.0 sprint default; the override is
proven to run).

Two items are NOT clean and must be tracked:
1. **(HIGH, mitigated)** As shipped, nothing in code stops a Phase-1 3% cap from arming on
   a Funded/live account — `prop_expected_login` is off in the generated sets, and the
   phase validator trusts the operator-declared phase. The sole barrier is the manual
   T_Live manifest gate. Close it by populating `prop_expected_login` in every prop set at
   deploy and asserting phase-vs-account in the manifest.
2. **(MEDIUM)** The framework header change was committed under a
   "build: pump auto-commit" (a35c08338), not the labeled feature commit; the
   implementation note's git-status provenance claim is false. No runtime impact, but it
   breaks revert/bisect and the evidence-over-claims discipline.

Recommended next step: before 9936 goes anywhere near a demo/live challenge account, run
the note's demo-verification protocol §4(a)-(d) — especially the observable-size check
(d) — and set `prop_expected_login` to the real login. Separately, re-attribute the
QM_PropFirm.mqh change in the history record (or at minimum annotate the provenance).
