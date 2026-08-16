# QM5_41031 XAU/XAG Gold-Lead Catch-Up Build And Q02 Enqueue

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41031_xauxag-goldlead` is a new low-frequency XAU/XAG relative-value
candidate. At each synchronized D1 boundary it computes exactly one completed
log return per metal. A gold return of at least 75 basis points in absolute
value may lead only when silver has moved strictly less than half as far in
gold's direction and has not moved farther in absolute terms. An upward gold
lead sells XAU and buys XAG; a downward lead buys XAU and sells XAG. The
equal-notional opposite-leg package closes at the first following XAU D1
boundary.

Krawiec and Gorska (2015), *Granger Causality Tests for Precious Metals
Returns*, report daily gold-to-silver predictive ordering and an adverse
reverse-direction result for 2008–2013 London USD prices. They do not report
coefficient signs or a trading rule. The same-direction catch-up, threshold,
response cap, CFD symbols, sizing, and lifecycle are disclosed QM
falsification choices. Schweikert (2018) supplies adverse evidence against a
constant universal gold/silver equilibrium; CME supplies carrier support.
No source return, profitability, neutrality, CFD equivalence, or portfolio
correlation transfers.

Opposite equal-notional legs reduce first-order common-metal intent. They do
not prove beta, volatility, dollar, factor, market, or portfolio neutrality.
Q09 alone may establish realized overlap with the certified XAU/SP500/NDX/XNG
book after the candidate survives earlier gates.

## Governance, Allocation, And Non-Duplicate Boundary

- Source approval commit: `f4aa2f4c7`.
- Deterministic EA-ID reservation commit: `af21130fe`.
- Strategy Card and OWNER G0 commit: `d490f1a8d`.
- Pre-magic directory identity commit: `3244bb502`.
- Two-magic registration/resolver commit: `47b1395d7`.
- Q01 build commit: `873e153c9`.
- Registered slots are XAU slot 0 / magic `410310000` and XAG slot 1 /
  magic `410310001`.
- The deterministic checker scanned 4,518 registry rows and 614 root cards
  with no exact or fuzzy match.
- Manual review separated ratio/residual reversion, five-return run fade,
  variance-ratio memory, monthly cross-sectional/seasonal systems, and
  `QM5_41030` weekly information-time flow disagreement. This mechanic has no
  ratio level, fitted center, regression, run, open-price flow split, weekly
  aggregation, Monday selector, or Friday ordinary lifecycle.
- Verdict:
  `CLEAN_XAUXAG_ASYMMETRIC_GOLD_LEAD_SILVER_CATCHUP_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Logical carrier: `QM5_41031_XAU_XAG_GOLDLEAD_D1`, hosted on exact
  `XAUUSD.DWX` D1 with companion `XAGUSD.DWX`.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes are OFF.
- The package targets equal absolute USD notionals within 20%, rounds both
  volumes down, and caps combined frozen-stop risk at one fixed-dollar
  budget. Each leg uses a frozen `3.0 * ATR(20,D1)` hard stop and no target.
- Independent reference suite: 13 tests PASS for synchronized endpoints,
  threshold and strict-response boundaries, both directions, silver-lead and
  invalid-state rejection, entry grace, date identity, joint sizing, and the
  first-next-D1 lifecycle.
