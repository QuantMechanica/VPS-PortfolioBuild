# FTMO demo book v2 — admission census (READ-ONLY)

Book sprint `docs/ops/BOOK_SPRINT_2026-09-20.md` item **F4** (decision **F3**: FTMO demo
book v2 = the DXZ v2 roster on FTMO broker symbol names, same sha-bound binaries, no
rebuild, no qualification claim), Sonnet ticket **42a437a4** (due Wed 2026-09-17 18:00Z).

This census is the prerequisite step before a profile/copy plan gets built. It decides
**ADMIT / EXCLUDE per sleeve** for a *burn-in* deployment on the FTMO **demo** terminal
(account **1514536732**, server `FTMO-Demo`).

## Hard-limit compliance (all honoured)

Read-only against both live terminals. No `terminal64.exe` start; no writes into any FTMO
or T_Live data dir; **no recompile** (binaries are bound by sha256, never rebuilt — a
rebuilt `.ex5` is a new identity by company policy); no chart attach; no governor policy
change. The only files written are in this evidence dir plus the re-runnable tool at
`tools/strategy_farm/ftmo_demo_v2_census.py`. The governor input deltas below are a
**PROPOSAL ONLY** — applied nowhere.

## Result

| | count |
|---|---|
| Roster sleeves (28-sleeve DXZ v2, 12969→41470 substitution applied) | **28** |
| **ADMIT** | **24** |
| **EXCLUDE** | **4** |

## Files

- `roster_ftmo_demo_v2.json` — one row per sleeve (schema below).
- `README.md` — this file.
- `tools/strategy_farm/ftmo_demo_v2_census.py` — reproduces the census end to end
  (read-only). Re-run: `python -X utf8 tools/strategy_farm/ftmo_demo_v2_census.py`.

## roster_ftmo_demo_v2.json schema (per row)

| field | meaning |
|---|---|
| `ea_id`, `ea_label` | EA identity / expert name of the binary that would be deployed |
| `replaces_ea_id` | set to `12969` on the 41470 row (the OWNER-approved substitution) |
| `dxz_symbol` | DXZ logical `.DWX` symbol from the profile manifest |
| `ftmo_symbol` | resolved FTMO raw symbol, or `UNVERIFIED` |
| `symbol_source` | `alias_registry_FTMO_TRIAL` / `native_capture_2026-09-06` / `ftmo_ticks_dir_1514536732` / `unverified` |
| `binary_path`, `binary_location` | resolved deployable `.ex5` (`T_Live` / `deploy_staging` / `repair_v2`) |
| `binary_sha256` | sha256 of that exact binary (identity binding — no rebuild) |
| `symbol_handling_class` | `chart-symbol-only` / `symbol-input-slot` / `…+multi-symbol` / `…+non-chart-reads` |
| `symbol_handling_detail` | raw inventory-tool output incl. any `trading_logic_literals` (file:line) |
| `news_compliance_capability` | `FTMO_MODE2_SELECTABLE` (has `qm_news_compliance` enum input; FTMO=2 selectable) / `NO_NEWS_INPUT` / `LEGACY_ONLY_MODE1` |
| `slot`, `magic` | slot from the DXZ preset; `magic = ea_id*10000 + slot` |
| `magic_formula_ok` | magic equals the formula |
| `magic_in_governor_allowed` | magic already in the FTMO governor's 8-magic set (same sleeve) |
| `magic_registry_ea_id` | ea_id the magic maps to in `magic_numbers.csv` |
| `magic_collision` | `true` only if the magic maps to a **different** ea (none do) |
| `risk_percent`, `risk_percent_field` | weight (existing) / burn-in (new); field documents which |
| `risk_percent_profile` | the value the DXZ v2 profile materialises (cross-check; matches all 28) |
| `decision`, `reason` | ADMIT / EXCLUDE + evidence-bound reason |

## Full roster

