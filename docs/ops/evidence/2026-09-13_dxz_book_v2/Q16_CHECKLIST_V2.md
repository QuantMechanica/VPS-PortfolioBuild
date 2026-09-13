# Q16 Operational Readiness — DXZ book v2 (**28 sleeves**), 2026-09-13

> **Rev 2 (28-sleeve book).** 13054/XTIUSD and 21505/XAGUSD are **DEFERRED_SYMBOL_LITERAL_FIX**
> and cut from this book (`--exclude-pair`); the three dark live sleeves 12778, 13117, 12969
> stay deployed as-is and are a **no-op until their source fix**. Weights re-solved by
> `build_book_dxz.py` (capped inverse-vol, cap 1.0, total 9.75, as-of 2026-09-12):
> `APPLY_RECOMMENDED`, 28 sleeves, ann 9.583 %, ret/DD 5.264, worst day −0.758 %, Sharpe 2.525,
> all three not-worse checks PASS. Per-sleeve weights:
> `D:/QM/reports/portfolio/dxz_v2_20260913/build_28/analytic_preview_manifest_28.json`
> (`manifest_28_full.json` = the builder's own manifest, sum 9.750000).
> The 30-sleeve artefacts are preserved under `C:/QM/deploy/DXZ_V2_20260913/_superseded_30/`.

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
| 25 | QM5_1537 aa-vol-sma10 / XAGUSD | D1 | 1 | 15370001 | `142a019e773a493d` | 0.0769 | 0.415218 | AMBER — routing unconfirmed |
| 26 | QM5_9641 bandy-cci-extreme-fade-mr-index / WS30 | D1 | 2 | 96410002 | `21eda8527f66dd25` | 0.0104 | 0.331040 | AMBER — routing + magic-embedding unproven |
| 27 | QM5_10700 tv-liq-break / XAUUSD | H1 | 3 | 107000003 | `5fbf2ba004825004` | 0.0130 | 0.078822 | GREEN-ready |
| 28 | QM5_13013 grimes-trendday-v2 / NDX | M15 | 0 | 130130000 | `bf2cc2ecaff8ae55` | 0.0105 | 0.335616 | GREEN-ready |

**Deferred, not staged:** 13054/XTIUSD (magic 130540000) and 21505/XAGUSD (magic 215050000) — `DEFERRED_SYMBOL_LITERAL_FIX`. Their `.ex5`, Q14 sets and 30-book presets remain in `_superseded_30/` for the rebuild.

**Burn-in risk total (28) = 8.700104 %** = 24 existing at v2 target (8.589304) + 4 new at min-lot median (0.1108). Target total = 9.750000 %.

## 2 · The 11 checks

| # | Check | Owner | 25/1537 | 26/9641 | 27/10700 | 28/13013 | 06/12778 | 17/12969 | 24/13117 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fresh compile on T_Live | Codex | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 2 | deploy manifest created | Codex | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) |
| 3 | manifest signed by OWNER | OWNER | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 4 | RISK_PERCENT set, min-lot for burn-in | Claude | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 5 | Q09 news mode configured | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 6 | commission/swap = DXZ schedule | Codex | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** | **OPEN** |
| 7 | DST timezone on T_Live | Codex | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 8 | kill-switch threshold defined | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 9 | symbol routing `.DWX` → broker | Codex | **OPEN** | **OPEN** | GREEN | GREEN | **RED** | **RED** | **RED** |
| 10 | magic registered + unique | Claude | GREEN | **OPEN** | GREEN | GREEN | GREEN | GREEN | GREEN |
| 11 | SHA256 factory → T_Live | Claude | GREEN | GREEN | GREEN | GREEN | n/a | n/a | n/a |

Counts (7 sleeves × 11 = 77): **GREEN 35 · OPEN 33 · RED 9**. No sleeve is fully GREEN.
The 3 dark sleeves keep their RED-9 and are a **no-op**: they stay on their existing charts, carry 1.276 % of the 28-book risk and demonstrably trade nothing until their source fix.

## 3 · The OPEN/RED items, with owner and exact action

**RED-9 · symbol routing — 3 deployed sleeves (12778, 12969, 13117) + 2 deferred (13054, 21505).**
Owner **Codex**. The `.mq5` compares `_Symbol` against a hardcoded `".DWX"` literal while
the live chart carries the bare broker name, so the EA can never trade. Full diagnosis and
the exact input contract: `REPAIR_DIAGNOSIS_DARK_SLEEVES.md`. Action: patch symbol literals
to `input string` (Hard Rule OWNER 2026-09-06), recompile, DL-089 requalification, then the
drafted presets under `C:/QM/deploy/DXZ_V2_20260913/repair/` become deployable.
*Done: 13054 and 21505 are cut from this book (`DEFERRED_SYMBOL_LITERAL_FIX`). The builder
re-solved 28 sleeves and still returns `APPLY_RECOMMENDED` with all three not-worse checks PASS,
so nothing of value was lost by dropping them.*

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
| 1537/XAGUSD | 2.8765 % | 0.4424 % | 2.3888 % | `D:/QM/reports/work_items/fac4d930-13b6-469e-8fe2-51ce06907f02/QM5_1537/Q10_NEWS/XAGUSD_DWX/aggregate.json` |
| 9641/WS30 | 2.7550 % | 0.0573 % | 1.8240 % | `…/c2bec0ec-d822-4c1f-8e0e-47177424c6be/QM5_9641/Q10_NEWS/WS30_DWX/aggregate.json` |
| 10700/XAUUSD | 10.0844 % | 0.2622 % | 1.5898 % | `…/152e8d29-7177-4436-a0ca-e6a0a5e66edb/QM5_10700/Q10_NEWS/XAUUSD_DWX/aggregate.json` |
| 13013/NDX | 2.1314 % | 0.0448 % | 1.4307 % | `…/5ea4c77d-6758-4b1c-8693-300aa5789198/QM5_13013/Q10_NEWS/NDX_DWX/aggregate.json` |

13054/XTIUSD (2.0457 %) and 21505/XAGUSD (3.4115 %) are recorded for the rebuild but are not
staged. Note 10700/XAUUSD: 10.08 % standalone DD is by far the worst of the four; its target weight
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

## 6 · Existing 24 sleeves (check 4, re-weighted to the 28-book solve)

All 24 deployed presets change. Verified dry-run: 24 presets parsed, each diff exactly one
line (`RISK_PERCENT=`), 0 problems, sum old 9.7499 → sum new **8.589305** (the 24-sleeve
share of 9.75; the 4 new sleeves take 1.160696). **9 of 24 move by more than 0.05 pp:**

10919/XTIUSD −0.1578 · 12567/XNGUSD −0.1308 · 1556/XAUUSD −0.1224 · 12778/AUDUSD −0.1011 ·
11132/SP500 −0.0776 · 11421/AUDUSD −0.0766 · 11165/AUDCAD −0.0725 · 13117/EURGBP −0.0565 ·
12567/XAUUSD −0.0509.

That is six fewer movers than the 30-book solve, because two sleeves less compete for the
same 9.75. **23 of 24 fall; exactly one rises — 12969/USDJPY 0.5100 → 0.523342 (+0.0133).**
Harmless while that sleeve cannot trade at all, but it is the one line in the re-weight that
increases live risk, so it should not pass unnoticed.

Proof: `C:/QM/deploy/DXZ_V2_20260913/stage_dryrun_28_existing24.json` (per file:
`sha256_deployed`, `sha256_staged`, `changed_lines`); the 28-manifest run
`stage_dryrun_28_all.json` additionally documents the 4 "no deployed preset" gaps, which are
exactly the 4 new sleeves.

## 7 · Copy plan dry-run (exact output)

```
python -X utf8 tools/strategy_farm/deploy_tlive_book.py   --plan C:/QM/deploy/DXZ_V2_20260913/copy_plan_v2.json

{ "schema": "qm.tlive_book_copy_plan.v1",
  "mode": "DRY_RUN",
  "plan": "C:\QM\deploy\DXZ_V2_20260913\copy_plan_v2.json",
  "owner_approval_evidence": "decisions/2026-09-13_owner_book_order_dxz.md",
  "live_root": "C:\QM\mt5\T_Live\MT5_Base",
  "validated_items": 8, "written_items": 0, "items": [ ... ] }
exit 0
```

`book_build_guard("dxz", …)` passed (it runs first, even for a dry-run),
`owner_approval_evidence` resolved, all 8 sources re-hashed and matched, all destinations
legal and unique. `items` = 4 `.ex5` + 4 burn-in presets. Full output:
`C:/QM/deploy/DXZ_V2_20260913/copy_plan_dryrun_output.json`.

`pending_items` (29) = 24 re-weighted existing presets (blocked by the ACTIVE risk freeze),
3 dark-sleeve repair drafts (no-op until the source fix), and the 2 deferred sleeves
13054/21505 — deliberately outside `items`, because a plan naming a source that does not
exist is a plan that lies.

The risk-freeze refusal on `--apply` was not provoked against T_Live; it was already
demonstrated by `stage_tlive_presets_risk.py --apply` (§3), which calls the same
`risk_freeze.assert_live_book_mutation_allowed` guard.
