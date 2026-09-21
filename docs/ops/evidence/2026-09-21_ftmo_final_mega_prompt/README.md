# OWNER 2026-09-21 FINAL FTMO MEGA Master Prompt — intake receipt (Fable, 2026-09-21 17:5x–18:2xZ)

- Verbatim: `owner_directive_verbatim.md` (sha256 `edc5af61f2f574719a5c2cdaacf92b64e4f05b8e39d10c7d36bf89868d4d2559`, 4185 lines).
- Decision record: `decisions/2026-09-21_owner_ftmo_final_mega_prompt_sunday_demo.md`; CLAUDE.md section
  OWNER-DEC-FTMO-FINAL-MEGA-20260921.

## 1. Codex plan probe (§O) — CODEX_PLAN = UPGRADED (pro), CODEX_QUOTA_STATE = weekly 0 %, reset 2026-09-28T17:57:49Z

| Step | Observation |
|---|---|
| `quota_pull.py` 17:5xZ (stored token from 2026-09-12) | HTTP 401 `token_expired`; last good snapshot 17:37Z still showed `plan_type prolite`, weekly used 39 %, reset 2026-09-26T08:44Z |
| trivial `codex exec` (read-only sandbox, scratchpad, "Reply OK") | refreshed `~/.codex/auth.json` (mtime 19:57 local), answered `OK`, 2,797 tokens |
| `quota_pull.py` 17:57:49Z | `plan_type: pro`, `rate_limit.primary_window {limit_window_seconds 604800, used_percent 0, reset_at 1790618269 = 2026-09-28T17:57:49Z}`, `secondary_window null` (no 5-hour window reported by the endpoint for this plan), `model_usage gpt-6-astra available`, credits 0 / no overage |
| `quota_governor.py` 17:59Z | codex used 0.0 % / elapsed 0.0 %, action noop "buffer (used 0 % < floor 15 %)"; claude 51.0 % / 54.8 % |
| `codex_budget_line.py --activate` 17:59Z | line re-anchored at (2026-09-21T17:59:09Z, 0.0 %), target 92 % at reset, slope 0.5477 %/h, `allowed: true` (the old anchor 2026-09-19 / 39 % against the 09-26 reset was stale scarcity) |
| `codex_fleet_pacer_state.json` before | `budget_line_hold`, line 31.8 %, next allowed in 11.5 h — the stale hold §O tells us to clear |
| `agent_quota_gate.v1.json` | `plan_tier pro_20x`, window enforcement mode `observe` (records, never refuses) — unchanged; the endpoint's `plan_type pro` is consistent with it |

Codex CLI 0.153.4, "Logged in using ChatGPT". No login action needed from OWNER.

## 2. Dispatch changes (§O priority list, §U)

| Ticket | Before | After |
|---|---|---|
| `d6189118` FTMO kill-switch governed initializer (Prague anchor, book tag, KS_DAY_ROLLOVER, pulse state check) | TODO 76, not exempt | IN_PROGRESS (routed 18:02Z) **86**, `codex_budget_line_exempt: true` — §O rank 1 |
| `7088da77` Velocity harness v2 | TODO 72, not exempt | IN_PROGRESS **84**, exempt; requirements appended: §K state vocabulary (CLEAR_REJECT / WORTH_MT5_TEST / UNKNOWN, never ECONOMICALLY_VALIDATED), §L golden test vs MT5 Every Real Tick trade-by-trade (acceptance-blocking), §J negative-lineage rule for 41485 — §O rank 2 |
| `a36a5983` News archive 2024 DST audit | TODO 78, not exempt | IN_PROGRESS **82**, exempt — §O rank 3 / §M |
| `3fae43b2` (new) account-level simulator confidence: financed inputs, seed-replicate SE, resolution flag, financed canonical re-run | — | TODO **81**, exempt — §O rank 4 / §U.5 / §V follow-up |
| `4505b206` (new) demo-day retro-audit + classification BEHAVIOR_IDENTICAL / POTENTIALLY_DIFFERENT / MATERIALLY_INVALID | — | TODO **80**, exempt — §N |
| `74c41987` (new) sleeve-level P&L attribution tool + Mission Control block | — | TODO **74**, exempt — §U.7 / §63 / §R OPERATIONS |
| `94a15624` (new) FTMO_DEMO_GENESIS_MANIFEST builder/verify + Sunday preflight tool | — | TODO **72**, exempt — §Q / §R / §U.9 |
| `4d655789` (new) compile-fail taxonomy (classification only) | — | TODO **60**, not exempt — §X / §O rank 9 |

The Codex orchestration lane (`QM_StrategyFarm_CodexOrchestration_15min`, one task-agnostic session, listed the IN_PROGRESS
set in priority order at 18:00Z: news audit → KS → harness v2 → feb6e536 → 160843a0) is the executor; `--max-sessions`
is Claude-only, so no second Codex session was started (session-race class, 2026-09-15).

**Fleet pacer disabled (receipt):** `QM_StrategyFarm_CodexFleetPacer` state Ready → **Disabled** at 18:0xZ
(`Disable-ScheduledTask`). Its prompt rotation (`D:/QM/strategy_farm/codex_pacer/prompts/focus_fx.md / focus_commodity.md /
focus_backlog.md`) spawns up to 4 agents whose mission is "advance the farm toward MORE certified portfolio sleeves" = card
builds and new-edge mechanisation = §O rank 10 and the hero-EA / card-count search §Z forbids. With the budget line freshly
open it would have consumed the first 5-hour windows on that. Rollback: `Enable-ScheduledTask -TaskName
QM_StrategyFarm_CodexFleetPacer` — planned once §O ranks 1–9 are in REVIEW, with an FTMO-focused prompt rotation.
Live codex processes at the time: one orchestration session (pid 13780, 20:00 local) — untouched.

## 3. Other §-items applied in this intake

- §J: `artifacts/cards_approved/QM5_41485_ny-preopen-range-breakout-jpy.md` (+ `D:` mirror) front matter
  `negative_lineage_tag: PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE`.
- §V: reconciled — `docs/ops/evidence/2026-09-21_ftmo_11708_sign_change_reconciliation/README.md`
  (`11708_SIGN_FLIP = EXPLAINED / EXPECTED_MODEL_IMPROVEMENT`; the +0.020 is not a resolved positive; 11708 → SHADOW_BOOK,
  11421 → HOLD, 11910 → REJECT).
- §F/§G/§Y: `docs/ftmo/FTMO_BOOK_CURRENT.md` v2 (INCUMBENT / SHADOW / DELTA / STRONGEST_MISSING), state JSON overlay,
  `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` (living pre-Sunday status).
- Provider state 18Z: Claude 51 % weekly (reset 2026-09-24T22:00Z), 5 h 6 %; Kimi `EXHAUSTED` flag since 2026-09-18 (CLI
  403 weekly/monthly limit); Antigravity `AGY_LOW_QUOTA.flag` reason `token_expired` since 2026-09-21T17:30Z (governor
  releases on a successful authenticated quota pull ≥ 20 %).