| ea_id | dxz_symbol | ftmo_symbol | symbol_source | handling_class | news | slot | magic | coll | risk% | decision |
|---|---|---|---|---|---|---|---|---|---|---|
| 1537 | XAGUSD.DWX | XAGUSD | native-2026-09-06 | chart-symbol-only | mode2 | 1 | 15370001 | n | 0.0769 | ADMIT |
| 1556 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only+non-chart-reads | mode2 | 4 | 15560004 | n | 0.540735 | ADMIT |
| 1567 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | **NO_NEWS_INPUT** | 7 | 15670007 | n | 0.184783 | ADMIT |
| 9641 | WS30.DWX | US30.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 2 | 96410002 | n | 0.0104 | ADMIT |
| 10403 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 2 | 104030002 | n | 0.217916 | ADMIT |
| 10440 | NDX.DWX | US100.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 104400003 | n | 0.058434 | ADMIT |
| 10513 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 105130003 | n | 0.298731 | ADMIT |
| 10700 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 107000003 | n | 0.013 | ADMIT |
| 10706 | GBPUSD.DWX | GBPUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 1 | 107060001 | n | 0.052676 | ADMIT |
| 10911 | GDAXI.DWX | GER40.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 109110003 | n | 0.125988 | ADMIT |
| 10919 | XTIUSD.DWX | USOIL.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 1 | 109190001 | n | 0.857769 | ADMIT |
| 10939 | GBPUSD.DWX | GBPUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 1 | 109390001 | n | 0.195791 | ADMIT |
| **11132** | **SP500.DWX** | **UNVERIFIED** | **unverified** | chart-symbol-only | mode2 | 0 | 111320000 | n | 0.427189 | **EXCLUDE** |
| 11165 | AUDCAD.DWX | AUDCAD | ftmo-ticks-dir | chart-symbol-only | mode2 | 2 | 111650002 | n | 0.508245 | ADMIT |
| 11165 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | mode2 | 0 | 111650000 | n | 0.409674 | ADMIT |
| 11421 | AUDUSD.DWX | AUDUSD | ftmo-ticks-dir | chart-symbol-only | mode2 | 3 | 114210003 | n | 0.321345 | ADMIT |
| 11421 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | mode2 | 0 | 114210000 | n | 0.324694 | ADMIT |
| 11708 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | mode2 | 0 | 117080000 | n | 0.544893 | ADMIT |
| 12567 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 125670003 | n | 0.784834 | ADMIT |
| **12567** | **XNGUSD.DWX** | **UNVERIFIED** | **unverified** | chart-symbol-only | mode2 | 2 | 125670002 | n | 0.957698 | **EXCLUDE** |
| **12778** | **AUDUSD.DWX** | AUDUSD | ftmo-ticks-dir | symbol-input-slot+multi-symbol | mode2 | 0 | 127780000 | n | 0.439281 | **EXCLUDE** |
| 41470 | USDJPY.DWX | USDJPY | alias-FTMO-TRIAL | symbol-input-slot | mode2 | 0 | 414700000 | n | 0.590437 | ADMIT |
| 12989 | XAUUSD.DWX | XAUUSD | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 3 | 129890003 | n | 0.227473 | ADMIT |
| 13013 | NDX.DWX | US100.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 0 | 130130000 | n | 0.0105 | ADMIT |
| **13117** | **EURGBP.DWX** | **UNVERIFIED** | **unverified** | symbol-input-slot+multi-symbol | mode2 | 0 | 131170000 | n | 0.409988 | **EXCLUDE** |
| 13128 | NDX.DWX | US100.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 0 | 131280000 | n | 1.102818 | ADMIT |
| 13213 | USDJPY.DWX | USDJPY | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 0 | 132130000 | n | 0.044306 | ADMIT |
| 13301 | GDAXI.DWX | GER40.cash | alias-FTMO-TRIAL | chart-symbol-only | mode2 | 10 | 133010010 | n | 0.064799 | ADMIT |

