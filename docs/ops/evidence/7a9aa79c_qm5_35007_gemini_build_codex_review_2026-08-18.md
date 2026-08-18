# Codex review: QM5_35007 Gemini build

- Review task: `7a9aa79c-3538-419c-a02a-7670d5ed603a`
- Gemini source task: `c0f9d1e3-582f-4842-86d4-9b37950b32c0`
- Source artifact: `docs/ops/evidence/c0f9d1e3_qm5_35007_build_ea_result_2026-08-17.md`
- Reviewed commit: `61e267f7a9748626952f0b18c1ad1014e6ca81f2`
- Source SHA-256: `a390d193fb248ade83c67848cb9932a28d145dd54410d7c0a794f9da102011ef`
- EX5 SHA-256: `7df381a8fccf9bb2bab008d24dc0cae3352effb41779cae2bf3eb7f6ca8f02ae`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The task-named review skills are unavailable, so Codex performed the mandatory
Gemini-code review directly against the approved card, committed source, and
strict build tools.

## Findings

### 1. Critical: the normal setup submits only the buy side

The card and thesis require stop orders on both sides of the mother bar: a
BUY_STOP above its high and a SELL_STOP below its low. In the normal unbroken
case, source lines 191-200 construct and return only the BUY_STOP. A sell order
is produced only as an unapproved market fallback after price is already below
the sell trigger (lines 182-189). The implemented strategy is therefore
long-biased and cannot execute the approved two-sided breakout setup.

Required rework must submit both pending legs from one setup, define OCO
ownership, and fail closed if the two-leg state cannot be established.

### 2. Critical: pending-order ownership and de-duplication are absent

`Strategy_HasOpenPosition` counts positions only (lines 56-61), not pending
orders. A later inside bar can therefore add another pending order while older
orders remain live. The implementation neither recognizes one active setup nor
cancels the opposite leg after a fill. Expiry is also measured as 12 elapsed
hours (`3 * PeriodSeconds(H4)`) instead of three completed H4 bars, so weekends
and market gaps do not obey the card's bar-count rule.

### 3. High: the card and build disagree on reward/risk

The card specifies an SL distance of `0.20 * Mother_Range` and a TP distance of
`2.0 * Mother_Range`, which is 10R, while calling it 1:2. The source implements
the literal distances (lines 161-162), and the build evidence incorrectly calls
that combination 1:2. The strategy definition must be corrected before code can
be judged faithful; this is not a parameter detail.

### 4. High: additional exits and fallbacks lack card authority

The source clamps the SL to at least five pips, converts already-broken setups
to market entries, and adds a +1R break-even move (lines 161, 172-190, and
239-265). None appears in the approved exit rules. These choices change trade
selection, stop distance, sizing, and payoff distribution.

### 5. High: the approved loss-limit contract is absent

The card's 2.0% daily entry halt, 2.5% daily hard stop, and 5.0% total-DD stop
are not implemented. The generic framework defaults do not reproduce those
thresholds.

## Independent verification

- Current EX5 size is 390,456 bytes, matching the source artifact.
- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS, zero findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_135726.json`.
- All three backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

No implementation or pipeline state was changed. The structural PASS cannot
override the one-sided order engine and unresolved strategy arithmetic.
