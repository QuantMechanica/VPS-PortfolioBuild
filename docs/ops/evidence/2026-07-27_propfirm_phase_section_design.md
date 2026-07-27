# Prop-firm phase section — framework design

**Date:** 2026-07-27
**Author:** Claude
**Scope:** DESIGN ONLY. No EA/framework source edited by this document. No Factory OFF/ON.
**Trigger:** OWNER (2026-07-27) — the V5 framework should gain a prop-firm phase selector
(Phase 1 / Phase 2 / Funded) so the operator picks the phase and the EA's risk and
behaviour change accordingly. One account at a time; improve the book, keep the 60/30 KPI.

This design is decisive: one shape, not a menu. It reuses the machinery already in
`framework/include/QM/QM_PropFirm.mqh` (added 2026-07-26) and the OWNER-ratified risk-cap
override; it adds no parallel risk engine, no second target checker, and no news code.

---

## 0. What already exists (read before proposing — verified file:line)

- `QM_PropFirm.mqh` is a **standalone header, opt-in per EA**. It is **not** in the core
  include chain — `QM_Common.mqh:4-25` does not `#include` it — and the tree contains
  exactly **one** includer, the compile probe
  (`framework/tests/mql5/QM_PropFirm_compile_probe.mq5:8`). No EA under `framework/EAs`
  includes it or calls `QM_PropInit`/`QM_PropEntryAllowed` (grep, 2026-07-27). This is the
  property that makes "default behaviour unchanged" free (§6).
- Existing prop inputs (`QM_PropFirm.mqh:61-70`): `prop_enabled` (bool, false master
  switch), `prop_venue` (telemetry only), `prop_start_balance`, `prop_target_pct` (10.0),
  `prop_flatten_at_target` (true, the **measured +28.8pp** lever — header :24-27),
  `prop_daily_halt_pct` (0=off), `prop_derisk_at_loss_pct` (0=off), `prop_derisk_scale`,
  `prop_anchor_risk_to_start` (true).
- Loss-side throttles default **OFF by measurement, not omission**: the preservation
  governor took the campaign 86.3%→65.2% (`QM_PropFirm.mqh:29-43`). Turning them on
  "should carry its own evidence." The phase selector must **not** switch them on.
- Target flatten path: `QM_PropEntryAllowed` (`QM_PropFirm.mqh:252-317`) reads
  `prop_flatten_at_target` (:271) and `prop_target_pct` (:269), flattens, confirms the
  book empty, then persists `target_reached` (:271-296). Live target uses `ACCOUNT_EQUITY`
  (floating included) — a deliberate, documented divergence from the closed-P&L study
  (:45-59). Keep it.
- Risk cap, the ratified path (`docs/ops/evidence/2026-07-27_risk_cap_clamp_analysis.md`):
  - `QM_Common.mqh:179` sets a 1%-of-equity money rail; `:182 QM_RiskSizerSetCapPct(1.0)`
    is **unconditional** — every EA starts at a 1% per-trade cap.
  - `QM_RiskSizer.mqh:91-117` clamps weighted risk to that cap
    (`QM_RiskSizerPercentCap` :84-89 for PERCENT, money rail for FIXED).
  - `QM_Common.mqh:315-330 QM_FrameworkSetRiskCapPct(cap_pct)` is the OWNER-ratified
    override: must run **after** `QM_FrameworkInit` (:317), bounded **(0, 5.0]** (:319,
    hard ceiling tied to the FTMO daily-loss limit — not to be raised), logs
    `RISK_CAP_OVERRIDE` when `cap_pct != 1.0` (:326-328).
  - The proven call pattern (Round25 EAs, e.g. `QM5_10163_tv-rsi-macd-long.mq5:45-49, :258`):
    `input double qm_risk_cap_pct = 1.0;` then, immediately after `QM_FrameworkInit`,
    `if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)) return INIT_FAILED;`.
