# T_Live decision — Q12-ready 5-sleeve book (2026-06-26)

## Decision
OWNER **approved** the 5-sleeve Q12-ready portfolio manifest for T_Live on 2026-06-26 (written
approval in session). Binding DD cap = **10% (FTMO-grade)**, account risk = 2% (risk-parity).

Approved artifact: `D:\QM\reports\portfolio\portfolio_manifest_q12_ready_all_DRAFT_20260626.json`
(`status=DRAFT_FOR_OWNER_APPROVAL`, `cap_met=True`, basis `portfolio_candidates.Q12_REVIEW_READY_all`).
Review/verification package: `docs/ops/T_LIVE_APPROVAL_q12_5sleeve_2026-06-26.md`.

Book (inverse-vol weights, registry magics): 11132:SP500 (0.389, magic 111320000),
10513:XAU (0.275, 105130003), 10940:XAU (0.216, 109400003), 10692:NDX (0.069, 106920005),
10440:NDX (0.051, 104400003). KPIs on the canonical $100k account: MaxDD **1.53%**, Sharpe 1.49,
net-of-cost $9,598.

## Status: APPROVED — deploy flow NOT yet executed
Per the Hard Rule (T_Live AutoTrading = OWNER + Claude only) and OWNER's instruction, the deploy
flow runs on OWNER's explicit "deploy" go, and the **AutoTrading flip requires OWNER's explicit
step-4 confirmation** (the first live deployment is a deliberate, confirmed sequence).

Remaining deploy-flow steps (none performed as of this record):
1. Generate live setfiles via `gen_setfile.ps1` (ENV=live, RISK_PERCENT per weight, RISK_FIXED=0,
   qm_magic_slot_offset = registry slot).
2. Confirm the live-sized (RISK_PERCENT) book DD < 10% on the $100k account (the 1.53% is the
   RISK_FIXED basis; live 2%-risk-parity projects to ~3%).
3. SHA256 match factory → `C:\QM\mt5\T_Live`; magic-registry recheck; news calendar present+current.
4. **OWNER or Claude** flip AutoTrading on T_Live (with OWNER's explicit confirmation).
5. Append the deploy/AutoTrading evidence to this record when executed.

## Note
This book is the first V5 live portfolio. Growth beyond 5 sleeves requires NEW diverse,
cost-robust edges reaching Q08 FAIL_SOFT — the current single-symbol funnel is tapped out (the
remaining Q07 survivors fail Q08 HARD). The lever is instrument/asset-class breadth (FX baskets,
crypto, energy, rates), not build volume.
