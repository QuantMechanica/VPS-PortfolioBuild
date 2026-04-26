# Dashboard evidence map

Provenance mapping for every widget on `Dashboard/project_dashboard.html`. Moved here under QUAA-228 (P6 Option C): the inline Block F table was collapsed to a 1-line footer pointing at this file so the dashboard scroll stays short.

Any dashboard number that is not backed by a field listed below is a bug — Controlling must not fabricate metrics.

## Block A — Phase Progress
| Column | Source field | Formula |
|---|---|---|
| Total | `DATA.phase_funnel[code].total` | — |
| Tested | `DATA.phase_funnel[code].tested` (falls back to `.passed`) | — |
| Pass | `DATA.phase_funnel[code].passed` | — |
| Fail | derived | `tested − passed` |
| Open | derived | `total − tested` |
| Progress% | derived | `tested / total × 100` |
| Pass-Rate% | derived | `passed / tested × 100` (n/a when tested=0) |
| Composition bar | derived | tri-segment passed / failed / remaining |

Upstream: `Company/data/ea_registry_summary.json` via the dashboard generator populates `phase_funnel`.

## Block B — Throughput + Terminal Pulse
| Widget | Source field |
|---|---|
| Overview strip | `DATA.kpis.*` + `DATA.summary.*` |
| Today-vs-7d delta strip | `DATA.delta_strip.{throughput,pass_rate,errors,avg_backtest_dur}` |
| Terminal rows (dot/current EA/queue/age) | `DATA.terminals[]` |

Upstream: `last_check_state.json.bl_progress` for per-terminal active EA + queue + report age; `DATA.daily_trend` for the 7d averages that drive the delta strip.

## Block C — V5 Deploy Readiness
| Widget | Source field |
|---|---|
| Readiness KPI (READY / NOT READY) | `DATA.v5_construction.slots[].state` aggregated |
| Slot rows | `DATA.v5_construction.slots[].{index, ea, symbol, phase, state, note}` |
| Headline blocker line | `DATA.kpis.deploy_readiness_v5.blocker_headline` |

Upstream: `V5_COMPOSITION_LOCK_20260418.md` mirrored into `controlling_panels.json`.

## Block D — Today at a Glance (QUAA-228 P3 Option A)
| Card | Source field |
|---|---|
| Today — PASS/FAIL/BLOCKED by phase | `DATA.daily_trend[today].phase_breakdown[code].{pass, fail, blocked}` |
| Symbol coverage today | `DATA.daily_trend[today].symbols_covered[]`, `.symbols_missing[]`; plus regex-parsed `DATA.last_check_state_snapshot.bl_progress.T*.latest_report` for current BL symbols |
| Ops snapshot | `DATA.last_check_state_snapshot.{disk_free_gb, timestamp, iteration, writer_pid, pending_tasks_open_count}`; restart/resolve counts derived from keys of `DATA.last_check_state_snapshot.{completed_events_today, events_this_tick}` matching `/RESTART|RESTARTED|RELAUNCH|REVIVE/i` vs. `/RESOLVED|DONE_|CLEARED|CLOSED/i` |
| Active blockers | `DATA.attention_items[]` ∪ `DATA.last_check_state_snapshot.blocked` (key, detail) |

Fields with no allowed source render as `NO DATA` with an explicit tooltip — dashboards must not substitute zero for missing data.

## Block E — MT5 Tri-Color Flow Visuals
| Card | Source field |
|---|---|
| Baseline per Instance | `DATA.last_check_state_snapshot.bl_progress.T1/T2/T3.{current, total, status, latest_report}` |
| PASS chain funnel (QUAA-228 P4 Option A) | `DATA.phase_funnel.{P2.total, P2.passed, P3.passed, P4.passed, P9.passed}`; tri-colour split from `DATA.phase_instance_split[code].{pass_t1, pass_t2, pass_t3, total_t1, total_t2, total_t3}` when present |
| Phase × Instance matrix | Overall PASS/FAIL from `DATA.phase_funnel[code].{passed, tested}`; T1/T2/T3 split rendered as `NO DATA` (not published in allowed sources yet — tracked under QUAA-228 follow-up) |

Percentages in the PASS-chain card are always labelled explicitly as `stage/previous%` and `stage/total%` (Block A P0 lesson: never render an unlabeled percent).

## Pipeline-health banner (QUAA-228 P1)
| Field | Source |
|---|---|
| State pill (HEALTHY / PARTIAL / DEGRADED / STALE) | Derived classifier over `DATA.last_check_state_snapshot.bl_progress.T*.{pid, report_age_sec, status}` and age of `DATA.last_check_state_snapshot.timestamp` vs. `DATA.refresh.cadence_min × 2` |
| Per-tracker on/off pills | Same `bl_progress.T*` fields |
| Dashboard-written timestamp | `DATA.refresh.dashboard_written_ts` |
| state.json timestamp | `DATA.last_check_state_snapshot.timestamp` |

## Header subtitle / refresh line
| Field | Source |
|---|---|
| Subtitle timestamp | `DATA.brand.subtitle_timestamp` |
| Dashboard-written timestamp | `DATA.refresh.dashboard_written_ts` |
| Summary-updated timestamp | `DATA.summary.updated` |

## Refresh script
`Company/Controlling/refresh_dashboard_data.js` is the single authority that mutates the embedded `DATA` block. It reads `last_check_state.json` on every Controlling heartbeat, patches the timestamp + `bl_progress` + event maps listed above, and writes to the canonical `Dashboard/project_dashboard.html` plus the G-drive root and MT5-terminal mirrors (preserving the `QM_PROCESSES_LINK` snippet on the root mirror).

## Out of scope (intentional NO DATA)
- Per-phase PASS/FAIL split by instance (T1/T2/T3) — not emitted by the generator today; Block E matrix renders `NO DATA` cells.
- 30-day pass-rate average — older pre-QUAA-228 widget; kept as an explicit stub rather than extrapolated.
- 24h/7d test split by instance — same reason.

If a future change teaches the generator to emit any of the above fields, the dashboard consumes them automatically (all renderers use `|| {}` / `|| []` fallbacks) — no HTML change needed.
