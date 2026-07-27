# FTMO campaign — consolidated state after remediation + adversarial verification

**Date:** 2026-07-27
**Author:** Claude
**Scope:** Read-only synthesis of five verification passes over the 2026-07-26/27 defect-fix
round. No EA/framework/set/manifest source edited by this doc. No Factory OFF/ON.
**Inputs verified:** commits `d5917a9ff`, `71b6cf87f`, `aadad1616`, `fcd46e6fc`, `2b4040f28`,
`6344682e7` on `agents/board-advisor`; live DB `D:/QM/strategy_farm/state/farm_state.sqlite`
(opened `mode=ro`, mtime 06:21); the four `*_ftmo_challenge.set` files; the deploy manifest;
`QM_Common.mqh` / `QM_RiskSizer.mqh` / `QM_PropFirm.mqh` read directly.

---

## Bottom line (read this paragraph)

**The book that would actually deploy today is materially worse than any headline.** The
framework hard-clamps every one of the four campaign legs to **1% of equity per trade (1×
backtest size)** — verified line-by-line in source — so the manifest's 4/4/8/8 sizing is
fiction the framework silently discards. The 90.2% headline was already refuted to **79.5%**
(commit `71b6cf87f`, below OWNER's 80% target), but even that 79.5% describes a *different,
lower-leverage book* (`9936+13213/USDJPY, 13301+13036/GDAXI` at ≤5×) — **not** the manifest
book — and is itself still optimistic. **The pass rate for the configuration the framework
will genuinely run today — the manifest book at a forced 1× — has never been measured. It is
strictly worse than 79.5% because sizing is one-quarter to one-eighth of what those odds
assume.** On top of that, the live DB shows **all four manifest legs carry a Q09 FAIL_PORTFOLIO
verdict** — the deployable book is composed entirely of sleeves that failed the portfolio gate.
There is no book on the table that is simultaneously Q09-admitted, deployable at its assumed
leverage, and measured at ≥80%. A demo run today is not worth starting.

---

## 1. Defect status — what is fixed, partial, not fixed

| # | Item | Commit | Verdict | Fixed in source? | Fixed in what deploys? |
|---|------|--------|---------|------------------|------------------------|
| 1 | PropFirm: per-account state, confirmed flatten, dead-input removal, doc divergence | `d5917a9ff` | CONFIRMED | **Yes** | **No — recompile debt** |
| 2 | Risk-cap clamp (campaign deploys at 1×) | `aadad1616` | CONFIRMED (analysis) | **No — analysis only** | **No** |
| 3 | Sleeve funnel reconciliation | `6344682e7` | PARTIAL | n/a (evidence doc) | n/a |
| 4 | Five falsified-claim doc corrections | `2b4040f28` | PARTIAL | n/a (doc) | n/a |
| 5 | Q09 re-run assessment (13036/13301) | `fcd46e6fc` | CONFIRMED | n/a (evidence doc) | n/a |

### Genuinely fixed
- **PropFirm four defects (`d5917a9ff`) — real code, in the tree.** Independently confirmed in the
  committed header: `prop_state_account_mismatch` (per-account state, login+server keyed),
  `QM_PropOpenPositions` + `prop_target_flatten_pending` (flatten-before-persist with a zero-open
  confirm), the `LIVE TARGET SEMANTICS` doc block, and **0** repo-side matches for the removed
  `prop_daily_loss_pct`/`prop_total_loss_pct` inputs. Compile log present
  (`scratchpad/propfirm_compile.log`, `0 errors, 0 warnings`).
- **Q09 re-run decision (`fcd46e6fc`).** 13036 correctly **refused** (Q09 FAIL post-dates the Q08
  PASS by ~2.5h and grades identical bytes → identical reject; refusing the review's false premise
  was correct). 13301 correctly **enqueued** (borderline, stream changed FAIL_SOFT 742 → PASS 551,
  `max_corr 0.498` just over the 0.40 line). Live DB confirms exactly **one** pending
  `Q09_PORTFOLIO` farm-wide (13301, `2026-07-27T04:28:10Z`), no duplicate rows, no Factory toggle.

### Partially fixed / defect stands
- **Risk-cap clamp (`aadad1616`) is a CONFIRMED diagnosis, not a fix.** The commit is a 246-line
  analysis doc. **No set file, EA, or manifest was changed.** The book still clamps to 1×. I
  re-derived the chain against source and it holds exactly:
  - `QM_Common.mqh:182` `QM_RiskSizerSetCapPct(1.0)` — unconditional.
  - `QM_RiskSizer.mqh:86-88` PERCENT cap = `equity × (1.0/100)` = 1% of equity.
  - `QM_RiskSizer.mqh:111-114` `weighted_risk (0.04·eq) > cap (0.01·eq)` → clamp to 1%.
  - All four `*_ftmo_challenge.set`: `RISK_FIXED=0`, `RISK_PERCENT=4/4/8/8`, `PORTFOLIO_WEIGHT=1`,
    **no `qm_risk_cap_pct` line**. Three of four EAs (13213, 10553, 13036) cannot even read the
    override input; 10848 has it but runs its compiled default `1.0`. So all four → 1×.
  - Override ceiling is **5.0** (`QM_Common.mqh:319`, tied to the FTMO daily-loss limit). The two
    8× legs (10553, 13036) are therefore **structurally impossible** — 8 > 5 fails closed.
- **Funnel reconciliation (`6344682e7`) — core CONFIRMED, one stability claim REFUTED.** The
  routing-code citations are exact and the snapshot figures reproduce (gate-clean 63, qualifying 9,
  Q08 FAIL_HARD 91, PASS_LOWFREQ blockers 0). But the doc's guarantee that the "9 / 16 / 0 decision
  layer is stable" is false: I confirmed on the live DB that **10582/XAUUSD Q08 = INFRA_FAIL at
  `2026-07-27T04:36:23Z`** — one minute after the commit — flipping the headline row-#1 qualifying
  sleeve into the infra-only bucket (qualifying 9→8, infra-only 16→17). Recoverable, but the
  stability claim was overstated on the very sleeve the doc foregrounded.
- **Doc corrections (`2b4040f28`) — 5 corrections clean, one sub-claim stale.** Correction A states
  "13036/GDAXI is `Q09_PORTFOLIO = pending` (never judged)." The **live DB says
  `QM5_13036/GDAXI = FAIL_PORTFOLIO, done, 2026-07-26T19:56:28Z`** — I confirmed the row directly.
  The claim was measured against a ~43-min-stale snapshot and even contradicts its own parent commit
  `fcd46e6fc` ("13036 disqualified... Q09 FAIL"). Direction runs *toward* the thesis (13036 is
  failed, not merely un-judged), so correction A's headline ("treat as un-admitted") is strengthened,
  not broken — but the committed text carries a factual error.

---

## 2. The DEPLOYABLE configuration today

**Book (deploy manifest `2026-07-27_ftmo_challenge_deploy_manifest.json`):**

| Leg | EA | Symbol / TF | Manifest RISK_PERCENT | **Cap the framework honours** | **Deployed size** | Live Q09 verdict |
|-----|-----|-------------|----------------------|-------------------------------|-------------------|------------------|
| 1 | QM5_13213 balke-gmt3-range-breakout | USDJPY H1 | 4 | 1.0% | **1×** | FAIL_PORTFOLIO (07-25) |
| 2 | QM5_10848 tv-mtf-ambush | XAUUSD H1 | 4 | 1.0% | **1×** | FAIL_PORTFOLIO (07-14) |
| 3 | QM5_10553 mql5-rsioma | XAUUSD H4 | 8 | 1.0% | **1×** | FAIL_PORTFOLIO (07-16) |
| 4 | QM5_13036 balke-go-long-regime | GDAXI M15 | 8 | 1.0% | **1×** | FAIL_PORTFOLIO (07-26) |

- **Per-account RISK_PERCENT the framework will actually honour: 1.0% for all four legs, full
  stop.** The set files say 4/4/8/8; the framework clamps every one to 1%. A demo run would emit a
  `per_trade_cap` `RISK_CLAMP` on every entry of all four legs — that log storm is itself the proof
  the book trades at 1×.
- **Measured pass rate for this configuration: none exists.** Every published figure is for a
  larger-sized and/or different book:
  - **90.2%** — refuted headline. Do not cite.
  - **86.3% OOS** (`FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md`) — computed at 4/4/8/8 sizing the
    framework discards, and includes XAUUSD sleeves where the MAE lower-bound is unbounded (see §4).
    Does not describe anything deployable.
  - **79.5% OOS** (`71b6cf87f`, `challenge_defensible.py`) — the most honest figure to date, but it
    is a **different book** (`9936+13213/USDJPY, 13301+13036/GDAXI`) at **≤5×**, restricted to
    ≤1%-multi-day sleeves, and it is **below OWNER's 80% target**. It still assumes "touch = pass",
    an unenforced 4-trading-day minimum, UTC (not CE(S)T) day boundaries, and a holdout reused
    adaptively all session. It excludes the two XAUUSD legs (10848, 10553) that the manifest
    *includes*.
- **Net:** the manifest book at its forced 1× has never been simulated. It is strictly worse than
  79.5% (sizing is ¼–⅛ of the assumed sprint sizing), and its members all failed Q09. There is no
  measured, deployable, gate-admitted ≥80% configuration.

---

## 3. Blocking items before a demo account is worth running at all

1. **Risk cap is not wired.** The 1× clamp is diagnosed but unfixed. Either (Option A) add
   `input qm_risk_cap_pct` + `QM_FrameworkSetRiskCapPct(...)` after `QM_FrameworkInit` to 13213 /
   10553 / 13036, set `qm_risk_cap_pct` in all four set files (≤5.0), recompile through the build
   lane, and **pin + SHA256-verify the deployed `.ex5`** (Round25 deploy-revert hazard); or (Option B)
   deliberately accept 1× and **re-measure the book at 1× first.** Deploying as-is tests a book
   nobody has simulated.
2. **The two 8× legs cannot exist.** 10553 and 13036 are capped at 5×; they must be re-sized ≤5× (or
   the book's risk budget re-derived) and the joint pass-rate simulation re-run at achievable
   leverage. Until then the manifest's 8× rows are undeployable.
3. **No deployable book has a measured ≥80% pass rate.** 79.5% is (a) below target, (b) for a
   different book than the manifest, (c) still optimistic. Before spending a demo, produce one honest
   simulation of an *actually deployable* book (correct members, ≤5× where the framework honours it,
   close-date MAE defect resolved) and confirm it clears the target.
4. **Every manifest leg is Q09 FAIL_PORTFOLIO** (live DB, all four). The deployable book is entirely
   portfolio-gate rejects. Either re-run Q09 for a re-sized book or pick a book with live
   PASS_PORTFOLIO members — do not demo a book of Q09 failures.
5. **PropFirm binaries carry the old logic.** The `d5917a9ff` fixes (per-account state, confirmed
   flatten) are in the tree but the deployed `.ex5` still holds pre-fix logic until a `--force`
   recompile + SHA-pin. The per-account-state guard that would stop one account's target state
   bleeding into another is **not protecting any live/demo account yet.**
6. **MAE-breach model is unsound for the XAUUSD legs.** `challenge_final.py:110` buckets every trade
   by close date and discards entry time, so a position open across multiple days is invisible to
   every intermediate day's daily-loss check. Multi-day share: 10848 39.5%, 10553 44.7%, 10582 44.3%
   (`71b6cf87f`). 10553's worst single-trade MAE is −2,070 at 1× → −9,315 at 4.5×, which can breach
   the 5% daily cap on a day the model shows nothing. Any pass rate that includes these sleeves is not
   a lower bound. Fix the model or exclude the sleeves before trusting a number.

---

## 4. Verification findings nobody has addressed yet

- **10582/XAUUSD Q08 INFRA_FAIL (`04:36:23Z`)** — recoverable, needs a requeue. It was the funnel
  doc's headline row-#1 qualifying sleeve (1,683 trading days) and the top "finish Q08" recommendation;
  it is currently sitting in the infra-only bucket, not gate-clean. Nobody has requeued it.
- **9936/USDJPY Q08 is still `active`** (`03:55:05Z`), never completed its own gate, no Q09 row. Yet
  9936 is a member of the 79.5% "defensible" book. That figure leans on a sleeve that has not cleared
  Q08 — so 79.5% is not even a clean-gate book.
- **The load-bearing measurement method is not in the repo.** Multiple docs cite
  `scratchpad/parallel_accounts.py:154` — an ephemeral session-temp file. A committed reader cannot
  reproduce the campaign's headline numbers. Per the evidence-over-claims rule this belongs in the
  repo (e.g. alongside `challenge_defensible.py`).
- **Four modelling caveats from `71b6cf87f` remain open and unfixed:** "touch = pass" overstates FTMO
  (which requires balance above target with all positions closed); the 4-trading-day minimum is
  unenforced; day boundaries are UTC not CE(S)T; the holdout was reused adaptively across the whole
  session. Each pushes the true pass rate below 79.5%.
- **The `86.3%` figure is still live in `FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md`** as the
  campaign's measurement basis even though it describes the clamped-away 4/8× book. It should be
  struck/annotated the same way the other five claims were, or it will be re-cited as if deployable.

---

## Evidence index

- Clamp chain: `framework/include/QM/QM_Common.mqh:179-182`, `:315-330`;
  `framework/include/QM/QM_RiskSizer.mqh:68-71, 84-89, 91-117`.
- Set files (RISK_PERCENT 4/4/8/8, no `qm_risk_cap_pct`):
  `framework/EAs/QM5_{13213,10848,10553,13036}_*/sets/*_ftmo_challenge.set`.
- Manifest: `docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json`.
- PropFirm fix: `framework/include/QM/QM_PropFirm.mqh:45,133,235,279,290` (markers present);
  `scratchpad/propfirm_compile.log` (0 errors/0 warnings).
- Live DB `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`): Q09_PORTFOLIO —
  13213 FAIL 07-25, 10848 FAIL 07-14, 10553 FAIL 07-16, 13036 FAIL 07-26, 13301 pending 07-27;
  Q08 — 10582 INFRA_FAIL 07-27T04:36:23Z, 9936 active 07-27T03:55:05Z; one pending Q09 farm-wide.
- Source analyses corroborated: `docs/ops/evidence/2026-07-27_risk_cap_clamp_analysis.md`,
  `..._sleeve_funnel_authoritative.md/.py`, `..._q09_rerun_assessment.md`,
  `docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md`,
  `tools/strategy_farm/portfolio/challenge_defensible.py` (`71b6cf87f`).
