# QM5_1537 monthly refresh runner — REVIEW

Router task: `447f4995-0eae-4da6-8530-78a88491b3d0`  
Branch: `agents/board-advisor`  
Verdict: **REVIEW / RUNNER_READY / SCHEDULE_NOT_REGISTERED**

## Outcome

The monthly runner now executes the reviewed chain as a create-only workflow:
Europe/Berlin month/schedule check, dedicated `T_Export` idle and
Darwinex-Live binding, governed native D1 export, append-only calendar build,
hash/source/prefix verification, new versioned preset, and an install-candidate
receipt. It stops in REVIEW and does not install terminal files, attach charts,
or alter AutoTrading.

Two producer constraints had to be made monthly-safe:

- The native exporter previously fixed `InpTo` and `InpMinimumLast` to
  September 2026. The Python wrapper now accepts bounded dynamic epochs, while
  the MQL exporter still rejects future-skewed ranges and remains read-only,
  path-bound to `D:/QM/mt5/T_Export`, and create-only.
- The calendar builder previously understood only one native append generation.
  It now verifies and preserves an existing per-row source sidecar as an exact
  prefix before adding the next native bundle. A chained August→September
  replay produced calendar SHA
  `EB9AE48AB607FA30C454CABBB43798A9D1C4EF4B2042187DCABC5940ED96AE78`
  and source SHA
  `C1F3B0A7899A649ABDCA80F515E711CC3AC1B751369718BD7358F94F1372A79C`,
  identical to the reviewed v2 artifacts.

The installer is dry by default. It prints a `schtasks.exe` definition for
05:30 Europe/Berlin on days 1–3 under SYSTEM (or `qm-admin`) and writes runtime
output to `D:/QM/reports/state/qm1537_refresh.log`. `-Apply` refuses to proceed
without an explicit `OWNER-DEC-*` release id. No task was registered here.

## September historical dry run

Command:

```text
python tools/strategy_farm/qm1537_monthly_sleeve_refresh.py --dry-run --month-key 202609 --native-export-receipt D:/QM/reports/qm1537_native_d1/20260907T095525Z_qm1537_native_d1/export_receipt.json --reproduce-calendar C:/QM/repo/framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v2.csv --evidence-dir C:/QM/repo/docs/ops/evidence/2026-09-07_qm1537_refresh_202609 --receipt-name dry_run_receipt.json
```

Result: `PASS`.

- Native receipt: 37/37 Darwinex-Live exports; SHA
  `BE8DE77CE812C7BB345BB180629DCC07DB39689F252EA2838E1D1581AF4756FE`.
- Prior v1 prefix: 834,341 bytes; SHA
  `401E0D91E2428DAB4ABFF17C1DF651F1C7BC716B7160B71A06D1A3ECA9B5288B`.
- Rebuilt v2: 3,567 rows, including 21 appended XAG rows; SHA
  `EB9AE48AB607FA30C454CABBB43798A9D1C4EF4B2042187DCABC5940ED96AE78`;
  byte-exact match `true`.
- Target `202609`: `valid_count=37`, `host_rank=0`, selected top three
  XAGUSD/XNGUSD/XTIUSD, first native XAG bar `2026-09-01T00:00:00Z`.
- Ranking contract remained
  `314634871498688C3784984B8EA3DF35716996ACBEDC63623396FBC31D188007`.
- No production or terminal artifact was written. See
  `dry_run_receipt.json` for the full machine-readable receipt.

The first replay intentionally failed closed because the builder's JSON
manifest inherited Windows CRLF serialization. That run wrote
`refresh_receipt_20260907T114036Z_7aededa7.json`; the serialization was fixed to
explicit LF and the identical replay then passed.

## Focused verification

- Python syntax compile: PASS for runner, exporter, and calendar builder.
- Focused tests: `19 passed` covering month key/schedule logic, native first-bar
  binding, exact prefix preservation, receipt safety schema, preset mutation
  scope, dynamic exporter bounds, and the existing calendar contract.
- Installer default invocation: exit 0, printed command only; no registration.
- `git diff --check`: PASS.
- LF byte scan: no carriage returns and final LF present in every changed text
  file and both run receipts.
- Guardrail: generated presets reject `qm_news_stale_max_hours > 336`; no
  backtest set, Q criterion, registry, terminal, chart, or AutoTrading state was
  changed.

## OWNER re-attach — emitted by every successful real run

1. On the FTMO demo XAGUSD D1 chart, remove the existing QM5_1537 instance.
2. Attach `QM5_1537_aa-vol-sma10.ex5` and load the new receipt-named versioned preset.
3. Keep AutoTrading under OWNER control and confirm `MONTHLY_SLEEVE_STATE` reports the receipt month, `ready=true`, `valid_count=37`.

These lines are instructions only. A real October-or-later artifact does not
exist until its first governed native trading-day export succeeds.
