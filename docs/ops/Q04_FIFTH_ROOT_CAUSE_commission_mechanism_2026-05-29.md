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

## VERIFICATION RESULT 2026-05-29 — groups file CANNOT reach custom symbols (3 backtests)

Implemented the per-run groups-file mechanism in `run_smoke.ps1` (commit 121da873:
`-CommissionPerLot`, writes terminal groups file from pinned canonical, injects an entry
for the symbol) and ran 3 real verification backtests on T1. Result: **commission still
$0** in every case — `Net == GrossProfit + GrossLoss` to the cent (e.g. QM5_10442 EURUSD.DWX
2024 M15: 137 trades, net −31,826.98 = 58,185.06 − 90,012.04). Even an exact-name entry
`CommissionSymbol=EURUSD.DWX` did not apply.

**Root cause (decisive):** the `.DWX` symbols are **Custom symbols** — they live under
`D:\QM\mt5\T*\bases\Custom\{history,ticks}\<SYM>`, NOT under `bases\Darwinex-Live\`. The
groups file `Profiles\Tester\Groups\Darwinex-Live_real.txt` governs the *Darwinex-Live
server* symbols; the tester does **not** apply it to Custom symbols. Commission for a custom
symbol is governed by the **custom-symbol specification** (set at `CustomSymbolCreate` /
`CustomSymbolSetInteger(SYMBOL_TRADE_*)` / commission fields), which defaults to 0. So the
groups-file approach is the wrong mechanism for our universe; the fix must set commission on
the custom symbol itself (or regenerate the custom symbols with the commission spec). This
is MT5-internals R&D — hand to a focused Codex/MT5 loop, not the Claude quota.

`run_smoke.ps1`'s `-CommissionPerLot` scaffolding (121da873) is harmless and correct to keep
(stops the argparse crash; writes a valid groups file; right hook once the mechanism is
known), but it does NOT yet apply commission to custom symbols.

### Two further bugs found while verifying (the chain continues past #5)

- **#6 expert-path:** `q04_walkforward.py:140` (and q05:80, q07:70) pass the bare EA label
  as `-Expert` (e.g. `QM5_10042`), but MT5/run_smoke need `QM\<full-ea-dir>` (e.g.
  `QM\QM5_10042_ff-notable-numbers`, per `p2_baseline.py:116`). Bare label →
  `deploy_skip=non_canonical_expert_path` → no `.ex5` deployed → `REPORT_MISSING`. Q02/Q03
  avoid this via `p2_baseline.find_ea_dir`. Fix: resolve the dir (glob `framework/EAs/<ea>_*`)
  and pass `QM\<dir.name>`. **Not yet applied** — applying it alone would make Q04 emit
  cost-free (misleading) verdicts, so hold until commission works.
- **#7 hardcoded period:** `q04_walkforward.py:144` forces `-Period H1` regardless of the
  EA's tuned timeframe; an M15 EA (QM5_10042) produced **0 trades** on H1. Folds should run
  on the EA's own period.

## MAJOR FINDING 2026-05-29 — commission has NEVER been applied to .DWX symbols

Verified from real MT5 reports (not inference): across 6+ recent backtests with trades,
`Total Net Profit == Gross Profit + Gross Loss` to the cent — i.e. **commission + swap =
$0 in every case**. Examples: EURUSD 138 trades net −23,777.55 = 60,305.48 − 84,083.03;
448 trades residual 0.00; etc. The shared `Darwinex-Live_real.txt` commission entries are
keyed to broker symbol *paths* (`Forex\*`, `Indices\Index 1\*`, …) that the **custom
`.DWX` symbols do not match**, so no entry ever applied.

Consequences:
- **The whole pipeline funnel to date is gross-of-costs.** Every Q02 (104) and Q03 (56)
  PASS was computed with zero commission AND zero swap. Q02's `PF>1.30` gate is therefore
  more lenient than intended; some PASSes will not survive realistic costs.
- The fix is not "override Forex 2.5 → 7" — it is "make the tester apply commission to
  custom symbols *at all*," which means a groups entry that MATCHES the `.DWX` symbols.
- The MT5 commission-field encoding (`CommissionMode/Type/Charge/Value`) **cannot be
  calibrated from existing data** (current applied commission is $0) — it requires ONE
  measured backtest: set a candidate entry, run a fold, read the report's commission, and
  scale `CommissionValue` until `commission_total ≈ trades × $7 × lots` (round-trip/lot).

## Refined implementation spec (for Codex task f308fe3f)

1. Pin canonical real groups file — DONE: `framework/registry/tester_groups/Darwinex-Live_real.canonical.txt`.
2. `run_smoke.ps1`: add `[double]$CommissionPerLot = 0`. Before launching the tester, write
   `<TerminalRoot>\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt` from the canonical
   (UTF-16 LE BOM, CRLF). If `$CommissionPerLot -gt 0`, ALSO inject a high-priority entry
   that matches the custom symbols — start with `CommissionSymbol=*` (or the exact tested
   symbol, e.g. `CommissionSymbol=EURUSD.DWX`) using a money-per-lot encoding at the value
   that yields $7/lot round-trip. If `=0`, the canonical restore keeps Q02/Q03 unchanged
   (still cost-free today — see "open question" below). Per-terminal, per-run write is
   race-free because the worker owns the terminal for the run.
3. Keep `q04_walkforward.py` passing `-CommissionPerLot 7.0` (already does, line 153).
4. **Calibrate with ONE real fold** on a known-trading FX EA (e.g. QM5_10042 GBPUSD.DWX):
   read the MT5 report commission, confirm `≈ trades × $7 × lot-size`. Adjust the encoding
   (per-side vs round-trip; money-per-lot mode) and re-run until correct. Capture the report
   as evidence.
5. After verified: bulk re-queue the ~3,900 Q04 INFRA_FAIL + trades=0 items so the real
   Q03-PASS cohort flows through Q04 with commission.
6. Beware: `q04_walkforward.py:144` hardcodes `-Period H1` regardless of the EA's tuned
   timeframe — verify this is intended for the walk-forward, else folds may mis-trade.

**Open question for OWNER (separate, larger):** should Q02/Q03 also apply realistic costs,
or are they intentionally gross screens with Q04 the first cost-aware gate? Today they are
cost-free by accident, not design. If gates 2-3 should be cost-aware, the same groups
mechanism applies to them and the current PASS cohort must be re-run.

## Decision required (OWNER), then implementation

**DECISION 2026-05-29 (OWNER): option (a) — the Vault spec $7/lot round-trip is
authoritative.** Implement a Q04 commission of $7.00/lot round-trip and apply it provably
in the tester; do NOT adopt the Darwinex-Live_real.txt 2.5/0.35 values for Q04. Implementation
proceeds on OWNER go (needs a real MT5 verification fold).

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
