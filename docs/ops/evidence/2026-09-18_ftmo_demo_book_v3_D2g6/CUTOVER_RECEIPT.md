# CUTOVER RECEIPT — FTMO demo book v3 = D2g6 (2026-09-18, executed by Fable)

Authority: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`. Decision: `docs/ftmo/FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` Addendum 4.
Terminal: FTMO Global Markets MT5 (data dir `…\81A933A9AFC5DE3C23B15CAB19C63850`), account 1514536732 / FTMO-Demo. T_Live and T1–T10 untouched.

| UTC | Step | Evidence |
|---|---|---|
| 04:2xZ | Governor rebind applied (6 magics, book 1.71875 %) | `governor_rebind_receipt.json`, commit `f695db6a02` |
| 04:3xZ | Clean shutdown (CloseMainWindow, PID 10836), authoritative profile backup | `profile_backup_pre_D2g6/` (11 charts + order.wnd) |
| 04:3xZ | `[Experts] Enabled` set 0 offline (terminal down; UI toggle unavailable headless) | `common.ini.pre_D2g6.bak` |
| 04:3xZ | `demo_install --package --execute` → INSTALLED_UNATTACHED_PARKED, 14 files, 2 backups | `install_receipt.json` |
| 04:3xZ | Target profile applied (9 charts) | `profile_target_D2g6/` (MANIFEST, PARSE_CHECK) |
| 04:39Z | Direct start: all six sleeves loaded, then **EA_MAGIC_RESOLUTION_FAILED** (sealed binaries compare `X.DWX` vs venue `X`) | experts log; per-EA DEINIT reason 8 |
| 04:4xZ | Alias builds of the six EAs from identical sources against canonical `framework/include` (0 errors / 0 warnings), installed; sealed binaries preserved | `RECEIPT_alias_builds.md`, `bin_ftmo_alias/`, `bin_sealed_replaced_by_alias/` |
| 04:43Z | Direct restart: all six INIT_OK; 10403 placed stop orders → broker 10027 "AutoTrading disabled" (expected) | per-EA logs |
| 04:4xZ | Verifier re-pinned to the actual chart numbering + alias hashes; governor preset deployed LF-normalized → `VERIFIED` | commit `85fcd098d6` |
| 04:47Z | Clean shutdown → `FTMO_ON.ps1` (verifier PASS, `Enabled=1` pinned, launched PID 10712) | `D:/QM/reports/state/live_launcher_events.jsonl` |
| 04:48–04:50Z | All six INIT_OK; pending orders live (10403 XAUUSD ×2, 11422 USDCAD); `demo_cycle` new cycle NEW, roster_hash `5432d3db…`, attached_dark 0 | `D:/QM/reports/state/ftmo_demo_cycle.json` |
| 04:5xZ | Orphan position of the removed 1537 sleeve closed via MetaTrader5 API (deal 522542664, +36.70 USD); positions empty | `orphan_1537_close_receipt.json` |

Rollback: restore `profile_backup_pre_D2g6/` into `MQL5/Profiles/Charts/Default`, restore backed-up binaries/presets from the install backups, re-pin the verifier to the previous table (git history `abf9175f7b^`), relaunch via `FTMO_ON.ps1`.

Known follow-ups: EXPECTED_MAGICS now roster-driven (57bfd3af); pulse read-model refresh pending; Friday-flat presets vs weekend-holding streams (GAPS); XAUUSD ×3 advisory cap; real venue financing to be measured in this cycle; demo acceptance contract (§51) to be written before any judgment; the sealed-vs-alias binary lineage means demo evidence is DEMO-BURN-IN, not gate evidence.
