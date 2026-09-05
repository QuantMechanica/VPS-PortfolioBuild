# Mutation-lock attribution — post-deploy 2 h measurement (2026-09-05)

Written 13:29Z. Tool: `tools/strategy_farm/mutation_lock_attribution.py --hours 2 --end-utc 2026-09-05T13:25:20Z`. Output: `docs/ops/evidence/mutation_lock_postdeploy_2h.json`. Attribution deploy: 871054b591 (11:26Z, workers reloaded in staggered idle-only chunks).

| Window (UTC) | Busy events | UNKNOWN owner | Top owners (count, median hold s) |
|---|---:|---:|---|
| 06:17–08:17 (pre-deploy, `2026-09-05_mutation_lock_owner_attribution.json`) | 110 | 47 | claim_atomic T6 13 / 1.4 s; T7 8 / 3.1 s; T10 7 / 4.3 s; matrix service 4 / 0.8 s |
| 11:25–13:25 (post-deploy) | 165 | **0** | **claim_atomic T10 29 / 63.1 s**; T5 19 / 1.7 s; T9 18 / 1.8 s; T8 17 / 2.1 s; T3 14 / 1.7 s; **sweep_enqueue_built_eas 8 / 58.0 s** |

## Reading

- The attribution deploy closes the UNKNOWN class completely (47 → 0); every busy observation now carries an owner and a hold age.
- The higher busy count (165 vs 110) coincides with the D1-prescreen skip waves (12:40–13:15Z, 1,323 cells marked `SKIPPED_PRESCREEN` by the matrix service) and with the sweep; the MEASURED census rate stayed flat at 14–21 cells per 10 min, so the busy events cost claim latency, not throughput.
- Two hold-time outliers stand out and are commissioned for diagnosis and a lock-scope-reduction proposal (Codex 62f54fa5): T10 `claim_atomic` holds the lock for a 63 s median while every other terminal holds it for about 2 s, and `sweep_enqueue_built_eas` holds it for 58 s.
- `post_deployment_window_proven` stays false by design: the tool wants a deployment receipt to prove log coverage; the deploy commit and reload evidence are recorded in OPEN_ITEMS (11:26Z addendum).
