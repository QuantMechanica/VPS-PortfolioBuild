# Codex review: QM5_36008 Gemini build

- Review task: `c57623a2-30ff-4264-9839-f7093e815695`
- Gemini source task: `bab6e8bf-435d-4da2-a25f-1e651cb33960`
- Source artifact: `D:/QM/strategy_farm/artifacts/build_results/QM5_36008_nnfx-gold-kama-vortex-supertrend_build_result.json`
- Reviewed tree HEAD: `07a691f79257a7f798b129f674e800769de5269b`
- Source SHA-256: `c9faa5180f432da511b2461f8638164dacc0ddbbe69b68228649cb2231d233b5`
- Fresh EX5 SHA-256: `a800cd130c9532c4f117310ed29916d4cbc7e920fd66f64a51165346679943e2`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The task-named review skills are not installed, so Codex reviewed the approved
card, current implementation, producer result, and V5 checks directly.

## Findings

### 1. Critical: the approved 50% TP1 and protected runner are absent

The card requires banking 50% at +1 ATR, moving the remainder to break-even,
and holding that runner for the KAMA exit. Entry lines 265-285 set only an SL,
leave `req.tp` at zero, and `Strategy_ManageOpenPosition` is empty at lines
288-290. There is no partial close, TP1, or break-even transition at all.

### 2. High: an unauthorized Vortex exit shortens the KAMA runner

The approved runner exits on an opposite KAMA cross. Lines 325-335 additionally
close whenever the Vortex directions reverse. That extra exit is not in the
card and changes the runner population and holding distribution.

### 3. High: the short WAE rule is replaced by a signed-momentum rule

Both card entry equations require `WAE > ExplosionLine`. Lines 174-193 create
a signed WAE result, and short entry line 263 requires `wae == -1`. That
directional substitution is not specified by the approved short equation and
changes which short signals qualify.

### 4. High: a large KAMA vector is rebuilt on every open-position tick

Exit lines 316-323 recalculate KAMA from a 171-bar vector. `OnTick` calls the
exit at line 398 before the new-bar gate at line 420, so the full warmup and
nested KAMA loop run repeatedly on every D1 tick instead of once per closed
bar.

### 5. High: the approved drawdown controls are absent

The EA does not implement the card's 2.0% daily realized-loss entry halt, 2.5%
daily hard stop, or 5.0% total-drawdown stop. Generic framework initialization
does not prove those thresholds.

### 6. Medium: entry-only filters can suspend the KAMA exit

`OnTick` returns on rollover or expanded spread at lines 393-394 before the
rule exit at lines 398-410. A no-entry filter is therefore allowed to leave an
existing position unmanaged.

### 7. High: the reviewed build has no committed source/binary identity

The complete EA directory is untracked in the canonical checkout. No commit
binds this source hash to the rebuilt EX5, so it is not eligible for acceptance
or pipeline handoff.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 396,472 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_145904/QM5_36008_nnfx-gold-kama-vortex-supertrend.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_150627.json`.
- Two active magic rows are collision-free and present in the generated
  resolver.
- Both backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON is statically schema-clean but defers smoke to Q02; no
  runtime or pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 only. No Gemini source,
setfile, registry, work item, terminal, AutoTrading, or pipeline state was
changed.
