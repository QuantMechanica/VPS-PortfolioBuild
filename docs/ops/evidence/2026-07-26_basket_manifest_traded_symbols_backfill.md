# Basket manifest `traded_symbols` backfill — fail-closed magic qualification

**Date:** 2026-07-26
**Author:** Claude (board-advisor worktree)
**Trigger:** Codex review CHANGES-REQUIRED on the basket-magic qualification fix in
`tools/strategy_farm/portfolio/ftmo_qualification.py`. The host-plus-consistency
fallback was not fail-closed: for a basket that declared neither `traded_symbols`
nor `conversion_symbols`, a genuinely traded leg whose magic-registry row was
missing was indistinguishable from an absent conversion-only leg, so the helper
returned success. See `decisions/2026-07-25_q08_tooling_invalid_is_infra.md`
lineage and the Codex batch-2 review evidence.

## Code change (summary)

`_active_magic_registered` no longer falls back to a host + registry-consistency
heuristic for basket EAs. A basket now clears the magic-completeness check ONLY
when its traded legs are authoritatively known:

- (a) `traded_symbols` declared in `basket_manifest.json`, or
- (b) a complete derivation `basket_symbols - conversion_symbols` where both keys
  are present.

If neither is available, `_basket_required_legs` returns `None` and the helper
rejects with reason
`active_magic_unknown_legs:<logical_symbol>:traded_symbols_undeclared`
(fail-closed). The dead `inactive` / `ea_row_count` tracking used only by the
removed heuristic was deleted.

## Backfill rationale and source of truth

Every FTMO qualification candidate that is a logical basket (`work_items` with
phase in Q07/Q08/Q10, status `done`, symbol matching `^QM5_\d+_`) was inventoried
against the read-only farm state DB
(`D:\QM\strategy_farm\state\farm_state.sqlite`, `mode=ro`): **14 logical
baskets**. Four already carried `traded_symbols` (13140, 13144, 13147, 13151);
the remaining **10 reached the fallback** and are backfilled here.

For each basket the traded legs were derived from the EA's own source
(`framework/EAs/<label>/*.mq5`, cross-checked against `SPEC.md`): the legs passed
to `Strategy_OpenLeg` / `Strategy_OpenBasketLeg` (edgelab/spread template) or the
`ResolvePairForSymbol` slot assignments (1058 Gatev template) are the traded
legs; symbols that appear only in `Strategy_EnsureBasketScope()`'s `SymbolSelect`
warmup list are conversion/history-only and are correctly excluded. Each derived
set was confirmed to equal the active rows in
`framework/registry/magic_numbers.csv` exactly (see verification below).

## Per-manifest backfill (before → after)

