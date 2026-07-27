# Prop-firm phase section — implementation note

**Date:** 2026-07-27
**Author:** Claude (board-advisor worktree)
**Scope:** Implements the prop-firm phase selector in the V5 framework, as corrected by
the adversarial review. Framework header + compile probe only. No EA edited. No Factory
OFF/ON. No T_Live touched.

**Design followed:** `docs/ops/evidence/2026-07-27_propfirm_phase_section_design.md`
**as corrected by** `docs/ops/evidence/2026-07-27_propfirm_design_adversarial_review.md`.
Where the two conflict, the **adversarial review wins** (per task instruction) — noted
per finding below.

---

## 1. What changed

Two files, verified via `git status --porcelain`:

- `framework/include/QM/QM_PropFirm.mqh` — the only framework header changed.
- `framework/tests/mql5/QM_PropFirm_compile_probe.mq5` — the sole includer of that
  header; updated to exercise the new symbols so unused-code elision cannot hide a
  signature error.

**No change to** `QM_Common.mqh`, `QM_RiskSizer.mqh`, `QM_NewsFilter.mqh`, or any EA.
Confirmed: `git diff --stat HEAD -- framework/include/QM/QM_Common.mqh
framework/include/QM/QM_RiskSizer.mqh` is empty.

### `QM_PropFirm.mqh` — concrete edits

- **Phase enum** `QM_PropPhase { OFF=0, PHASE_1=1, PHASE_2=2, FUNDED=3 }` and
  `input QM_PropPhase prop_phase = QM_PROP_PHASE_OFF;` **replace** the old
  `input bool prop_enabled = false;`. `OFF` reproduces `prop_enabled=false` exactly.
- **Removed inputs** `prop_target_pct`, `prop_flatten_at_target` → replaced by phase-
  **derived** getters `QM_PropTargetPct()` (P1=10, P2=5, OFF/FUNDED=0) and
  `QM_PropFlattenEnabled()` (true only P1/P2). The target *is* the phase; a set file can
  no longer contradict it.
- **Added inputs** `prop_swing_account` (false), `prop_expected_login` (0=off),
  `prop_allow_unit_risk` (false). Loss-throttle inputs (`prop_daily_halt_pct`,
  `prop_derisk_*`) kept and still default OFF; the phase never turns them on.
- **New validators / logger** (pure, no `QM_Common` dependency, no include cycle):
  `QM_PropPhaseValidateCap`, `QM_PropPhaseValidateWeekend`, `QM_PropLogEffectiveCap`,
  plus `QM_PropPhaseName`.
- **Guards repointed** from `!prop_enabled` to `prop_phase == QM_PROP_PHASE_OFF` in
  `QM_PropInit`, `QM_PropRiskBasis`, `QM_PropRiskScale`, `QM_PropEntryAllowed`.
- **`QM_PropEntryAllowed`** now reads the getters and applies the H4 balance-gated latch.

### Reference OnInit wiring for an adopting EA (not applied to any EA here)

Ordering relative to the unconditional `QM_RiskSizerSetCapPct(1.0)` at
`QM_Common.mqh:182` (which runs *inside* `QM_FrameworkInit`):

```mql5
if(!QM_FrameworkInit(...)) return INIT_FAILED;                 // :182 sets cap=1.0
if(!QM_PropPhaseValidateCap(qm_risk_cap_pct)) return INIT_FAILED;   // phase legality (loud)
if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)) return INIT_FAILED; // ratified override; wins over 1.0
QM_PropLogEffectiveCap(qm_risk_cap_pct, g_qm_risk_per_trade_cap_pct); // proof-of-effect log
if(!QM_PropPhaseValidateWeekend(qm_friday_close_enabled)) return INIT_FAILED;
if(!QM_PropInit(qm_ea_id)) return INIT_FAILED;                 // anchor + H3 account bind
```

The override wins because it is a separate statement *after* `QM_FrameworkInit` returns
(sequential program order) — the ordering the review certified as SURVIVES.

---

## 2. How each confirmed adversarial finding was addressed

### HIGH

**H1 — cap is a ceiling, not a setter; a cap-log check certifies a 1× book.**
Addressed, with an explicit scope statement. `QM_PropLogEffectiveCap(requested, effective)`
emits `PROP_EFFECTIVE_CAP` with the **effective** cap read back from the sizer global
`g_qm_risk_per_trade_cap_pct` (not an echo of the input), and a `matched` boolean —
proving the override took effect *from a log*. But the payload is labelled
`"note":"ceiling_not_position_size"` because the log proves only the ceiling. Proving the
realised **size** is an observable-size check that lives outside the EA (H1's own fix
direction): on the demo, assert `lots × stop-money == N% of anchored balance`, **not**
merely the cap log and absence of `per_trade_cap` clamps. That belongs in the demo-
verification protocol (below), not in framework code, because the size is set by
`RISK_PERCENT`/`RISK_FIXED`, which this section deliberately does not own.

