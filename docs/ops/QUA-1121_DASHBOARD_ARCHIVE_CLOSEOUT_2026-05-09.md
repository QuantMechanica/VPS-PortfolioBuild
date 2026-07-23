# QUA-1121 Dashboard + Strategy Archive Redesign Closeout (2026-05-09)

## Objective Mapping

1. Brand-consistent redesign
- Implemented in `C:/QM/paperclip/tools/ops/render_dashboard.py` and `C:/QM/paperclip/tools/ops/render_strategies.py` using QM brand variables and shared style direction.
- Generated outputs:
  - `C:/QM/paperclip/dashboards/current.html`
  - `C:/QM/paperclip/dashboards/strategies.html`

2. Mission-Hero
- `current.html` contains North-Star mission hero block ("First Live EA", gates progress).
- Source: `render_dashboard.py` Heureka section.

3. No-phasing workstreams
- Workstream section explicitly states continuous parallel mode and DL-061 context.
- Source marker in output: `Active Workstreams (continuous parallel · DL-061 Endausbaustufe)`.

4. Dev-Codex + Claude visibility
- Added dedicated dashboard module `Development Visibility — Codex + Claude`.
- Added agent heartbeat freshness telemetry (`fresh/stale/cold/unknown`) for dev pair and full fleet.
- Source: `render_dashboard.py` + generated `current.html` markers.

5. Strategies page showing all cards (fix 4/29 perception)
- Added unified `All Strategy Cards (N)` table in `strategies.html`.
- Added count clarity: `29 card files / 28 active strategies`.
- Added mismatch alert tile when expected active count differs.

6. Daily refresh visibility
- Added explicit cadence marker in both generated pages:
  - `Cadence: hourly render + daily audit`

## Verification Snapshot

- `current.html` includes:
  - `Development Visibility — Codex + Claude`
  - Dev freshness pills (example: `Development-Codex ... fresh ...`)
  - Footer cadence marker

- `strategies.html` includes:
  - `All Strategy Cards (28)`
  - `Card Count Mismatch: expected 29 active cards, detected 28`
  - Footer cadence marker

## Notes

- Active strategy cards are 28 because `_TEMPLATE.md` is counted as file inventory (29 total files) but excluded from active strategy rows.
- If OWNER confirms active target should be 28, `OWNER_EXPECTED_ACTIVE_CARDS` can be set to 28 to remove mismatch warning.
