# NEEDS FABIAN — decisions/countersigns from the 2026-07-24 audit implementation

> **ALL 6 ANSWERED by OWNER 2026-07-24** — see
> `decisions/2026-07-24_owner_approvals_audit_package.md` for the per-item record.
> Retained for provenance; the Vault mirror carries the ticked checkboxes.

1. **Live-book manifest countersign (ESC-02).** New as-deployed 24-sleeve manifest
   `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`
   (sha256 `a766b5baed6075decaf26617a3871c413e6879f6286fa498d7b1b01de3db6908`,
   status LIVE, `approved_by: PENDING_OWNER_COUNTERSIGN`). It records deployed
   reality (verified twice, Claude+Codex); it authorizes nothing. Please
   countersign (reply or edit approved_by) — the 26.07 wave manifest supersedes it.
2. **Book-DD halt threshold (ESC-01).** The new `QM_StrategyFarm_LiveBookDDGuard`
   trips at **10.0%** book drawdown from HWM (env `QM_BOOK_DD_HALT_PCT`; details
   `decisions/2026-07-24_live_book_dd_guard.md`). Confirm 10% or name your number.
3. **News-blackout exemptions (ESC-05).** Ratify (or reject) the draft
   `DECISION_DRAFT_news_exemption_2026-07-24.md` (baskets 12778/13117 + event-EA
   13128). Until ratified, their matrix news cells stay FAIL.
4. **20048 WTI pre-holiday (ESC-06).** Source hardcodes `qm_friday_close_enabled=false`
   (weekend holds are the strategy). Needs your explicit Q12 exception or a redesign
   before any live admission. Recommendation: decide at its Q12 review, not before.
5. **26.07 wave (ESC-03).** Confirm the wave runs Sunday 26.07 as planned. It retires:
   11 dead-KS-channel binaries, P0.1 deinit-kill on all 24, the full P0/P1 bundle,
   13128's calendar-horizon guard, and the 2 news-MISSING selftest gaps. If it slips
   >1 week I recommend an interim rebuild of only the 11 dead-channel sleeves.
6. **DD-guard stale-telemetry policy (codex review finding 5).** Today the guard
   goes loudly BLIND on stale equity telemetry (escalating alarm) but does NOT
   auto-halt the book; codex recommends fail-closed (halt on prolonged telemetry
   loss). Auto-halt would flatten all 24 positions on a monitoring outage — your
   call. Also recommended for the wave: a timer-driven EQUITY_SNAPSHOT emission
   (currently event-driven, gaps up to 20.6h) so the staleness limit can tighten
   from 50h to ~2h.
