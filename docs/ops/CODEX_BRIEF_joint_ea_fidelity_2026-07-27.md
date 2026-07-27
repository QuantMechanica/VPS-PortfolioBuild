# Codex brief — why does the joint EA diverge 8.5% from the gated sleeve?

Date: 2026-07-27
Priority: high. A workflow agent was assigned this and died mid-run; nothing was produced.

## The failure

QM5_20180 is a backtest-only joint FTMO EA. Replaying **sleeve 0 alone** against the
gated QM5_9936 stream, same window, matched commission, produced:

```
match_rate = 0.914741      3 extra trades, 107 unmatched joint, 104 unmatched gated
```

Required 1.0. The gate refused and the run was correctly stopped
(`docs/ops/evidence/2026-07-27_joint_backtest_run_EXECUTED.md`). The build documentation
predicted BYTE-IDENTICAL results for sleeve 0 because it uses the default QM_Entry path.
That prediction is refuted, and why matters far beyond this EA.

## Already eliminated — do not re-derive

- **Sizing mode is not the cause.** Both the joint set files and the gated 9936 backtest
  set carry `RISK_FIXED=1000` with `RISK_PERCENT=0`. Fixed money risk is already in
  force, so equity-dependent position sizing cannot explain the drift.
- **Magic allocation is not obviously the cause.** Each sleeve has its own registered
  slot magic; sleeve 0 opens through the default path with `explicit_magic=0`.

## Still to eliminate — one is a real asymmetry

- The joint set carries `qm_risk_cap_pct=1.0`; the gated 9936 set does **not** carry the
  key at all. The framework default at `QM_Common.mqh:182` is also 1.0, so this *should*
  be a no-op. Prove it is, or find that it is not. Do not assume.
- Indicator warm-up, bar indexing, shift-0 vs shift-1 reads, session/time handling,
  parameter binding from the gated set, the news filter's `symbol_slot`, per-symbol state
  arrays, the equity sampler perturbing execution, or a differing starting balance.

## What to establish

1. **WHICH trades differ**, categorised with counts: extra, missing, same trade at a
   different price or size, different exit. Read
   `tools/strategy_farm/compare_joint_replay.py` FIRST and confirm what "match" means to
   it — a comparator artifact is a live hypothesis and must be ruled out before the EA is
   blamed. 107 unmatched joint against 104 unmatched gated with only 3 extra suggests
   most are the *same* trades failing a matching predicate, which would point at the
   comparator or at a small price/time offset rather than at signal logic.
2. **WHERE it starts.** From the first trade, or after a specific event? A divergence
   with a start date points at history or state; one spread evenly points at logic.
3. **THE MECHANISM**, named and evidenced.
4. **IS IT FIXABLE?** Answer plainly. If a gated sleeve's behaviour cannot be reproduced
   outside its own EA, say so in those terms — it would mean every plan to extract sleeve
   logic into a shared module is unsound, which is a far larger finding than this EA.

## Constraints

- Prefer static analysis and existing artifacts. Do NOT run a backtest unless a terminal
  is genuinely free — check `python tools/strategy_farm/farmctl.py mt5-slots`, and never
  take T5 (disabled) or T9 (reserved).
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; never `C:/QM/mt5/T_Live`.
- Do NOT tune anything to make the match rate rise. The gate exists to catch exactly that.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

`docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`
