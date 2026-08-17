# Codex review: QM5_35002 Gemini build

- Review task: `bc910727-5ee3-47a3-ae81-420aa819f589`
- Gemini source task: `da27d5d7-b9e2-44c7-892e-7253154a7ba7`
- Source artifact: `docs/ops/evidence/da27d5d7_qm5_35002_build_ea_result_2026-08-17.md`
- Reviewed commit: `735595f3e54b23076c61fb1324fc1bb14cba1dc2`
- Source SHA-256: `ca605b2e8b4312db36acb641311cb3ad1359c516c3929f5a6a02a2367d30a8be`
- EX5 SHA-256: `86b08bc27aa75a5caf03e227a3a1a5b0477a3b33c189edb02f53dfc4af9c411e`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

Neither router-named review skill is installed in this session. Codex therefore
performed the mandatory review directly against the approved card and the
committed source, with independent strict structural checks.

## Findings

### 1. High: the hard 50-pip stop is replaced by an ATR-dependent stop

Card section 3.4 defines a hard 50-pip stop (or a recent H1 swing extreme).
The EA implements neither alternative consistently. Lines 131-139 clamp the
50-pip distance into an invented `[0.5 ATR, 3.5 ATR]` corridor and lines
147-165 use the resulting value. For example, a 10-pip ATR produces a 35-pip
stop, while a 200-pip ATR produces a 100-pip stop. TP and risk sizing change
with it. This is a strategy mechanic, not a broker stop-level normalization.

Required rework must use the card's 50-pip choice or implement a precisely
defined swing-extreme alternative authorized in the card; invalid broker stops
should fail closed rather than silently change the strategy distance.

### 2. High: the implementation resolves an inconsistent DI contract without authority

The card's exact long and short equations (sections 3.2-3.3) require EMA cross,
RSI, and ADX but do not include directional DI. Its earlier mathematical
paragraph mentions `+DI > -DI` only, which cannot serve as a symmetric short
rule. Source lines 116-120 and 141-156 choose a new directional interpretation:
`+DI > -DI` for long and `-DI > +DI` for short. That may be plausible, but it is
an unapproved resolution of a card ambiguity and filters a different trade
population. The card must be corrected before the EA can be called mechanical.

### 3. Medium: the no-trade gate disables trailing management

At lines 249-256, rollover/spread filtering returns before the 30-pip-triggered
trailing logic runs. The card defines that filter as an idle/entry condition,
not permission to suspend management of an existing position.

### 4. High: the artifact's EX5 evidence is inconsistent

The artifact reports 392,698 bytes, whereas the reviewed commit/current EX5 is
392,398 bytes, with no commit hash, hashes, compiler log, or report path to
reconcile the claim.

## Independent verification

- Build guardrails with `--max-news-stale-hours 336`: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260817_205339.json`.
- All three current backtest setfiles retain `RISK_FIXED > 0` and
  `RISK_PERCENT=0`.

No implementation or pipeline state was changed. The task remains REVIEW-only
pending corrected card fidelity and independently bound build evidence.