- Weekend/Friday flatten already exists: `QM_FrameworkFridayCloseNow`
  (`QM_Common.mqh:384-398`) + `QM_FrameworkHandleFridayClose` (:673-692), gated by
  `g_qm_fw_friday_close_enabled`, itself set from `QM_FrameworkInit`'s `friday_close_enabled`
  and validated against the Card by `QM_FrameworkDeclareExecutionContract` (:247-308). The
  phase selector must **reuse** this, not add a second flattener.
- News is a separate 2-axis system (`QM_NewsFilter.mqh`) with a real
  `QM_NEWS_COMPLIANCE_FTMO` profile (:40, window logic :913-960). The mandatory news
  blackout is a **company hard rule, binding in every phase** (FTMO rules doc :86). The
  phase selector must **not** own or relax it.

---

## The design in one sentence

Replace the free `prop_enabled` boolean with a single `prop_phase` enum whose default
(`OFF`) leaves the framework byte-identical; the enum is the **sole authority** for every
phase-dependent value (target %, flatten-at-target, weekend requirement) and a
**fail-closed guardrail** on the one number that must stay operator-supplied — the
per-trade risk cap, which continues to flow through the existing `qm_risk_cap_pct` input
and `QM_FrameworkSetRiskCapPct`, never a second knob.

---

## 1. What the phase selector changes

The enum has one value: `prop_phase ∈ {OFF, PHASE_1, PHASE_2, FUNDED}`. Everything below
is derived from it or validated against it. "Derived" = the phase is the only source, no
competing input exists. "Validated" = the value lives in another input and the phase
rejects an illegal combination at OnInit (loud), never silently rewrites it.

| Item | Input / mechanism | Type | Default (OFF) | PHASE_1 (Challenge) | PHASE_2 (Verification) | FUNDED | Source of the value |
|---|---|---|---|---|---|---|---|
| Phase | `prop_phase` | enum | `OFF` | `PHASE_1` | `PHASE_2` | `FUNDED` | operator (set file) |
| Profit target % | `QM_PropTargetPct()` (derived) | double | 0 (n/a) | **10.0** | **5.0** | **0 (none)** | FTMO rules doc: P1 +10%, P2 +5%, Funded no target (:11, :27, :63) |
| Flatten at target | `QM_PropFlattenEnabled()` (derived) | bool | false | **true** | **true** | **false** | +28.8pp measured (`QM_PropFirm.mqh:24-27`); Funded has no target to flatten at |
| Per-trade risk cap % | `qm_risk_cap_pct` → `QM_FrameworkSetRiskCapPct` (**validated**) | double | 1.0 (unchanged) | legal band **(0, 5.0]** | legal band **(0, 5.0]** | legal band **(0, 1.0]** | operator; band enforced by phase (§2, §3). Optimum 3–4% P1, 1% Funded (MEASUREMENT STATE) |
| Daily-loss guard | `prop_daily_halt_pct` | double | 0 (off) | **0 (off)** | **0 (off)** | **0 (off)** | measured harmful in every phase (`QM_PropFirm.mqh:29-43`); phase never turns it on |
| De-risk throttle | `prop_derisk_at_loss_pct` / `_scale` | double | 0 (off) | **0 (off)** | **0 (off)** | **0 (off)** | same measurement; evidence-gated opt-in only |
| Total-loss guard | *(none — deliberately absent)* | — | — | — | — | — | FTMO's −10% is an external breach; a self-halt before it is the "give up at −6%" that cost 21pp (`QM_PropFirm.mqh:31-38`). Respected by sizing (the cap), not a halt |
| Weekend / 2h-break flatten | reuse `friday_close` contract; phase **validates** | — | not touched | **not required** (phase asserts nothing) | **not required** | **required**: friday-close contract enabled **or** `prop_swing_account=true`, else INIT_FAILED | FTMO rules doc :84, :86 — weekend closure does **not** apply in Challenge/Verification; a Standard **Funded** account must close before weekend / any 2h+ break; Swing is exempt |
| Risk basis (live vs backtest bridge) | `prop_anchor_risk_to_start` | bool | true | true | true | true | phase-independent; sizing-mode bridge, §4 |
| News blackout | `news_compliance` axis (separate) | — | not touched | not touched | not touched | not touched | company hard rule, binding all phases; **not** in this section (§5) |

