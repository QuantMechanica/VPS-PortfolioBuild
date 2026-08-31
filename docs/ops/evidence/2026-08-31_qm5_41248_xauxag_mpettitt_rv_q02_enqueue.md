# QM5_41248 XAU/XAG Pettitt Ratio Reversion Q02 Enqueue

Date: 2026-08-31

Branch: `agents/board-advisor`

## Outcome

The OWNER commodity/energy mission produced one new, source-approved,
non-duplicate market-neutral-style sleeve. `QM5_41248_xauxag-mpettitt-rv`
passed source-fresh Q01 compilation and was enqueued exactly once into Q02 as
pending logical-basket work item
`456f5bc8-86ed-4706-b4e4-c9fcf86373c3`.

The basket manifest selected only
`QM5_41248_XAU_XAG_MPETTITT_RV_D1 / D1`. The physical XAU and XAG presets
were both skipped with `basket_manifest_logical_setfile_preferred`; no
standalone-leg fan-out occurred.

No manual backtest, dispatch tick, live action, portfolio-gate change,
certification claim, or correlation claim was made. Q09 remains the only
authority for realized portfolio overlap.

## Edge And Non-Duplicate Boundary

At the first eligible broker-month transition, the EA reconstructs thirteen
consecutive synchronized completed month-end
`ln(XAUUSD.DWX)-ln(XAGUSD.DWX)` ratios. It assigns strict ranks, computes all
twelve Pettitt cumulative rank sums, requires one unique maximum absolute sum
at a central split `K=4..9`, and fades the detected level shift with opposite
equal-target-notional XAU/XAG legs for the next broker month.

This is mechanically distinct from the certified long-only two-day XNG
oscillator pullback (`QM5_12567`), the outright XAU sleeve, XTI/XNG Pettitt
ratio reversion (`QM5_41175`), fixed-split XAU/XAG Mann-Whitney reversion
(`QM5_41177`), and magnitude-retaining XAU/XAG centered CUSUM reversion
(`QM5_41247`). The fail-closed preallocation scan found no exact identity
across 4,747 registry identities, 1,385 cards, and 45 Strategy Wiki nodes.

Canonical dedup receipt:
`artifacts/qm5_xauxag_mpettitt_rv_preallocation_dedup_20260831.json`, SHA-256
`86E98E01358C6CCA8B016DBDE45E4D206C49BEAB0A4672496E057321830E1FF9`.

## Source And Governance

- Source approval: commit `f00319dfd0`.
- EA identity reservation: commit `2cf43df24e`.
- G0-approved Strategy Card: commit `72ae8d18b5`.
- Deterministic two-slot magic allocation: commit `4c269458d6`.
- EA, SPEC, manifest, reference fixtures, and fixed-risk presets: commit
  `ada75eb489`.
- Source-fresh binary and sealed setfile hashes: commit `2fc3dd2a74`.

The bounded source packet combines peer-reviewed state-dependent gold/silver
relationship evidence, official CME carrier research, Pettitt's named
peer-reviewed change-point lineage, and complete pinned public method files.
The exact thirteen-month central-band contrarian basket remains an explicitly
pre-result QM translation.

## Q01 Evidence

- Governed compile work item:
  `e17d6ea5-d1f0-4a78-acf3-3a7fe6255cfa` on T9.
- MetaEditor: PASS, 0 errors, 0 warnings.
- Strict build check: PASS; failure classes empty.
- MQ5 SHA-256:
  `F338EE8456020192B930F772A403EC8C59F71BFA2A28186A21F95F610AF0587B`.
- EX5 SHA-256:
  `7C75EF52288986FC354782FD3C6DE39C2523580CC1C0844D3DD636E12DBAD69F`.
- Compile-evidence SHA-256:
  `76DCE8BC03D25E451BB8DEB9B375C6B1FA0B21FAB780474A44FD582908457CC0`.
- Logical setfile SHA-256:
  `F29CD3C3636C1C5B5F5CBC2B1F027A022F3E29F5F0EF6835E06F8FEFBA2FE47C`.
- Basket-manifest SHA-256:
  `770518E796CA43E68F84D28A1E3F6E86952F7F779F7C4E83BAFFDD3CDC428BA4`.
- P1 artifact validation: PASS.
- Independent reference suite: 7/7 PASS.
- Canonical and local card schema lints: PASS and byte-identical.
- Build prerequisite guard, raw-MQ5 quarantine, SPEC validation, and scoped
  static guardrails: PASS.

All three backtest presets lock `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The basket manifest makes only the logical preset Q02
eligible.

## Paced Q02 Enqueue

The five-sample whole-host window immediately before `record-build` was
`56.1788%`, `56.0503%`, `56.5527%`, `49.9331%`, and `51.7871%` (average
`54.1004%`, maximum `56.5527%`). Every sample was below the 97% hard ceiling.

The canonical basket-aware build recorder created exactly one row:

- work item: `456f5bc8-86ed-4706-b4e4-c9fcf86373c3`;
- readback: pending, attempt 0, unclaimed, no verdict;
- logical symbol / timeframe:
  `QM5_41248_XAU_XAG_MPETTITT_RV_D1 / D1`;
- host: `XAUUSD.DWX / D1`;
- component symbols: `XAUUSD.DWX`, `XAGUSD.DWX`;
- window: `2018.07.02` through `2024.12.31`;
- tester currency/deposit: USD / 100000;
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- multisymbol timeout: 450 minutes;
- custom-history archive admission: ACTIVE, 216 selected rows; and
- priority track: true.

This session enqueued but did not manually dispatch or execute the row.

## Safety Boundary

AutoTrading was not toggled. `T_Live`, its manifest, deploy manifests, the
portfolio gate, portfolio admission, and certification state were untouched.
The artifact establishes a new testable precious-metals relative-value sleeve,
not performance, neutrality, or realized decorrelation.

Machine-readable receipts:
`artifacts/qm5_41248_build_result_20260831.json` and
`artifacts/qm5_41248_xauxag_mpettitt_rv_q02_enqueue_20260831.json`.