- All three Strategy Card copies are byte-identical and pass card/schema/ML
  lint. The seven-section spec, basket manifest, and fixed-risk set identity
  pass.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260816_211706/QM5_41031_xauxag-goldlead.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_211706.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41031/P1/P1_QM5_41031_result.json`.
- No smoke, manual tester, or pipeline phase runner was invoked.

## Capacity And Target-Only Queue Mutation

All samples counted only `terminal64.exe` processes whose executable path
matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. `T_Live`, FTMO, and
other terminals were excluded.

- Initial sample at `2026-08-16T21:19:41.9323592Z`: 4/7, T1/T2/T3/T5.
- Immediate pre-apply sample at `2026-08-16T21:24:17.0796372Z`: 2/7,
  T7/T9.
- Post-enqueue sample at `2026-08-16T21:24:40.3389685Z`: 2/7, T7/T9.

The basket-aware target-only dry run selected exactly one never-tested Q02
row and zero stranded/recovery rows:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41031 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The same scoped selection was applied once:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41031 --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Immediate readback found exactly one matching row:

| Field | Value |
|---|---|
| Work item | `2b31ad53-2ac1-4410-81bd-d1a3e499ac23` |
| Phase / kind | `Q02` / `backtest` |
| Logical symbol | `QM5_41031_XAU_XAG_GOLDLEAD_D1` |
| Host | `XAUUSD.DWX` / D1 |
| Basket symbols | `XAUUSD.DWX`, `XAGUSD.DWX` |
| Created | `2026-08-16T21:24:22+00:00` |
| Observed status | pending, unclaimed |
| Attempt / evidence / verdict | 0 / none / none |

Two legacy `farmctl enqueue-backtest` probes failed closed before mutation
because fresh Q02 is not a cascade/rerun path. A `build-ea` preflight also
returned `written=false` because the governed card lives in the current
repository card topology rather than the legacy farm-card directory. The
scoped built-EA sweep is the current precedent for new branch builds. The
pre-enqueue work-item count was zero and the post-enqueue count was one.

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`f0dced6f9d9bb3406ecf26363b504a579e69b75c53c079983cb45b717618255b`
at immediate readback.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `589521e4727be9a674662354b75a23af85d1d6f4ae9cbb404bfbacbe0c766ea2` |
| G0 decision | `397fce7f8b851f5a6435ee3f31ae962c619e67ef1e371ab34b1459c61685ce3d` |
| governed source packet | `a2ba7247c1bdd05ae0b19cb0094a32db499d6f5dc83666c5e91d55fe5522c484` |
| each synchronized Strategy Card | `e62c36230c31cb8c5ab7d7d6bc08fb951f79d81d4b93a21c148f25796ab422aa` |
| MQ5 | `21a76b522c7de4e491a9efca83d997718c64cfa1657e4836cf3afec3cbcf0783` |
| EX5 | `5f331a313ce4b4c4b81276d985b3363e52b4dda9098e388ea41deaf7834e713e` |
| SPEC | `f8f8b1650c74e59644147522757b5666f14e273ad73b44c36399d39ceffd6ad8` |
| basket manifest | `b03336f04201370949714eb865bff28343e61a16fbe46b6a1d9b71a3ac2817b6` |
| fixed-risk setfile | `d054ad391e21efa06e6046e6e5007652a8b7d94d49de8ae300a172809938ca39` |
| reference suite | `d4ade16fdf63dc0fe685ed46e263b3d44541a22a2eae9e5951d69ffe17cfeb3d` |
| build-check report | `558737eb9177667198b11f6ac0af04357938fc9a3777901fb9c8ab4e6e812bba` |
| static P1 result | `f5fe16f82a6e85af7b507582b27fe98fb07160f02d1c25f48a1d6784a8ada79f` |

## Safety And Handoff

No manual backtest, smoke test, dispatcher tick, terminal start/stop,
reservation change, AutoTrading action, `T_Live` action, live/demo/shadow/
stress/optimization preset, deploy or T_Live manifest, portfolio-gate edit,
portfolio admission, or correlation waiver occurred.

Q02 must retire on zero trades, fewer than five completed logical packages
per full post-warm-up year, unsynchronized or current-bar endpoints, silver
leadership, wrong thresholds/sides, repeated or late entry, aggregate risk or
notional breach, orphan survival, wrong lifecycle, nondeterminism, invalid
risk mode, or nonpositive governed economics. This receipt records an
enqueue, not a Q02 verdict, certification, profitability result,
decorrelation finding, or portfolio admission.