Justification notes tied to the verified FTMO rules (`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`):

- **Target 10 / 5 / none** is the single hard published difference between the phases
  (:11 target 5% Verification; brief: 10% Challenge; :63 Funded has no profit target). It
  must be phase-derived because getting it wrong (e.g. flattening a Funded account at a
  phantom +10%) silently caps a live account's upside.
- **Flatten-at-target true for P1/P2, false for Funded** falls straight out of "has a
  target / has none." For P1/P2 it is the campaign's biggest measured lever.
- **Cap band (0,5.0] sprint vs (0,1.0] Funded** encodes the measured optimum (3–4% P1, 1%
  Funded) as a *legal range*, not a fixed number, because the optimum differs per sleeve
  (MEASUREMENT STATE swept 3–4×). The phase constrains; the set file chooses.
- **Weekend required only for Funded** is the exact FTMO asymmetry (:84): no weekend rule
  in Challenge/Verification, mandatory closure on a Standard Funded account. This is *why*
  multi-day sleeves are admissible for the challenge but hostile to a Standard Funded
  deploy — the phase makes that incompatibility loud instead of a silent live breach.
- **Loss throttles off everywhere** and **no total-loss guard** are not timidity; they are
  the two measured findings in the `QM_PropFirm.mqh` header. The phase inherits them.

---

## 2. How the phase drives the risk cap (exact call site and ordering)

The cap value is **not** phase-fixed. It stays in the existing `qm_risk_cap_pct` set-file
input (single source of the number). The phase supplies a **legal band** and a
**fail-closed check**. One number, one call, one log line — no silent second knob.

New helper in `QM_PropFirm.mqh` (pure, no `QM_Common` dependency, so no include cycle):

```
// Returns true iff cap_pct is legal for the selected phase. Logs a loud
// PROP_PHASE_CAP_REJECT on false. OFF imposes no constraint (framework's own
// (0,5.0] bound still applies downstream).
bool QM_PropPhaseValidateCap(const double cap_pct)
  {
   switch(prop_phase)
     {
      case QM_PROP_PHASE_OFF:    return true;
      case QM_PROP_PHASE_1:
      case QM_PROP_PHASE_2:      return (cap_pct > 0.0 && cap_pct <= 5.0);
      case QM_PROP_PHASE_FUNDED: return (cap_pct > 0.0 && cap_pct <= 1.0);
     }
   return false; // unknown enum → fail closed
  }
```

**Call site — the EA's `OnInit`, unchanged in shape from the Round25 pattern**
(model: `QM5_10163_tv-rsi-macd-long.mq5:240-262`). Ordering relative to the unconditional
`QM_RiskSizerSetCapPct(1.0)` at `QM_Common.mqh:182`:

```
// 1. QM_FrameworkInit runs FIRST. Internally, QM_Common.mqh:182 sets the cap to 1.0.
if(!QM_FrameworkInit(qm_ea_id, ..., qm_news_compliance)) return INIT_FAILED;

// 2. Phase legality BEFORE we touch the cap, so the error names the phase.
if(!QM_PropPhaseValidateCap(qm_risk_cap_pct)) return INIT_FAILED;   // loud

// 3. The ONE ratified override. Runs strictly AFTER :182 (separate post-init call),
//    so it OVERWRITES the 1.0 with the validated cap. Logs RISK_CAP_OVERRIDE (!=1.0),
//    and fails closed on >5.0 at QM_Common.mqh:319.
if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)) return INIT_FAILED;

// 4. Weekend legality for the phase (Funded only), reusing the existing contract.
if(!QM_PropPhaseValidateWeekend(qm_friday_close_enabled)) return INIT_FAILED;

// 5. Anchor start balance / per-account state.
if(!QM_PropInit(qm_ea_id)) return INIT_FAILED;
```

