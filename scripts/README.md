# Scripts

VPS-local scripts: snapshot export, evidence collection, MT5 helpers.

No script here is run without a documented purpose in a process or checklist.

## Current Scripts

- `export_public_snapshot.ps1`: hourly public snapshot exporter for
  quantmechanica.com (`public-data/*.json`), with schema validation, optional git
  commit/push, and Netlify Build Hook fallback.
- `aggregator/standalone_aggregator_loop.py`: V5 standalone state writer for
  `last_check_state.json` with atomic writes + lock handling, T1-T5 process
  detection, report directory counting, and T6 hard exclusion.
