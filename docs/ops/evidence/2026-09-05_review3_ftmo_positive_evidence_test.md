# Third independent review — FTMO positive-evidence acceptance test R4

Reviewed file: `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`  
Reviewed R4 raw SHA-256: `d669aa1e4a1ff7882f982f90f9e3302bf63f384ecb5758030125e18bd59dde8a`  
Reviewed R4 LF-normalised SHA-256: `1e821203c31860530a117f852cddd1ad5769433ca832cef4443648129f6835d4`  
Dependency tip audited: `47800e367c41f04e89d4ac05b081c0a4f82afd28` (including portability fix `7f56e1c825`)  
Verdict: **FAIL — exact R4 bytes are not ratifiable; the method is ratifiable after a mechanical R5 correction**

R4 closes the substantive blockers from reviews 1 and 2: its R-1 arithmetic
is reproducible, R-2 is now an explicit OWNER-choice predicate, the
degenerate-HAC and short-span guards are operational, C-6 is honestly inert,
and D.2 excludes the deferred-deflation PASS. It still cannot be ratified on
the exact reviewed bytes for two independently sufficient reasons below.

Even after correction and ratification, the test cannot lift `NO-BUY` today:
C-6 breach/P2/joint gates remain inert, the OWNER choices are unresolved, and
the existing 96-day diagnostic span does not meet the proposed R-2 floor.

## Findings

### F1 — BLOCKER: 59 truncated starts are not 59 forced TIMEOUTs

R4 correctly fixes the engine's *enumeration count*: `rolling_outcomes()`
visits every `eligible_start`, so an all-eligible 96-day trace has 96 starts,
not 37 (`ftmo_timebox_eval.py:898-902`). It also correctly computes 37 start
positions that have all 60 calendar days available and 59 whose potential
horizon extends beyond the trace.

It then makes an invalid step. R4 lines 35, 288 and 295 call all 59 truncated
starts right-censored/forced `TIMEOUT` and say they are structurally unable to
pass. `evaluate_phase()` instead checks daily breach and target conditions on
every available day and returns immediately on either event
(`ftmo_timebox_eval.py:858-890`). It returns `TIMEOUT` only if no terminal event
has occurred before the available data ends (`:891-895`). A truncated start can
therefore PASS or breach; only an unresolved truncated start is right-censored.
The number of right-censored starts is outcome-dependent and cannot be derived
as `96 - 37` before opening the result. The direction and size of the effect on
`p1_raw_rate` likewise cannot be declared from the calendar alone.

Reproduction using production `DailyPoint` and `rolling_outcomes`: a 96-day,
all-eligible synthetic trace with four +3% days beginning at index 91 produced
96 rolling starts; the start at index 91 had only five observed days remaining
and returned `PASS` on day four. Among the 59 truncated starts, 56 returned
PASS and only 3 returned TIMEOUT. This directly refutes the fixed “59
right-censored” statement without reading any real result.

This does not change `D=96`, `W_sealed=floor(96/60)=1`, or the R-2 decision.
It does make the exact predeclared description false and must be corrected
before OWNER signature.

### F2 — BLOCKER: six static seal identities and OQ-11 are stale after the ordered portability fix

The priority-58 portability change landed before this priority-70 review, as
required by the deterministic queue. It made the contract digest portable,
recorded raw provenance beside it, corrected three contract citations, and
added the contract path as `-text`. Consequently R4 lines 405, 425-426 and 499
now state facts that are false, and the static hashes for the evaluator,
diagnostic engines, builder, contract JSON, and loader no longer describe the
code that would execute the test.

This is expected pre-seal change, not contamination. But R4 says those exact
identities are load-bearing seal inputs. The document must advance to R5 and
record the current identities before it is ratifiable. No threshold or
statistical rule needs to change.

### F3 — MEDIUM: R-2's policy coupling is valid as an OWNER choice, not as an independence identity

The code does append one 60-day block per bootstrap draw
(`ftmo_timebox_eval.py:990-998`) and repeats draws until it reconstructs `D`
days (`:995-1009`). For `D=96` that is two block draws per replicate from 37
overlapping start positions; the R4 arithmetic stating this is correct.

However, “one disjoint 60-day block is therefore exactly one independent draw”
(R4 line 236) does not follow from the implementation. Bootstrap draws are
conditionally independent RNG selections with replacement, but the 37 source
blocks overlap heavily and are not 37 independent market observations.
`W_sealed=floor(D/60)` is a conservative coverage rule, and the 1:1
`W_min=ESS_min` coupling is explicitly surfaced as OQ-2c. That makes it a
ratifiable proposed policy. R5 should call it a conservative OWNER-chosen
coverage unit, not claim code-derived statistical independence.

## Required checks

### R-1 / R-2 arithmetic — PASS

