# Codex review: QM5_37005 Gemini build

- Review task: `8d44760b-92f8-40d2-a54e-da5317ad4577`
- Gemini source task: `98fb1997-3c5d-4bfa-af26-6f46dd7c8a1b`
- Source artifact: `C:/QM/repo/artifacts/builds/98fb1997-3c5d-4bfa-af26-6f46dd7c8a1b.json`
- Reviewed tree HEAD: `59467c41c4e53ec72c6731c0378dc0f8c13c1e73`
- MQ5 SHA-256: `12dd519d1493d732d093e7d613dde5c6c63c5ff7fe0102037e4a61f1aa754e1f`
- Fresh EX5 SHA-256: `24552679e230ad968363a8afd13972d880a422ea74eb279869f8fdbc31ab7709`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. High: invalid midline targets are replaced by an unauthorized 1R TP

The approved exit target is the 20-period Bollinger/SMA midline. Lines 143-159
substitute `ask + sl_dist` or `bid - sl_dist` when the midline is not beyond the
current quote. That turns the trade into a fixed 1R payoff the card never
authorizes. The implementation should reject an invalid target or obtain an
approved rule.

### 2. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path uses 3.0% daily and 0.0% portfolio drawdown instead.

### 3. High: the reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, rebuilt binary, and producer result.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 388,558 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_152823/QM5_37005_chan-bollinger-adx-mean-reversion.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and one call-graph warning;
  report `D:/QM/reports/framework/21/build_check_20260818_152945.json`. The
  warned one-bar `CopyRates` call is in `Strategy_EntrySignal`, which is invoked
  only after `QM_IsNewBar()`.
- Three active magic rows are collision-free and represented by the current
  generated-resolver hash.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON satisfies the static build-result criteria but supplies no
  smoke summary (`smoke_result=deferred_p2_smoke`); no runtime or pipeline
  verdict is inferred.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, work item, terminal,
AutoTrading, or pipeline state was changed.
