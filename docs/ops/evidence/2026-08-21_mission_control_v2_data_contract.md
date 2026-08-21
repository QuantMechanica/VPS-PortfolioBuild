# Evidence — Mission Control v2 data contract + emitter

Task QM-TODO-20260820-002 · Router 891b1860 · Claude · 2026-08-21

## What was delivered

1. `docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md` — versioned `qm.mission_control.v2`
   spec: envelope + per-section `meta` freshness/staleness contract, the exact
   terminal→work-item join, progress definitions (incl. mixed-era caveats),
   ETA-to-empty basis, OWNER-decision source order. Field-by-field with
   canonical source, cadence, staleness, Qxx-only display names.
2. `tools/strategy_farm/mission_control_v2_data.py` — read-only emitter building
   the full contract JSON, embedded JSON-Schema + dependency-free validator,
   writes `D:\QM\reports\state\mission_control_v2_preview.json`.
3. `tools/strategy_farm/tests/test_mission_control_v2_data.py` — 8 tests
   (progress definitions on fixtures + whole-contract schema validation +
   live-preview validation).

## Measured facts (live run 2026-08-21 ~14:10Z)

Emitter run:
```
[mission_control_v2] factory=CRITICAL queue_total=2254 terminals running=5 owner_open=31
  -> D:\QM\reports\state\mission_control_v2_preview.json   (exit 0, self-validated)
```

Terminal join surfaced the previously-hidden fields for all live claims:
```
T1 QM5_11165 weiss-rsi-ma AUDCAD.DWX Q07 elapsed 1150
T2 QM5_1230  carver-dynvol-mav USDJPY.DWX Q07 elapsed 1288
T3 QM5_11182 ft004-adx-cci XAUUSD.DWX Q07 elapsed 4587
T4 QM5_20203 eurusd-audjpy ...COINTEGRATION_D1 Q04 elapsed 76
T8 QM5_10916 grimes-impulse GDAXI.DWX Q07 elapsed 938
```
counts running=5 reserved=0 idle=5 fleet_size=10.

Queue / ETA:
```
pending_total 2249  executable 2224  parked 25  active 5
ETA: throughput_per_hour_24h=8.083  count_24h=194
     eta_hours_p50=275.13  eta_hours_p90=458.56  eta_empty_utc_p50=2026-09-02T01:21:15Z
parked phases: Q09_NEWS=24, HARNESS_PP_FIXTURE=1  (excluded from ETA, as designed)
```

Progress (MT5-tester phases, counted by updated_at):
```
today     completed=72  gate_pass=26 economic_fail=17 infra_transient=29 infra_rate=0.40
yesterday completed=122 gate_pass=56 economic_fail=37 infra_transient=29 infra_rate=0.24
7d avg    completed=192.14 distinct_ea_symbol=139.43 (mean of 7 per-day KPIs)
total     completed=107606 gate_pass=26492 economic_fail=23358 infra_transient=57340 since=2026-05-23
```

Cross-check of the trailing-window counts against a raw query
(`status IN (done,failed)`, all phases): today=71/yesterday=134/7d=1436 raw vs
the contract's MT5-phase-scoped 72/122 — the small deltas are the intended scope
(MT5-tester phases only) plus clean-view restamping, both documented.

Factory state CRITICAL is correct: `health.json overall=FAIL`,
`mt5_worker_saturation` FAIL (4/10 workers alive) — a genuine factory-down check.

## Tests

```
python -m pytest tools/strategy_farm/tests/test_mission_control_v2_data.py -q
........                                                                 [100%]
8 passed in 0.85s
```

Coverage: progress bucket classification (pass/economic/infra/mixed-seed),
windowed progress + MT5 scope exclusion of Q09_NEWS, ETA parked-exclusion,
terminal join (ea_id/slug/symbol/Qxx/work_item/elapsed + IDLE reason),
owner-decision source merge + superseded exclusion + Q12 injection, full-contract
schema validity, validator rejects a bad doc, and live-preview validation.

## Read-only / safety

- DB opened `file:...?mode=ro` + `PRAGMA query_only=ON` (same as
  `render_cockpit.db_rows`). No table is written; the only write is the preview
  JSON under `D:\QM\reports\state\`.
- No T_Live, live account, scheduled-task, or factory-process access.
- `jsonschema` is not installed on the VPS — handled by the embedded
  dependency-free validator; `validate_contract` uses `jsonschema` only if
  present.

## Rollback

Pure addition — three new files, no existing file touched:
- `tools/strategy_farm/mission_control_v2_data.py`
- `tools/strategy_farm/tests/test_mission_control_v2_data.py`
- `docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md`

Rollback = delete the three files and (optionally) the preview artifact
`D:\QM\reports\state\mission_control_v2_preview.json`. Nothing consumes the
emitter yet (the renderer is a separate, later task), so removal has zero blast
radius on the live cockpit or factory.

## Scope boundary / follow-ups (for the renderer task)

- Process-liveness overlay (terminal64/worker scan → `ERROR` state) is a
  renderer concern, deliberately not in this read-only emitter.
- Expected-duration baselines (phase/symbol median runtimes) are a future
  enrichment; `elapsed_seconds` is emitted now, baseline can be added without a
  contract change.

## Codex review addendum

Codex reran the focused suite against the canonical checkout and found that the
terminal-join fixture was coupled to the live
`state/terminal_reservations.json`: a real T2 reservation made the synthetic T2
assertion non-deterministically report `RESERVED` rather than `IDLE`.
`build_terminals` now accepts an explicit `reservations_override` dependency for
fixtures while production calls retain the canonical live reservation loader.

Post-fix verification on 2026-08-21:

```text
python -m pytest tools/strategy_farm/tests/test_website_archive_contract.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py -q
59 passed in 7.60s

python tools/strategy_farm/mission_control_v2_data.py
factory=CRITICAL queue_total=2255 terminals running=5 owner_open=31
output=D:/QM/reports/state/mission_control_v2_preview.json
```

The CRITICAL state is the emitter's read-only rendering of current health
evidence, not a new pipeline verdict.
