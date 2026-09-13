# DXZ Book v2 — dark-sleeve repair staging: QM5_12969 -> QM5_41470 (USDJPY M30)

**DRY-RUN STAGING ONLY. 2026-09-13.** No T_Live file, chart, terminal or AutoTrading state
was touched; every deploy-tool invocation was dry-run. Package:
`C:\QM\deploy\DXZ_V2_20260913\repair_v2\`.

## What this repairs

The live sleeve **QM5_12969 / USDJPY M30** (magic 129690000) has traded **0 times since
2026-07-13**. Root cause (diagnosis `REPAIR_DIAGNOSIS_DARK_SLEEVES.md` §2): `Strategy_IsTarget()`
compares `_Symbol` against the hardcoded literal `"USDJPY.DWX"`; the T_Live chart is bare
`USDJPY`, so `Strategy_NoTradeFilter()` blocks every tick. The symbol-input rebuild
**QM5_41470** (magic 414700000) replaces the literal with input `strategy_host_symbol` and
compares canonical base names, so the bare live symbol matches. Strategy unchanged — proven
`EQUIVALENT_LOT_NORMALISED`.

## Artifacts and SHA-256s

| Artifact | Path | SHA-256 |
|---|---|---|
| 41470 .ex5 (staged) | `repair_v2\eas\QM5_41470_usdjpy-gotobi-nakane-fix-symfix.ex5` | `ef34638d26eb4e8ddc839e0790457ee898e5a7aedfcd5774eb733c69608e2cf2` |
| 41470 .ex5 (compile evidence) | wi `624dde76-cafe-4932-b108-712bbe5bb89d` | `ef34638d26eb4e8ddc839e0790457ee898e5a7aedfcd5774eb733c69608e2cf2` (MATCH) |
| 41470 live preset | `repair_v2\presets\17_USDJPY_M30_QM5_41470_usdjpy-gotobi-nakane-fix-symfix.set` | `2060856175f12722c3752ad073b1e785896e5435f34a700caf765622ae5368d7` |
| deployed 12969 preset (base) | `T_Live\...\MQL5\Presets\17_USDJPY_M30_QM5_12969_usdjpy-gotobi-nakane-fix.set` | `360991b5a72f2451c47c01dabf1c12f3f2ec96470dd1047d44a26a502ddc4649` |
| identity-equivalence proof | `D:\QM\reports\identity_equivalence\QM5_12969__QM5_41470\USDJPY.DWX\proof.json` | `3648983baea047f4f0a0f48d922ea442646bcb00022e7cdaca498fe31635828a` |
| param diff | `repair_v2\presets\param_diff_41470.json` | (C2 guard, below) |
| manifest delta | `repair_v2\manifest_delta_41470.json` | — |
| copy plan | `repair_v2\copy_plan_repair_v2.json` | — |
| copy-plan dry-run | `repair_v2\copy_plan_repair_v2_dryrun.json` | — |

## Magic numbers (registry `framework/registry/magic_numbers.csv`, both active)

- 41470 / USDJPY.DWX / slot 0 -> **414700000** = 41470*10000+0
- 12969 / USDJPY.DWX / slot 0 -> **129690000** = 12969*10000+0

## Preset changes (base = deployed 12969 live preset)

Only: `qm_ea_id` 12969->41470; header identity (slug/set_version/build_hash); `RISK_PERCENT`
0.5100 -> **0.590437** (repair_report new_risk); added symbol input **`strategy_host_symbol=USDJPY`**
(bare broker name). `RISK_FIXED=0`, `PORTFOLIO_WEIGHT=1`, `environment: live`, `risk_mode: PERCENT`
preserved.

**C2-trap guard (`param_diff_41470.json`, BOM-aware):** `no_strategy_parameter_reset = true`.
The five strategy_* params (entry 200 / exit 955 / holiday true / stop 120 / spread 0) are
carried byte-identical; the only strategy addition is `strategy_host_symbol`. No lane-staged
strategy-param wipe.

## Dry-run result

`python -X utf8 tools/strategy_farm/deploy_tlive_book.py --plan repair_v2/copy_plan_repair_v2.json`
(no `--apply`): **exit 0**, `mode=DRY_RUN`, `validated_items=2`, `written_items=0`. The
book-build guard passed (>=25 qualified pairs + valid `decisions/2026-09-13_owner_book_order_dxz.md`
token) and both source hashes matched. Saved to `copy_plan_repair_v2_dryrun.json`.

## Deployment is BLOCKED until

1. **OWNER receipt** on `decisions/2026-09-13_identity_equivalence_proof_rebuilds.md`
   (state: PROPOSED, receipt pending).
2. **Book-v2 cutover order** (separate OWNER act).
3. **LIVE_RISK_FREEZE lift** (runbook §1.3) — the freeze is ACTIVE.

AutoTrading remains OWNER-only and is never toggled by an AI seat. The removal of the old
12969 preset and the chart detach/re-attach are manual cutover steps (see
`ANLEITUNG_REPAIR_V2.md`); the copy-plan schema copies files only.

## Sibling dark sleeves — not staged here

- **QM5_41471** (replaces 12778 / AUDUSD, basket) and **QM5_41472** (replaces 13117 / EURGBP,
  basket): magic identities are reserved (414710000/…001, 414720000/…001, active), but there
  is **no identity-equivalence proof directory** for them yet under
  `D:\QM\reports\identity_equivalence\`. They **wait for their Q02 rows + equivalence proofs**
  before any equivalent staging. (Proof dirs currently present: 12969->41470, 13054->41473,
  21505->41474.)
