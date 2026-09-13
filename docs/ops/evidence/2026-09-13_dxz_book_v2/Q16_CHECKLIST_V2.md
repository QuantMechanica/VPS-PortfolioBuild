# Q16 Operational Readiness — DXZ book v2 (30 sleeves), 2026-09-13

Staging only. Nothing deployed, nothing on T_Live written, AutoTrading untouched.
Checklist source: vault `03 Pipeline/Q16 Operational Readiness.md` (11 checks) and
`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` §4.

## 0 · Precedent for check 1 (fresh compile on T_Live)

**The July ceremony did NOT recompile on T_Live.** `C:/QM/deploy/DXZ_FINAL_2026-07-19/`
staged two *factory* binaries (`eas/`, `live_eas_sha256.txt`: 13213 `321b1dca…`,
1567 `71c2f84b…`) and copied them; readiness rested on check 3 (SHA256 factory → T_Live),
which `deploy_tlive_book.py` enforces per item. This package follows that precedent and
records the deviation explicitly rather than claiming a compile that did not happen.
Escalating check 1 to a real T_Live compile is an OWNER call; it is listed as OPEN below
for every new sleeve.

## 1 · Per-sleeve status — 6 NEW

Magic verified by formula `ea_id*10000+slot` against `framework/registry/magic_numbers.csv`.
`.ex5` SHA256 verified equal to the Q14 terminal receipt's `expected_ex5_sha256`
(`D:/QM/reports/portfolio/dxz_v2_20260913/pool.json`) — the binary staged is the binary
the gate ruled on.

| # | EA / symbol | TF | slot | magic | `.ex5` SHA256 (first 16) | burn-in RISK% | target RISK% | status |
|---|---|---|---|---|---|---|---|---|
| 25 | QM5_1537 aa-vol-sma10 / XAGUSD | D1 | 1 | 15370001 | `142a019e773a493d` | 0.0769 | 0.38602 | AMBER — routing unconfirmed |
| 26 | QM5_9641 bandy-cci-extreme-fade-mr-index / WS30 | D1 | 2 | 96410002 | `21eda8527f66dd25` | 0.0104 | 0.307762 | AMBER — routing + magic-embedding unproven |
| 27 | QM5_10700 tv-liq-break / XAUUSD | H1 | 3 | 107000003 | `5fbf2ba004825004` | 0.0130 | 0.073278 | GREEN-ready |
| 28 | QM5_13013 grimes-trendday-v2 / NDX | M15 | 0 | 130130000 | `bf2cc2ecaff8ae55` | 0.0105 | 0.312014 | GREEN-ready |
| 29 | QM5_13054 brent-tom-mom / XTIUSD | D1 | 0 | 130540000 | `2e65488fccdbd985` | 0.0488 | 0.405275 | **RED — dark on arrival** |
| 30 | QM5_21505 xag-weekly-lowvol-momentum / XAGUSD | D1 | 0 | 215050000 | `395c4747832acbcd` | 0.0714 | 0.280423 | **RED — dark on arrival** |

## 2 · The 11 checks

| # | Check | Owner | 25/1537 | 26/9641 | 27/10700 | 28/13013 | 29/13054 | 30/21505 | 06/12778 | 17/12969 | 24/13117 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | fresh compile on T_Live | Codex | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 2 | deploy manifest created | Codex | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) |
| 3 | manifest signed by OWNER | OWNER | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 4 | RISK_PERCENT set, min-lot for burn-in | Claude | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 5 | Q09 news mode configured | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 6 | commission/swap = DXZ schedule | Codex | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** |
| 7 | DST timezone on T_Live | Codex | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 8 | kill-switch threshold defined | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 9 | symbol routing `.DWX` → broker | Codex | **OPEN** | **OPEN** | GREEN | GREEN | **RED** | **RED** | **RED** | **RED** | **RED** |
| 10 | magic registered + unique | Claude | GREEN | **OPEN** | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 11 | SHA256 factory → T_Live | Claude | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | n/a | n/a | n/a |

Counts (9 sleeves × 11): **GREEN 45 · OPEN 39 · RED 15**. No sleeve is fully GREEN.

## 3 · The OPEN/RED items, with owner and exact action

**RED-9 · symbol routing — 5 sleeves (13054, 21505, 12778, 12969, 13117).**
Owner **Codex**. The `.mq5` compares `_Symbol` against a hardcoded `".DWX"` literal while
the live chart carries the bare broker name, so the EA can never trade. Full diagnosis and
the exact input contract: `REPAIR_DIAGNOSIS_DARK_SLEEVES.md`. Action: patch symbol literals
to `input string` (Hard Rule OWNER 2026-09-06), recompile, DL-089 requalification, then the
drafted presets under `C:/QM/deploy/DXZ_V2_20260913/repair/` become deployable.
*Recommendation: cut 13054 and 21505 from the v2 cutover and ship 28 sleeves; adding two
sleeves that provably cannot trade only inflates the sleeve count.*

