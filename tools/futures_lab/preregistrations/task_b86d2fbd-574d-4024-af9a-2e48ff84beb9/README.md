# Futures preregistration — task b86d2fbd-574d-4024-af9a-2e48ff84beb9

Status: **FROZEN BEFORE FUTURES ECONOMIC RESULTS**. This is a separate,
futures-only research specification. It is not a profitability claim, an MT5
Strategy Card, a Q-gate result, a provider selection, a challenge purchase, or
live authorization.

## Frozen experiment

- Two hypotheses, five arms, and no implicit sixth arm. Unused capacity below
  the six-arm ceiling is not permission to add a result-driven variant.
- Source-grounded family: Zarattini/Aziz QQQ five-minute opening-range breakout,
  translated explicitly—not claimed as an exact replication—to raw CME equity
  index futures.
- QM-authored family: one fully specified MES failed-breakout reversion arm,
  labelled `NONE_QM_AUTHORED` for external-source claims.
- MES comes first. MNQ is released only after technical data-quality checks;
  MES economics cannot control that release.
- Signal and fill identities remain separate: MES→MES, ES→MES, MNQ→MNQ, and
  NQ→MNQ. Every runtime symbol must be a verified individual quarterly raw
  contract. Continuous/back-adjusted series and `.DWX` aliases cannot satisfy
  the contract.
- Every scheduled arm/session is retained as `TRADE`, `NO_SIGNAL`,
  `NEWS_BLACKOUT`, `DATA_INVALID`, `ROLL_EXCLUDED`, or `RISK_SKIP`. A zero-trade
  session cannot disappear from cadence or coverage denominators.

The fixed windows are development 2019-06-03..2022-12-30, locked validation
2023-01-03..2024-12-31, and a historical context test
2025-01-02..2026-09-18. The latter is explicitly **not untouched** because
related CFD folds were already viewed. The only untouched market holdout is
prospective: 2026-09-23..2027-03-31, embargoed from economic access until
2027-04-01.

## Bound prior evidence

The preregistration retains the earlier CFD selection history instead of
resetting it:

- `QM5_1255` (the exact source-card lineage) has Q02/Q03 PASS rows but no
  completed positive Q04 verdict; its Q04 history is INFRA_FAIL/pending.
- Adjacent NQ-origin ORB `QM5_10743` has a real Q04 FAIL on NDX.DWX, with net
  fold PFs 0.98, 1.28, and 0.51 across 165 trades. Its GDAXI.DWX Q04 folds also
  failed (0.95, 0.97, 1.34; 528 trades).
- The related stocks-in-play index-CFD port `QM5_10334` has Q02 FAIL rows on
  NDX.DWX, SP500.DWX, and WS30.DWX. Their old summary files are no longer at the
  database paths, so the preregistration binds only the stable row IDs and card
  hash and does not invent metrics.
- The adverse 2026 MNQ falsification paper (arXiv:2605.04004) remains a negative
  prior, not support.

These facts neither prove nor disprove the raw-futures hypotheses. They prevent
the futures pivot from presenting an already selected idea as pristine.

## Reproducible compilation

From the repository root:

```powershell
python -B tools/futures_lab/preregister.py `
  --config tools/futures_lab/preregistrations/task_b86d2fbd-574d-4024-af9a-2e48ff84beb9/preregistration.json `
  --emit-plan tools/futures_lab/preregistrations/task_b86d2fbd-574d-4024-af9a-2e48ff84beb9/trial_plan.json

python -B -m unittest discover -s tools/futures_lab -p "test_preregister.py" -v
```

The compiler produces exactly 60 not-run cells: five arms × four periods ×
three mandatory execution scenarios. It also expands 132 candidate raw
quarterly symbols for definition verification. It never opens market data or
computes a result.

Frozen file hashes:

- `preregistration.json`:
  `a91938e318e7ce5948a9b87949ae22b27af1ea3491f3d4723880385d123bea02`
- `trial_plan.json`:
  `4ffae4eea06f490e1a9762cfbe9ccd5e4ff21c80ffe98377ecf4758aafc80827`

## Fail-closed dependencies

No economic run is currently actionable. Licensed raw definitions/status/
trades/MBP-1, an exact definition-verified roll roster, a dated CME calendar,
complete hash-bound news calendars, provider-bound costs, native-platform
parity, and completion of the prospective holdout remain explicit gaps. A
fixture, CFD history, continuous contract, missing calendar, or unquoted cost
cannot fill any of them.
