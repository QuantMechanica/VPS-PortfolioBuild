# Q04 — fifth (and final-plumbing) root cause: commission mechanism never wired

**Found:** 2026-05-29 (interactive senior-agent session), after the first four Q04
bugs were fixed and the runner finally executed end-to-end.
**Status:** Diagnosed with evidence. **NOT auto-fixed** — this is gate-correctness +
evidence-integrity work (commission directly sets PF-net, the entire point of Q04), not a
mechanical patch. Needs an OWNER decision on the commission source, then a verified
implementation.

## Where we are

The Q04 graveyard had FIVE stacked causes. The first four are fixed and live:

1. phase-name `P3`/`Q03` lookup mismatch — `26fb4fdb` (needs worker restart; done 2026-05-29).
2. `sys.path` off-by-one (`parents[1]`→`[2]`) crashing `import framework` — `9c1427eb` (live).
3. dispatcher passed P-era `--out-prefix`/`--period` to Q-runners — `a8c1da38` (needs restart; done).
4. UTF-8: runner `print()`s `->` (U+2192) and cp1252 stdout crashed it — `684058d5` (live).

After (1)–(4) + worker restart, Q04 **produces real verdicts for the first time ever**
(e.g. `work_item 75fd6cf9` QM5_10569 EURJPY → `done`/FAIL, aggregate.json written). But
every fold returns `exit_code: 1`, `summary_path: null`, `trades: 0`, and the whole
"3-fold walk-forward" completes in ~2 seconds — i.e. the per-fold MT5 run never starts.

## Root cause #5 (code)

`framework/scripts/q04_walkforward.py :: run_fold_via_smoke` (≈ line 137) invokes
`run_smoke.ps1` with:

```
-CommissionPerLot 7.0      # line 153
```

`framework/scripts/run_smoke.ps1` is `[CmdletBinding()]` with a fixed `param()` block
(lines 2–30) that does **not** declare `-CommissionPerLot`. CmdletBinding rejects unknown
named parameters → PowerShell aborts before doing anything → `exit 1` in ~2s → no
summary.json → fold `trades=0`/FAIL. `-CommissionPerLot` is passed *only* by Q04 and is
consumed by **nothing** in the repo (`grep -rn CommissionPerLot` = one hit, the call site).

## The deeper gap — commission is not applied to the spec

Removing the bad arg is NOT a correct fix. `run_smoke.ps1` has **no commission handling at
all**. Commission in the MT5 tester comes from the per-server groups file:

`D:\QM\mt5\T*\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt` (UTF-16 LE BOM) — present,
and it configures:

```
CommissionSymbol=Forex\*            CommissionValue=2.5000  CommissionType=1 CommissionMode=1 CommissionCharge=2
CommissionSymbol=Indices\Index 1\* CommissionValue=0.3500  ...
```

So the tester DOES apply a commission — but **Forex 2.5 / Indices 0.35**, which does NOT
match the Q04 spec's locked **$7.00/lot round-trip** (`COMMISSION_PER_LOT_ROUND_TRIP = 7.00`,
q04_walkforward.py:55, "locked by Vault Q04 spec"). There is a genuine inconsistency between
the spec value the runner *intends* and the value the terminal *actually applies*.

Per the Hard Rule (no invented commission/swap values; documented commission source) and the
T1–T10 test-environment ownership process, this must be reconciled deliberately, not guessed.

## Decision required (OWNER), then implementation

**Q1 — what is the correct Q04 commission?**
- (a) The Vault Q04 spec value **$7/lot round-trip** is authoritative → generate/point a
  Q04 groups file at $7/lot (round-trip) and apply it for the fold backtests; OR
- (b) The Darwinex-Live_real groups values (Forex 2.5 / Indices 0.35) are the real broker
  cost → the Vault Q04 spec's $7/lot is stale and should be corrected to match.

These produce materially different PF-net; the choice changes which EAs survive Q04. It is
an evidence-integrity decision, so OWNER owns it.

**Q2 — mechanism.** Whichever value wins, wire it so the tester provably applies it:
- Option A (clean): `q04_walkforward.py` writes a Q04 tester groups file with the chosen
  commission (per [[reference_mt5_tester_commissions]] format: UTF-16 LE BOM CRLF) and
  `run_smoke.ps1` selects that groups file for the run; OR
- Option B: add `-CommissionPerLot` to `run_smoke.ps1`'s param block and have it patch the
  groups file before launching the tester.
Either way: **drop the bare unknown-arg pass** (it crashes the run today), and **verify**
on one fold that the tester applied the intended commission — capture PF-gross vs PF-net
from the MT5 report and confirm the delta matches `trades * commission * lots`.

## Verification after the fix (per fold)

```
# pick a QM5_10569-class EA known to trade in 2023-2025; run one fold:
pwsh framework/scripts/run_smoke.ps1 -EAId 10569 -Expert QM5_10569 -Symbol EURJPY.DWX \
  -Year 2023 -Terminal T4 -Period H1 -Model 4 -SetFile <q03 plateau set> -Runs 1
# expect: trades > 0, a tester report written, PF-net < PF-gross by the commission delta.
```

The `phase_infra_graveyard` canary (commit `07cea03f`) will stay GREEN through this because
Q04 now produces real FAIL verdicts (not INFRA_FAIL); track instead via a "Q04 all-folds
trades=0" signal or the first Q04 PASS.

## Note on scope

The same `run_smoke.ps1` contract is used by Q05–Q10 fold runners. Confirm none of them
pass args outside the `run_smoke.ps1` param block once the front line advances.
