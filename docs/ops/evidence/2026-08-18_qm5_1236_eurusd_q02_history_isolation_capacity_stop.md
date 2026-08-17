# QM5_1236 EURUSD Q02 History-Isolation Recovery — Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `DIAGNOSED_AND_CLAIMED; Q02 NOT ENQUEUED — HARD CPU CEILING`

## Selection and non-duplicate claim

The approved build backlog was checked first. It contained 21 open `build_ea`
agent tasks: two were already in progress and every remaining unclaimed card
had an active EA-ID row but zero allocated magic rows. The standard
`qm-build-ea-from-card` preflight therefore forbids those builds; no ad-hoc
magic allocation or raw build-volume work was performed.

The strongest diverse infrastructure recovery was then selected:

- EA: `QM5_1236_gh-donchian-55`;
- target: `EURUSD.DWX`, `D1`, Q02;
- failed predecessor: `1b921415-5b5e-441a-896d-9304e3ad9392`;
- approved card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1236_gh-donchian-55.md`;
- card SHA-256:
  `df224b2081d7b585988dc84ffa0c2e75c9d4c5fe8d9c80aea819f72fa8b2cb4f`;
- governance: `g0_status: APPROVED`, R1-R4 PASS, expected 18 trades/year;
- mechanic: completed-bar 55/20 Donchian trend following with ATR filter,
  fixed ATR stop, one position per symbol/magic, no ML, grid, martingale, or
  pyramiding; and
- diversity basis: an unadvanced low-frequency EURUSD sleeve, while the seven
  active Q08 jobs were concentrated in indices and metals.

`QM5_1058`, the higher-priority market-neutral FX-pairs candidate, was rejected
as a collision because it already had a pending Q04 retry. For `QM5_1236 /
EURUSD.DWX`, the pre-claim database read found no successor row, no open work
item for the EA, and no related open agent task. Other symbols of this EA have
reached Q04 and its XAUUSD lane passed Q04 and Q05, but EURUSD has no downstream
row.

The farm router atomically assigned distinct task
`32d9b93a-18eb-41e9-bf09-242419686fd0` to `codex` at priority 98 under claim
key
`manual:codex:agents/board-advisor:QM5_1236:EURUSD.DWX:q02-no-history:20260817T234521Z`.
Before the claim, the canonical database was backed up online to:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1236_eurusd_q02_claim_20260817T234521Z.sqlite`

The backup passed `PRAGMA quick_check`, has SHA-256
`5a4fb4e6af2c2bf79969cd98004b2a8a6bad5ee439fbe62317e2b7be8cd381ea`,
and is 399,638,528 bytes.

## Infrastructure diagnosis

The predecessor's bound summary is:

`D:/QM/reports/work_items/1b921415-5b5e-441a-896d-9304e3ad9392/QM5_1236/20260728_115044/summary.json`

Its SHA-256 is
`c14b18a9f5a6735f6be0b8bdd819b9cac63b60c19771a0df812a93015899d87a`.
The only attempt was an invalid infrastructure run with `ONINIT_FAILED`,
`NO_HISTORY_LOG`, `BARS_ZERO`, empty expert/symbol fields, and the characteristic
1970/M0 invalid-history signature. The run produced no valid trading result,
so it is not a strategy-quality verdict.

Artifact deployment was stable during the failed run: the repo and T2 binary
hashes matched, the repo and T2 setfile hashes matched, and neither changed
during execution. Current artifacts still have the same hashes:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `797e048a936fae2050b0a1b43f506ff42e0ddf8c79e8822046306248fffaac37` |
| EX5 | `3d161d442dbd8b9087e0ad46106ead9e0ba0abd5c522f9373a4ad7bc73583690` |
| EURUSD D1 backtest setfile | `7a104f547f56f143c7134403807e5f6fc17c98f3b7a64957b961d29912acf7d2` |

The setfile remains backtest-only fixed risk: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and `environment=backtest`. The active
magic registry contains slot 0 `EURUSD.DWX` magic `12360000`.

The invalid attempt ended on 2026-07-28, before Variant-A custom-history
copy-on-claim isolation was activated on 2026-08-09. The current activation
contract is enabled for T1-T10, containment mode is false, and the activation
file SHA-256 is
`0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`.
Its OWNER-approved archive manifest contains EURUSD `.hcc` history for every
year 2017-2025 plus monthly tick archives. This remediation directly addresses
the predecessor's history failure; changing the EA mechanics or recompiling
the already exact binary is not indicated.

An optional 47-test isolation regression command was started before the final
capacity census, but it did not finish inside a 60-second diagnostic budget
under host load. Its owned Python process was identified by exact command line
and stopped; it was not left running and no PASS is claimed from that attempt.
The active signed isolation contract and archive coverage above are the
requeue basis.

## Mandatory capacity stop

At the final gate, the canonical database reported seven governed active
work items, exactly the paced ceiling:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T1 | `QM5_10145` | Q08 | `XAUUSD.DWX` |
| T3 | `QM5_10128` | Q08 | `XAUUSD.DWX` |
| T5 | `QM5_11132` | Q08 | `SP500.DWX` |
| T6 | `QM5_10403` | Q08 | `XAUUSD.DWX` |
| T7 | `QM5_10145` | Q08 | `SP500.DWX` |
| T8 | `QM5_10911` | Q08 | `GDAXI.DWX` |
| T9 | `QM5_10692` | Q08 | `NDX.DWX` |

There were 2,221 pending rows. Five consecutive whole-host CPU samples were
`100.0`, `99.7`, `100.0`, `93.6`, and `99.4` percent: average `98.5%`, maximum
`100.0%`. The maximum exceeds the explicit 97% hard host-CPU ceiling as well
as the active-row census meeting the seven-slot ceiling.

Per the mission stop condition, no append-only Q02 row was created. The final
readback still showed no successor and no open work item for `QM5_1236`.
There was no dispatcher tick, smoke test, MetaTrader launch, phase runner, or
manual backtest.

At `2026-08-17T23:51:21Z`, router task
`32d9b93a-18eb-41e9-bf09-242419686fd0` was moved from `IN_PROGRESS` to
`BLOCKED` with verdict `BLOCKED_CAPACITY`; the router released its lease. This
prevents a stale ownership collision while requiring a fresh capacity and
collision check before any later retry.

## Capacity-clear handoff

After a fresh collision guard, artifact-hash check, governed-slot census, and
five-sample CPU check both fall below their ceilings, the canonical append-only
handoff is:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1236 --phase Q02 --from-work-item-id 1b921415-5b5e-441a-896d-9304e3ad9392 --append-only-rerun-of 1b921415-5b5e-441a-896d-9304e3ad9392 --rerun-reason "Predecessor ended with infrastructure-only ONINIT_FAILED/NO_HISTORY/BARS_ZERO on 2026-07-28 before Variant-A custom-history isolation; current EX5, MQ5, and EURUSD D1 RISK_FIXED set hashes remain exact. Append one isolated EURUSD.DWX D1 retry without manual dispatch." --expected-current-ex5-sha256 3d161d442dbd8b9087e0ad46106ead9e0ba0abd5c522f9373a4ad7bc73583690
```

No EA source, EX5, Strategy Card, setfile, registry, resolver, portfolio gate,
portfolio manifest, deploy artifact, `T_Live` path, or AutoTrading state was
changed.
