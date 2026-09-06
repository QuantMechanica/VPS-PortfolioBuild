# QM5_9579 diverse D1 rework and compile handoff

Date: 2026-09-06

Branch: `agents/board-advisor`

Outcome: `SOURCE_REPAIR_PASS / COMPILE_HELD / CPU_CEILING_STOP`

## Selection

`QM5_9579_bandy-atr-channel-breakout-trend` was selected as one high-diversity, low-frequency unit. A read-only farm inventory found 152 approved EA directories with no `work_items`; this approved D1 card covers seven FX symbols plus five indices and XAU, expects roughly 14 trades per year, and had no Q02 verdict. It also had a concrete RECYCLE review, so repairing it advances a distinct diverse sleeve without adding raw build volume.

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9579_bandy-atr-channel-breakout-trend.md`
- Build task: `34ffb386-bb5b-4c08-8319-c8b893fc50cc`
- Review task: `ad98fd21-0459-4b0b-a673-69d41d2b1a0d`
- Pre-claim database backup: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_9579_claim_20260906T105559Z.sqlite`
- Source: Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management* (Blue Owl Press, 2015), ISBN 9780979183850.

## Source repair

The reviewed defects were closed without changing the approved strategy thresholds, fixed-risk model, magic allocation, or registered symbol set:

1. Declared the D1 framework execution contract during `OnInit`.
2. Moved the sole D1 new-bar gate ahead of signal refresh while keeping position management reachable on every tick.
3. Cached closed-bar D1 price, SMA(20), and ATR(14) once per new D1 bar.
4. Made the approved 5 ATR catastrophic backstop executable as a loss ceiling, with the tighter 2 ATR initial Chandelier stop controlling normal protection.
5. Reconciled `SPEC.md` to the actual D1 mechanics, all eight strategy inputs, and the existing 13-symbol registered portability subset.

Current MQ5 SHA-256: `8e18aff5def9ca39c01d445be3842ea3f9409d345d25b8cc99ca59b37ddd4e48`

## Deterministic checks

- `validate_spec_doc.py`: PASS (1/1)
- `validate_build_guardrails.py`: PASS (14 files, zero findings)
- `validate_symbol_scope.py --fail-on-leak --verbose`: `SINGLE_SYMBOL_OK`
- `build_gate_hardening.py`: PASS, 13/13 exact registry symbols, zero failures and warnings
- Targeted compile-authority test: PASS (`1 passed, 73 deselected`)
- `python -m py_compile tools/strategy_farm/compile_work_items.py`: PASS

One direct `build_check.ps1` attempt was refused before compilation by the live-factory guard (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). It was not retried or bypassed.

## Governed compile handoff

The existing review task requires a corrected MQ5 followed by governed `COMPILE_EA`. An exact-label, exact-task source-repair authority was added for that review task; it grants append-only compile enqueue authority and no backtest or gate authority.

- COMPILE_EA work item: `8958e6ed-0bd6-4055-97a3-f48a01ab6e13`
- State: `pending`, attempt 0, unclaimed
- Active hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- Requested source SHA: `8e18aff5def9ca39c01d445be3842ea3f9409d345d25b8cc99ca59b37ddd4e48`
- Payload: D1, 13 registered symbols
- Exact-row release dry run: PASS; actual and expected source hashes match

The hold was not bypassed. Resident terminal workers predate the new reviewed authority binding; releasing before a normal compile-worker rollout would make them reject the row during their independent authority recheck.

## Capacity stop

A ten-second processor sample reached 99.51% CPU (average 85.66%), above the farm's 97% ceiling. At the sample time there were four `metatester64` processes, six `terminal64` processes, and five active farm items (one Q04, one Q08, three OPT_CENSUS). The pending queue was 11,535.

Per the paced-fleet instruction, no smoke test, Q02 enqueue, compile-worker restart, or further backtest load was started. The old EX5 and 13 setfiles remain on disk but are bound to superseded source SHA `dde31d552fb197f3d16f311353b553d7956cb90a5b84ef2efb79cddf1f7fdd44`; they are not current build evidence.

The next deterministic action, after normal worker rollout and CPU headroom, is to release only compile row `8958e6ed-0bd6-4055-97a3-f48a01ab6e13`, require `COMPILE_OK` and regenerated RISK_FIXED setfiles bound to the current source hash, then run one smoke and enqueue Q02.

No T_Live files, AutoTrading state, portfolio gate, or live manifest were touched.
