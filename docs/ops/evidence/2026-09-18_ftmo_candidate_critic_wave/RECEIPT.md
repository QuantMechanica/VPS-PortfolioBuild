# FTMO candidate critic wave — 2026-09-18 (Fable, independent non-Kimi critic)

**Authority:** `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` (directive §31–§33). Creator: Kimi (interim
delegation 2026-09-15/16). Critic seat: Claude / `claude-fable-5-1` (Fable orchestrator). Method: three parallel
read-only Claude audit agents, one per EA, against the 40-item critic contract of directive §32; Fable personally
re-read the source for every BLOCKING finding before accepting it and before authoring a fix. Individual verdicts,
never combined. AI review means "ready for the deterministic pipeline" — Q02–Q14 remain the judge.

Critiques (full text, file:line evidence): `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/`
`critique_41475_hcw_fable_20260918.md` · `critique_41476_hmr_fable_20260918.md` · `critique_41477_hfxmr_fable_20260918.md`.

## Verdicts

| EA | Verdict | Blocking / Major / Minor | Fix commit (EA branch) | Post-fix compile |
|---|---|---|---|---|
| QM5_41475 H-CW | ACCEPT_WITH_FIXES → fixes applied → APPROVE for Q00 | 1 / 4 / 6 | `b473a5710d` on `agents/kimi-hcw-20260915` | 0 errors, 0 warnings (MetaEditor64, canonical include tree) |
| QM5_41476 H-MR | ACCEPT_WITH_FIXES → fixes applied → APPROVE for Q00 | 2 / 3 / 5 | `e149aaa872` on `agents/kimi-hmr-20260916` | 0 / 0 |
| QM5_41477 H-FXMR | ACCEPT_WITH_FIXES → fixes applied → APPROVE for Q00 | 1 / 5 / 6 | `eb85a6af0e` on `agents/kimi-fxmr-20260916` | 0 / 0 |

Merged one-directionally into `agents/board-advisor` (canonical checkout): `667cd8f25a` (H-MR; card add/add conflict
resolved to the canonical side, which already carries the QM5_10140 differentiation paragraph), `b988277f3b`
(H-FXMR), `4118ab5636` (H-CW). No `.ex5` committed (EX5_COMMIT_GUARD PASS on every commit); setfiles keep
`; build_hash: pending`.

## Blocking findings — verified by Fable and fixed