`risk%` provenance: 24 existing sleeves use `weight_risk_percent`, 4 new sleeves
(1537, 9641, 10700, 13013) use `burn_in_risk_percent`, from
`analytic_preview_manifest_28_r11.json`. Every value equals the value the DXZ v2 profile
materialises as chart `risk_percent` (0 mismatches).

## EXCLUDE reasons (each bound to evidence)

**Reason A — "no verified FTMO symbol name" (3 sleeves: 11132/SP500, 12567/XNGUSD, 13117/EURGBP)**

The FTMO raw symbol name could not be verified against any read-only source:
- Alias registry `framework/registry/execution_symbol_aliases_v1.json` FTMO_TRIAL venue
  (lines 52–86) lists only GBPUSD, GER40.cash, US100.cash, US30.cash, USDJPY, USOIL.cash,
  XAUUSD — **no** SP500/US500, XNGUSD/NGAS, or EURGBP.
- Native FTMO capture 2026-09-06 `symbols_covered_native`
  (`docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json:16`):
  XAUUSD, GER40.cash, GBPUSD, EURUSD, USDCAD, NZDUSD, USOIL.cash, XAGUSD — none of the three.
- FTMO terminal ticks dir
  `…/81A933A9AFC5DE3C23B15CAB19C63850/bases/FTMO-Demo/ticks/` (live listing captured in
  `roster_ftmo_demo_v2.json → sources.ftmo_ticks_dir_symbols`): 27 symbol dirs present
  (AUDCAD, AUDUSD, EURUSD, GER40.cash, US100.cash, USOIL.cash, XAGUSD, XAUUSD, …) — **no**
  US500.cash, NGAS/XNGUSD, or EURGBP dir.
- The encrypted `symbols-1514536732.dat` is not human-readable (verified: only random
  tokens on a binary scan), so it cannot supply a name either.

Per the census brief, no verified name ⇒ `symbol_source: unverified` ⇒ EXCLUDE. These are
*not guessed* (US500.cash / NGAS.cash would be plausible but unverified on this account).

**Reason B — "dark no-op in v2 (NOT_EQUIVALENT rebuild, multi-symbol cointegration/pair)"
(2 sleeves: 12778, 13117)**

`docs/ops/BOOK_SPRINT_2026-09-20.md:39` (item D7): *"12778/13117 (NOT_EQUIVALENT rebuilds)
stay dark no-ops in v2; own chains continue … accepted"*. Corroborated by the symbol-handling
class: both are `symbol-input-slot+multi-symbol` cointegration/pair EAs (inventory tool:
4 `symbol_input_default` + non-chart market-data access each). Their second leg is not
verified on FTMO (12778 needs EURJPY; 13117 needs AUDJPY + the unverified EURGBP primary —
EURJPY has no ticks dir). 13117 therefore hits **both** Reason A and Reason B; 12778's
primary AUDUSD *is* verified but it is excluded on the D7 dark-no-op decision.

The claim "12778 and 13117 are dark no-ops" from the brief is **confirmed**, not assumed.

## Symbol resolution summary

17 sleeves resolve via the alias registry (authoritative), 5 via the native 2026-09-06
capture (EURUSD ×4, XAGUSD), 3 via the FTMO ticks dir (AUDCAD, AUDUSD ×2 incl. the
excluded 12778), 3 unverified. `WS30.DWX → US30.cash` rests **only** on the alias registry
(no US30.cash ticks dir yet) — it is authoritative but will only actually receive data once
the OWNER adds US30.cash to the FTMO Market Watch, same pattern as the DXZ ceremony D3.

## Magic-number analysis

All 28 magics satisfy `magic = ea_id*10000 + slot` and each maps in
`framework/registry/magic_numbers.csv` to its own sleeve. **No collision** (`magic_collision`
is `false` for all 28). Three ADMIT magics already sit in the FTMO governor's 8-magic set —
**15370001** (1537/XAGUSD), **107060001** (10706/GBPUSD), **114210000** (11421/EURUSD) — but
each is the *same* sleeve, so these are consistency, not collisions (`magic_in_governor_allowed`
flags them for the profile builder). The other 5 governor magics (114220004, 119100006,
130540000, 200480000, 215050000) belong to non-roster EAs already on the demo and are left
untouched.

