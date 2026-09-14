# Q16 Operational Readiness — DXZ book v2 (**28 sleeves @ 11.0 % / cap 1.5 %**), 2026-09-13

> **Rev 3 (28 sleeves @ total risk 11.0 %, sleeve cap 1.5 %).**
> `OWNER-DEC-BOOK-RISK-11-20260913`: the builder sweep shows the not-worse gate vs the deployed
> 24 holds at 11.0/1.5 and breaks at 12.0. Concentration-policy budget committed at 11.0.
> Re-solved: `APPLY_RECOMMENDED`, 28 sleeves, sum **11.000000**, ann **10.812 %**,
> maxDD **2.052 %**, ret/DD **5.269**, worst day **−0.856 %**, Sharpe **2.525**, all three
> not-worse checks PASS, `concentration_reject: []`.
> 13054/XTIUSD and 21505/XAGUSD stay **DEFERRED_SYMBOL_LITERAL_FIX**; the three dark live
> sleeves 12778, 13117, 12969 stay deployed as-is and are a **no-op until their source fix**.
> Weights: `D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/analytic_preview_manifest_28_r11.json`
> (builder manifest `manifest_28_r11_full.json`, roster_sha256 `604da475…`,
> sleeve_list_sha256 `af2d1ad2…`).
> **No sleeve reaches the 1.5 cap** — the largest is 13128/NDX at 1.102818, which is exactly
> the sleeve the old 1.0 cap was binding on. Superseded packages:
> `_superseded_30/` (30 sleeves @ 9.75) and `_superseded_975/` (28 sleeves @ 9.75).

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
| 25 | QM5_1537 aa-vol-sma10 / XAGUSD | D1 | 1 | 15370001 | `142a019e773a493d` | 0.0769 | 0.468451 | AMBER — routing unconfirmed |
| 26 | QM5_9641 bandy-cci-extreme-fade-mr-index / WS30 | D1 | 2 | 96410002 | `21eda8527f66dd25` | 0.0104 | 0.373481 | AMBER — routing + magic-embedding unproven |
| 27 | QM5_10700 tv-liq-break / XAUUSD | H1 | 3 | 107000003 | `5fbf2ba004825004` | 0.0130 | 0.088928 | GREEN-ready |
| 28 | QM5_13013 grimes-trendday-v2 / NDX | M15 | 0 | 130130000 | `bf2cc2ecaff8ae55` | 0.0105 | 0.378644 | GREEN-ready |

**Deferred, not staged:** 13054/XTIUSD (magic 130540000) and 21505/XAGUSD (magic 215050000) — `DEFERRED_SYMBOL_LITERAL_FIX`. Their `.ex5`, Q14 sets and 30-book presets remain in `_superseded_30/` for the rebuild.

**Burn-in risk total (28) = 9.801297 %** = 24 existing at 11-book target (9.690497) + 4 new at min-lot median (0.1108). Target total = **11.000000 %**, sleeve cap 1.5 %, max sleeve 1.102818 (13128/NDX), 0 sleeves at cap.

## 2 · The 11 checks

| # | Check | Owner | 25/1537 | 26/9641 | 27/10700 | 28/13013 | 06/12778 | 17/12969 | 24/13117 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fresh compile on T_Live | Codex | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 2 | deploy manifest created | Codex | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) | GREEN(draft) |
| 3 | manifest signed by OWNER | OWNER | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN |
| 4 | RISK_PERCENT set, min-lot for burn-in | Claude | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 5 | Q09 news mode configured | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 6 | commission/swap = DXZ schedule | Claude | **OPEN** | GREEN* | GREEN | GREEN | GREEN | GREEN | GREEN* |
| 7 | DST timezone on T_Live | Claude | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 8 | kill-switch threshold defined | Codex | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| 9 | symbol routing `.DWX` → broker | Codex | **OPEN** | **OPEN** | GREEN | GREEN | **RED** | **RED** | **RED** |
| 10 | magic registered + unique | Claude | GREEN | **OPEN** | GREEN | GREEN | GREEN | GREEN | GREEN |
| 11 | SHA256 factory → T_Live | Claude | GREEN | GREEN | GREEN | GREEN | n/a | n/a | n/a |

