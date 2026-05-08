# QM Token Monitor

- Generated UTC: 2026-05-08T15:20:53.7556130Z
- Status: critical
- spent_cents: 28800
- daily_delta: 17800.64
- org_cap_pct_used: 96
- days_to_exhaust: 0.07

| Agent | Spent (cents) | Daily Delta (cents/day) | Last Heartbeat UTC |
|---|---:|---:|---|
| CEO ($(@{agent_id=a1; agent_name=CEO; adapter=claude_local; status=active; spent_cents=12000; daily_delta_cents=5340.19; last_heartbeat_at_utc=2026-05-08T14:58:00.0000000Z}.agent_id)) | 12000 | 5340.19 | 2026-05-08T14:58:00.0000000Z |
| DevOps ($(@{agent_id=a2; agent_name=DevOps; adapter=codex_local; status=active; spent_cents=9800; daily_delta_cents=7120.26; last_heartbeat_at_utc=2026-05-08T14:59:00.0000000Z}.agent_id)) | 9800 | 7120.26 | 2026-05-08T14:59:00.0000000Z |
| CTO ($(@{agent_id=a3; agent_name=CTO; adapter=codex_local; status=active; spent_cents=6100; daily_delta_cents=3560.13; last_heartbeat_at_utc=2026-05-08T14:57:00.0000000Z}.agent_id)) | 6100 | 3560.13 | 2026-05-08T14:57:00.0000000Z |

## Anomalies
- [critical] ORG_CAP_CRITICAL: Org spend reached hard-stop threshold.
- [critical] ORG_EXHAUSTION_LEQ_4D: Projected exhaustion window is within 4 days.