All ten manifests had **no `traded_symbols` key** before; the "after" column is
the value written. Paths are under `C:\QM\repo\`.

| EA | Manifest path | `basket_symbols` (unchanged) | `traded_symbols` written (after) | Source (traded-leg authority) |
|---|---|---|---|---|
| 1058 | `framework/EAs/QM5_1058_gatev-fx-pairs-zscore/basket_manifest.json` | EURUSD, GBPUSD, AUDUSD, NZDUSD | EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX | `QM5_1058_gatev-fx-pairs-zscore.mq5` `ResolvePairForSymbol` Pair A (slots 0/1) + Pair B (slots 2/3); `SPEC.md` §1/§3 — EA trades both pairs (all 4 legs get magic numbers) |
| 12712 | `framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/basket_manifest.json` | EURGBP, EURAUD, EURUSD, GBPUSD, AUDUSD | EURGBP.DWX, EURAUD.DWX | `..._eurgbp-euraud-cointegration.mq5` `g_leg_eurgbp`/`g_leg_euraud` → `Strategy_OpenLeg`; EURUSD/GBPUSD/AUDUSD only in `Strategy_EnsureBasketScope` (conversion) |
| 12772 | `framework/EAs/QM5_12772_edgelab-gbpjpy-audjpy-cointegration/basket_manifest.json` | GBPJPY, AUDJPY, USDJPY | GBPJPY.DWX, AUDJPY.DWX | `..._gbpjpy-audjpy-cointegration.mq5` `g_leg_gbpjpy`/`g_leg_audjpy` → `Strategy_OpenLeg`; USDJPY conversion-only (`allowed[3]` scope) |
| 12778 | `framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/basket_manifest.json` | AUDUSD, EURJPY, EURUSD, EURAUD | AUDUSD.DWX, EURJPY.DWX | `..._audusd-eurjpy-cointegration.mq5` `g_leg_audusd`/`g_leg_eurjpy` → `Strategy_OpenLeg`; EURUSD/EURAUD conversion-only |
| 12781 | `framework/EAs/QM5_12781_edgelab-usdjpy-audjpy-cointegration/basket_manifest.json` | USDJPY, AUDJPY | USDJPY.DWX, AUDJPY.DWX | `..._usdjpy-audjpy-cointegration.mq5` `g_leg_USDJPY`/`g_leg_audjpy` → `Strategy_OpenLeg`; no conversion legs |
| 12831 | `framework/EAs/QM5_12831_wti-audusd-brk/basket_manifest.json` | XTIUSD, AUDUSD | XTIUSD.DWX, AUDUSD.DWX | `QM5_12831_wti-audusd-brk.mq5` `g_leg_xti` (host breakout, slot 0) + `g_leg_audusd` → `Strategy_OpenBasketLeg`; both traded |
| 12864 | `framework/EAs/QM5_12864_oilsilver-rspr/basket_manifest.json` | XTIUSD, XAGUSD | XTIUSD.DWX, XAGUSD.DWX | `QM5_12864_oilsilver-rspr.mq5` `g_leg_xti`/`g_leg_xag` → `Strategy_OpenLeg`; both traded |
| 13059 | `framework/EAs/QM5_13059_xti-audjpy-rspr/basket_manifest.json` | XTIUSD, AUDJPY | XTIUSD.DWX, AUDJPY.DWX | `QM5_13059_xti-audjpy-rspr.mq5` `g_leg_xti`/`g_leg_audjpy` → `Strategy_OpenLeg`; both traded |
| 13076 | `framework/EAs/QM5_13076_xti-nzdcad-rspr/basket_manifest.json` | XTIUSD, NZDCAD | XTIUSD.DWX, NZDCAD.DWX | `QM5_13076_xti-nzdcad-rspr.mq5` `g_leg_xti`/`g_leg_nzdcad` → `Strategy_OpenLeg`; both traded |
| 13117 | `framework/EAs/QM5_13117_eurgbp-audjpy/basket_manifest.json` | EURGBP, AUDJPY, GBPUSD, USDJPY | EURGBP.DWX, AUDJPY.DWX | `QM5_13117_eurgbp-audjpy.mq5` `g_leg_eurgbp`/`g_leg_audjpy` → `Strategy_OpenLeg`; GBPUSD/USDJPY conversion-only (manifest note + `Strategy_EnsureBasketScope`) |

Note on 1058: its manifest `notes` say AUDUSD/NZDUSD "remain declared because the
EA warmup path selects all registered pair symbols." The source shows they are
not warmup-only — `ResolvePairForSymbol` assigns them slots 2/3 and the EA opens
Pair B on them, so all four legs are genuinely traded and all four own active
magic rows. `traded_symbols` therefore includes all four.

## Already-authoritative (no change) — 4 baskets

| EA | Manifest path | `traded_symbols` (pre-existing) |
|---|---|---|
| 13140 | `framework/EAs/QM5_13140_energy-aliq-rank/basket_manifest.json` | XTIUSD.DWX, XNGUSD.DWX |
| 13144 | `framework/EAs/QM5_13144_energy-micro11/basket_manifest.json` | XTIUSD.DWX, XNGUSD.DWX |
| 13147 | `framework/EAs/QM5_13147_energy-jumpbeta/basket_manifest.json` | XTIUSD.DWX, XNGUSD.DWX |
| 13151 | `framework/EAs/QM5_13151_energy-volbeta/basket_manifest.json` | XTIUSD.DWX, XNGUSD.DWX |

## Verification

- All 14 manifests parse as valid JSON after the edit.
- For every basket, `traded_symbols` equals the set of `active` rows for that EA
  in `framework/registry/magic_numbers.csv` (exact set match) — so the fail-closed
  helper passes each real candidate via branch (a).
- Negative regression added to `test_ftmo_qualification.py`
  (`test_basket_without_authoritative_legs_second_leg_removed_is_rejected` and
  `test_basket_without_authoritative_legs_rejected_even_when_consistent`): a
  manifest lacking both keys is now rejected even when the host is active and the
  registry is otherwise consistent.
- `python -m pytest tools/strategy_farm/tests/test_ftmo_qualification.py -q` —
  full pass (see PR/working-tree run).

No factory DB writes; state DB read only in `mode=ro`. No T_Live artifacts
touched.