`GREEN*` = class-level evidence only (the instrument itself has no live deal history yet;
the commission-class formula was validated from other live deals in the same class on this
account). Full evidence: `Q16_CHECK6_CHECK7_EVIDENCE_2026-09-14.md`. 25/1537 (XAGUSD) stays
OPEN because the one commodity instrument with history (XAUUSD) showed a small worst-case
overshoot at min-lot size — see that file's check-6 finding before certifying XAGUSD's own
burn-in fills.

Counts (7 sleeves × 11 = 77): **GREEN 48 (2 of them class-proxy `*`) · OPEN 20 · RED 9**. No sleeve is fully GREEN.
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

*2026-09-14 update (OWNER-DEC-IDENTITY-EQUIVALENCE-20260913, receipt 099bebe6): **17/12969**
gets an alternate closure that does not wait for the generic patch/recompile/DL-089 path —
its rebuild QM5_41470 carries an `EQUIVALENT_LOT_NORMALISED` proof
(`docs/ops/evidence/2026-09-13_identity_equivalence/README.md`) and the staging package
`C:/QM/deploy/DXZ_V2_20260913/repair_v2/` (see `REPAIR_V2_41470_STAGING.md`) is now
**DEPLOYABLE_AT_CUTOVER** — still blocked only by the book-v2 cutover order and the
LIVE_RISK_FREEZE lift, not by a source patch. **06/12778 and 24/13117 are unaffected**: their
same-day proofs for QM5_41471 and QM5_41472 both came back `NOT_EQUIVALENT` (structural deal
divergence, basket/cointegration legs), so no inheritance shortcut exists for them — they stay
on the original RED-9 action (patch, recompile, DL-089 requalify).*

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

**RESOLVED-6 (except 25/1537) · commission group.** Owner **Claude**, 2026-09-14.
`C:/QM/mt5/T_Live/MT5_Base/MQL5/Profiles/Tester/Groups/` still **does not exist** — no
tester-Groups artifact exists today, confirmed again. Answered instead from the live deal
journal (`Files/QM/journal/live_deals_normalized.csv`, 259 deal legs) matched per closed
position against `framework/registry/live_commission.json`'s worst-case model: index (NDX)
and forex (AUDUSD, USDJPY) classes realise comfortably inside the model; the commodity class
(XAUUSD, 14 closed positions) shows a small, real overshoot at min-lot size (5/14 positions,
$0.001–$0.008 above model). Full numbers, per-position table and the class-proxy reasoning
for 26/9641, 24/13117: `Q16_CHECK6_CHECK7_EVIDENCE_2026-09-14.md`. **25/1537 (XAGUSD) stays
OPEN** — same no-flat-floor commodity formula as XAUUSD, no XAGUSD deal history yet to check
its own burn-in fills against the model's demonstrated min-lot blind spot.