Recomputed directly with
`ceil(1.96^2 * p* * (1-p*) / (p* - 0.80)^2)`:

| p* | ESS_min = W_min | D_min P1 | D_min joint |
|---:|---:|---:|---:|
| 0.82 | 1,418 | 85,080 | 127,620 |
| 0.85 | 196 | 11,760 | 17,640 |
| 0.86 | 129 | 7,740 | 11,610 |
| 0.88 | 64 | 3,840 | 5,760 |
| 0.90 | 35 | 2,100 | 3,150 |
| 0.92 | 20 | 1,200 | 1,800 |
| 0.95 | 9 | 540 | 810 |

All R4 table entries are exact. With the proposed coupling,
`W_sealed=floor(D/60)` and `PASS(R-2) iff W_sealed >= W_min and D >= 60*ESS_min`
are deterministic at seal time from the SHA-bound contiguous calendar.

### R-2b degenerate branch — PASS

For a constant Boolean series, `gamma0 <= 0` returns raw `n` and an empty
autocorrelation list (`ftmo_timebox_eval.py:948-957`). R4's detector is exact.
Its substitution of `W_sealed` is fail-closed. The prose at R4 line 270 should
say the ordinary non-degenerate result is clamped *to the interval* `[1,n]`,
not “clamped up to raw n”; the implementation is `max(1,min(n,effective_n))`
at `:968-973`. This wording does not alter the predicate.

### R-2c D <= 60 — PASS

For `D <= 60`, `_resampled_days()` sets `block=D`, leaving only start zero;
every replicate reconstructs the same trace (`:990-1010`). Percentiles then
collapse (`:1013-1033`). Declaring `D <= 60` inadmissible is a correct
fail-closed guard. For the edge case of zero eligible starts, the bootstrap
coerces `None` to `0.0` (`:1021-1023`), so R5 should avoid the universal phrase
“equals raw rate”; the degeneracy conclusion remains unchanged.

### D.0 / D.1 C-6 alignment — PASS

The live v1 contract still declares `breach` and `two_phase`
`INERT_UNTIL_C6_ENGINE_OWNER_APPROVED`. The loader refuses any different status
at `ftmo_probability_contract.py:123-126`, and the evaluator republishes both
inert statuses at `ftmo_timebox_eval.py:1480-1487`. It credits only the P1 lower
bound at `:1474`. R4 correctly concludes that D.1 cannot currently be met and
that no measurement can lift `NO-BUY` while these necessary conjuncts remain
inert.

### D.2 deflating-branch requirement — PASS

The DSR engine's empty-cohort branch returns a documented trivial PASS with
deflation deferred (`sub_8_2_dsr_mc_fdr.py:196-210`). The actual deflating
branch calculates the effective candidate count at `:221-223` and passes only
when `p_value < 0.05` at `:225-228`. R4 correctly refuses to credit the former
and correctly preserves 369 versus measured-census 154 semantics.

## Eighteen-item seal audit

All currently materialised static identities were recomputed using SHA-256 over
LF-normalised bytes. Items that exist only after OWNER choices / `prepare-config`
/ repair remain intentionally unmaterialised and must be written into the seal
receipt before any result is opened.

| item | result at audited tip |
|---:|---|
| 1 | R4 exact LF `1e821203c31860530a117f852cddd1ad5769433ca832cef4443648129f6835d4` (raw `d669aa1e…`) — matches task identity |
| 2 | 8/8 bundle files exist and each raw SHA matches the eight values in §A / `2026-09-04_fund_score_current_population.md:24-31` |
| 3 | rulepack LF `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992` — matches R4 |
| 4 | provider snapshot raw/LF `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905` — matches R4 and rulepack |
| 5 | evaluator LF `5a3f522de35d3d21f3c4089fa2e0adec83e9bba4db2cabefd98a0cd37ecd85ca` — **R4 stale** (`c3b2fcd8…`) |
| 6 | P1 MC LF `80e57bce0fcccf9730da5d4a781faccd9ccb8412bea5ff8b096fe5388e8119ba`; first-passage LF `fc3b58c91aebed95cf49fdabcda888576c3972c2056a1c3fc7e655dc2fad68bc` — **R4 stale**; rules engine `2c79ccd2…` and rule loader `02adb2eb…` still match |
| 7 | builder LF `5cf70d3f9e54ea4f512149d9b90c9d4a1e0431a7f387d1d0586ad57f984987bd` — **R4 stale**; scorer `cb9c3989…` and counter `e3ba4737…` match |
| 8 | DSR `906bef88…`, lineage `177313cb…`, census `1c0ffccd…` — all match R4 |
| 9 | not yet sealable: literal per-identity lineage inputs and read-level multiplicity must be recorded before result access |
| 10 | not yet materialised: prepared-config path and SHA |
| 11 | cost snapshot LF `7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280` — matches expected constant |
| 12 | concentration policy LF `ef8b10ec564e21863d8ca3706535d1af21b173c1aff15baa771bb82192890d17` — matches R4 |
| 13 | not yet materialised: repaired calendar bundle identity / repin |
| 14 | not yet materialised: OWNER's OQ literal answers and derived floors |
| 15 | probability JSON LF/stamped `5b4e24eb60cd175f0973ddf7c8ea3f9db0daf2965379f1fedff6a8d816f79362` — **R4 stale** (`54cb80fd…`) |
| 16 | contract loader LF `c6c8ddf6f525bfac0dbddbbf8a2643a9ec7c725fb5fb4a0ed48d25c158943b0f` — **R4 stale** (`a8596709…`) |
| 17 | Layer-A producer LF `4b3c2888954b6b35170396369c617bffec0d4bddb384c60601a8233499dd26c1` — matches R4; produced artifact still must be bound at seal |
| 18 | probability/correlation contract document LF `e25eceb81dc24a815ec7944b225b92a67f56b88ca5420cdeaf7bc48ca6f611ee` — matches R4 |