## News-compliance capability (record only — never an exclude reason)

27 of 28 binaries declare `input QM_NewsComplianceProfile qm_news_compliance`
(`QM_NewsFilter.mqh:38-41`: NONE=0, DXZ=1, **FTMO=2**, 5ERS=3), so FTMO mode 2 is selectable
at deploy time via the set file / profile input. **Exception: 1567
(demark-td-reverse-sequential-h4) has NO news-compliance input at all** (`NO_NEWS_INPUT`;
older framework, no `qm_news_mode_legacy` either). 1567 is still ADMIT on symbol/magic/risk
grounds, but the profile/copy plan should record that 1567 cannot enforce the FTMO news
blackout in-EA and rely on the account governor / OWNER awareness for it.

## GOVERNOR INPUT DELTAS — PROPOSAL ONLY (do not apply)

These are the chart01 governor input values the FTMO demo book v2 would need. **Not applied
anywhere. Policy `FTMO_2S_P1_100K_V2` / M13 unchanged.** The governor EA QM5_13206 and its
presets are untouched by this census.

- **`allowed_magics_csv`** (existing 8 ∪ 24 ADMIT magics):
  `15370001,15560004,15670007,96410002,104030002,104400003,105130003,107000003,107060001,109110003,109190001,109390001,111650000,111650002,114210000,114210003,114220004,117080000,119100006,125670003,129890003,130130000,130540000,131280000,132130000,133010010,200480000,215050000,414700000`
- **New magics to add** (21; the 3 governor overlaps 15370001/107060001/114210000 already present):
  `15560004,15670007,96410002,104030002,104400003,105130003,107000003,109110003,109190001,109390001,111650000,111650002,114210003,117080000,125670003,129890003,130130000,131280000,132130000,133010010,414700000`
- **`governed_symbols_csv`** (distinct FTMO raw symbols across the 24 ADMIT sleeves):
  `AUDCAD,AUDUSD,EURUSD,GBPUSD,GER40.cash,US100.cash,US30.cash,USDJPY,USOIL.cash,XAGUSD,XAUUSD`

Whether the 5 pre-existing non-roster governed symbols/magics stay or are pruned is an
OWNER call for the profile/copy plan (F4), out of scope for this census.

## Blockers / caveats

1. **3 unverified symbols** (SP500, XNGUSD, EURGBP): to admit later, capture the real FTMO
   name read-only (Market Watch add + native `SymbolInfo` read, or a fill receipt) — do not
   guess US500.cash/NGAS.cash.
2. **US30.cash** verified only by alias registry, not by terminal data yet — will need
   Market Watch add before it trades (same as the DXZ D3 XAGUSD/WS30 pattern).
3. **1567** has no in-EA news filter (see above).
4. **News-capability + symbol-handling class are source-derived** (the sha-bound binary's
   build provenance is its identity; current tip source is the reference). No binary was
   recompiled to confirm the wired input.
5. **1537** carries a `trading_logic_literal` `"XAGUSD.DWX"` at
   `framework/EAs/QM5_1537_aa-vol-sma10/QM5_1537_MonthlySleeveCalendar.mqh:312`, but it is a
   calendar-bundle SHA guard keyed on the EA's **host-symbol input** (`QM1537_HostSymbol()`),
   documented at `QM5_1537_aa-vol-sma10.mq5:57-61` as the OWNER "symbols are inputs" pattern
   (set the input to `XAGUSD.DWX` on FTMO where the chart symbol is plain `XAGUSD`). It is
   **not** a blocking chart-symbol literal — 1537 stays ADMIT. Recorded in
   `symbol_handling_detail.trading_logic_literals`.