**RESOLVED-7 · DST.** Owner **Claude**, 2026-09-14. Broker time GMT+2 outside US DST, GMT+3
during, confirmed **consistently +3.000h to +3.001h across all 14 days** 2026-08-31→2026-09-14
(84,023 log lines scanned), with the 2026-09-05/06 weekend gap explained (MT5 freezes
`TimeCurrent()` at the last tick when the market is closed — not a DST defect). Log-based
artifact stands in place of the terminal screenshot the gate originally asked for (Hard Rule:
evidence must be a log/CSV path, not a screenshot). Full per-day table:
`Q16_CHECK6_CHECK7_EVIDENCE_2026-09-14.md`.

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
| 1537/XAGUSD | 2.8765 % | 0.4424 % | 2.6950 % | `D:/QM/reports/work_items/fac4d930-13b6-469e-8fe2-51ce06907f02/QM5_1537/Q10_NEWS/XAGUSD_DWX/aggregate.json` |
| 9641/WS30 | 2.7550 % | 0.0573 % | 2.0579 % | `…/c2bec0ec-d822-4c1f-8e0e-47177424c6be/QM5_9641/Q10_NEWS/WS30_DWX/aggregate.json` |
| 10700/XAUUSD | 10.0844 % | 0.2622 % | 1.7936 % | `…/152e8d29-7177-4436-a0ca-e6a0a5e66edb/QM5_10700/Q10_NEWS/XAUUSD_DWX/aggregate.json` |
| 13013/NDX | 2.1314 % | 0.0448 % | 1.6141 % | `…/5ea4c77d-6758-4b1c-8693-300aa5789198/QM5_13013/Q10_NEWS/NDX_DWX/aggregate.json` |

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

## 6 · Existing 24 sleeves (check 4, re-weighted to the 11.0 % / cap 1.5 % solve)

All 24 deployed presets change. Verified dry-run: 24 presets parsed, each diff exactly one
line (`RISK_PERCENT=`), 0 problems, sum old 9.7499 → sum new **9.690497** (the 4 new sleeves
take 1.309503 of the 11.0). **Only 5 of 24 move by more than 0.05 pp** — raising the total
from 9.75 to 11.0 almost exactly offsets what the four new sleeves take out:

| sleeve | old | new | Δ pp |
|---|---|---|---|
| 13128/NDX | 1.0000 | 1.102818 | **+0.1028** |
| 12969/USDJPY | 0.5100 | 0.590437 | **+0.0804** |
| 1556/XAUUSD | 0.6017 | 0.540735 | −0.0610 |
| 10919/XTIUSD | 0.9181 | 0.857769 | −0.0603 |
| 12778/AUDUSD | 0.4905 | 0.439281 | −0.0512 |

**Eight sleeves rise, and the two largest risers deserve a sentence each:**

* **13128/NDX +0.1028 to 1.102818** — this sleeve was sitting exactly on the old 1.0 sleeve
  cap. The move from 9.75/1.0 to 11.0/1.5 releases it: the increase is *cap-driven
  concentration*, not a change in its measured vol. It is now the single largest sleeve in the
  book at ~10 % of total risk. That is inside the ratified 1.5 cap, but it is the one line
  where "raise the total" quietly became "raise one sleeve".
* **12969/USDJPY +0.0804 to 0.590437** — a sleeve that demonstrably cannot trade
  (RED-9, §3) is being allocated more risk. Harmless in effect today, meaningless until the
  source fix, and it should not be mistaken for a deliberate conviction increase.

Remaining risers, all small: 12567/XAUUSD +0.0383 · 11708/EURUSD +0.0369 · 10939/GBPUSD
+0.0071 · 1567/EURUSD +0.0057 · 13213/USDJPY +0.0012 · 10440/NDX +0.0007.

Proof: `C:/QM/deploy/DXZ_V2_20260913/stage_dryrun_28_r11_existing24.json` (per file:
`sha256_deployed`, `sha256_staged`, `changed_lines`); `stage_dryrun_28_r11_all.json`
additionally documents the 4 "no deployed preset" gaps — exactly the 4 new sleeves.

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

`pending_items` (29) = 24 re-weighted existing presets at the 11-book weights (blocked by the
ACTIVE risk freeze),
3 dark-sleeve repair drafts (no-op until the source fix), and the 2 deferred sleeves
13054/21505 — deliberately outside `items`, because a plan naming a source that does not
exist is a plan that lies.

The risk-freeze refusal on `--apply` was not provoked against T_Live; it was already
demonstrated by `stage_tlive_presets_risk.py --apply` (§3), which calls the same
`risk_freeze.assert_live_book_mutation_allowed` guard.