**H2 — omitting `qm_risk_cap_pct` silently ships the 1.0 default = 1×.**
Fixed in `QM_PropPhaseValidateCap`: for `PHASE_1`/`PHASE_2`, `cap_pct == 1.0` (within
1e-9 of the compiled default sentinel) is **REJECTED** (INIT_FAILED + loud
`PROP_PHASE_CAP_REJECT`, reason `unit_risk_default_in_sprint_phase`) unless the operator
sets `prop_allow_unit_risk=true`. A sprint leg that forgets the cap line now fails to
arm instead of trading at 1×.

**H3 — no binding between `prop_phase` and the actual account.**
Fixed (in-EA half) by `input long prop_expected_login`. When non-zero, `QM_PropInit`
refuses to arm (INIT_FAILED + `PROP_PHASE_ACCOUNT_MISMATCH`) if
`AccountInfoInteger(ACCOUNT_LOGIN)` differs. A Phase-1 set file deployed to the Funded
account (different login) fails init rather than trading a 4% cap live. The check lives
inside `QM_PropInit` (which the EA already calls) so it cannot be forgotten as a separate
step. **Residual, documented:** full cross-deploy safety still needs the T_Live-style
manifest/SHA verification (OWNER+Claude) asserting the set file's `prop_phase` matches the
account before AutoTrading — the EA cannot read an FTMO phase from MT5.

**H4 — equity-trip `flatten_at_target` latches below target forever.**
Fixed in `QM_PropEntryAllowed`. The flatten still fires on the **equity** trip
(`eq >= target`) so the excursion is locked the instant it exists. But the **permanent
latch** (`g_qm_prop_target_reached = true` + persist) is now gated on realised
**balance**: after the flatten confirms an empty book, latch only if
`AccountInfoDouble(ACCOUNT_BALANCE) >= target`; otherwise log `prop_target_flatten_shortfall`
(WARN) and **stay armed** (target flag stays false). No flatten storm: once flat, floating
P&L is 0 so `eq == balance < target`, the trip stops firing, and the EA resumes trading
toward the real target. This preserves the design's "lock +10% the instant it exists"
intent while removing the review's "passed-below-target then idle into a dormancy block"
failure.

### MEDIUM