1. **B-NEWS (all three).** The card-level high-impact blackout (`Hcw/Hmr/FxmrNewsBlackoutBlocks`) called
   `QM_NewsInit("D:\QM\data\news_calendar")` + `QM_NewsInWindow` unconditionally, i.e. a LIVE build would read the
   factory backtest archive — Hard Rule violation ("live EAs never read the backtest news archive", framework
   principle 8) and a contradiction of the cards' "native calendar" claim. Fix: when `MQL_TESTER==0 &&
   MQL_OPTIMIZATION==0` the hook now calls the framework's `QM_NewsLiveInWindow(_Symbol, TimeTradeServer(),
   minutes, 0, ok)` and blocks when `!ok || in_window` (fail-closed). Tester path unchanged (deterministic archive).
   Impact threshold follows `qm_news_min_impact` (default `high`).
2. **B-WINDOW (H-CW, H-MR).** The entry window `[start+N, end]` was tested on the FORMING bar's hour while the
   signal was read from the closed bar (shift 1). Effect: the last range/window bar was dead and the `session_end`
   signal bar was dropped — with defaults only the 16:00 UTC signal bar could fire, halving the preregistered
   pilot's signal set (`h_mr_fire_count.py` applies the window to the signal bar). Fix: the window is evaluated on
   `iTime(_Symbol, PERIOD_H1, 1)`; `now` still governs Friday cutoff and flatten proximity. With defaults the
   signal bars 16:00 and 17:00 UTC fire (entries 17:00 / 18:00), flatten 20:00.

Also fixed: stale `PENDING_ALLOCATION / do not pipeline` headers in the `.mq5` files and SPEC.md (registry rows
have been active since 2026-09-15/16).

New `.ex5` sha256 from the verification compiles (not committed; the COMPILE_EA lane rebuilds and binds):
H-CW `88d00038aefef694dfa266837626e897ab3cf4f6f1c07bab4081f7442300ad0e` ·
H-MR `fda3f2a945e12239d7f3ab3cbafda2b4fea3e8c45ba4b903039395eccf3fc936` ·
H-FXMR `26c0302e57722f654ceb6ca03442dff5889a1657e7313e44a3eb6cb552fadc30`.

## Major / minor findings — disposition (deferred, tracked)

| # | Finding | EAs | Disposition |
|---|---|---|---|
| M-DST | Fixed 13:00 UTC session start does not track the US cash open across DST (13:30 UTC summer / 14:30 winter); GDAXI's own cash open is 07:00/08:00 UTC, so "cash-open" is a US-overlap thesis for GDAXI | H-CW, H-MR | Preregistered UTC anchors are kept for lineage v1 (the pipeline judges over both DST regimes). A v2 lineage with exchange-local (America/New_York) anchoring is pre-registered as the follow-up hypothesis; not silently changed now. |
| M-RISK | Backtest `RISK_FIXED=1000` (1% of 100k) vs live `RISK_PERCENT=0.25` → the %-of-equity breakers (−1%/−2%) trip 4× more easily in the tester; density/breaker statistics not fully representative of live | all three | Company baseline (fixed-risk comparability) retained for Q02–Q08. Before any Demo/portfolio use, a representative run at `RISK_FIXED=250` (or R-denominated breakers as lineage v2) is required; flagged in the FTMO gap document. |
| M-FAMILY | `max_positions_total` family cap cannot be exercised in the single-symbol tester; index concentration (NDX/GDAXI/SP500 co-moving) must be measured, not assumed | H-CW, H-MR | Q08 dependence panel / portfolio layer. No code change. |
| M-COUNTERS | Entry counters set on signal, not on fill: a rejected live order burns the window's one entry | H-FXMR | Live-only concern; acceptable for tester evidence. Follow-up before Demo: move the "traded" flag to a fill-confirmed path. |
| M-STOPS | No EA-level `SYMBOL_TRADE_STOPS_LEVEL`/freeze check | H-FXMR (all) | Framework `QM_TradeManagement.mqh:214-243` enforces stops-level distance with live hygiene; EA-level duplication not required. Closed. |
| M-STRETCH | Run-of-closes stretch has no magnitude floor (three tiny same-direction closes qualify) | H-FXMR | Preregistered design choice; falsifiable by Q02/Q08. No change. |
| M-SPREAD | Spread filter fails open on `.DWX` zero modeled spread; live spread-shock protection unvalidated | all three | Known factory property (`.DWX` zero spread). Cost fidelity is covered by the Q05/Q06 stress arms and the Demo. |
| m-LIVESET | Live setfiles still carry `.DWX` symbol inputs → `INIT_SLOT_MISMATCH` on a real broker symbol | all three | Deploy packaging rewrites slot inputs to bare broker names (SPEC §3). No change now; checked at Demo packaging. |
| m-GRID | `target_r` grid 1.5–2.0 narrow and undocumented | H-CW | Documentation follow-up on the card at next amendment. |
| m-DENSITY | Pilot density 2.9/month/symbol (one NDX-class feed), below the card's own ≥3 active days/month bar | H-MR | Stated as weak factory-time candidate; pipeline decides. Lowest priority of the three for Q02 fanout. |
| Prior H-CW findings (2026-09-15 REVISE) | small-sample reliance / index concentration / session-definition look-ahead; minor: breaker vs min-trading-days, target_r grid, spread warm-up | H-CW | Look-ahead: none found (shift-1 reads); spread warm-up fixed (`strategy_spread_min_days=5`); the rest are validation-agenda items carried into Q08 and the M-DST follow-up. |

## Cost fragility (H-FXMR, from the critique)

Round-trip cost ≈ 0.85 pip (Darwinex commission modeled in the tester; spread not) vs ≈ 8.75-pip TP → ≈ 10% of target,
≈ 0.12R per trade; the thesis needs gross ≥ +0.22R/trade to clear the card's +0.10R kill floor. Moderately fragile; the
Q05/Q06 cost arms and the Demo spread observation are the decisive evidence.

## Independence

H-MR vs QM5_10140: genuinely different thesis (FX London M5 continuation vs index H1 failed-breakout reversion); the
prescreen NEAR_DUPLICATE score 1.0 is a vocabulary-subset false positive — adjudication upheld. H-MR vs H-CW:
~80% shared strategy-module code but disjoint entry triggers (close-outside vs pierce-and-close-inside cannot co-fire
on the same bar); joint risk is bounded per magic, not jointly — must be correlation-measured at Q08.

## Gate transitions executed 2026-09-18

- `critic_receipt.json` written for QM-RESEARCH-2026-0002 / 0005 / 0006 (schema `qm.agent-chain.receipt.v1`, creator
  Kimi, critic Claude/`claude-fable-5-1`, `repo_write:false`).
- `research_source.py seal` → new `source_hash`: 0002 `55c97b90…9904` (status reviewed), 0006 `bafb38da…f8b2`,
  0005 `54880ead…7934` (status preregistered); `verify` → `ok: true` for all three.
- Cards 41476/41477 `source_hash` rebound + in-place `approve-card`; prescreen results recorded in the session log
  (target: KEEP ×3, H-MR NEAR_DUPLICATE demoted to warning).
- Next: `farmctl enqueue-compile` ×3 → `release_compile_wave.py --apply` → COMPILE_OK → governed smoke →
  `intake-first-q02 --apply` (canary symbols NDX.DWX / NDX.DWX / EURUSD.DWX).

## Cross-vendor review of the fix diffs

Requested from Antigravity (`agy -p`, read-only prompt with the three unified diffs):
`D:/QM/reports/ai_exchange/20260918_critic_fix_diff_review_agy/` (prompt.md, agy_review*.md). Result appended below
when available.

### Antigravity result (2026-09-18 ~00:3xZ, `agy --dangerously-skip-permissions -p`, read-only prompt)

Verdict APPROVE ×3 (`agy_review_v2.md`): live branch fail-closed in every path; `TimeTradeServer()` is the correct
clock for the calendar API; before/after asymmetry consistent with the tester path; `MQL_OPTIMIZATION` guard redundant
but harmless; signal-bar window leaves no dead bar (defaults: signal bars 16/17 UTC → entries 17:00/18:00, flatten 20:00).
**One interaction finding accepted and fixed:** the Friday cutoff (`>= 17` on the forming-bar hour) blocked every
Friday entry because the earliest entry evaluation is at 17:00 — moved to the closed signal bar's hour/day, matching
the preregistered pilot ("Friday only the hour-16 bar may signal"). Recompiled 0/0; see the follow-up commits on the
H-CW/H-MR branches.