Ordering guarantee: `:182` executes *inside* `QM_FrameworkInit`; steps 2–3 are separate
statements *after* it returns. Sequential program order makes the override always win over
the 1.0 default. This is exactly the Round25 chain, with the phase check inserted at
step 2.

**How the set file supplies the value:** two lines, both real inputs, both logged.

```
prop_phase=1
qm_risk_cap_pct=4
```

No fiction is possible: `qm_risk_cap_pct` reaches `QM_FrameworkSetRiskCapPct`, which emits
`RISK_CAP_OVERRIDE {cap_pct:4.0,...}` (`QM_Common.mqh:326-328`) and returns false
(→ INIT_FAILED) on >5.0; `prop_phase` reaches `QM_PropInit`, which logs `prop_init` with
the phase. The previous campaign's 4/8× manifest was fiction because the set files carried
`RISK_PERCENT=4/8` but **never** set `qm_risk_cap_pct`, and three of four EAs could not
read it, so the 1.0 cap at `:182` silently clamped everything to 1×
(`2026-07-27_risk_cap_clamp_analysis.md:103-125`). This design closes that hole: the cap
is a required, logged, fail-closed input on every prop leg.

**Anti-fiction verification protocol (run on the demo before any live deploy):** in the
demo log assert (a) exactly one `RISK_CAP_OVERRIDE` at init with the intended `cap_pct`,
and (b) **zero** `RISK_CLAMP` with `kind="per_trade_cap"` during trading. A single
`per_trade_cap` clamp means the leg is sizing below intent — the same signature that
exposed the 1× bug (`2026-07-27_risk_cap_clamp_analysis.md:129-160`).

---

## 3. One enum, not booleans — and why the Funded mistake is impossible/loud

**One enum.** Reasons, decisive:

1. **Mutual exclusion is structural.** An account is in exactly one phase. An enum can hold
   exactly one value; three booleans admit `2^3` states, most of them nonsense
   (`is_phase1 && is_funded`, or all-false). Representing a single-choice fact as
   independent toggles manufactures illegal states you then have to hand-check.
2. **The "Phase 1 cap on a Funded account" mistake becomes loud, at OnInit, by
   construction.** With `prop_phase=FUNDED` and `qm_risk_cap_pct=4`,
   `QM_PropPhaseValidateCap` returns false → `INIT_FAILED` + `PROP_PHASE_CAP_REJECT`
   log naming the phase and the illegal cap. The account never arms. It is not clamped
   silently and it is not left to a human to notice — the EA refuses to initialise. With
   booleans the same check would be a matrix of cross-conditions, easy to get wrong.
3. **Smaller parameter surface = less set-file drift.** One enum line instead of three
   booleans keeps Q08 parameter-identity and survivor-purity checks simple.
4. **Default OFF makes the whole feature inert** (§6). A boolean `prop_enabled=false` did
   the same, but the enum folds that master switch into the same single input, removing the
   contradictory "enabled but no phase chosen" / "phase set but disabled" states entirely.

**Collapse `prop_enabled` into `prop_phase`.** `OFF` (=0, default) replaces
`prop_enabled=false`; `PHASE_1/2/FUNDED` replace `prop_enabled=true`. Every current
`if(!prop_enabled)` guard (`QM_PropFirm.mqh:152, 200, 207, 254`) becomes
`if(prop_phase == QM_PROP_PHASE_OFF)`. This is a mechanical, semantics-preserving refactor
of an unwired header (§6 shows the blast radius is zero live EAs).

The enum:

