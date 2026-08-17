# Codex review: QM5_35001 Gemini build

- Review task: `9a869adc-1d15-4e54-bd1f-6605d2a36291`
- Gemini source task: `070ebd11-f252-4c4c-853a-a32d145c2148`
- Source artifact: `docs/ops/evidence/070ebd11_qm5_35001_build_ea_result_2026-08-17.md`
- Reviewed commit: `6077f4e1e0d9b14f24588fd1794d1d01964480b3`
- Source SHA-256: `4dd4786a5bfa3f4e587b49d93b450672c2c516f62f589c7b6add1e2b81fadc42`
- EX5 SHA-256: `952d324cbe31a56029a70b94242101655ec82f9712f67adb416af2fd90908d7b`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed, so Codex reviewed the approved card and committed implementation
directly and independently reran the structural guardrails.

## Findings

### 1. High: the MACD trigger is broadened beyond the card

Card section 2 requires a zero-line transition: long
`hist[1] > 0 AND hist[2] <= 0` (and the symmetric short transition). Source
lines 173-176 instead accept long whenever `hist[1] > 0` and either it is rising
or `hist[2] <= 0`. A positive histogram that has remained above zero for many
bars therefore qualifies merely because it rose. Lines 202-205 make the same
expansion below zero for shorts. This changes the entry population and the
artifact's description of a generic "slope confirmation" does not amend the
approved card.

Required rework: implement the card's exact zero transition, or obtain a card
amendment that explicitly selects the broader slope rule and its short-side
symmetry.

### 2. High: ATR clamping moves the required swing stop

The card requires the recent M15 swing extreme plus/minus a 3-pip buffer.
Source lines 149-151 construct an unapproved 0.5-to-3.5 ATR corridor; lines
180-192 and 209-221 then replace the swing stop whenever it lies outside that
corridor. This changes initial risk, position size, TP, and the 1R break-even
trigger. The approved stop must remain the swing stop unless the card is
explicitly amended with deterministic rejection/clamping semantics.

### 3. Medium: entry-only filters suppress open-position management

`Strategy_NoTradeFilter` is evaluated before `Strategy_ManageOpenPosition`
(lines 325-332). During the rollover window or an expanded spread, the EA skips
the card's +1R break-even protection even though the filter is specified as an
inactive/entry gate. Open-position safety and exits must run before entry-only
filters.

### 4. High: compile evidence is not bound to the committed EX5

The artifact reports 394,816 bytes; the committed/current EX5 is 394,946 bytes.
It supplies no commit hash, hashes, compiler log, or strict report path.

## Independent verification

- Build guardrails at the mandatory 336-hour ceiling: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260817_205322.json`.
- Current backtest setfiles retain fixed-risk mode (`RISK_FIXED > 0`,
  `RISK_PERCENT=0`).

No Gemini code or operational state was changed. Structural PASS is not a
strategy-fidelity verdict; the task remains in REVIEW for independent close-out.
