# Escalations — Factory Audit 2026-07-24

> **ALL DECIDED 2026-07-24** (OWNER: "alles freigegeben"; record
> `decisions/2026-07-24_owner_approvals_audit_package.md`): ESC-01 built+10%
> confirmed · ESC-02 countersigned · ESC-03 wave confirmed Sunday 26.07 ·
> ESC-04 rule amended · ESC-05 exemptions ratified · ESC-06 10145 re-gated,
> 20048 deferred to Q12. Text below retained as decision context.

Decisions only OWNER can make. Each item is decision-ready: context, options, and the
audit's recommendation. Nothing here blocks the factory today; ESC-01/ESC-03 are
live-money-relevant.

## ESC-01 — Max-DD kill channel has no producer (book-wide FAIL)

KS_PORTFOLIO_DD is deployed armed in existence-trip mode (halt_pct=0.0 ⇒ mere signal-file
existence halts, `QM_KillSwitch.mqh:435-436`) but **no live process writes any signal
file**: the only writer in the codebase (`ftmo_trial_pulse.py:231-241`) is gated on
`FTMO_DD_FLOOR_ARMED.flag` which is absent, and all halt dirs are empty
(`evidence/framework__killswitch_portfolio_dd.txt`). The DXZ book has no equity-DD
monitor at all — the max-DD kill is dead in practice, matrix column FAIL ×24.
**Options:** (a) build a small live book-DD monitor (reads `live_book_pulse.json`
equity, writes the per-book signal file on breach; scheduled task, strictly read-only
on T_Live files) — recommended; (b) formally accept "no EA-side max-DD kill, DXZ VaR
limit is the guard" and re-grade the column N_A by decision. Note: 11 pre-fix binaries
cannot receive ANY file-channel halt until rebuilt (ESC-03), so (a) only becomes fully
effective after the wave.

## ESC-02 — Live-book manifest is a stale 23-sleeve DRAFT

`D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json`
(status=DRAFT) vs 24 actually loaded sleeves: 3 ghosts (10476, 10692, 10715), 4 live
sleeves unlisted. The T_Live hard-rule workflow assumes an OWNER-approved manifest
matching the book. **Ask:** regenerate a 24-sleeve manifest and approve it in writing
(natural vehicle: the 26.07 wave manifest).

## ESC-03 — 26.07 wave is the single dependency for three debt classes

The wave retires (1) the 11 dead-KS-channel instances (9 EAs, fix `47f1d9709` in tree
since 07-05), (2) P0.1 deinit-kill exposure present in ALL 24 live binaries (07-20 fix
`5b21b9b1d` in tree, newest live build is 07-17), (3) the rest of the P0/P1 bundle
(P0.2 frozen cap, P0.5 pending-stack, P0.6 CSV-boot-brick, P1.1-P1.6). **Ask:** confirm
the wave date. If it slips >1 week, the audit recommends an interim rebuild of only the
11 dead-channel sleeves (restores halt capability without the full dual-book choreography).

## ESC-04 — Operating Rule 13 is stale (gemini lane)

Rule 13 (OPERATING_RULES_2026-07-03) says the gemini scheduled lane is defective and
must stay disabled; in reality `QM_StrategyFarm_GeminiOrchestration_15min` is enabled,
heartbeating, and completed a real agy dispatch 07-23 16:30Z rc=0. **Ask:** ratify the
re-enabled lane (update the rule text) or order it disabled again.

## ESC-05 — News-blackout opt-outs by design (3 live sleeves)

12778 + 13117 (basket EAs, `qm_filter_news_enabled=0` in deployed sets) and 13128
(pre-FOMC drift, all news axes off by documented design — the qm gate would block the
strategy's own pre-statement exit inside the blackout window; source :17,:328) violate
the letter of the mandatory-news-blackout charter item; graded FAIL ×3 in the matrix.
Implementation update 2026-07-24: 13128's compiled FOMC table DOES have a
fail-closed validity horizon (20261231) in HEAD since commit 2b7e73b83 (07-15) —
the deployed 07-13 binary just predates it; the 26.07 rebuild closes that gap. **Ask:** (a) grant a documented exemption
class for basket/event sleeves (with rationale recorded next to the Hard Rules), or
(b) order news filters enabled / 13128 given a maintained calendar source with a
stale-guard. Until decided, the FAILs stand.

## ESC-06 — Candidate defects needing sign-off before any live admission

- **10145 (3 Q10-PASS ablation configs):** factory sets carry only legacy
  `qm_filter_news_*` keys the current source no longer reads → news effectively OFF
  while the Q10 aggregates claim PRE30_POST30/DXZ compliance. Metadata contradicts the
  tested config; recommend set regeneration + Q10 re-run before Q11/Q12 consideration.
- **20048 (WTI pre-holiday):** source hardcodes `qm_friday_close_enabled=false`
  (holds over weekends by design). Needs an explicit OWNER exception at Q12 or a
  redesign; graded FAIL until then.

## Cross-review note

No verdict divergences between Claude and Codex remain unresolved — all 8 contested cells (6 divergence classes) adopted the stricter reading (see `COMPLIANCE_MATRIX.md` § Divergence resolution).
The items above are policy questions, not evidence disputes.
