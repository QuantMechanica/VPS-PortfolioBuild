# Codex review: QM5_36003 Gemini build

- Review task: `b4c223a0-818d-444d-bb7d-1336da8abdd2`
- Gemini source task: `019d50ff-a716-46a4-b097-c5c650dea63b`
- Source artifact: `docs/ops/evidence/019d50ff_qm5_36003_build_ea_result_2026-08-17.md`
- Reviewed commit: `e0f0d81a719aed620141a2d5514dd50dc38b7852`
- Source SHA-256: `b9f28c34027ffa44712121cd63e2a9374559fa1770733ea3460be6f75297a7e5`
- EX5 SHA-256: `baffb41f8b8af18990919b622acf8c27d5c98a4543dc2c9160f7b020a1a3be47`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The task-named review skills are unavailable. Codex independently reviewed the
approved card, committed implementation, current binary, and strict build
evidence.

## Findings

### 1. Critical: the implemented ZeroLag EMA is not the approved formula

The card defines ZeroLag MACD legs as
`EMA(Price + (Price - EMA(Price, period)), period)`. Lines 114-123 do not EMA
the adjusted-price series. They take the ordinary EMA at one shift and apply a
single alpha update using only that bar's adjusted price. This is algebraically
and path-dependently different from the specified second EMA, so both the MACD
line and every downstream signal are wrong. Lines 131-143 also invent a simple
mean as the signal line without a card-defined basis.

### 2. Critical: the 50% TP1 plus runner is replaced by a full-position TP

The card requires half the position to close at +1 ATR and a runner to exit on
the ZeroLag MACD signal crossover. Source lines 275-301 attach +1 ATR as a TP
to the whole order, contain no partial-close call, and use the same +1 ATR
threshold for break-even at lines 317-353. The broker TP normally eliminates
the complete position before the runner exit can operate.

### 3. High: `BetterVol == HIGH` is resolved by an unauthorized 1.02 rule

The approved card never defines `HIGH` numerically. The SPEC says expansion
relative to a 20-bar average, but lines 192-204 require the current bar to be at
least 1.02 times an average that already includes that bar. The 2% buffer and
window convention are implementation inventions that alter trade selection.
The card must define the mechanic before code can implement it faithfully.

### 4. High: the GMT and loss-limit contracts are not implemented

Lines 57-61 and 213-216 treat raw broker time as GMT, shifting the rollover
blackout by UTC+2/+3. The EA also lacks the card's 2.0% daily entry halt, 2.5%
daily hard stop, and 5.0% total-DD stop; generic framework defaults differ.

### 5. High: strict build validation fails

Fresh `build_check.ps1 -SkipCompile` rejects source line 118 because its raw
`iClose` call lacks the required reviewed `perf-allowed` annotation or a QM
wrapper. Report:
`D:/QM/reports/framework/21/build_check_20260818_142625.json`.

### 6. Medium: entry-only filters can suppress the runner exit

`OnTick` returns on rollover or spread at line 422 before management and the
ZeroLag MACD exit at lines 424-434. An open runner can therefore remain exposed
after its card-defined exit condition while an entry-only filter is active.

## Independent verification

- Current EX5 size is 394,876 bytes, matching the source artifact.
- Build guardrails at the mandatory 336-hour ceiling: PASS, zero findings.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, one failure, zero warnings.
- Three active magic rows are collision-free and present once each in the
  generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

No Gemini source, setfile, registry, work item, or pipeline state was changed.