The test is not yet sealed; missing items 9, 10, 13 and 14 are expected. The
six stale static identities are not acceptable in a document that claims they
were recomputed at the current tip.

## File:line anchor audit — 71 sampled targets

A range is counted as one target, matching review 2's convention. Content was
checked, not merely line existence.

| surface | sampled targets | result |
|---|---:|---|
| Rulepack: `:9,:24,:151-160,:458-463,:464-469,:470-475,:476-481,:482-487,:488-493,:494-499,:500-505,:462,:468,:474,:480,:486,:492,:498,:504` | 19 | 19 correct |
| DSR: `:22,:32,:33,:34,:38,:39,:40-46,:47,:54,:78-79,:93-100,:103-143,:149-150,:161-176,:182-186,:196-210,:221-228,:243-245` | 19 | 19 correct |
| Timebox: `:79,:81,:84,:97,:101-105,:112-118,:251-275,:323-333,:396-397,:464-465,:576-585,:629-630,:707-708,:723-724,:858-895,:898-902,:948-974,:990-1033,:1063-1069,:1115-1117,:1145-1158,:1307-1312,:1474,:1480-1487` | 25 | 25 semantic targets correct; R4's interpretation of `:891-895` is wrong (F1) |
| Other: `emit_q16_lineage.py:16-21,:179-187,:212`; its test `:112-119`; `opt_census.py:36`; `fund_score.py:94-103`; `book_build_guard.py:28,:236-239` | 8 | 8 correct |

Additionally, every builder and contract-loader anchor in R4 was checked.
Adding one builder constant shifts post-import builder anchors by +1; adding the
normalisation helper shifts loader validation anchors by +6. The R4 statements
remain behaviorally correct but their line citations are not current. Contract
JSON lines 29-30 now contain the corrected citations and no longer support
R4's OQ-11 complaint.

## Minimal corrective diff — not applied

```diff
--- a/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
+++ b/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
@@ §1 item 2 / §C.4 R-2d
-37 starts with full horizon and 59 right-censored starts; the latter are forced TIMEOUT and structurally cannot pass.
+37 starts have a full 60-day horizon available; 59 starts are horizon-truncated. A truncated start can PASS or breach before the trace ends. Only those with no terminal event in the observed tail return TIMEOUT, so the actual right-censored count is result-dependent and is not opened before the seal.
@@ §C.4 R-2
-One disjoint 60-day block is therefore exactly one independent draw the CI can be built from.
+The implementation appends one 60-day block per bootstrap draw. For the conservative OWNER-choice coverage rule, one non-overlapping 60-day source block counts as one W unit; this is a policy coupling, not a claim that overlapping source blocks are independent market observations.
@@ §C.4 R-2b
-The final value is additionally clamped up to raw n.
+The non-degenerate result is clamped to the interval [1,n].
@@ §E digest convention / OQ-11
-The loader hashes raw bytes; the contract is not -text; OQ-11 remains open.
+Portability fix 7f56e1c825 marks the contract -text, stamps its LF-normalised digest, and records raw_sha256 beside it. OQ-11 is RETIRED. Seal both fields; the portable identity is authoritative.
@@ §E items 5-7,15-16 and §G
-[R4 hashes and pre-portability line anchors]
+[current LF hashes from this review's eighteen-item table and current anchors]
```

## Disposition

Keep receipt row 18 `PENDING`. Exact R4 is not ratifiable. Its decision method
is ratifiable as a predeclared, refutable test after an R5 applies the narrow
corrections above and a hash-only confirmation verifies the amended bytes.
Neither R5 nor later ratification can by itself lift `NO-BUY`, authorize a
purchase, enable `T_Live`/AutoTrading, or make the currently inert C-6 gates
pass.