```
enum QM_PropPhase
  {
   QM_PROP_PHASE_OFF    = 0, // default; framework unchanged (was prop_enabled=false)
   QM_PROP_PHASE_1      = 1, // Challenge:     target +10%, flatten on, cap <= 5%
   QM_PROP_PHASE_2      = 2, // Verification:  target  +5%, flatten on, cap <= 5%
   QM_PROP_PHASE_FUNDED = 3  // FTMO Account:  no target, no flatten, cap <= 1%, weekend req.
  };
input QM_PropPhase prop_phase = QM_PROP_PHASE_OFF;
```

Additional guardrails that make phase mistakes impossible or loud:

- **Funded cap** — handled above: `>1.0` → INIT_FAILED.
- **Funded weekend** — `QM_PropPhaseValidateWeekend(bool friday_close_enabled)` returns
  false unless `friday_close_enabled` (the EA's Card-driven friday-close contract) is true
  **or** `prop_swing_account=true`. A weekend-holding sleeve deployed to a Standard Funded
  account fails at init instead of breaching FTMO's weekend rule live. Reuses the existing
  contract; adds no flattening code.
- **Unknown enum value** → `default`/`return false` fail-closed in both validators.

`prop_target_pct` and `prop_flatten_at_target` stop being operator inputs and become
derived getters (`QM_PropTargetPct()`, `QM_PropFlattenEnabled()`). This removes the classic
two-inputs-one-truth trap the brief warns about: there is no way to set `prop_phase=FUNDED`
and also `prop_target_pct=10` and have one of them silently lose — the target *is* the
phase. (FTMO-specific numbers 10/5/0 are baked because every current book is FTMO and
`prop_venue` is telemetry-only; a future venue with different targets is a table keyed on
`prop_venue`, explicitly out of scope here — §5.)

---

## 4. Backtest (RISK_FIXED) vs live (RISK_PERCENT) — no rule broken

The hard rule — RISK_FIXED for backtest, RISK_PERCENT for live, never both — is enforced
by `QM_FrameworkValidateRiskInputs` (`QM_Common.mqh:101-114`, exactly one of the two > 0).
**The phase section never touches `RISK_FIXED`/`RISK_PERCENT`.** It touches only the *cap*,
which is mode-agnostic by construction:

- The cap set by `QM_FrameworkSetRiskCapPct(cap)` is applied in **both** modes:
  PERCENT sizing clamps to `equity·cap/100` (`QM_RiskSizer.mqh:84-89, 108-110`); FIXED
  sizing clamps to the money rail `equity·cap/100` set at `QM_Common.mqh:323`. So one
  `qm_risk_cap_pct` governs both a RISK_FIXED backtest and a RISK_PERCENT live run.
- **Backtest that qualifies a Phase 1 sleeve at N×:** set file carries `RISK_FIXED` sized
  to N% of the fixed initial deposit, `RISK_PERCENT=0`, and `qm_risk_cap_pct=N` so the
  fixed amount is not clamped (`2026-07-27_risk_cap_clamp_analysis.md:70-90`). `prop_phase`
  may be set for the target/flatten behaviour, but the *money* is RISK_FIXED — HR4 intact.
- **Live deploy of that sleeve:** set file carries `RISK_PERCENT` (≤ cap), `RISK_FIXED=0`,
  the same `qm_risk_cap_pct=N`, `prop_phase` for real, and `prop_anchor_risk_to_start=true`
  so live sizes off the frozen start balance and reproduces the fixed-size backtest rather
  than compounding as equity drifts (`QM_PropFirm.mqh:194-203`). HR (RISK_PERCENT live)
  intact.

So the phase section is orthogonal to the mode: it sets a ceiling both modes already
respect, and the split is still expressed only through which of RISK_FIXED / RISK_PERCENT
the set file populates. The phase adds a *lower* effective ceiling for Funded (1%) — that
only ever tightens, never relaxes, either mode.

**Named risk / companion wiring (not this section's job, but a blocker for the anchor to be
real):** `prop_anchor_risk_to_start` is only honoured if the sizing call is fed
`QM_PropRiskBasis(...)`. Today `QM_Entry` sizes via `QM_RiskSizerRiskMoney(equity)` with
live equity (`2026-07-27_risk_cap_clamp_analysis.md:65-68`); `QM_PropRiskBasis`/
`QM_PropRiskScale` are **not** wired into that path. Until they are, the anchor is itself a
silent input for live compounding. Flagging it here so it is not mistaken for solved; it is
a separate entry-path change, evidence-gated, outside the phase-selector edit.

---

## 5. What must NOT be in this section, and why

- **No news inputs.** The mandatory blackout is a company hard rule binding in every phase
  (FTMO rules doc :86) and already lives on the `news_compliance` axis with a real
  `QM_NEWS_COMPLIANCE_FTMO` profile. Putting news under `prop_phase` would (a) duplicate the
  2-axis machinery and (b) create a path to a phase that *relaxes* a hard rule. News stays
  where it is; the phase does not read or write it.
- **No total-loss / daily-loss self-halt driven by the phase.** Measured to cost 21pp of
  pass probability (`QM_PropFirm.mqh:29-43`). The −10%/−5% FTMO limits are respected by
  *sizing* (the cap) and by not over-leveraging, not by an EA halt. `prop_daily_halt_pct`
  and `prop_derisk_*` remain independent, evidence-gated opt-ins the phase never flips on.
- **No second risk knob.** The cap is `qm_risk_cap_pct` only. The phase must not introduce
  `prop_risk_pct` or similar — that is precisely the silent-input trap (two knobs, one
  wins). The phase validates the existing knob's band; it does not carry its own number.
- **No new weekend flattener.** Reuse `friday_close`. The phase validates that the Funded
  weekend requirement is met; it does not add a parallel close loop.
- **No raising or bypassing the 5.0 ceiling.** `QM_FrameworkSetRiskCapPct` stays the sole
  gate; Funded further tightens to 1.0. `QM_Common.mqh:319` is untouched.
- **No RISK_FIXED/RISK_PERCENT selection.** That stays the set file's job under HR4/HR-live.
- **No per-venue target table (yet).** FTMO-only 10/5/0 is deliberate; multi-venue is a
  future `prop_venue`-keyed extension, explicitly deferred so this section stays small.
- **No AutoTrading / T_Live control.** Live enable is OWNER+Claude only; not an EA input.

---

## 6. Files, functions, blast radius, and the default-unchanged guarantee

### Files and functions touched

1. **`framework/include/QM/QM_PropFirm.mqh`** (the only framework header changed):
   - Add `enum QM_PropPhase` after the includes (~:8).
   - Replace `input bool prop_enabled = false;` (:62) with
     `input QM_PropPhase prop_phase = QM_PROP_PHASE_OFF;`.
   - Remove `input double prop_target_pct = 10.0;` (:65) and
     `input bool prop_flatten_at_target = true;` (:66); add derived getters
     `double QM_PropTargetPct()` and `bool QM_PropFlattenEnabled()`.
   - Add `input bool prop_swing_account = false;` (Funded weekend exemption).
   - Add `bool QM_PropPhaseValidateCap(const double cap_pct)` and
     `bool QM_PropPhaseValidateWeekend(const bool friday_close_enabled)`.
   - Repoint the four `if(!prop_enabled)` guards (:152, :200, :207, :254) to
     `prop_phase == QM_PROP_PHASE_OFF`; repoint `QM_PropEntryAllowed` (:269, :271) to the
     getters; update the `prop_init` log (:180-190) to emit `prop_phase` and the derived
     target/flatten.
2. **`framework/tests/mql5/QM_PropFirm_compile_probe.mq5`**: set `prop_phase` and exercise
   the two new validators + two getters so elision can't hide a signature error (mirror of
   its existing :10-31 shape).
