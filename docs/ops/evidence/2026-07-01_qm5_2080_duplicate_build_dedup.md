# QM5_2080 Duplicate Build Task Dedup - 2026-07-01

## Scope

Mission: advance diverse, non-duplicate portfolio sleeve throughput.

Selected candidate: `QM5_2080_pring-special-k-h4`, a price-only H4 Special-K strategy targeting FX majors plus XAU and global index symbols. The candidate matched the requested diversity preference better than the invalid rates/bonds and lumber-gold cards because it is fully DWX-testable without external macro or futures series.

## Finding

The pending build task `9b8d6881-3b97-4a1d-ba80-a28e265d54d9` was a stale duplicate of build task `d85063a1-13e4-473a-854b-224ae23e64f3`.

The earlier task already completed the useful unit of work:

- Build result: `D:\QM\strategy_farm\artifacts\builds\d85063a1-13e4-473a-854b-224ae23e64f3.json`
- Status: build check PASS, compile PASS, 0 errors, 0 warnings
- Codex review: PASS
- EA review: APPROVE_FOR_BACKTEST
- Smoke: deferred because the MT5 fleet was saturated, so Q02 is the runtime smoke

The source was already reworked in place to fix the impossible same-bar Special-K extreme/turn condition by using previous-bar extreme plus current-bar confirmation. Rebuilding again before the pending Q02 rows run would be duplicate work and would risk speculative strategy drift.

## Action Taken

Claimed the stale duplicate task, then recorded the already-approved build result against it:

```text
python tools/strategy_farm/farmctl.py record-build --task-id 9b8d6881-3b97-4a1d-ba80-a28e265d54d9 --result-file D:/QM/strategy_farm/artifacts/builds/d85063a1-13e4-473a-854b-224ae23e64f3.json
```

Result:

- Duplicate build task `9b8d6881-3b97-4a1d-ba80-a28e265d54d9` -> `done`
- New Q02 rows created: `0`
- Existing Q02 rows preserved:
  - `21ba2ea5-f42d-4575-849e-1d920877bdea` - `EURUSD.DWX`
  - `768bc13f-f3f8-4e8c-bad0-9364cb9adce1` - `GDAXI.DWX`
  - `780e6b12-70a3-4fb0-8b3c-a297fe71212a` - `XAUUSD.DWX`
- Existing UK100 stranded infra row preserved:
  - `db4ea8b1-c0bf-4ce7-85aa-4fe0464ca24e` - `UK100.DWX`, prior `NO_HISTORY`

The farm auto-Q02 deduper skipped the existing stage-1 rows and kept the other symbols staged/deferred according to the diversity fanout rule.

## Boundary

No source logic, registry, setfile, portfolio gate, T_Live manifest, or AutoTrading state was changed in this wake.

