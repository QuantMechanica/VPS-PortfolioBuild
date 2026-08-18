# Codex review: QM5_35006 Gemini build

- Review task: `b8886e40-547b-4d41-989a-aad8324f5a69`
- Gemini source task: `348092fa-14ad-4bd0-974f-c1a360144519`
- Source artifact: `framework/EAs/QM5_35006_guppy-multiple-moving-average-breakout/QM5_35006_guppy-multiple-moving-average-breakout.mq5`
- Reviewed tree HEAD: `6be2a520a1b9c957454c8e5a90c0b38fb2ecd9af`
- Source SHA-256: `28e00b4b1a5b8efc45bc78ccdcbeba0f20369b1548facabec7fb91dc451d882b`
- EX5 SHA-256: `7bd722291c2612aafe8a810e6f4337e5b5d6fae62b0e645f307e40ed2c0f5ffd`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

Neither router-named review skill is installed, so Codex performed the review
directly against the approved card, current source, and strict repository
checks.

## Findings

### 1. Critical: the approved signal is not mechanically defined, and code invents it

The card requires the Trader ribbon to be "Expanded" but supplies no formula,
threshold, comparison bar, or state transition for expansion. Source lines
145-152 and 175-183 resolve that ambiguity by requiring every fast EMA and
every slow EMA to be strictly ordered, then requiring complete ribbon
separation. Full slow-ribbon ordering is not in the exact entry equations and
is not a definition of expansion. It materially changes the trade population.

The card must first define a reproducible expansion mechanic; code must then
implement that exact rule. A plausible interpretation cannot substitute for
strategy authorization.

### 2. High: the stop rule is changed at the point of entry

The card says the SL is beyond the outer EMA(60) edge. Source lines 157-165 and
188-196 place it exactly at EMA(60), unless that is closer than an invented
10-pip minimum, in which case it is moved to a fixed-distance stop. No buffer or
minimum appears in the card. This changes risk and the 2.5R target.

### 3. High: the required EMA(30) exit can be suppressed

`OnTick` applies the spread/rollover no-trade filter at line 266 before checking
the EMA(30) close exit at line 270. The card defines the filter as an idle/entry
condition. A widened spread or rollover window can therefore leave a position
open after the approved exit signal.

### 4. High: the GMT and loss-limit contracts are not implemented

The 23:55-00:05 GMT blackout uses raw broker `TimeCurrent()` (lines 69-74), and
the EA contains none of the card's 2.0% daily entry halt, 2.5% daily hard stop,
or 5.0% total-DD stop. Generic framework defaults do not reproduce those rules.

### 5. High: source and binary have no committed build identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. The source task
provided no durable build artifact, commit, compiler report, or hashes. The
current EX5 is 388,688 bytes, but it cannot be reproducibly bound to the
reviewed source until the intended build is committed and recompiled into an
evidence packet.

## Independent verification

- Build guardrails with the 336-hour maximum: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_135712.json`.
- Both backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

No Gemini implementation or pipeline state was changed. Structural PASS does
not cure the undefined signal or missing artifact identity; keep the task in
REVIEW for independent close-out.
