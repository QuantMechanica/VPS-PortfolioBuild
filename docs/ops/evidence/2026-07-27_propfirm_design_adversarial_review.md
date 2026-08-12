# Prop-firm design — adversarial review

**Date:** 2026-07-27
**Author:** Claude (board-advisor worktree; adversary role)
**Scope:** Refute, don't approve. Targets:
- `docs/ops/evidence/2026-07-27_propfirm_phase_section_design.md` (phase selector)
- `docs/ops/evidence/2026-07-27_dormancy_handling_design.md` (dormancy)

Every finding below is verified against source, not against the design prose. Where a
claim survived the attack it is stated as SURVIVES with the reason.

---

## Verdict

The two designs are directionally right — the phase enum, the "flatten stays on for
P1/P2", the "dormancy is a selection constraint + telemetry", and the "no heartbeat
trade" calls all hold. But **the central promise of the phase design — that it closes
the silent-1× hole that sank the last campaign — is false as written.** The cap is a
ceiling, not a setter; the design's own set-file example and anti-fiction protocol
certify a 1× book as fully sized. That is the same failure class, re-created. Two more
HIGH findings (no phase↔account binding; equity-trip flatten latching below target) and
several MEDIUM/LOW follow.

Count: 4 HIGH, 4 MEDIUM, 3 LOW, plus explicit SURVIVES.

---

## HIGH

### H1 — Raising `qm_risk_cap_pct` does not raise position size. The anti-fiction protocol certifies a 1× book as sized. (hunt #1)

**Claim attacked** (phase design §2:165-185): the set file supplies size via
`prop_phase=1` + `qm_risk_cap_pct=4`, and "No fiction is possible: `qm_risk_cap_pct`
reaches `QM_FrameworkSetRiskCapPct`, which emits `RISK_CAP_OVERRIDE`… This design closes
that hole: the cap is a required, logged, fail-closed input on every prop leg."

**What breaks it:** the cap is a **ceiling**, never a setter. Position size is set by
`RISK_PERCENT` (live) or `RISK_FIXED` (backtest); the cap only clamps the minimum of the
two. `QM_RiskSizer.mqh:97-115`: `base = equity*RISK_PERCENT/100`; clamp fires *only if*
`weighted > cap_global`. `QM_Common.mqh:323-325`: the override sets `cap_pct`, nothing
else.

Concrete failure: a PHASE_1 live leg with `qm_risk_cap_pct=4` but `RISK_PERCENT=1`
(the backtest twin's value, or the EA's default, left in the set file):
- `base = 1% · eq`, `cap = 4% · eq`; `1% > 4%` is false → **no clamp**, size = **1%**.
- Init still logs `RISK_CAP_OVERRIDE{cap_pct:4.0}` because `4.0 != 1.0`
  (`QM_Common.mqh:326`).
- During trading, **zero** `per_trade_cap` `RISK_CLAMP` (base never exceeds the ceiling).

So the design's anti-fiction protocol (§2: assert (a) exactly one `RISK_CAP_OVERRIDE`
with the intended `cap_pct`, and (b) zero `per_trade_cap` clamps) **passes in full while
the account trades at 1×.** The protocol is necessary but not sufficient: it proves the
*ceiling* is 4, never that the *size* is 4. The §2 headline set-file example omits
`RISK_PERCENT` entirely, so an operator following §2 literally deploys the silent-1× book
the whole exercise was meant to kill. §4 does mention "RISK_PERCENT (≤ cap)" in prose, but
the verification protocol never checks it.

