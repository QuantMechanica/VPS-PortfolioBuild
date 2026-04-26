# Scripts

VPS-local scripts: snapshot export, evidence collection, MT5 helpers.

No script here is run without a documented purpose in a process or checklist.

## Current Scripts

- `export_public_snapshot.ps1`: hourly public snapshot exporter for
  quantmechanica.com (`public-data/*.json`), with schema validation, optional git
  commit/push, and Netlify Build Hook fallback.
