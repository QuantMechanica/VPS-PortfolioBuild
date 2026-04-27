QUA-246 first-run confirmation: de-dup queue contract executed.

Run evidence:
- `run_key`: `<sha256>`
- `ea_id`: `<EA_ID>`
- `version`: `<VERSION>`
- `symbol`: `<SYMBOL>`
- `phase`: `<PHASE>`
- `sub_gate_config`: `<CONFIG_HASH>`
- `terminal`: `<T1..T5>`
- `status`: `<succeeded|failed|no_report|aborted>`
- `report_dir`: `<absolute path>`
- `htm_count`: `<int>`
- `report_bytes`: `<int>`
- `scanner_pid`: `<pid>`
- `enqueue_ts_utc`: `<timestamp>`
- `claim_ts_utc`: `<timestamp>`
- `ack_ts_utc`: `<timestamp>`

Validation checks:
1. De-dup table lookup for tuple returns single row.
2. Queue transition sequence observed: `queued -> claimed -> running -> final`.
3. `report_manifest.json` counts match filesystem truth.
4. Heartbeat recorded terminal status and final ack.
