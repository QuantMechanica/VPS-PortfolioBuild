# Codex review: QM5_34008 Gemini build

- Review task: `72b63c06-7749-4ac4-8276-fcf7bdc02dc4`
- Gemini source task: `fa7ca587-77f8-4cea-b71b-7bb1b746b33d`
- Source artifact: `docs/ops/evidence/fa7ca587_qm5_34008_build_ea_result_2026-08-17.md`
- Reviewed commit: `039a86faed689e3b00644ca48c43bfbbfc0631f6`
- Source SHA-256: `2d9561291bd10a468c40be0f6a184d4bffda7b6f2afe08d6a88184001d68796d`
- EX5 SHA-256: `85962ade2c7c4251a188bd38d8f269df57d8cff0f1f534035db60dc541661186`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router requested `code-review` and `gemini-output-review`, but neither
skill is installed in this session. This mandatory review was therefore
performed directly against the approved card, committed patch, current source,
strict build check, and build guardrails.

## Findings

### 1. Critical: the market-neutral two-leg package is not implemented

The approved card requires one package which buys `argmin(delta_k)` and sells
`argmax(delta_k)` (card sections 1 and 3.2-3.3). The EA calculates each host's
z-score, but never calculates either basket arg-extremum. At source lines
177-233, every independently launched host whose absolute z-score exceeds the
threshold can submit a single market order. `QM_TM_OpenPositionCount(magic)` at
lines 110-115 is isolated to that host-slot magic and cannot coordinate the
other six instances.

The result can be a lone directional position, multiple non-extreme positions,
or legs opened on different ticks. None is the card's atomic market-neutral
max/min package. Required rework must define package ownership, select exactly
the two extrema from one shared snapshot, size the combined risk budget, and
fail closed if both legs cannot be established.

### 2. Critical: the card's package exits are absent

The card requires closing the combined package at +1.5% portfolio profit or
-1.5% portfolio drawdown. `Strategy_ExitSignal` is an unconditional `false`
(lines 243-246), while entry lines 166-170 and 184-231 create independent
1.5-ATR stops and 2R take-profits. That replaces basket-arbitrage economics with
unapproved per-leg directional exits. The source artifact describes those
per-leg exits but does not disclose that they contradict the approved card.

### 3. High: the build artifact does not bind the committed binary

The artifact reports an EX5 size of 388,442 bytes. The EX5 created by the
reviewed commit and present in the current tree is 389,242 bytes. The artifact
provides no commit hash, source/EX5 hashes, compiler log, or strict report path,
so its compile claim is not cryptographically reproducible.

## Independent verification

- `validate_build_guardrails.py --max-news-stale-hours 336 <EA dir>`: PASS,
  zero findings.
- `build_check.ps1 -EALabel QM5_34008_multicurrency-basket-dispersion-hedger
  -SkipCompile`: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260817_205306.json`.
- Current setfiles retain `RISK_FIXED > 0`, `RISK_PERCENT=0`, and the 336-hour
  news-staleness ceiling.

Those structural passes do not override the strategy-definition failures. No
source, binary, setfile, registry, work item, or pipeline state was changed by
this review. The Gemini build and this Codex review remain for independent
close-out in REVIEW.