**OPEN-9 · routing unconfirmed — XAGUSD (1537, 21505) and WS30 (9641).** Owner **OWNER**.
`framework/registry/dwx_symbol_matrix.csv`: only `SP500.DWX` carries
`live_order_status=ORDER_ROUTABLE_CONFIRMED`; XAGUSD/WS30 cells are empty. Symbol
*existence* on the Darwinex-Live account is proven — `D:/QM/mt5/T2/bases/Darwinex-Live/history/XAGUSD`
and `D:/QM/mt5/T1/bases/Darwinex-Live/history/WS30` — but neither is present in T_Live's
own `bases/Darwinex-Live/history/`, i.e. neither is in T_Live's Market Watch.
Action: **OWNER adds XAGUSD and WS30 to Market Watch on T_Live** before the charts are
opened. The min-lot burn-in is then itself the routability test; Claude confirms from the
first accepted order and updates the matrix row (the SP500 precedent,
`docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md`).
XAUUSD / NDX / XTIUSD cells are also empty but are de-facto confirmed by sleeves already
trading them live (10403, 13128, 10919).

**OPEN-10 · magic embedding for 9641/WS30.** Owner **Codex**. `QM_MagicResolver.mqh` is a
generated table compiled *into* the binary. Git history shows magic `96410002` first
appears in the resolver in commit `d8ce8f68fe` (2026-08-11T04:03:49+02:00) — the same
commit that carries the `.ex5`, whose file mtime is 2026-08-11T01:42Z. The resolver commit
immediately *preceding* the build (`24365ab4d9`, 2026-08-11T00:59Z) does **not** contain it.
Whether the working-tree resolver was regenerated before the compile is therefore not
provable from the repo, and byte-scanning the `.ex5` is not a valid method (verified: a
little-endian search for each magic and a UTF-16 search for each symbol return 0 hits even
for values that must be present — MetaEditor compresses the image). Action: either a fresh
T_Live compile (which also closes check 1) or read `"event":"INIT","payload":{"magic":…}`
from `MQL5/Files/QM/QM5_9641_ea-9641.log` after the chart is attached and before
AutoTrading. Every other sleeve's binary post-dates its registry row by ≥1 resolver commit.

**OPEN-6 · commission group.** Owner **Codex**. `C:/QM/mt5/T_Live/MT5_Base/MQL5/Profiles/Tester/Groups/`
is **empty — no `<server>_<account>.txt` exists**, so the check has no artifact at all
today. Worst-case model to verify against (`framework/registry/live_commission.json`,
OWNER 2026-06-01): forex `max(0.005% RT notional, $5/lot RT)`, index
`max(0.005%, $5.50/lot)`, commodity `max(0.005%, $0/lot)`. Per new sleeve the class is
XAGUSD/XAUUSD/XTIUSD = commodity, WS30/NDX = index. No commission value may be invented
(Hard Rule).

**OPEN-7 · DST.** Owner **Codex**. Expect broker time GMT+2 outside US DST, GMT+3 during.
2026-09-13 is inside US DST → GMT+3. Cross-check: `QM5_13213_ea-13213.log` last line
`ts_utc 2026-09-11T19:51:13.984Z` vs `ts_broker 2026-09-11T22:51:17` = **+3h, correct**.
Formally still OPEN because the gate asks for a terminal screenshot.

**OPEN-1/3 · fresh compile and OWNER signature.** See §0 and `deploy_manifest_v2_DRAFT.yaml`.

**BLOCKER outside the per-sleeve grid · live risk freeze is ACTIVE.**
`stage_tlive_presets_risk.py --apply` refuses:
`LIVE_RISK_FREEZE_BLOCKED: status=ACTIVE; held=True` with three unmet lift conditions
(SP-A1/A2-DEPLOY-POINTER BLOCKED, NEWS-CONTRACT-V2 PARTIAL, GOVERNOR-HARDENING PARTIAL).
Therefore the 24 re-weighted existing presets exist only as a verified dry-run diff proof
(`C:/QM/deploy/DXZ_V2_20260913/stage_dryrun_existing24.json`), not as files. Owner
**OWNER**: a written lift is required before the ceremony (runbook §1.3). No AI seat lifts
it, and none may be inferred from a condition merely being satisfied.

## 4 · Kill-switch thresholds (check 8) — 2 × simulated Q10 max DD

Q10 evidence = the `Q10_NEWS` CONFIG_LOCKED `aggregate.json` whose `ex5_sha256` equals the
staged binary (verified per sleeve). `worst_drawdown_pct` is measured at the tester's
`RISK_FIXED=$1000` on 100k = 1.0 %/trade, so it scales linearly with RISK_PERCENT.