**Fix direction (not part of this review's remit, stated for the author):** the
demo-verification protocol must additionally assert the realised per-trade risk (lots ×
stop-money, or the sized `risk_money`) equals N% of anchored balance — an
observable-size check, not a cap-log check.

**Severity: HIGH.** Recreates the exact silent-1× class
(`2026-07-27_risk_cap_clamp_analysis.md:14-25`) with a protocol that green-lights it.

---

### H2 — `qm_risk_cap_pct` is NOT required or fail-closed. Omitting the line ships 1× silently. (hunt #1)

**Claim attacked** (phase design §2:178-179): "the cap is a required, logged,
fail-closed input on every prop leg."

**What breaks it:** the input's compiled default is `1.0`
(`QM5_10163_tv-rsi-macd-long.mq5:49`; confirmed for 10848 in
`2026-07-27_risk_cap_clamp_analysis.md:120-122`). A set file that omits the line uses
`1.0`. In PHASE_1, `QM_PropPhaseValidateCap(1.0)` returns true (`1.0 ∈ (0,5.0]`), the
override runs with 1.0, and `QM_Common.mqh:326` suppresses `RISK_CAP_OVERRIDE` because
`|1.0-1.0| < 1e-9`. Result: **no INIT_FAILED, no override log, book at 1×.** Nothing is
"required" and nothing is "fail-closed" about a value whose default silently means 1×.

The design's validator only rejects *illegal* caps (Funded > 1.0, unknown enum). It never
rejects the *absence of intent*. To actually be fail-closed for a sprint phase, PHASE_1/2
would have to reject `cap_pct == 1.0` (the default sentinel) unless an explicit
"deliberately-1×" flag is set — which the design does not have.

**Severity: HIGH.** Same silent-1× class as the previous campaign, at the init boundary.

---

### H3 — No binding between `prop_phase` and the actual account. A PHASE_1 set file on a live Funded account runs at 4% — not impossible, not loud. (hunt #5)

**Claim attacked** (phase design §3:197-202): "The 'Phase 1 cap on a Funded account'
mistake becomes loud, at OnInit, by construction… The account never arms."

**What breaks it:** the claim is conditioned on `prop_phase == FUNDED`.
`QM_PropPhaseValidateCap` keys on the *self-declared enum*, with **no** cross-check
against the account the EA is attached to (grep: nothing in the design or
`QM_PropFirm.mqh` reads `ACCOUNT_LOGIN`/account type to validate the phase; the only
`ACCOUNT_LOGIN` use is the state-file namespace `QM_PropFirm.mqh:129-137`, which does not
touch phase or cap). The realistic operational failure is not "operator sets FUNDED and
also cap=4" — it is **"operator deploys the Phase-1 set file (`prop_phase=1`,
`qm_risk_cap_pct=4`) to the live Funded account."** Then `prop_phase=PHASE_1` →
validator passes cap=4 → the EA arms at 4% per trade on a real funded account whose
limits are −5% daily / −10% total. Neither impossible nor loud.

This is precisely the class the prompt warns about (a manifest/config saying one thing,
the deployed reality another). The enum closes the *within-config* mistake and leaves the
*across-deploy* mistake wide open. The §2 anti-fiction protocol checks `cap == intent`,
never `phase == account`.

**Fix direction:** a Funded deploy needs a T_Live-style verification step (like the SHA256
/ magic-registry checks) that asserts the set file's `prop_phase` matches the account the
binary is actually attached to, before AutoTrading is flipped.

**Severity: HIGH.** A Phase-1 cap can reach a Funded/live account through the ordinary
wrong-set-file mistake the design claims to prevent.

---

### H4 — `flatten_at_target` latches permanently on an equity (floating) trip, with no balance re-check. It can halt a challenge below target forever. (hunt #3 / correctness)

**Claim attacked** (phase design §0:32-36, §1:83, "Keep it"): flatten-at-target is the
+28.8pp lever, is made **mandatory and non-disableable** for P1/P2 (derived getter, no
longer an operator input), and the live equity-trip semantic is endorsed ("Keep it").

**What breaks it:** FTMO passes when **BALANCE** exceeds target with **all positions
closed** (FTMO rules doc; prompt context). The EA trips on **ACCOUNT_EQUITY** (floating
included), flattens, and — the moment the book is confirmed empty — latches
`g_qm_prop_target_reached = true` and persists it (`QM_PropFirm.mqh:271-287`), with **no
check that realised balance actually reached target** and **no re-arm**
(`QM_PropFirm.mqh:265` returns false forever; the flag is reloaded on restart at
`:143`).

Concrete failure: balance +8%, an open position floats +2% → equity +10% → trip →
flatten. If the position gives back part of the excursion during the close (entirely
plausible on the fast move that spikes equity), balance realises at, say, +9.6% < +10%.
`target_reached` latches true, the EA never opens another position, the account sits idle
→ and now runs straight into the dormancy block (H/§dormancy). The challenge is **not
passed and cannot self-recover.** Making flatten mandatory for P1/P2 removes the operator's
ability to avoid this, and "Keep it" cements the equity-vs-balance gap that causes it.

**Fix direction:** after the flatten confirms an empty book, latch `target_reached` only
if `balance ≥ target`; otherwise log and stay armed.

**Severity: HIGH** for the campaign KPI. Pre-existing code, but the phase design promotes
it from a defaulted, disableable input to a mandatory, phase-derived behaviour.

---

## MEDIUM

### M1 — The Funded weekend guard is incomplete: friday-close does not cover 2h+ non-Friday breaks, and gap-trading is unaddressed. (hunt #3)

**Claim attacked** (phase design §1 weekend row, §3): reusing the `friday_close`
contract satisfies the FTMO Standard-Funded "close before weekends / any 2h+ break"
requirement, and a weekend-holding sleeve on Funded "fails at init instead of breaching."

**What breaks it:** `QM_FrameworkFridayCloseNow` fires **only** on `day_of_week == 5` at
or after a fixed broker hour (`QM_Common.mqh:384-398`); `QM_FrameworkHandleFridayClose`
closes once that Friday (`:673-692`). It does **nothing** for holidays or the daily index
session breaks (GDAXI, SP500, XTI) that exceed 2 hours. FTMO's rule (and the
forbidden-practices page, verified 2026-07-27) covers "any market break over 2 hours" and
explicitly forbids **gap trading** including "two hours or less before a relevant
financial market is closed." So `QM_PropPhaseValidateWeekend` asserting only
`friday_close_enabled` lets a multi-day **index** sleeve pass init and still hold across a
>2h daily/holiday break on a Standard Funded account → breach. The guard is loud for the
Friday case and silent for every other 2h+ break.

