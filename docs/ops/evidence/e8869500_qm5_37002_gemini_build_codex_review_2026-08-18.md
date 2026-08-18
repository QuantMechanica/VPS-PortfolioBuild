# Codex review: QM5_37002 Gemini build

- Review task: `e8869500-9153-47dc-bd5d-4ebc884a0ef9`
- Gemini source task: `c0b1b0f0-9945-4aa2-8dc0-43d67c1b1070`
- Source artifact: `D:/QM/strategy_farm/artifacts/build_results/QM5_37002_dual-thrust-asymmetric-range-breakout_build_result.json`
- Reviewed tree HEAD: `07a691f79257a7f798b129f674e800769de5269b`
- Source SHA-256: `ff087004c4d299738890bf65d0c8db94f74109656233a64e3b2fdcbba62661a4`
- Fresh EX5 SHA-256: `2948aaf1c16e41fbb055cc4bc2f75951c7b4a339613d1d151ae2293403297647`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The named router review skills are not installed. Codex reviewed the approved
card, source, producer result, registries, and available checks directly.

## Findings

### 1. Critical: the trigger calculation has same-bar lookahead and the wrong anchor

The card requires today's open plus a range derived from preceding closed
days. `CalculateDualThrust` copies from shift 1, includes `rates[0]` in the
range at lines 91-97, and also uses that same closed bar's open at line 108.
Entry then compares the same bar's close at lines 167-183. At a new D1 bar the
algorithm therefore uses the completed day's high/low to construct a trigger
supposedly known at that day's open, instead of using the current open and N
strictly prior days.

### 2. Critical: pending breakout orders are replaced by next-bar market orders

The approved mechanic places BUY_STOP and SELL_STOP orders at both daily
triggers on the daily open. Lines 150-196 leave `req.price=0`, choose a single
market `QM_BUY` or `QM_SELL` only after a closed-bar comparison, and never
place the paired pending orders. This is a different execution model and trade
population.

### 3. Critical: stop and exit rules do not match the card

The card specifies an opposite-boundary or 0.50-range stop and an end-of-day
market exit. Lines 180/186 instead set a 2 ATR stop. Lines 229-248 exit on a
recomputed opposite trigger or after five full D1 bars; no EOD close exists.
Both downside and holding-period behavior are therefore unauthorized.

### 4. High: the approved drawdown controls are absent

The EA omits the 2.0% daily realized-loss entry halt, 2.5% daily hard stop, and
5.0% total-drawdown stop specified by the card.

### 5. Medium: entry-only filters can suspend mandatory exits

`OnTick` returns on rollover or expanded spread at lines 305-306 before the
opposite-boundary/time exit at lines 310-322. An entry filter can therefore
prevent management of an existing trade.

### 6. High: the reviewed source and binary are untracked

The EA directory has no committed identity in the canonical checkout. No
commit binds the reviewed source hash to the rebuilt binary, so the build must
remain in REVIEW.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 390,866 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_145950/QM5_37002_dual-thrust-asymmetric-range-breakout.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_150632.json`.
- Three active magic rows are collision-free and present in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON is statically schema-clean but defers smoke to Q02; no
  runtime or pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 only. No Gemini source,
setfile, registry, work item, terminal, AutoTrading, or pipeline state was
changed.
