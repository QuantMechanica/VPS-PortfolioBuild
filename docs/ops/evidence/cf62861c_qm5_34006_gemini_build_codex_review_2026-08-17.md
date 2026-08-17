# Codex review: QM5_34006 Gemini build

- Review task: `cf62861c-2bb3-40ec-8239-c12627e0a0a0`
- Gemini source task: `70238994-3b68-455c-b170-034bffb81530`
- Source artifact: `docs/ops/evidence/70238994_qm5_34006_build_ea_result_2026-08-17.md`
- Reviewed commit: `039a86faed689e3b00644ca48c43bfbbfc0631f6`
- Source SHA-256: `47ee42750126a191b6ef687b42ee7f2f925f02ab30163204e1b42803b028b1e3`
- EX5 SHA-256: `d2a1ff418fd82b186c5772a00ba63572b72155a8613c676aec88c1b2530e010c`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-named review skills are not installed. Codex reviewed the approved
card and committed implementation directly, then reran the available strict
structural checks.

## Findings

### 1. High: the EA silently changes the approved channel definition

The card explicitly defines `PC_High = max(High[i]), i=1..24` and then requires
`Close[1] > PC_High[1]`. Because `Close[1] <= High[1]`, that literal contract is
not representable as a long signal (and the short side has the symmetric
problem). The implementation recognizes this but silently changes the lookback
to bars 2 through 25 at source lines 102-116.

Excluding the signal bar is a plausible breakout definition, but it is a
strategy decision and must be authorized in a corrected card. Until then the
build is neither a faithful implementation nor evidence that the approved
mechanic is executable. Required rework: amend the card to define the channel
as the 24 bars preceding bar 1, then bind a regression that proves bar 1 is
excluded and all reads remain closed-bar only.

### 2. High: the exact SAR stop is replaced by an ATR corridor

The card requires the current Parabolic SAR dot as SL. Source lines 131-152 and
169-181 replace the SAR price whenever its distance is outside an invented
0.5-to-3.5 ATR range. That changes stop placement, position sizing, and TP. A
broker-invalid SAR stop should fail closed or follow an explicitly approved
normalization rule; it must not be turned into an ATR strategy by default.

### 3. High: compile evidence is inconsistent with the committed binary

The source artifact reports 384,486 EX5 bytes. The reviewed commit/current EX5
is 384,962 bytes. No commit hash, source/EX5 hashes, compiler log, or strict
report path is supplied to reconcile the discrepancy.

## Independent verification

- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260817_205417.json`.
- Current setfiles retain fixed-risk mode (`RISK_FIXED > 0`,
  `RISK_PERCENT=0`).

The structural passes do not resolve the card ambiguity or stop-rule change.
No EA, binary, setfile, registry, work item, or pipeline state was changed by
this review. Keep the Gemini build and this review in REVIEW for independent
close-out.