**Severity: MEDIUM.** Narrows to index/multi-day sleeves on Funded; the campaign's
single-account best (9936:USDJPY) is FX and less exposed, but 10291:SP500 / 13108:XTIUSD
sit in the dormancy-safe pool and would be caught by this.

---

### M2 — The (0, 5.0] band's upper bound equals the −5% daily-loss limit; a single max-cap stop-out is a one-trade daily breach. (claim refutation, hunt #5-adjacent)

**Claim attacked** (phase design §1 cap row, §3): "(0,5.0] … encodes the measured optimum
(3–4% P1) as a *legal range*."

**What breaks it:** a per-trade cap of 5% against a −5% daily-loss limit means **one**
stopped-out trade at the cap consumes the entire daily budget; at 4% a single loss plus
ordinary slippage/spread can still trip it, and any second same-day loss certainly does.
The measured optimum is 3–4%, but the band *permits* up to 5%, and the top of that "legal
range" is self-defeating for the very limit the ceiling is said to encode. The band is
not, at its upper end, a safe range.

I am **not** proposing to change the OWNER-ratified 5.0 ceiling
(`QM_Common.mqh:319`). The refutation is of the design's framing that the whole (0,5.0]
interval is a safe legal range for a phase with a 5% daily limit.

**Severity: MEDIUM.**

---

### M3 — `prop_swing_account` is an unverified operator claim that disables the only weekend guard. (hunt #5)

**Claim attacked** (phase design §3): `QM_PropPhaseValidateWeekend` returns true if
`friday_close_enabled` **or** `prop_swing_account == true`.