3. **Per prop-adopting EA only** (opt-in, not fleet-wide): add
   `#include <QM/QM_PropFirm.mqh>` and the five-step OnInit chain of §2. Reference wiring
   shown against `QM5_10163_...mq5:240-262`; **not** applied to any EA by this design.

No change to `QM_Common.mqh` (`:179-182`, `:315-330` unchanged), `QM_RiskSizer.mqh`, or
`QM_NewsFilter.mqh`.

### Blast radius

- **Existing EAs that recompile differently: 0.** `QM_PropFirm.mqh` is included only by
  `QM_PropFirm_compile_probe.mq5` (grep 2026-07-27) and is not in `QM_Common.mqh`'s include
  list (:4-25). Editing it recompiles the **probe** and nothing else in `framework/EAs`.
- The 12 Round25 EAs that call `QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)` are untouched:
  their input keeps default 1.0, the override keeps logging/behaving as today. No prop code
  runs in them because they do not include the header.
- First real consumer is whichever campaign leg opts in (adds the include + OnInit chain +
  set-file lines). That is a deliberate, per-EA, evidence-gated adoption — and it must
  re-confirm Q08 8.5-neighborhood + set-file parameter identity for the edited EA
  (survivor purity), because adding inputs changes the parameter surface
  (`2026-07-27_risk_cap_clamp_analysis.md:186-187`).

