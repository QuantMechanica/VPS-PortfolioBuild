# Codex review: QM5_36001 Gemini build

- Review task: `d47d0803-00ea-4832-905a-d5436728784f`
- Gemini source task: `3c1da904-b03a-40d5-a1b3-c23e9ffad4b8`
- Source artifact: `docs/ops/evidence/3c1da904_qm5_36001_build_ea_result_2026-08-17.md`
- Reviewed commit: `2ad86abe71e451218607b7d5f304c3138b5b4acc`
- Source SHA-256: `7e3f4568c0adb106fc92fc26b484b48f3b2a878e42516bfa2b924f6c38ceb2cc`
- EX5 SHA-256: `5b463d9138ee8ad1d31566ac0093b127932965facfde75c09f184c683f789a61`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The task-named review skills are unavailable. Codex independently reviewed the
approved card, committed implementation, binary, registries, and build checks.

## Findings

### 1. Critical: TP1 closes the whole position, so no runner survives

The card requires a 50% partial close at +1 ATR, moving the remaining runner
to break-even for the DeMarker/SSL exit. Lines 238-264 attach a +1 ATR broker
TP to the entire order and contain no partial-close call. Lines 280-316 trigger
break-even at the same level, which cannot reliably run before the full broker
TP. The implemented payoff is a simple 1R all-out exit, not the approved NNFX
two-stage lifecycle.

### 2. High: SSL state is substituted for the approved SSL crossover

Card sections 3.2-3.3 require `SSL Crossover == UP/DOWN`. Lines 96-107 examine
only the current closed bar and return a persistent directional state; no prior
bar or transition is tested. Entry lines 217 and 241-256 can therefore fire on
any later bar while the state remains aligned, rather than only on a crossover.

### 3. High: DeMarker levels are substituted for crossover exits

The card says to close the runner when DeMarker crosses the opposite extreme.
Lines 327-347 test only `> 0.70` or `< 0.30`, without comparing the previous
closed bar. A fresh trade opened while DeMarker is already extreme can be
closed on the next tick even though no post-entry crossover occurred.

### 4. High: the WAE short gate is not the rule written in the card

Both exact card equations require `WAE > ExplosionLine`. Lines 145-164 create a
signed momentum result, and short entry line 256 requires that result to be
negative. That directional substitution is not stated in the approved short
equation and changes its trade population; the card must either authorize and
define signed WAE explicitly or the code must implement the written gate.

### 5. High: the GMT and loss-limit contracts are not implemented

Lines 59-63 and 173-176 evaluate raw broker time as GMT. The EA also lacks the
card's 2.0% daily entry halt, 2.5% daily hard stop, and 5.0% total-DD stop;
generic framework defaults are 3.0% daily and no local portfolio threshold.

### 6. Medium: entry-only filters can defeat protective management and exits

`OnTick` returns at line 384 on rollover or spread before break-even and the
DeMarker/SSL exit at lines 386-396. Those no-trade conditions govern entries,
not whether an existing position remains protected.

## Independent verification

- Current EX5 size is 395,494 bytes, matching the source artifact.
- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_142650.json`.
- Five active magic rows are collision-free and present once each in the
  generated resolver.
- All five backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

No Gemini implementation, setfile, registry, work item, or pipeline state was
changed.