**M1 — Funded weekend guard incomplete (friday-close ≠ any 2h+ break; gap trading).**
Addressed honestly rather than overclaimed (the design forbids a new weekend flattener).
`QM_PropPhaseValidateWeekend` still requires `friday_close_enabled` (or swing) for FUNDED,
but when it passes on friday-close alone it emits `PROP_PHASE_FUNDED_WEEKEND_PARTIAL`
(WARN) stating friday-close does **not** cover >2h daily/holiday index-session breaks or
gap-trading windows, and that multi-day/index holds require intraday-flat or a Swing
account. The guard is loud for the Friday case and now *labelled* for the rest instead of
silently blessing an index Funded sleeve. A full >2h-break flattener is a separate,
larger change (out of this section's scope).

**M2 — the (0, 5.0] band's upper end is self-defeating vs the −5% daily limit.**
Addressed without touching the OWNER-ratified 5.0 ceiling (`QM_Common.mqh:319`): a sprint-
phase cap `> 4.0` emits `PROP_PHASE_CAP_NEAR_DAILY_LIMIT` (WARN) noting a single max-cap
stop-out can consume the whole −5% daily budget. The band stays (0,5.0] because 5.0 is
ratified and the measured optimum (3–4%) is inside it; the framing is now flagged, not
asserted as uniformly safe.

**M3 — `prop_swing_account` is an unverified operator claim disabling the only guard.**
When `prop_swing_account=true` is used to pass the Funded weekend check,
`QM_PropPhaseValidateWeekend` emits `PROP_PHASE_SWING_CLAIMED` (WARN) demanding the real
account type be verified at deploy. Combined with `prop_expected_login` (H3), a swing
claim is now loud and account-bindable rather than silent.

**M4 — dormancy telemetry has no fresh-account init of `last_open_epoch`.**
**Does not apply to this change.** Dormancy telemetry is a separate OWNER recommendation
(`2026-07-27_dormancy_handling_design.md`) and is **not** implemented in this phase-
selector edit; no `last_open_epoch` field, `QM_PropNoteOpen`, or dormancy events were
added (state file stays the 3-field `login;balance;target`). When dormancy telemetry is
implemented, it MUST anchor `last_open_epoch = TimeCurrent()` in `QM_PropInit` on a fresh
account (the M4 fix) to avoid a false-critical storm.

### LOW

**L1 — `QM_PropNoteOpen()` is an unenforced EA hook.** Does not apply — no dormancy hook
was added (see M4). When added, enforce/telemetry-guard the call.

**L2 — `prop_anchor_risk_to_start` logs an anchor that is not wired to the entry path.**
Fixed. The `prop_init` log now emits `"risk_anchor_input"` (the intent) plus
`"risk_anchor_wired":false`, and a separate `prop_anchor_not_wired` (WARN) fires when the
input is true, stating `QM_PropRiskBasis` is not wired into `QM_Entry` and live sizes off
live equity. The log no longer asserts a behaviour that does not run. Wiring the anchor
into the entry path remains a separate, evidence-gated change.

**L3 — removed inputs make legacy set-file keys silent no-ops.** Migration note for
adopters: `prop_target_pct=` / `prop_flatten_at_target=` / `prop_enabled=` lines in an old
`.set` are now silently ignored by MT5 (unknown keys). Intent is preserved — target and
flatten are phase-derived — but an adopter must set `prop_phase` instead of those keys.
No live consumer exists today (blast radius 0), so this only affects future adopters.

### SURVIVES (kept as-is)

Blast radius 0, override-wins ordering, heartbeat ruled out, one-enum-not-booleans,
dormancy-as-selection-constraint, freeze-as-manual-break-glass — all left intact.

---

## 3. Compile result (canonical path)

Driver: `framework/scripts/compile_one.ps1` (the same driver `tools/strategy_farm/
compile_ea.py` wraps; invoked directly because the probe lives under
`framework/tests/mql5/`, outside `framework/EAs/`). MetaEditor is a separate process
from the tester's `terminal64.exe`; no backtest or T_Live process was touched.

```
compile_one.result=PASS
compile_one.reason_class=OK
compile_one.errors=0
compile_one.warnings=0
```

Compile log (`framework/build/compile/20260727_082443/QM_PropFirm_compile_probe.compile.log`):

```
Result: 0 errors, 0 warnings, 1527 ms elapsed, cpu='X64 Regular'
```

- **Errors: 0. Warnings: 0.**
- `compile_one.ps1` deletes the target `.ex5` before building, so this was a **true
  rebuild**, not a cache skip.
- `metaeditor_exit_code=1` is MetaEditor's normal non-zero-on-success return; the driver
  classifies PASS from `errors=0` in the parsed log (standard for this repo).
- The build artifact `QM_PropFirm_compile_probe.ex5` was removed after the build and is
  **not** committed.
- **Side effect of the canonical path (disclosed):** `compile_one.ps1` syncs
  `framework/include` into every terminal's `MQL5\Include` (its normal behaviour on every
  build-lane compile). This pushed the branch's includes — whose only functional change is
  the unused `QM_PropFirm.mqh` — into the factory/roaming terminal include dirs. It does
  **not** touch `C:\QM\mt5\T_Live` (portable, not under `%APPDATA%\MetaQuotes\Terminal`),
  does **not** recompile any factory/live EA (running binaries use their `.ex5`, not
  includes), and is inconsequential because no compiled EA includes `QM_PropFirm.mqh`
  (blast radius 0). The build lane re-syncs its own source on its next compile.

---

## 4. Exact evidence that the cap now takes effect

The mechanism (unchanged, ratified) plus the new proof:

1. `QM_FrameworkInit` sets `QM_RiskSizerSetCapPct(1.0)` unconditionally at
   `QM_Common.mqh:182`.
2. The adopting EA calls `QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)` as a **separate
   statement after** init returns; `QM_Common.mqh:325` calls `QM_RiskSizerSetCapPct(cap_pct)`,
   overwriting the 1.0. Sequential program order guarantees the override wins (review:
   ordering SURVIVES).
