# Review: QM5_20177 Early-Target-at-Fill Fix (Gemini build_ea → Claude review_ea)

Router review task `ea8b14f6-829c-4c1f-8237-6e233c3a7a03` (priority 81, `review_ea`,
reason `codex_review_required_for_gemini_code`), reviewing source task
`141b8518-0be0-4c1d-87a3-3e8a2f20e14b` (`build_ea`, agent `gemini`, backend `agy`,
verdict `FIXED_AND_AUDITED`, artifact
`docs/ops/evidence/141b8518_qm5_20177_early_target_fix_and_cohort_audit_2026-08-17.md`,
commit `24e5bb90a` on `agents/board-advisor`).

**Verdict: DO NOT ACCEPT AS FINAL.** The fix is directionally sensible and its narrow
claims (hashes, 3 pytest passes) verify clean, but there is a real, precisely-derivable
risk that the guard it adds makes `QM5_20177` fire far less often than the source
artifact assumes — potentially trading a "0-second round trip" defect for a
"near-zero-trade" defect, which would not surface until after a full 6-symbol Q02
requalification cycle is already spent. Per Hard Rules this task stays in `REVIEW` for
Codex/OWNER follow-up; not self-approved, not moved to `PIPELINE`.

## 1. What was independently re-verified (matches the artifact's claims)

- SHA256 of all three changed files (`certutil -hashfile ... SHA256`) matches the
  artifact's table exactly for `.mq5`, `.ex5`, and the new test file.
- `pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py -v`:
  3 passed in 0.27s — matches the claimed 3/3.
- Spot-checked 3 of the cohort-audit's categorized EAs against actual source
  (`QM5_1401_harmonic-shark-xabcd-h4` — empty `Strategy_ManageOpenPosition`;
  `QM5_11902_bermuda-triangle-123-fib-extension-h1` and
  `QM5_11392_justforex-momentum7-divergence-fib` — both anchor management to live
  position state, not raw C/D geometry). All three match their claimed category.

## 2. Primary finding — the new `t1_ok` guard is geometrically self-restricting

The fix (bullish branch, `.mq5:220-231`) adds:
```
const double t1 = d_proj + t1_fib * (C - d_proj);   // = d_proj - t1_fib*(B-A), t1 < d_proj since B>A
const bool t1_ok = (ask < t1);
long_ok = touch_ok && confirm_ok && t1_ok && ...;
```
`touch_ok` pins `c2.close` (and `c2.low`) to within `tol = 0.5*ATR14` of `d_proj`.
`confirm_ok` requires `c1.close > c2.high`, and `c2.high >= c2.close >= d_proj - tol`.
`ask` at signal-evaluation time is bounded below by (approximately) `c1.close`, hence
by `c2.high`, hence by `d_proj - tol` in the best case for the guard.

For `t1_ok` (`ask < t1`) to be *geometrically reachable at all*, it is necessary that:
```
d_proj - tol < t1 = d_proj - t1_fib*(B-A)
  =>  tol > t1_fib*(B-A)
  =>  (B-A) < tol / t1_fib = (0.5*ATR14) / 0.382 ≈ 1.31 * ATR14
```
i.e. the guard can only pass when the **AB leg magnitude is smaller than ~1.3x ATR14**
— a short/tight leg relative to volatility. Nothing in the existing entry conditions
(`ab_bars` 3–60, `bc_ratio` 0.382–0.886, `time_symmetry_tolerance` 0.20) constrains
`(B-A)` relative to ATR, so both large and small legs are structurally permitted today.
The bearish branch is symmetric: `(A2-B2) < tol/t1_fib` is likewise necessary.

This is a **necessary, not sufficient**, condition (the touch bar also has to sit near
the low edge of the tolerance band and the confirm excess has to be small) — so the
guard is not provably a hard zero, but it restricts qualifying entries to a materially
narrower slice (short-amplitude AB legs) than the pattern's original design range. That
slice may be rare or absent in the actual 6-symbol H4 archive data. The
`FIXED_AND_AUDITED` verdict and the artifact's Executive Summary ("Signals where T1
already lies behind the prospective fill price are rejected") reads as if this filters
an edge case; the derivation above shows it is closer to the common case for any AB leg
that isn't unusually tight relative to ATR.

**Recommendation before spending the 6-symbol Q02 requalification cycle**: run a cheap
offline scan of `touch_ok && confirm_ok` bar counts vs. `touch_ok && confirm_ok &&
t1_ok` bar counts against existing H4 archive data for at least one of the 6 target
symbols. If the post-fix count is at or near zero, the fix needs to change *how* T1 is
anchored rather than gate the existing entries — e.g. anchor T1/T2 to
`PositionGetDouble(POSITION_PRICE_OPEN)` post-fill (the pattern used by the cohort's
"category 2" EAs, e.g. `QM5_11902`, `QM5_1376`) instead of the pre-entry C/D
projection, or redefine T1 to sit beyond D in the travel direction if a continuation
target (not a retracement-back-toward-C target) was actually intended.

## 3. Secondary finding — cohort-audit count does not reconcile

The artifact's Executive Summary and §3 header both claim **"Audited all 84 pattern,
harmonic, wave, and Fibonacci EAs"**. Parsing §3's three categorized lists
programmatically:

- Category 1 (empty `Strategy_ManageOpenPosition`): 49 EAs
- Category 2 (anchors to `POSITION_PRICE_OPEN`): 13 EAs
- Category 3 (explicit signal-time target checks): 6 EAs
- Total categorized as immune: **68**, plus `QM5_20177` itself (the one confirmed
  defective) = **69** distinct EA IDs actually enumerated in §3.

That leaves a **15-EA gap** between the claimed audited count (84) and the enumerated
evidence (69). This doesn't invalidate the specific EAs that *are* listed (spot-checks
in §1 above confirm those categorizations are accurate), but the artifact's headline
conclusion — "`QM5_20177` was the single isolated instance of this defect" — is only as
strong as its enumeration, and 15 EAs are unaccounted for. Given this conclusion
directly justifies voiding the frequency-floor retirement for `QM5_20177` specifically
(not the other 15), the immediate risk is scoped, but the "sole EA" claim itself is not
yet fully evidenced. Recommend the audit list be reconciled to 84 (or the claimed count
corrected to 68/69) before treating the cohort conclusion as closed.

## 4. Guardrail compliance (unaffected by this fix, confirmed clean)

`pytest`'s third test independently confirms, for every existing `QM5_20177` setfile
(`EURUSD`, `GBPUSD`, `NDX`, `USDJPY`, `WS30`, `XAUUSD` — all 6 target symbols from the
requalification list already have setfiles): `RISK_FIXED > 0`, `RISK_PERCENT == 0`,
`qm_news_stale_max_hours <= 336`. No guardrail regression from this change.

## 5. Disposition

- No code changes made by this review.
- Router task `ea8b14f6-829c-4c1f-8237-6e233c3a7a03` → `REVIEW` (not `APPROVED`, not
  `PIPELINE`) per the Gemini-code Hard Rule; artifact = this file.
- Recommend next action be a cheap pre-Q02 signal-frequency sanity check (§2) rather
  than proceeding straight to the 6-symbol Q02 requalification.
