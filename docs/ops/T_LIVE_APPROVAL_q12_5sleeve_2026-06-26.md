# T_Live Approval Package — Q12-ready 5-sleeve book (2026-06-26)

Prepared by: Claude. **AWAITING OWNER WRITTEN APPROVAL. No T_Live copy, no setfile deploy, no
AutoTrading performed.** This is the first V5 live portfolio.

## OWNER decision recorded
- DD cap binding the live book = **10% (FTMO-grade)** (OWNER, 2026-06-26).

## The DD-cap question — resolved (it was a capital-base artifact)
The manifest first reported **MaxDD 13.83%**, which appeared to breach the 10% cap. Root cause:
`build_manifest` computed DD on `starting_capital=$10k`, but the `q08_trades` streams are generated
on the **canonical $100k tester account** (`framework/registry/tester_defaults.json`
`initial_deposit=100000`, `RISK_FIXED=$1000 = 1%/trade`). On the correct $100k base the book MaxDD is
**1.53%** (identical streams, manifest's own `portfolio_metrics`). Fixed: the manifest default now
loads `initial_deposit` from `tester_defaults.json` (commit `e0e346856`).

| starting_capital | book MaxDD |
|---|---|
| $10k (old default — wrong) | 13.83% |
| **$100k (canonical account)** | **1.53%** |

→ The book meets the 10% cap with a ~6× margin. (Live `RISK_PERCENT` 2%-risk-parity sizing projects
to roughly ~3% — still far under 10%; the exact live-sized DD is confirmed in the deploy flow.)

## The book (manifest `portfolio_manifest_q12_ready_all_DRAFT_20260626.json`)
- Basis: `portfolio_candidates.Q12_REVIEW_READY_all` (== DB Q12_REVIEW_READY exactly, 0 dup ready rows)
- `status=DRAFT_FOR_OWNER_APPROVAL`, `cap_met=True` (10% cap), `manual_approval_required=true`,
  `deployment_action=NONE`, `autotrading_action=NONE`
- KPIs (on $100k): MaxDD **1.53%**, Sharpe **1.49**, net-of-cost **$9,598** over 799 trading days
- account_risk_pct = 2.0% (risk-parity split)

| sleeve | weight | RISK_PERCENT | magic (registry ✓) | slot | ex5 SHA256 (16) |
|---|---|---|---|---|---|
| 11132:SP500 | 0.389 | 0.778% | 111320000 | 0 | 7b48a34c786debb4 |
| 10513:XAU | 0.275 | 0.551% | 105130003 | 3 | ee92f1c62949b3d4 |
| 10940:XAU | 0.216 | 0.432% | 109400003 | 3 | 363a27933f66d8d5 |
| 10692:NDX | 0.069 | 0.138% | 106920005 | 5 | e28f8a1e452ac5c6 |
| 10440:NDX | 0.051 | 0.101% | 104400003 | 3 | 336b59109aa9a419 |

## Verification evidence (Claude review)
- ✅ Commit logic (`c40505dcd` q12-ready-all = certified book + inverse-vol; greedy is separate).
- ✅ Reproducible KPIs (re-ran the canonical command, identical).
- ✅ Book == DB `Q12_REVIEW_READY` exactly; max pairwise monthly |corr| 0.14 (every pair ≤0.30).
- ✅ Magic numbers match `magic_numbers.csv` for all 5 (fixed `6d45eb796`; matches `QM_MagicResolver`
  `ea_id*10000+symbol_slot` and what `gen_setfile.ps1` will emit).
- ✅ All 5 `.ex5` present (SHA256 above) for the factory→T_Live copy verify.
- ✅ Safety flags hard-set (DRAFT / manual_approval / deploy NONE / autotrading NONE).
- ✅ Portfolio test group green (37 tests incl. manifest registry-magic + DD-cap regression).

## What OWNER is asked to approve
Approve **this manifest** (the 5-sleeve Q12-ready book, 10% DD cap, 2% account risk) in writing.

## Post-approval deploy flow (only AFTER written approval — none done yet)
1. Generate live setfiles via `gen_setfile.ps1` (ENV=live, RISK_PERCENT per weight, RISK_FIXED=0,
   qm_magic_slot_offset = registry slot).
2. **Confirm the live-sized (RISK_PERCENT) book DD < 10%** on the $100k account (the deploy-flow DD
   gate; the 1.53% above is the RISK_FIXED basis).
3. SHA256 match factory → `C:\QM\mt5\T_Live`; magic-registry recheck; news calendar present+current.
4. **OWNER or Claude** flip AutoTrading on T_Live.
5. Record `decisions/2026-06-26_t_live_q12_5sleeve_book.md` with the verification evidence.

**No step 1–4 will be taken without OWNER's written approval.**
