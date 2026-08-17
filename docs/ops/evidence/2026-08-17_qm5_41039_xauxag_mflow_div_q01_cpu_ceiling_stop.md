# QM5_41039 XAU/XAG Monthly Relative-Flow Divergence — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41039_xauxag-mflow-div` is a new low-frequency logical commodity
basket. At the first synchronized `XAUUSD.DWX` / `XAGUSD.DWX` D1 boundary of
a broker month, it reconstructs every completed session in the immediately
prior month plus the preceding month-end close anchor. For each metal it
separately sums prior-close-to-open and open-to-close log returns, subtracts
silver from gold for each component, and reconciles both metal totals and the
relative total within `1e-10`.

The candidate trades only strict relative-component opposition. Positive
session-relative flow against negative overnight-relative flow buys XAU and
sells XAG; the reverse sells XAU and buys XAG. Agreement, exact zero,
nonconsecutive month identity, timestamp mismatch, invalid endpoints, failed
reconciliation, late attachment, or an already consumed month remains flat.
No current-month bar enters either signal sum and no label shifting is
permitted.

Each package targets equal absolute USD notionals, rejects post-rounding
mismatch above 20%, and caps combined frozen-stop risk at one
`RISK_FIXED=1000` budget. Both legs use `3.5 * ATR(20,D1)` hard stops, no
target, and a paired next-month exit with a 40-day stale guard. Friday close
and both news axes are OFF.

The governed packet combines the OWNER-supplied Tier-A Williams price-flow
decomposition with peer-reviewed Schweikert gold/silver state-dependence,
peer-reviewed Moskowitz/Ooi/Pedersen one-month commodity lineage, and CME
gold/silver carrier material. None of those sources tests this exact
conjunction, Darwinex continuous-CFD implementation, package economics, or
portfolio correlation. This receipt records a build, not certification,
profitability, decorrelation, neutrality, or portfolio admission.

## Governance And Non-Duplicate Boundary

- Source approval commit: `cf8667151`.
- Deterministic EA-ID reservation commit: `72a239c18`.
- Strategy Card and OWNER G0 commit: `726e103f4`.
- Pre-magic directory identity commit: `60a5e0b5d`.
- Basket magic registration/resolver commit: `86bf588aa`.
- Q01 build commit: `dfa7db799`.
- Registered routes are slot 0 `XAUUSD.DWX` / magic `410390000` and slot 1
  `XAGUSD.DWX` / magic `410390001`.
- The canonical checker scanned 4,526 EA-registry rows and 623 cards, found
  no exact identity, and raised only `QM5_41030_xauxag-flowdiv` at fuzzy
  score `0.75`.
- `QM5_41030` consumes an exact Monday-Friday formation and exits Friday.
  This identity consumes every session in one completed broker month and
  holds through the next-month boundary.
- Manual verdict:
  `CLEAN_XAUXAG_MONTHLY_RELATIVE_FLOW_DIVERGENCE_AFTER_WEEKLY_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- The only preset is the logical D1 backtest setfile with
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- The basket manifest binds both traded symbols to one logical test identity;
  neither leg is a standalone strategy.
- Independent mechanic suite: 21 tests PASS, covering exact current and
  completed synchronization, month/grace/anchor identity, 15/25 session
  bounds, timestamp order, endpoint validity, both opposition directions,
  agreement/zero states, all reconciliation gates, attempt consumption,
  joint risk/notional rounding, rollback, orphan/rollover, Friday hold, and
  stale repair.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_070502/QM5_41039_xauxag-mflow-div.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_070502.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41039/P1/P1_QM5_41039_result.json`.
- No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
  invoked.

## Binding Capacity Gate

Both samples counted only `terminal64.exe` processes whose resolved
executable path exactly matched `D:/QM/mt5/T1..T10/terminal64.exe`.
`T_Live`, FTMO, and all non-factory terminals were excluded.

- Initial sample at `2026-08-17T07:08:02.2337627Z`: 4/7 active roots — T3,
  T5, T6, and T9; observed host CPU load was 93%.
- The target-only dry run selected exactly one never-tested Q02 row and zero
  stranded/recovery rows:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41039 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

- Binding pre-apply sample at `2026-08-17T07:12:30.8151514Z`: 7/7 active
  roots — T1, T2, T3, T5, T6, T8, and T9; observed host CPU load was 99%.
- The ceiling became binding before the apply step. The helper was not
  invoked with `--apply`; no Q02 work item was inserted.
- The dry run refreshed its rolling planning receipt at
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` but did not
  mutate queue state.

Per the mission stop condition, no apply, enqueue, dispatch, backtest, tester,
or terminal action followed the binding sample.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `eb8a9c48a4359e505f1d813054418127a168dd4330e43463c9fd89d327d246d3` |
| G0 decision | `6404ae8f5aa31275c7a740a3e7dcb65b3b1a008801672e30189842bfc0d87c93` |
| governed source packet | `4eb761cf3f189203e94b33136a5ac761744d1c810b8b813134a2e915f26d3872` |
| each synchronized Strategy Card | `268ce7aef97ed276b5252a30c1850eff45b6c52c225a37d8447a012708d60f96` |
| MQ5 source | `9f3968040e3cb7b1481983dc18952217232b6a33f86c78b6674dae1b1108df12` |
| compiled EX5 | `eef68cda904eefd6a5922fee19033741ff37fac339436446a0953addba1ac93e` |
| strategy spec | `de9ae8f8e91911cf8ad4a80cd62f890a53f3d10dcf6cdd41e0ec3059bb7ef30d` |
| basket manifest | `dd816f83c2f84436b5c762abfee3a3f9bededcc6091aa20282bb4881b38bf096` |
| fixed-risk setfile | `4f4c2044490e2e9a41b2ecf5093325015e89c1d1a87aadd291ff03e863eebe3b` |
| reference suite | `d36b2f2bb3fb75b76413a511fb8702c299de04f6d7ee118afc4fca576be909a7` |
| strict compile log | `3aa4482400b0edbc2f2270c6613f0ae6aa15e76261f2332c736d8b6065e5744d` |
| final build-check report | `bc475031113b571d3608b1fc3c812e1ce60bf32a70a569553d7125b98020d19e` |
| static P1 result | `f75be636ff0e9ae44d7757f55284bbf365f05fe96dff7a47cdbb55e6a81ae297` |

## Safety And Handoff

No queue apply, manual MT5 run, terminal start/stop, worker mutation,
AutoTrading action, `T_Live` access, live/demo/shadow/stress/optimization
preset, deploy manifest, T_Live manifest, portfolio-gate edit, portfolio
admission, neutrality claim, or correlation waiver occurred.

The next authorized action is a fresh exact-path capacity sample, followed
only when below seven by the same one-target dry run and one guarded apply.
Q02 must retire on zero trades, fewer than five completed packages per full
post-warm-up year, wrong month identity/endpoints, timestamp mismatch,
invalid opposition or direction, failed reconciliation, leakage,
late/repeated entry, wrong package lifecycle, nondeterminism, invalid risk
mode, or nonpositive governed economics.