**What breaks it:** nothing verifies the attached account is actually an FTMO **Swing**
account. An operator who mislabels a Standard Funded account as `prop_swing_account=true`
re-opens exactly the silent weekend-hold → breach path the guard exists to close. It is a
self-declared boolean with no account-side check, in the same spirit as H3.

**Severity: MEDIUM.**

---

### M4 — Dormancy telemetry has no fresh-account / pre-first-trade initialization of `last_open_epoch`. (dormancy design, hunt #1)

**Claim attacked** (dormancy §4:235-242): append a 4th `last_open_epoch` field, read
defensively `if StringSplit(...) >= 4` so "old files stay loadable."

**What breaks it:** the defensive read handles *old* files, but not a **new** account that
has not traded yet. Before the first `QM_PropNoteOpen()`, the field is absent (3-field
file) or zero. The per-day evaluation `idle = today − last_open_day`
(§4:247) then computes idle against epoch 0 (1970) → ~20,000 days →
`prop_dormancy_critical` (`QM_ERROR`) fires from init, every day, until the first trade.
The design never anchors `last_open_epoch` to init time on a fresh account. That is a
false-critical storm on exactly the account state (freshly deployed, waiting for first
signal) that is most normal.

**Fix direction:** initialise `last_open_epoch = TimeCurrent()` in `QM_PropInit` when no
prior value loads, so the idle clock starts at deploy.

**Severity: MEDIUM** (telemetry only, but it inverts the signal — alarms when nothing is
wrong, training the operator to ignore it).

---

## LOW

### L1 — `QM_PropNoteOpen()` is an EA-wired hook; if an adopter forgets it, telemetry is silently wrong. (dormancy, hunt #1)

`last_open_epoch` only updates if the adopting EA calls `QM_PropNoteOpen()` after each
successful entry (dormancy §4:239-241). Nothing enforces the call. An EA that includes the
header, sets the phase, but omits the one-liner will never advance `last_open_epoch` →
permanent false critical (same no-op class as the anchor, L2). Same failure mode as the
previous campaign's unwired input, just on the telemetry path. **LOW** because it does not
touch order flow.

### L2 — `prop_anchor_risk_to_start` defaults true and `prop_init` logs `risk_anchor:start_balance`, but nothing on the entry path calls it. (hunt #1, acknowledged)

Grep confirms `QM_PropRiskBasis`/`QM_PropRiskScale` are defined in `QM_PropFirm.mqh:198,
205` and called **nowhere else** in `framework/include`; `QM_Entry` sizes off live equity
via `QM_RiskSizerRiskMoney(equity)` (`2026-07-27_risk_cap_clamp_analysis.md:65-68`). The
phase design §4:274-280 *does* flag this as unwired — credit for that — but the input still
defaults **true** and `QM_PropInit` emits `"risk_anchor":"start_balance"`
(`QM_PropFirm.mqh:190`), affirmatively claiming an anchor that is not applied. Misleading
telemetry, not just a missing feature. **LOW** (design already flags it; the residual is
the false log line).

### L3 — Removing `prop_target_pct` / `prop_flatten_at_target` as inputs makes legacy set-file keys silent no-ops.

MT5 silently ignores unknown keys in a `.set` file. A future adopter carrying a set file
that still lists `prop_target_pct=` / `prop_flatten_at_target=` gets those lines silently
dropped. Intent is preserved (values are now phase-derived), so this only bites if an
operator *believes* they are overriding the target — which they can no longer do. **LOW**,
worth a migration note for adopters.

---

## Claims that SURVIVED the attack

- **Blast radius = 0 / 485 EAs unchanged** (phase design §6). Verified:
  `grep QM_PropFirm.mqh` over `framework/` returns only
  `QM_PropFirm_compile_probe.mq5:8`; `grep prop_enabled|prop_phase|QM_PropInit|…` over
  `framework/EAs` returns **nothing**. No EA includes the header or references any prop
  input, so editing it recompiles only the probe. **SURVIVES.**
