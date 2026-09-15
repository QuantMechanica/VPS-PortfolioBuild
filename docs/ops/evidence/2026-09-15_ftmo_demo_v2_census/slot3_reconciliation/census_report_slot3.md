# FTMO demo book v2 - admission census (book sprint F4)

Ticket: `42a437a4-9674-47ce-9ca9-80eba8a2bc91 (book sprint F4)`

Target: FTMO DEMO account **1514536732** (FTMO-Demo), governor QM5_13206 policy FTMO_2S_P1_100K_V2 (UNCHANGED by this census).

**26 ADMIT / 2 EXCLUDE** of 28 DXZ v2 roster sleeves.

Read-only census: no terminal started, no FTMO/T_Live data-dir write, no recompile,
no governor policy change. Governor input deltas below are a **proposal**.

## Schema (roster_ftmo_demo_v2.json)

`roster[]` - one row per roster sleeve:

- `ea_id / effective_ea_id / replaced_by_ea_id` - roster id; id actually deployed (12969 -> 41470)
- `dxz_symbol / ftmo_symbol` - logical .DWX name; FTMO raw name or `UNVERIFIED`
- `symbol_source / symbol_evidence` - how the FTMO name was bound, with evidence paths
- `binary_path / binary_source / binary_sha256` - the exact .ex5 that would be deployed
- `symbol_handling_class` - chart-symbol-only / symbol-input-slot / .DWX-literal
- `required_preset_overrides / required_preset_pins` - preset work needed before deploy
- `news_compliance_capability` - MODE_2_CAPABLE or MODE_1_LEGACY_ONLY (recorded, not excluding)
- `slot / magic / magic_formula_ok / magic_collision` - magic = ea_id*10000+slot and collision state
- `risk_percent / risk_basis` - DXZ v2 per-sleeve weight
- `decision / reason` - ADMIT or EXCLUDE with evidence-bound reason

## ADMIT

| ea | FTMO symbol | class | magic | risk % | news | binary sha256 (12) |
|---|---|---|---|---|---|---|
| 1537 QM5_1537_aa-vol-sma10 | XAGUSD | chart-symbol-only (preset-pinned logical symbol) | 15370001 | 0.0769 | MODE_2_CAPABLE | `142a019e773a` |
| 1556 QM5_1556_aa-zak-mom12 | XAUUSD | chart-symbol-only | 15560004 | 0.540735 | MODE_2_CAPABLE | `9371a8a03008` |
| 1567 QM5_1567_demark-td-reverse-sequential-h4 | EURUSD | chart-symbol-only | 15670007 | 0.184783 | MODE_1_LEGACY_ONLY | `71c2f84b3e69` |
| 9641 QM5_9641_bandy-cci-extreme-fade-mr-index | US30.cash | chart-symbol-only | 96410002 | 0.0104 | MODE_2_CAPABLE | `21eda8527f66` |
| 10403 QM5_10403_et-turtle20x | XAUUSD | chart-symbol-only | 104030002 | 0.217916 | MODE_2_CAPABLE | `b6c194d928b6` |
| 10440 QM5_10440_mql5-ohlc-mtf | US100.cash | chart-symbol-only | 104400003 | 0.058434 | MODE_2_CAPABLE | `b71d302997ec` |
| 10513 QM5_10513_mql5-ichimoku | XAUUSD | chart-symbol-only | 105130003 | 0.298731 | MODE_2_CAPABLE | `04b62af28c64` |
| 10700 QM5_10700_tv-liq-break | XAUUSD | chart-symbol-only | 107000003 | 0.013 | MODE_2_CAPABLE | `5fbf2ba00482` |
| 10706 QM5_10706_tv-mon-ls | GBPUSD | chart-symbol-only | 107060001 | 0.052676 | MODE_2_CAPABLE | `01e34b2059de` |
| 10911 QM5_10911_grimes-complex-pb | GER40.cash | chart-symbol-only | 109110003 | 0.125988 | MODE_2_CAPABLE | `a815c73da991` |
| 10919 QM5_10919_grimes-overshoot | USOIL.cash | chart-symbol-only | 109190001 | 0.857769 | MODE_2_CAPABLE | `57e0db840161` |
| 10939 QM5_10939_grimes-context-pb | GBPUSD | chart-symbol-only | 109390001 | 0.195791 | MODE_2_CAPABLE | `308604a3546c` |
| 11132 QM5_11132_tm-cum-rsi2 | US500.cash | chart-symbol-only | 111320000 | 0.427189 | MODE_2_CAPABLE | `25b68c44d972` |
| 11165 QM5_11165_weiss-rsi-ma | AUDCAD | chart-symbol-only | 111650002 | 0.508245 | MODE_2_CAPABLE | `8f6d33a3dfb0` |
| 11165 QM5_11165_weiss-rsi-ma | EURUSD | chart-symbol-only | 111650000 | 0.409674 | MODE_2_CAPABLE | `8f6d33a3dfb0` |
| 11421 QM5_11421_ohlc-daily-squeeze-reversal-d1 | AUDUSD | chart-symbol-only | 114210003 | 0.321345 | MODE_2_CAPABLE | `0f7c8ff9ad91` |
| 11421 QM5_11421_ohlc-daily-squeeze-reversal-d1 | EURUSD | chart-symbol-only | 114210000 | 0.324694 | MODE_2_CAPABLE | `0f7c8ff9ad91` |
| 11708 QM5_11708_anon-market-squeeze-d1 | EURUSD | chart-symbol-only | 117080000 | 0.544893 | MODE_2_CAPABLE | `de06fb032c9b` |
| 12567 QM5_12567_cum-rsi2-commodity | XAUUSD | chart-symbol-only | 125670003 | 0.784834 | MODE_2_CAPABLE | `5d5be334288e` |
| 12567 QM5_12567_cum-rsi2-commodity | NATGAS.cash | chart-symbol-only | 125670002 | 0.957698 | MODE_2_CAPABLE | `5d5be334288e` |
| 41470 QM5_41470_usdjpy-gotobi-nakane-fix-symfix | USDJPY | symbol-input-slot (canonical-compare, no override needed) | 414700000 | 0.590437 | MODE_2_CAPABLE | `ef34638d26eb` |
| 12989 QM5_12989_grimes-nested-pb-v2 | XAUUSD | chart-symbol-only | 129890003 | 0.227473 | MODE_2_CAPABLE | `7f2c298f4a8b` |
| 13013 QM5_13013_grimes-trendday-v2 | US100.cash | chart-symbol-only | 130130000 | 0.0105 | MODE_2_CAPABLE | `bf2cc2ecaff8` |
| 13128 QM5_13128_pre-fomc-drift-ndx | US100.cash | chart-symbol-only | 131280000 | 1.102818 | MODE_2_CAPABLE | `364867a9fe8d` |
| 13213 QM5_13213_balke-gmt3-range-breakout | USDJPY | chart-symbol-only | 132130000 | 0.044306 | MODE_2_CAPABLE | `321b1dca0064` |
| 13301 QM5_13301_balke-minute-range-breakout | GER40.cash | chart-symbol-only | 133010010 | 0.064799 | MODE_2_CAPABLE | `d7f10a684bdb` |