### Default-behaviour-unchanged guarantee (four independent locks)

1. **Not in the core chain.** An EA that does not `#include <QM/QM_PropFirm.mqh>` cannot see
   any of this; its compilation is byte-for-byte identical.
2. **Opt-in by call, not by include.** Even an EA that includes the header gets nothing
   until it calls `QM_PropInit`/`QM_PropEntryAllowed`/the validators.
3. **`OFF` is the default and is inert.** With `prop_phase == QM_PROP_PHASE_OFF`,
   `QM_PropPhaseValidateCap` returns true (no constraint), `QM_PropInit` early-returns
   (:152), `QM_PropEntryAllowed` returns true (:254), `QM_PropRiskBasis`/`Scale` return
   the fallback/1.0 (:200, :207) — exactly the old `prop_enabled=false` behaviour.
4. **The cap default is still 1.0.** No EA's cap changes unless its set file sets both
   `prop_phase` and `qm_risk_cap_pct`; `QM_Common.mqh:182`'s unconditional 1.0 remains the
   floor of behaviour for everyone else.

The refactor of `prop_enabled → prop_phase` is safe precisely because there is **no live
consumer** to break: the header is one week old, wired into nothing, and covered by a
compile probe that is updated in the same change.

---

## Evidence index

- `framework/include/QM/QM_PropFirm.mqh:24-59` (flatten +28.8pp; loss-throttle OFF measured; live equity target semantic), `:61-70` (current inputs), `:147-317` (init / entry / basis / scale), `:152,200,207,254,269,271` (prop_enabled guards + target/flatten reads)
- `framework/include/QM/QM_Common.mqh:101-114` (risk-mode XOR), `:179-182` (unconditional 1% cap), `:315-330` (override, ceiling 5.0), `:384-398, 673-692` (friday-close machinery), `:247-308` (execution contract validating friday-close)
- `framework/include/QM/QM_RiskSizer.mqh:68-71, 84-89, 91-117` (cap set + clamp math)
- `framework/include/QM/QM_NewsFilter.mqh:36-41, 913-960` (FTMO news compliance profile)
- `framework/EAs/QM5_10163_tv-rsi-macd-long/QM5_10163_tv-rsi-macd-long.mq5:45-49, 240-262` (ratified qm_risk_cap_pct + override call pattern)
- `framework/tests/mql5/QM_PropFirm_compile_probe.mq5:8` (sole includer of the header)
- `docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md:11,27,63,84,86` (targets 10/5/none; weekend rule per phase; binding news blackout)
- `docs/ops/evidence/2026-07-27_risk_cap_clamp_analysis.md:29-160,166-209` (clamp chain, 1× fiction, anti-fiction verification, ratified pattern)
- MEASUREMENT STATE (`tools/strategy_farm/portfolio/challenge_book_60d.py`, commit 50cf7f5a4): 3–4% P1 optimum, 1% Funded
