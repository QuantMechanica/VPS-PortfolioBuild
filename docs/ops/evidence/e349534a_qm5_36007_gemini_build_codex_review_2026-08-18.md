# Codex review: QM5_36007 Gemini build

- Review task: `e349534a-89d0-4640-b7d5-48761fd3b5f3`
- Gemini source task: `a7acf60d-9f28-4cfc-a080-061eb3aaedb9`
- Source artifact: `docs/ops/evidence/a7acf60d_qm5_36007_build_ea_result_2026-08-17.md`
- Reviewed tree HEAD: `07a691f79257a7f798b129f674e800769de5269b`
- Source SHA-256: `8aa76ddc81354f9885b2e06af0c8296ad2600beca517d378f8823ada6619f8a2`
- Fresh EX5 SHA-256: `1697c53bb1be220da295e39a8854095e0cd3128b9dcd3cf6402327d2e0e9464a`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested review skills are unavailable. Codex independently
reviewed the approved card, implementation, binary, and focused V5 checks.

## Findings

### 1. Critical: TP1 closes the complete position, leaving no runner

The card requires a 50% close at +1 ATR, break-even protection, and a remaining
TRIX runner. Lines 250-277 attach a +1 ATR broker TP to the entire order and no
partial-close operation exists. Break-even is triggered at the same level at
lines 292-329, so the full TP normally removes the position before the runner
or TRIX exit can operate.

### 2. High: the producer's strict build-check claim is false

Fresh strict `build_check.ps1 -SkipCompile` rejects eight unreviewed raw-series
calls at lines 76, 105, 123, 133, 162, 168, 169, and 175. Report:
`D:/QM/reports/framework/21/build_check_20260818_150606.json`. The source
artifact is prose Markdown rather than canonical build-result JSON, so its
claimed PASS cannot provide the required machine fields.

### 3. High: the full TRIX history is recomputed on every tick

`Strategy_ExitSignal` runs the multi-stage TRIX warmup at lines 339-341, and
`OnTick` invokes it at line 401 before the new-bar gate at line 423. The D1
history walk therefore repeats for every incoming tick while a position is
open.

### 4. High: GMT and drawdown contracts are not implemented

Lines 190-193 evaluate raw broker time as the required GMT rollover window.
The EA also omits the card's 2.0% daily realized-loss entry halt, 2.5% daily
hard stop, and 5.0% total-drawdown stop.

### 5. Medium: entry-only filters suspend protection and the TRIX exit

`OnTick` returns on rollover or expanded spread at line 397 before break-even
and rule-exit handling at lines 399-411. Existing exposure can consequently be
left unmanaged by a filter intended only to block entries.

### 6. High: the reviewed build is untracked

The MQ5, EX5, SPEC, and setfiles have no committed identity in the canonical
checkout. The build must remain in review until the authorized close-out path
binds repaired source and binary hashes.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 395,408 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_145929/QM5_36007_nnfx-vidya-trix-fisher-momentum.compile.log`.
- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, eight failures, zero warnings.
- Three active magic rows are collision-free and present in the resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 only. No Gemini source,
setfile, registry, work item, terminal, AutoTrading, or pipeline state was
changed.