## EXCLUDE

| ea | dxz symbol | reason |
|---|---|---|
| 12778 QM5_12778_edgelab-audusd-eurjpy-cointegration | AUDUSD.DWX | auxiliary symbol EURJPY.DWX (input slot) has no verified FTMO name; auxiliary symbol EURAUD.DWX (input slot) has no verified FTMO name; DXZ v2 preset carries no symbol-slot override, so the EA would run dark (SymbolSelect/CopyClose on .DWX names absent on FTMO): C:\QM\deploy\DXZ_V2_20260913\presets\existing\06_AUDUSD_D1_QM5_12778_edgelab-audusd-eurjpy-cointegration.set |
| 13117 QM5_13117_eurgbp-audjpy | EURGBP.DWX | chart symbol EURGBP.DWX has no verified FTMO name (no alias row, no attach-map magic binding, not observed in terminal); auxiliary symbol EURGBP.DWX (input slot) has no verified FTMO name; DXZ v2 preset carries no symbol-slot override, so the EA would run dark (SymbolSelect/CopyClose on .DWX names absent on FTMO): C:\QM\deploy\DXZ_V2_20260913\presets\existing\24_EURGBP_D1_QM5_13117_eurgbp-audjpy.set |

## Symbol bindings

| logical | FTMO raw | source |
|---|---|---|
| AUDCAD.DWX | AUDCAD | terminal attach map (magic-bound) |
| AUDJPY.DWX | AUDJPY | terminal inventory (bare base name observed) |
| AUDUSD.DWX | AUDUSD | terminal attach map (magic-bound) |
| EURAUD.DWX | UNVERIFIED | unverified |
| EURGBP.DWX | UNVERIFIED | unverified |
| EURJPY.DWX | UNVERIFIED | unverified |
| EURUSD.DWX | EURUSD | terminal attach map (magic-bound) |
| GBPUSD.DWX | GBPUSD | terminal attach map (magic-bound) |
| GDAXI.DWX | GER40.cash | terminal attach map (magic-bound) |
| NDX.DWX | US100.cash | terminal attach map (magic-bound) |
| SP500.DWX | US500.cash | terminal attach map (magic-bound) |
| USDJPY.DWX | USDJPY | alias table (FTMO_TRIAL acct 1513845506) |
| WS30.DWX | US30.cash | alias table (FTMO_TRIAL acct 1513845506) |
| XAGUSD.DWX | XAGUSD | terminal inventory (bare base name observed) |
| XAUUSD.DWX | XAUUSD | terminal attach map (magic-bound) |
| XNGUSD.DWX | NATGAS.cash | terminal attach map (magic-bound) |
| XTIUSD.DWX | USOIL.cash | alias table (FTMO_TRIAL acct 1513845506) |

