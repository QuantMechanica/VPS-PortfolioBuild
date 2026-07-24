# 2026-07-24 — OWNER approvals: audit-implementation package (NEEDS_FABIAN 1–6)

**Source (written approval):** OWNER chat 2026-07-24 — „1 bestätigt, 2 bleibt 10%,
5 Wave läuft Sonntag wie geplant, alles freigegeben!" — plus all six checkboxes
ticked in the Vault mirror `G:\My Drive\QuantMechanica - Company Reference\NEEDS_FABIAN.md`.

| # | Item | OWNER decision | Operative effect |
|---|---|---|---|
| 1 | 24-sleeve as-deployed manifest (ESC-02) | **Countersigned.** | `approved_by` updated in the manifest; countersigned content sha256 `a766b5baed6075decaf6...dbf` (full: `a766b5baed6075decaf26617a3871c413e6879f6286fa498d7b1b01de3db6908`; post-signature file sha differs by the approved_by field only). Superseded by the 26.07 wave manifest when it lands. |
| 2 | Book-DD halt threshold (ESC-01) | **Stays 10.0%.** | `QM_BOOK_DD_HALT_PCT` default confirmed; decisions/2026-07-24_live_book_dd_guard.md annotated. |
| 3 | News-blackout exemptions (ESC-05) | **Ratified** ("alles freigegeben"). | Draft promoted to `decisions/2026-07-24_news_blackout_exemptions.md`; matrix news cells 12778/13117/13128 re-graded FAIL → PASS_EXEMPT; annex added to Vault `01 Identity/Hard Rules.md`. |
| 4 | 20048 WTI pre-holiday Friday-close-off (ESC-06) | **Approved as recommended**: decision deferred to its Q12 review (no exception granted today; currently moot — 20048 is Q11 FAIL_PORTFOLIO). | Matrix cell stays FAIL until a Q12 exception is granted. |
| 5 | 26.07 recompile wave (ESC-03) | **Confirmed for Sunday 26.07.** | Wave retires: 11 dead-KS-channel binaries, P0.1 deinit-kill on all 24, P0/P1 bundle, 13128 calendar guard, 2 news-selftest gaps, and rolls the Q03 binding fix to the remaining 8 workers. Claude owns SHA manifest + T_Live verification per the standing reservation. |
| 6 | DD-guard stale-telemetry policy | **Approved as implemented** (loud escalation, no auto-halt) + timer-driven EQUITY_SNAPSHOT approved for the wave bundle. | Codex task enqueued for the EQUITY_SNAPSHOT timer emission (include-level, rides the wave); staleness limit tightens after it ships. |