3. **New proof log** — `QM_PropLogEffectiveCap(qm_risk_cap_pct, g_qm_risk_per_trade_cap_pct)`
   emits `PROP_EFFECTIVE_CAP {requested_cap_pct, effective_cap_pct, matched, note:
   "ceiling_not_position_size"}`. The `effective` value is **read back from the sizer
   global**, so a mismatch (override didn't take) is visible in the log as `matched:false`
   at ERROR level. This is the "verifiable from a log, not from reading source" the task
   required.
4. **Loud refusal above the ceiling (requirement #3):** for a phase leg, a cap outside the
   band (`>5.0` in P1/P2, `>1.0` in FUNDED, or the H2 unit-risk sentinel) is refused by
   `QM_PropPhaseValidateCap` → `PROP_PHASE_CAP_REJECT` (ERROR) → INIT_FAILED, **before**
   `QM_FrameworkSetRiskCapPct` runs. Refused and logged loudly — never clamped into
   acceptance. The framework's own `QM_Common.mqh:319` (0,5.0] remains the untouched
   downstream backstop (returns false → INIT_FAILED).

**Demo-verification protocol for the first adopting leg (mandatory before any live deploy;
extends the design's protocol with H1's observable-size check):**

- (a) exactly one `PROP_EFFECTIVE_CAP` with `matched:true` and the intended `cap_pct`;
- (b) exactly one `RISK_CAP_OVERRIDE` (from `QM_Common.mqh:326`) when `cap_pct != 1.0`;
- (c) **zero** `RISK_CLAMP` with `kind:"per_trade_cap"` during trading;
- (d) **observable size (H1):** realised per-trade `risk_money` (or lots × stop-money)
  equals `N%` of the anchored balance — proving the book trades at N×, not merely that the
  ceiling is N. (c) alone is necessary but not sufficient; (d) is the check the previous
  campaign lacked.

---

## 5. Default-behaviour-unchanged verification (requirement #4 — verified, not asserted)

1. **No core-chain file touched.** `git diff --stat HEAD` for `QM_Common.mqh` and
   `QM_RiskSizer.mqh` is empty. Only `QM_PropFirm.mqh` changed under `framework/include`.
2. **Zero header includers among EAs.** `git grep -l QM_PropFirm.mqh -- framework/**`
   returns only `framework/tests/mql5/QM_PropFirm_compile_probe.mq5`; `git grep` for
   `prop_phase|prop_enabled|QM_PropInit|QM_PropEntryAllowed` across `framework/EAs/**`
   returns nothing. `QM_Common.mqh:4-25` does not include `QM_PropFirm.mqh`. So every EA
   that does not opt in compiles byte-for-byte identically.
3. **`OFF` traces identical to old `prop_enabled=false`.** `QM_PropInit` early-returns
   `true`; `QM_PropEntryAllowed` returns `true`; `QM_PropRiskBasis` returns the fallback;
   `QM_PropRiskScale` returns 1.0 — exactly the old false-path. The H3 login check sits
   **after** the OFF gate, so OFF never reaches it. Validators/getters are inert under OFF
   even if called (`QM_PropPhaseValidateCap`/`Weekend` return true).

---

## 6. Risks / blockers

- **First adopter must re-confirm survivor purity.** Adding the prop inputs changes an
  adopting EA's parameter surface, so its Q08 8.5-neighborhood and set-file parameter-
  identity must be re-confirmed for that EA (per the clamp analysis). Not triggered here —
  no EA was edited.
- **H3 residual.** The in-EA `prop_expected_login` closes the common wrong-set-file case,
  but a Funded live deploy still needs the T_Live manifest/SHA/phase-vs-account verification
  (OWNER+Claude) as the authoritative cross-deploy gate.
- **Dormancy telemetry not implemented** (M4/L1 out of scope). If/when added, apply the M4
  init-anchoring and enforce the `QM_PropNoteOpen` call.
- **8× legs remain impossible** under the ratified 5.0 ceiling (from the clamp analysis) —
  unchanged by this work; a book that assumed 8× must be re-sized ≤5× or re-derived.

## 7. Recommended next step

Pick the single-account leg (per MEASUREMENT STATE, 9936:USDJPY at 3×) as the first
adopter: add `#include <QM/QM_PropFirm.mqh>` and the §1 OnInit chain, set
`prop_phase=1`, `qm_risk_cap_pct=3`, `prop_expected_login=<demo login>` in its challenge
`.set`, recompile through the build lane, and run the demo-verification protocol §4
(a)-(d) — especially the observable-size check (d) — before any live consideration.

---

## Evidence index

- `framework/include/QM/QM_PropFirm.mqh` (this change) — enum, getters, validators,
  effective-cap log, H2/H3/H4 logic, L2 honest telemetry.
- `framework/tests/mql5/QM_PropFirm_compile_probe.mq5` (this change) — exercises the new
  symbols.
- `framework/build/compile/20260727_082443/QM_PropFirm_compile_probe.compile.log`
  — `Result: 0 errors, 0 warnings`.
- `D:\QM\reports\compile\20260727_082443\summary.csv` — driver summary row (PASS/OK).
- `framework/include/QM/QM_Common.mqh:182` (unconditional 1.0), `:315-330` (ratified
  override, ceiling 5.0), `:326` (RISK_CAP_OVERRIDE) — unmodified.
- `framework/include/QM/QM_RiskSizer.mqh:68-71,84-89,91-117` (cap = ceiling clamp) —
  unmodified.
- Design + adversarial review: `docs/ops/evidence/2026-07-27_propfirm_phase_section_design.md`,
  `docs/ops/evidence/2026-07-27_propfirm_design_adversarial_review.md`.
- Clamp analysis: `docs/ops/evidence/2026-07-27_risk_cap_clamp_analysis.md`.
- FTMO rules: `docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`.