- **Ordering: override wins over the unconditional `:182` 1.0.** Verified against the real
  chain `QM5_10163_tv-rsi-macd-long.mq5:240-259` — `QM_FrameworkInit` (which runs
  `QM_RiskSizerSetCapPct(1.0)` at `QM_Common.mqh:182`) returns, then
  `QM_FrameworkSetRiskCapPct` runs as a separate statement and overwrites. Sequential
  program order guarantees it. **SURVIVES** (the ordering is not where the risk-cap defect
  lives — H1/H2 are).
- **Heartbeat trade ruled OUT** (dormancy §1c). Correct and well-founded: FTMO
  forbidden-practices (verified 2026-07-27) names manipulative/simulated trades and
  gap trading; a trade injected because the idle clock is near 30 is manufactured activity.
  **SURVIVES.** Minor: the doc's phrase "not replicable in real markets" is a paraphrase;
  the page's actual wording is "if performed in real market conditions" (re gap trading).
  Substance unaffected.
- **One enum vs three booleans** (phase design §3) for representing mutually exclusive
  within-config phase state. Structurally sound; it does eliminate the illegal
  `is_phase1 && is_funded` states. **SURVIVES** — but note it does **not** address the
  cross-deploy mistake (H3), which is the one that actually reaches a live account.
- **Dormancy = selection constraint + EA telemetry, admission decided in the book layer**
  (dormancy §4). Sound separation; the P60/gap measurement is reproducible via
  `dormancy_exposure.py` and the four cited maxima (13213=26, 9936=27, 13301=36,
  13036=279) reconcile with MEASUREMENT STATE. **SURVIVES.**
- **Freeze as manual break-glass, not an EA action** (dormancy §1d). Correct; an EA that
  phones a prop firm is out of scope. **SURVIVES.**

---

## Evidence index

- `framework/include/QM/QM_RiskSizer.mqh:68-71` (SetCapPct), `:84-89`
  (`QM_RiskSizerPercentCap`), `:97-115` (cap = ceiling, clamp only when base>cap) — H1
- `framework/include/QM/QM_Common.mqh:179-182` (unconditional 1% cap), `:315-330`
  (override; `:326` suppresses the log at cap==1.0; `:319` ceiling 5.0) — H1, H2, M2
- `framework/EAs/QM5_10163_tv-rsi-macd-long/QM5_10163_tv-rsi-macd-long.mq5:49`
  (`qm_risk_cap_pct` default 1.0), `:240-259` (real OnInit ordering) — H2, ordering-SURVIVES
- `framework/include/QM/QM_PropFirm.mqh:129-137` (ACCOUNT_LOGIN used only for state
  namespace, not phase), `:143` (target flag reloaded on restart), `:190`
  (risk_anchor log), `:198,205` (uncalled basis/scale), `:265-296` (equity-trip flatten,
  permanent latch, no balance re-check) — H3, H4, L2
- grep `QM_PropRiskBasis|QM_PropRiskScale` over `framework/include` → definitions only,
  no external callers — L2
- grep `QM_PropFirm.mqh` over `framework/` → only `QM_PropFirm_compile_probe.mq5:8`;
  grep prop inputs over `framework/EAs` → none — blast-radius SURVIVES
- `framework/include/QM/QM_Common.mqh:384-398` (`QM_FrameworkFridayCloseNow`, Friday-only),
  `:673-692` (`QM_FrameworkHandleFridayClose`) — M1
- FTMO forbidden-trading-practices (fetched 2026-07-27): gap trading incl. "two hours or
  less before a relevant financial market is closed"; manipulative/simulated trades;
  hedging; no published dormancy rule — M1, heartbeat-SURVIVES
- `docs/ops/evidence/2026-07-27_risk_cap_clamp_analysis.md:14-25,65-68,120-122` — H1, H2, L2
- `docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md` (balance-with-all-closed
  target; weekend/2h-break rule; 4-day minimum on OPEN) — H4, M1
- MEASUREMENT STATE (`tools/strategy_farm/portfolio/challenge_book_60d.py`, 50cf7f5a4);
  dormancy maxima reconcile — dormancy-SURVIVES
