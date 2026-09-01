# QM5_20062 Q03 infrastructure recovery — CPU-deferred enqueue

- Recorded: 2026-09-01 04:07:59 UTC
- Branch: `agents/board-advisor`
- EA: `QM5_20062_kats-eu-macisar`
- Instrument / cadence: `EURUSD.DWX` / D1 / approximately 12 trades per year
- Source: Katsanos, *Intermarket Trading Strategies* (Wiley, 2008), recorded by the approved card as Tier A
- Scope: Q03 infrastructure recovery only; no T_Live, AutoTrading, portfolio gate, or deploy-manifest action

## Selection and diagnosis

No genuinely unbuilt, preallocated low-frequency FX/crypto/rates/pairs card remained in the build backlog after exact EA-directory and farm-identity checks. The strongest diverse infrastructure recovery was the canonical Q03 gap for QM5_20062:

- Q02 predecessor `36bfac85-63e2-46a7-9f35-8ae583252d2f`: immutable `done/PASS` on T10.
- Q03 source `0108e4d5-2d2d-49e4-8458-5434dd8f34d4`: immutable `done/INFRA_FAIL` on T4 with `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS`.
- There were no pending/active rows for the EA and no append-only rerun of the Q03 source.
- Current MQ5, EX5, and RISK_FIXED setfile exactly match the sealed Q02/Q03 identity:
  - MQ5: `c245bdc262f7d4c8ce0e70171ea852919765eb299a278eaab4b607c2a0b78424`
  - EX5: `68d54999a025cb1b95692f0702055a4acc18c28061ce61087728c37c279994d2`
  - setfile: `c4c05dbc0a377b27ed3cabe7465dbc5e130d03ec4dfcd2b2511b577db9877000`
  - risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Report retention compressed the Q02 proof from the DB path `summary.json` to the immutable sibling `summary.json.gz`. The prior enqueue guard did not resolve that retained sidecar.
- The Q03 report itself aged out. The guard also treated a same-binary `INFRA_FAIL` as an economic terminal result, preventing an exact-identity history recovery.

## Repair implemented

`farmctl` now:

1. Resolves retained evidence at its original path or its compressor-created `.gz` sibling, including Q02/Q03 append-only checks.
2. Hash-binds the actual retained Q02 evidence path into a new Q03 payload.
3. Allows a purged, same-binary Q03 rerun only when the source verdict is `INFRA_FAIL` and every MQ5/EX5/setfile/symbol/period/expert binding exactly matches the current Q02 PASS identity.
4. Continues to reject same-binary economic terminal results and any drifted infrastructure identity.
5. Stamps the recovery payload with the source infrastructure reason/signature and compressed-evidence provenance.

Verification: `python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q` → `44 passed`.

## CPU stop and disposition

The final five-sample whole-host admission window was:

`[97.8550, 99.5137, 99.1212, 97.8539, 92.6793]` percent; average `97.4046`, peak `99.5137`, ceiling `97.0`.

The guarded command exited before its collision query and before `farmctl enqueue-backtest`. Post-check confirmed zero pending/active QM5_20062 rows, zero append-only reruns of the Q03 source, and the historical source remained unchanged. Enqueue is deliberately deferred until a future wake obtains a fresh below-ceiling admission window.
