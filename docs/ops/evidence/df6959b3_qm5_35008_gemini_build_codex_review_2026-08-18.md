# Codex review: QM5_35008 Gemini build

- Review task: `df6959b3-d3e8-4702-8aed-a3b85a23e222`
- Gemini source task: `60e3146d-c363-4b7c-af29-18380260e8f1`
- Source artifact: `docs/ops/evidence/60e3146d_qm5_35008_build_ea_result_2026-08-17.md`
- Reviewed commit: `bf720ba6f9c710024ce92bf5776d7068123326e9`
- Source SHA-256: `abe9d95eee1f043f629a8e5e700dbb1b2faae48bbe8f03789c66cfd484f8ec99`
- EX5 SHA-256: `998a192d8c954cdf671ac6a4628da373ec16c51fd7fb67b3b0a16d563d774f77`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The requested review skills are unavailable. Codex independently reviewed the
approved card, committed source, current binary, and strict build evidence.

## Findings

### 1. Critical: every GMT rule is evaluated in broker time

The card's identity depends on the quiet 18:00-22:00 GMT entry session and a
23:00 GMT time exit. Source lines 103-109 use raw broker `iTime` for entry;
lines 245-251 use raw `TimeCurrent()` for exit; and lines 65-70 do the same for
the rollover blackout. Darwinex broker time is UTC+2/+3 and DST-aware, so all
three windows occur at the wrong hours and drift seasonally. The source
artifact calls them GMT even though no conversion exists.

### 2. Critical: an entry-only filter can defeat the mandatory time exit

`OnTick` returns on expanded spread or rollover at line 285 before evaluating
the 23:00 close at line 289. If spread remains above the entry threshold, the
position misses its mandatory close; after 23:55 the rollover filter always
returns before the exit. Forced exits and open-position management must run
before entry-only gates.

### 3. High: the middle-band target is replaced by an unapproved 1.5R target

The card requires TP at the SMA(20) middle band. Source lines 143-147 and
164-168 replace it with 1.5R whenever the band is within three pips or lies on
the wrong side of execution. That changes the mean-reversion exit instead of
failing closed on an invalid setup.

### 4. High: additional stop and management mechanics lack card authority

The source clamps the exact 1.5-ATR stop to a five-pip minimum and adds a +1R
break-even move (lines 134 and 181-243). Neither mechanic appears in the
approved exit rules, and both change risk, sizing, and payoff distribution.

### 5. High: the approved loss limits are absent

The card's 2.0% daily realized-loss entry halt, 2.5% daily drawdown hard stop,
and 5.0% total drawdown stop are not implemented. The generic framework
defaults do not establish those thresholds.

## Independent verification

- Current EX5 size is 393,286 bytes, matching the source artifact.
- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_135736.json`.
- All three backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

No Gemini source, setfile, registry, work item, or pipeline state was changed.
The build must remain in REVIEW pending clock, exit-ordering, and card-fidelity
rework plus independent close-out.
