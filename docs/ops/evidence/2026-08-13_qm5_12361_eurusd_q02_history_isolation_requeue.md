# QM5_12361 EURUSD Q02 History-Isolation Requeue

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: one existing structural D1 FX sleeve advanced with one append-only Q02
retry; automatically claimed by paced worker T3 at final readback

## Outcome

The approved-card/build-backlog audit found no genuinely unbuilt diversity card
that also had the deterministic EA and magic-registry allocations required by
the standard build process. Candidates with diverse symbols were already
built, already had a successor or strategy verdict, or had active related farm
work. A new build would therefore have duplicated governed work.

The mission's infrastructure-recovery fallback was used for
`QM5_12361_tmom-ibs`, an approved, price-only D1 EURUSD mean-reversion sleeve.
The canonical append-only enqueue created exactly one Q02 successor:

- new work item: `e275e5da-29c5-4b73-ba99-f2320c1bff22`;
- exact predecessor: `caf70551-b1e9-45c0-bbb7-1ebd80715bd3`;
- symbol/period: `EURUSD.DWX` / `D1`;
- state at the 2026-08-13T05:59:13Z readback: `active`, claimed by paced worker
  `T3`, attempt 0, with no verdict yet; and
- predecessor preservation: true.

No pump, dispatch, tester launch, or manual backtest followed the enqueue. The
normal paced scheduler independently claimed the row on T3.

## Distinct Claim and Source Quality

Before mutation, the canonical farm database was backed up online to:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12361_q02_claim_20260813T055336Z.sqlite`

The backup passed `PRAGMA quick_check` and has SHA-256
`3a95f44354497e53dd741f8ae7748862517160a8b5008d7ba73068d168e9a927`.

The farm router assigned distinct task
`dd858984-2470-4bc5-a35e-daa17f5d59bc` to `codex`, keyed to the exact EA,
symbol, phase, and failed predecessor. Before claiming, there was no successor,
open work item, related agent task, or competing lease for this EA. A different
EA with a live pending Q02 row was explicitly rejected to avoid collision.

The OWNER-approved card is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12361_tmom-ibs.md` (SHA-256
`e6e8794dade8bd01509eeff0191fca6a697ffed4d45ea4591b09ceefe7b8eb14`).
It records `g0_status: APPROVED`, `r1_track_record: PASS`, and R2-R4 PASS. Its
public implementation source is ThewindMom's 151 Trading Strategies repository:

`https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/mean_reversion.py`

The rule is structural internal-bar-strength mean reversion using daily price
bars. It contains no ML, grid, martingale, or banned indicator dependency. The
paced expectation is six trades per year on EURUSD, above the Q02 five-trades-
per-year floor, and the card expectation is 50 trades per year.

## Infrastructure Diagnosis

The predecessor's bound summary is:

`D:/QM/reports/work_items/caf70551-b1e9-45c0-bbb7-1ebd80715bd3/QM5_12361/20260728_145427/summary.json`

It has SHA-256
`02409b657b6f995d9c70704a61ecb3cbc785a0b008c2d845f02743a54e1dde8a`.
All three attempts were invalid infrastructure runs, with `NO_HISTORY`,
`BARS_ZERO`, empty expert/symbol fields, and a 1970/M0 period signature. The
summary reports no OnInit failure, no log bomb, stable binary deployment,
source/deployed hash agreement, and a healthy news-calendar preflight. It
contains no valid trade result and therefore no strategy-quality verdict.

Those attempts ended on 2026-07-28, before Variant-A copy-on-claim custom-
history isolation was activated on 2026-08-09 for T1-T10. Current activation
state is enabled and has SHA-256
`0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`.
The targeted isolation checks passed:

```text
38 passed in 5.23s
```

The tested modules were `test_custom_history_copy_on_claim.py`,
`test_terminal_worker_custom_history_isolation.py`, and
`test_mt5_history_isolation.py`. Because the strategy artifacts are exact and
the failure predates the infrastructure remediation, changing the EA or its
trading mechanics was neither indicated nor authorized.

## Immutable Risk and Artifact Bindings

The canonical EURUSD setfile is backtest-only fixed risk:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`; and
- `environment=backtest`.

The enqueue bound the current artifacts exactly:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `d9174b52a89e4ed61c62bfecb2a297f174cb2fc2331b32af12a24c7e4638d251` |
| EX5 | `8a3fe3556fa4e3722386d6f2ea710207c95e0237b1469239fba6819e5bbbacc9` |
| EURUSD D1 backtest setfile | `4f72e58f1c8c368aff44a3aba57acfe8c9344f1913022b450709f75e9aefcf6d` |

The canonical command was:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12361 --phase Q02 --from-work-item-id caf70551-b1e9-45c0-bbb7-1ebd80715bd3 --append-only-rerun-of caf70551-b1e9-45c0-bbb7-1ebd80715bd3 --rerun-reason "Predecessor exhausted three infrastructure-only NO_HISTORY/BARS_ZERO attempts on 2026-07-28 before Variant-A custom-history isolation activation; current EX5, MQ5, and EURUSD D1 RISK_FIXED set hashes remain exact, and the 38-test isolation suite passes. Append one isolated EURUSD.DWX D1 retry without manual dispatch." --expected-current-ex5-sha256 8a3fe3556fa4e3722386d6f2ea710207c95e0237b1469239fba6819e5bbbacc9
```

## Paced-Fleet and Safety Boundaries

The pre-enqueue governed-slot inspection found five active T1-T10 testers,
below the binding paced ceiling of seven. External terminal processes were not
counted as governed farm slots and were not controlled. Although host CPU was
busy during the observation, this unit only appended a pending database row;
it did not consume a new tester slot or force a scheduler tick.

- No manual smoke test, backtest, dispatch, terminal reservation, process
  launch, process stop, or AutoTrading action was performed.
- `T_Live`, the live manifest, deploy artifacts, and live setfiles were not
  touched.
- No portfolio gate, portfolio KPI, or Q08-contribution record was touched.
- No Strategy Card, EA source, EX5 binary, registry row, magic row, or setfile
  was changed.
- No unrelated tracked file on the shared branch was modified by this unit.