| sleeve | Q10 worst DD @1.0 % | KS @ burn-in risk | KS @ target risk | Q10 evidence |
|---|---|---|---|---|
| 1537/XAGUSD | 2.8765 % | 0.4424 % | 2.2207 % | `D:/QM/reports/work_items/fac4d930-13b6-469e-8fe2-51ce06907f02/QM5_1537/Q10_NEWS/XAGUSD_DWX/aggregate.json` |
| 9641/WS30 | 2.7550 % | 0.0573 % | 1.6956 % | `…/c2bec0ec-d822-4c1f-8e0e-47177424c6be/QM5_9641/Q10_NEWS/WS30_DWX/aggregate.json` |
| 10700/XAUUSD | 10.0844 % | 0.2622 % | 1.4779 % | `…/152e8d29-7177-4436-a0ca-e6a0a5e66edb/QM5_10700/Q10_NEWS/XAUUSD_DWX/aggregate.json` |
| 13013/NDX | 2.1314 % | 0.0448 % | 1.3300 % | `…/5ea4c77d-6758-4b1c-8693-300aa5789198/QM5_13013/Q10_NEWS/NDX_DWX/aggregate.json` |
| 13054/XTIUSD | 2.0457 % | 0.1997 % | 1.6582 % | `…/15c0377e-f79f-4662-a406-9cdee6496db3/QM5_13054/Q10_NEWS/XTIUSD_DWX/aggregate.json` |
| 21505/XAGUSD | 3.4115 % | 0.4872 % | 1.9133 % | `…/49868397-5ab2-4dc9-b438-878a72c94c2b/QM5_21505/Q10_NEWS/XAGUSD_DWX/aggregate.json` |

Note 10700/XAUUSD: 10.08 % standalone DD is by far the worst of the six; its target weight
(0.0733 %) is correspondingly the smallest — the capped inverse-vol solve already priced it.
The 10440/NDX KS gap stays open and is **not** synthesized (runbook §4.8).
The existing per-EA KS baselines on T_Live (`QM\baselines\QM5_<id>_<SYM>.json`) are
present for 23 of 24 deployed sleeves; only 10440 has none.

## 5 · News calendar (check 10) — GREEN

Live EAs use the **native MT5 calendar**, fail-closed (DL-080); the CSV is tester
diagnostics only. Latest `NEWS_CALENDAR_LOADED` on T_Live
(`MQL5/Files/QM/QM5_13213_ea-13213.log`, 2026-09-11T19:51:13.984Z):
`hash 3B8966690D45BCC3A78BA8B2DCB134686329D9CC0299EBE751B79D48AE851DFC`,
`rows 97443`, `modified_utc 2026.09.10 05:30:31`.
Age at 2026-09-13 ≈ **72 h**, bound 336 h → within tolerance. 21 of 24 deployed sleeves
report the same hash; 12778/13117 report none (they never complete init) and 13128 does
not read the CSV. `KILL_SWITCH_INIT` is present for all with the post-fix relative
`QM\halt\` path.

## 6 · Existing 21 sleeves (check 4, re-weighted)

All 24 deployed presets change, because six new sleeves take a share of the fixed 9.75
total. Verified dry-run: 24 presets parsed, each diff exactly one line
(`RISK_PERCENT=`), 0 unexplained hunks, sum old 9.7499 → sum new 7.98523 (the 24-sleeve
share of 9.75). **15 of 24 move by more than 0.05 pp:**

10919/XTIUSD −0.2113 · 12567/XNGUSD −0.1905 · 1556/XAUUSD −0.1561 · 12778/AUDUSD −0.1285 ·
11165/AUDCAD −0.1042 · 11132/SP500 −0.1042 · 12567/XAUUSD −0.0998 · 11421/AUDUSD −0.0966 ·
13128/NDX −0.0913 · 13117/EURGBP −0.0821 · 11165/EURUSD −0.0751 · 11421/EURUSD −0.0688 ·
11708/EURUSD −0.0590 · 10513/XAUUSD −0.0588 · 12989/XAUUSD −0.0546.

Every change is a *reduction*; no sleeve gains risk. Proof:
`C:/QM/deploy/DXZ_V2_20260913/stage_dryrun_existing24.json` (per file: `sha256_deployed`,
`sha256_staged`, `changed_lines`).

## 7 · Copy plan dry-run (exact output)

```
python -X utf8 tools/strategy_farm/deploy_tlive_book.py \
  --plan C:/QM/deploy/DXZ_V2_20260913/copy_plan_v2.json

{ "schema": "qm.tlive_book_copy_plan.v1",
  "mode": "DRY_RUN",
  "plan": "C:\\QM\\deploy\\DXZ_V2_20260913\\copy_plan_v2.json",
  "owner_approval_evidence": "decisions/2026-09-13_owner_book_order_dxz.md",
  "live_root": "C:\\QM\\mt5\\T_Live\\MT5_Base",
  "validated_items": 12, "written_items": 0, "items": [ ... ] }
exit 0
```

`book_build_guard("dxz", …)` passed (it runs before anything else, even for a dry-run),
`owner_approval_evidence` resolved, all 12 sources re-hashed and matched, all destinations
legal and unique. Full output: `C:/QM/deploy/DXZ_V2_20260913/copy_plan_dryrun_output.json`.
The plan's `pending_items` (24 re-weighted existing + 3 repair drafts) are deliberately
outside `items` — their sources do not exist yet (risk freeze / missing patched binary),
and putting a non-existent source in `items` would be a plan that lies.

The expected risk-freeze refusal on `--apply` was **not** provoked against T_Live; it was
already demonstrated by `stage_tlive_presets_risk.py --apply` (§3), which uses the same
`risk_freeze.assert_live_book_mutation_allowed` guard.
