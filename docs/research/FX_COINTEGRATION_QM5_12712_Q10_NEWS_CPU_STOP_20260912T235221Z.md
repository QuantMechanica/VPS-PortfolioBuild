# FX cointegration QM5_12712 Q10_NEWS dependency / CPU stop

Recorded: 2026-09-12T23:52:21Z (2026-09-13 01:52 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `f5ccdae83b7dd4e11cf49558e0ab182e306d3fc9`

## Outcome

The frozen 66-pair FX cointegration scan remains fully mechanized. Its two
published strict survivors are not Q02-blocked:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, Q04 FAIL.

No new scan-derived Card, EA, registry row, magic row, setfile, basket manifest,
compile item, or Q02 item was created.

The selected existing-forex fallback was
`QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1`. Its authenticated chain has
Q02-Q07 PASS and a current-contract Q09 PASS under work item
`844cb4a9-5cd5-4198-a8ae-56e5764f3bea`. The canonical v4 successor is the
news/FTMO evidence lane stored as `Q10_NEWS`; this is not the portfolio lane.

The exact bounded enqueue attempt was:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_12712 `
  --phase Q10_NEWS `
  --from-work-item-id 844cb4a9-5cd5-4198-a8ae-56e5764f3bea
```

It created and requeued zero rows. The fail-closed finding was exactly:

```text
q08_evidence_missing_or_unreadable
```

The controller recorded the refusal in the event ledger at
`2026-09-12T23:50:00+00:00`. The work-item count for
`QM5_12712 / Q10_NEWS` remained zero. Although the command's top-level
`enqueued` field was `true`, its `created` and `requeued` arrays were empty and
its sole result was the skipped predecessor. No success is claimed from that
misleading summary boolean.

The required Q08 regeneration already exists as work item
`b68d05cd-e52c-43a5-96aa-5e0306efa60f`: pending, unclaimed, attempt zero,
`priority_track=true`, canonical claim-order rank 5 of 5,516 pending rows. A
second Q08 row or a Q10_NEWS row without readable Q08 evidence would be
duplicate or dependency-invalid work, respectively.

The previously selected Q02 fallback
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` also remains present exactly once
as pending work item `547c4fd3-f3fd-4c59-b9dc-654e96521251`, with
`priority_track=true`. Its current canonical rank is 2,547, so another Q02 row
was not appended.

## PACER guard and artifact bindings

No MQ5 source was generated or edited and no compile command was enqueued. A
read-only audit of the selected existing source nevertheless returned exit
zero, `ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py `
  --check-source "C:/QM/repo/framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/QM5_12712_edgelab-eurgbp-euraud-cointegration.mq5"
```

Artifact hashes at inspection:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `afdfd1a80dbfcd2c398ddc92dffe2181e5727f3837c37df2a772f25b68e171d1` |
| EX5 | `0003ed98f590e95a28a08e7d8198639b48213e882e8c5d2428cad4422355c982` |
| basket manifest | `a15214089f0efd8564a1ee6f2d6bb09164cde12d742ad8627fa1f7870d6e773a` |
| logical backtest set | `105a23da1d33d559cff4ff19a5e8c5c51e8a72eb6cec5b7f6a92ecedaea6208c` |

The logical set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The manifest declares EURGBP.DWX and EURAUD.DWX as the
traded legs and declares their USD conversion-history dependencies.

A pre-mutation SQLite backup was written outside the repository at:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12712_q10_news_enqueue_20260912_234958Z.sqlite`

## Binding CPU stop

Five whole-host CPU samples taken two seconds apart were 99.951%, 99.904%,
100.000%, 96.680%, and 88.332%. Average CPU was 96.973%; maximum CPU was
100.000%. The mission ceiling binds when any sample reaches 97%, so the maximum
latched the stop.

The final slot scan observed factory testers on T1, T3, T7, and T9 and one
worker daemon for each of T1-T10. `T_Live` and the external FTMO terminal were
observed only by the read-only slot inventory and were not controlled.

After the ceiling fired, no further enqueue, claim, dispatch tick, tester
launch, terminal reservation, compile, or backtest was attempted.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest, deploy artifact, terminal state, or AutoTrading state
  changed.
- No Card, EA source/binary, setfile, basket manifest, registry, magic row,
  work-item status, priority, claim, or verdict changed.
- Unrelated shared-worktree changes were preserved and excluded from this
  evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12712_q10_news_cpu_stop_20260912T235221Z_board_advisor.json`.