## Magic collision check

- No magic is shared by two roster sleeves (all 28 unique).
- Roster magics vs the 5 current demo-book magics that are not in the roster: no overlap.
- All ADMIT rows satisfy `magic == ea_id*10000 + slot`: yes

## Evidence caveats / residual risk

1. **Alias-table rows are bound to a different account.** `execution_symbol_aliases_v1.json` declares `matching: EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL` and its `FTMO_TRIAL` venue is account **1513845506**, not the target **1514536732**. Same server (FTMO-Demo), so the raw names are expected to be identical, but the registry does not formally cover this account. Affected: USDJPY, WS30->US30.cash, XTIUSD->USOIL.cash.
2. **`US30.cash` was never observed in the target terminal.** It appears in no tick dir, history dir, chart profile, attach map or native snapshot - only in the alias table (see 1). EA 9641 is ADMITted on that binding alone; confirm the name in Market Watch before deploying it.
3. **Symbol-handling class is derived from source, not from the binary.** The deployed `.ex5` files are compressed and expose no readable string constants, so no literal can be read back out of the binary. Classification comes from the sanctioned source scanner at the current `C:/QM/repo` HEAD; it assumes each `.ex5` was built from the source now in the tree. Binaries are sha256-bound in `roster[].binary_sha256` so the assumption is auditable, but it is an assumption.
4. **EA 1537 only works if the preset pins the logical name.** `QM1537_HostSymbol()` returns `_Symbol` when `strategy_calendar_symbol` is empty, and the sealed monthly-sleeve CSV is keyed by `XAGUSD.DWX` and compared with `==` (`QM5_1537_MonthlySleeveCalendar.mqh:289` and `:312`). With a bare `XAGUSD` chart and an empty input, every calendar row is skipped and the bundle-SHA guard never fires. The current FTMO chart08 and the DXZ v2 preset both set `strategy_calendar_symbol=XAGUSD.DWX`, so this is satisfied today - it must not be dropped.
5. **EA 1567 predates the news-compliance contract.** It exposes only the legacy `qm_news_mode` (`QM_NEWS_PAUSE`) and has no `qm_news_compliance` input, so it cannot be driven to FTMO news mode 2. Recorded, not excluded (demo burn-in), per the ticket.
6. **Ticket premise correction: 12778 and 13117 are not `.DWX`-literal EAs.** Both carry proper per-slot symbol *inputs* under the OWNER 2026-09-06 rule (`QM5_13117_eurgbp-audjpy.mq5:50-53`, `QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5:90-93`); the `.DWX` strings are input *defaults*, and the source comment states presets are expected to override them with bare broker names. They are dark on FTMO only because the DXZ v2 presets set no symbol overrides at all (verified: those `.set` files contain `RISK_*` and nothing else). They become admissible once EURGBP / EURJPY / EURAUD have verified FTMO names **and** the preset overrides every slot - the exclusion is a preset+symbol gap, not a code defect.

## Governor input delta (PROPOSAL - not applied)

- today  `allowed_magics_csv=107060001,114210000,114220004,119100006,130540000,15370001,200480000,215050000`
- proposed `allowed_magics_csv=15370001,15560004,15670007,96410002,104030002,104400003,105130003,107000003,107060001,109110003,109190001,109390001,111320000,111650000,111650002,114210000,114210003,117080000,125670002,125670003,129890003,130130000,131280000,132130000,133010010,414700000`
- proposed `governed_symbols_csv=AUDCAD,AUDUSD,EURUSD,GBPUSD,GER40.cash,NATGAS.cash,US100.cash,US30.cash,US500.cash,USDJPY,USOIL.cash,XAGUSD,XAUUSD`
- retained-from-today (current demo book, not in roster): [114220004, 119100006, 130540000, 200480000, 215050000]

> The proposed allowed_magics_csv covers ADMITted roster sleeves only. Magics listed in magics_retained_from_today_not_in_roster belong to the current 8-sleeve demo book and must be unioned in if those sleeves stay.

## Inputs (sha256-bound)

- `roster`: D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/analytic_preview_manifest_28_r11.json
- `roster_sha256`: b69e40bcf32530e014b240d0b5c5a8aee5de139442573de30df307c31995aa0a
- `profile_manifest`: C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json
- `profile_manifest_sha256`: 83c0268d9aff5d55074485a57b79a2b5b1370227e9b86fe384abbfd38901aab5
- `aliases`: C:/QM/repo/framework/registry/execution_symbol_aliases_v1.json
- `aliases_sha256`: 8bc64afd4e66fbd32321b18000da4b5b4251f1826ae4d8d8cded0411af6094f1
- `attach_map`: C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/ftmo_demo_attach_map.json
- `attach_map_sha256`: fd89f17f9a1d60d324f8a2ed581c8733a32c29e0dca4d1e72a9a2a3678d31d3a
