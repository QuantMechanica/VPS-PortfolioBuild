# Multi-Symbol / Basket Machinery Recon (2026-07-27)

Cartography for the joint FTMO backtest-only EA design. **This is a map, not a
design.** Every claim below is anchored to `file:line` in the current tree
(branch `agents/board-advisor`, `C:\QM\repo`). Where a fact could not be
established from the code, it is marked **NOT ESTABLISHED**.

Author: Claude. Task: RECON 1 (multi-symbol machinery inventory).

---

## 0. TL;DR for the designer (facts only)

- The framework already runs **one EA instance, one `ea_id`, N legs, N distinct
  magics**. A basket EA attaches to ONE host chart, reads the other symbols with
  `CopyClose`/`iClose`, and opens/closes real positions on each `.DWX` leg via
  `QM_BasketOpenPosition(...)` (`framework/include/QM/QM_BasketOrder.mqh`).
- Per-leg magic = `ea_id*10000 + symbol_slot`. Each leg carries its own
  `symbol_slot`; each `(ea_id, symbol_slot)` MUST have a registered row in
  `framework/registry/magic_numbers.csv` or the order is rejected at runtime.
- Two distinct slot models exist in shipped code, and they are NOT
  interchangeable:
  - **symbol-pinned slot** (QM5_10024, QM5_1017): slot ↔ a fixed symbol; magic
    identifies *which symbol*.
  - **leg-position slot** (QM5_10718): slot ↔ leg index (1,2); the symbol on a
    leg rotates; magic identifies *which leg*, not which symbol.
  For a joint EA where each sleeve trades a FIXED symbol with its OWN strategy,
  the **symbol-pinned** model (10024 / 1017) is the relevant precedent.
- Q08/Q09 evidence for a basket is keyed on the **host symbol**, not the logical
  composite. `basket_manifest.json` declares `host_symbol` and the pipeline
  reads the TRADE_CLOSED / equity stream from the host-symbol file.
- **What does NOT exist**: any EA that dispatches a *different* strategy per
  symbol. Every shipped basket EA runs ONE shared signal (stat-arb / carry /
  cointegration) across its legs. A per-sleeve strategy dispatcher is
  **NOT ESTABLISHED** in the tree — see §6.
- The prop-firm phase layer (`QM_PropFirm.mqh`) exists and is account-level
  (equity/balance), independent of the basket machinery — see §3.5.

---

## 1. Existing multi-symbol / basket / cointegration EAs

### 1.1 Inventory (EAs shipping a `basket_manifest.json` under `framework/EAs/`)

Confirmed by `basket_manifest.json` presence:

| EA | slug | shape |
|---|---|---|
| QM5_1017 | chan_pairs_stat_arb | 2-leg cointegration pair (read in full) |
| QM5_1023 | chan-at-bb-pair | 2-leg BB pair (XTI/XAU) |
| QM5_1058 | gatev-fx-pairs-zscore | 2-leg z-score pair (EURUSD/GBPUSD) |
| QM5_10009 | rw-fx-cointeg-bb | 3-leg AUD/NZD/CAD cointegration |
| QM5_10024 | rw-fx-comm-basket | 4-leg fixed-weight stat-arb (read in full) |
| QM5_10309 | cointeg-hft-pairs | pair z (HFT) |
| QM5_10717 | edgelab-xsec-fx-momentum | FX8 cross-sectional (28-pair universe); "first V5 basket EA" |
| QM5_10718 | edgelab-regime-filtered-carry | FX8 regime-filtered carry (28-pair universe) (read in full) |

Additional shipped `QM_BasketOpenPosition` callers named authoritatively in the
code comment at `framework/include/QM/QM_BasketOrder.mqh:180-185`: `10009,
10025, 20123, 12821, 12778, 13117, 13140, 10309`. (QM5_10308 `hft-pairs-z`,
QM5_1067/1070 carver also match basket text but were not opened; their exact
shape is **NOT ESTABLISHED** here.)

I read three in full as the representative sub-patterns:

### 1.2 Fixed-weight multi-leg basket — QM5_10024 (`framework/EAs/QM5_10024_rw-fx-comm-basket/QM5_10024_rw-fx-comm-basket.mq5`)

This is the closest existing analogue to OWNER's "hardcode the .DWX symbols in
one EA" idea.

- **Symbol enumeration**: hardcoded arrays at `:48-49`:
  ```
  string g_leg_symbols[4] = {"AUDUSD.DWX","NZDUSD.DWX","USDCAD.DWX","AUDNZD.DWX"};
  int    g_leg_slots[4]   = {0, 1, 2, 3};
  ```
- **Dispatch**: single strategy (log-spread z-score). `OnTick` (`:441`) gates on
  `QM_IsNewBar`, refreshes shared state once per bar (`Strategy_RefreshState`,
  `:174`), then runs exit / entry. `Strategy_OpenBasket` (`:241`) loops all legs
  and opens each via `QM_BasketOpenPosition(qm_ea_id, ..., breq, ticket)`
  (`:289`). All legs open together; there is no per-symbol strategy branch.
- **Magic allocation**: per-leg. `breq.symbol_slot = g_leg_slots[leg]` (`:285`);
  the leg magic is resolved inside `QM_BasketOpenPosition` via
  `QM_MagicChecked(ea_id, req.symbol_slot, req.symbol)`
  (`QM_BasketOrder.mqh:138`). Registry rows: `magic_numbers.csv:1834-1837`
  map ea_id 10024 slots 0-3 to exactly AUDUSD/NZDUSD/USDCAD/AUDNZD — a clean 1:1
  slot↔symbol alignment with the EA arrays.
- **Per-symbol state**: none per symbol; state is basket-level scalars
  (`g_z_now`, `g_z_prev`, `g_spread_stdev`, `g_state_ready`, `:52-56`). Open-leg
  bookkeeping is done by scanning `PositionsTotal()` and matching magic:
  `Strategy_IsRegisteredBasketPosition` (`:189`) recomputes
  `QM_MagicChecked(qm_ea_id, g_leg_slots[leg], symbol)` and compares to
  `POSITION_MAGIC`.
- **Host/slot quirk (READ THIS)**: the EA only trades when the chart symbol's
  leg slot equals `qm_magic_slot_offset`: `Strategy_NoTradeFilter` (`:296`)
  returns "no-trade" unless `_Symbol` is a leg AND
  `qm_magic_slot_offset == g_leg_slots[leg]`. The shipped host set runs on
  AUDUSD.DWX with offset 0 (manifest `host_symbol: "AUDUSD.DWX"`). So exactly one
  chart instance drives the whole basket.

### 1.3 Cross-sectional rotating basket — QM5_10718 (`framework/EAs/QM5_10718_edgelab-regime-filtered-carry/QM5_10718_edgelab-regime-filtered-carry.mq5`)

- **Symbol enumeration**: three hardcoded const arrays — 8 currencies
  (`:60`), 28 `.DWX` pairs (`:64-72`), 7 USD pairs for the vol regime (`:75-77`).
  A helper `QM10718_FindPair(base,quote,...)` (`:87`) resolves a currency pair to
  its `.DWX` symbol and an `inverted` flag.
- **Dispatch**: single strategy. Weekly rebalance ranks the 8 currencies by carry
  and opens exactly TWO market-neutral legs (top-vs-bottom carry),
  `QM10718_Rebalance` (`:307`).
- **Magic allocation — LEG-POSITION model**: `const int QM10718_LEG_SLOT[2] =
  {1,2}` (`:81`), comment "Slot 0 is reserved for the framework identity magic;
  the two market-neutral legs use slots 1 and 2." The *symbol* on slot 1/2
  changes every rebalance; the magic identifies the LEG, not the symbol. Cleanup
  scans the magic RANGE `[base, base+9]`: `QM10718_CloseAll` (`:253-265`).
- **History preload**: `QM_SymbolGuardInit(basket_list)` +
  `QM_BasketWarmupHistory(basket_list, PERIOD_D1, 280)` in `OnInit` (`:371-375`).

### 1.4 Cointegration pair — QM5_1017 (`framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5`)

- **Symbol enumeration**: two `input string` symbols (`pair_symbol_1`,
  `pair_symbol_2`, `:25-26`) copied to `g_pair_symbols[2]` in `OnInit` (`:576`).
- **Slots — symbol-pinned, and they must match the registry**: `#define
  STRATEGY_PRIMARY_SLOT 4` / `STRATEGY_HEDGE_SLOT 26` (`:37-38`), comment "AUDUSD.DWX
  registry slot; NZDUSD.DWX uses slot 26". The registry confirms it:
  `magic_numbers.csv:445` = `1017,...,4,AUDUSD.DWX,10170004` and `:467` =
  `1017,...,26,NZDUSD.DWX,10170026`. ea_id 1017 has all 36 symbols registered
  (slots 0-35, alphabetical, `:441-476`); the EA hand-picks the two slots whose
  registry symbol matches its two legs. **This is the binding a joint EA must
  reproduce: each leg's `symbol_slot` constant must equal the `magic_numbers.csv`
  slot for that exact symbol under that `ea_id`.**
- **Dispatch / per-symbol state**: annual walk-forward fit of the cointegration
  model (`Strategy_FitModel`, `:219`; ADF t-stat + OU half-life); state in
  globals (`g_hedge_ratio`, `g_spread_mean`, `g_spread_stdev`, `g_z_now`,
  `:46-52`). `OnInit` hard-fails if either slot is not registered:
  `QM_MagicRegistered(qm_ea_id, STRATEGY_PRIMARY_SLOT/HEDGE_SLOT)` (`:592-594`).
- **Partial-fill discipline**: `Strategy_ManageOpenPosition` (`:530`) rolls the
  whole pair back if only one leg is open — a deliberate all-or-nothing guard.

### 1.5 The one thing none of them do

Every basket EA above runs a **single shared signal** across its legs. None
dispatches a different strategy per symbol. OWNER's joint-FTMO idea (9936:USDJPY
running its breakout, 13213:USDJPY running its rules, on ONE account) needs
per-sleeve strategy logic that is **NOT ESTABLISHED** in any shipped EA. See §6.

---

## 2. The `host_symbol` concept

### 2.1 Where it is defined

- **Manifest** (`framework/EAs/<ea>/basket_manifest.json`). Example
  `framework/EAs/QM5_10024_rw-fx-comm-basket/basket_manifest.json`:
  ```json
  {"logical_symbol":"QM5_10024_RW_FX_COMM_BASKET_D1",
   "host_symbol":"AUDUSD.DWX","host_timeframe":"D1",
   "basket_symbols":["AUDUSD.DWX","NZDUSD.DWX","USDCAD.DWX","AUDNZD.DWX"], ...}
  ```
- **Work-item payload**. `farmctl.py` writes basket work items with payload keys
  `host_symbol`, `host_timeframe`, `logical_symbol`, `basket_symbols`,
  `basket_symbol_count`, `portfolio_scope:"basket"`
  (`tools/strategy_farm/farmctl.py:4953-4999`, `BASKET_CONTEXT_PAYLOAD_KEYS`).
- **In the EA binary**: `host_symbol` is not a variable — it is the physical
  chart symbol the tester runs on. `_Symbol` inside a basket EA equals the host
  symbol; the EA's own logs stamp it (`QM_BasketOrder.mqh:94,283` write
  `"host_symbol":"<_Symbol>"`).
- **In set files**: the runner reads a `; host_symbol:` header line from the
  `.set` to resolve the basket (see Q08/Q09 usage below).

### 2.2 What Q08 (and Q09) do with it

- **Runner target selection**: when a work item is a basket (logical symbol),
  `farmctl` swaps the *runner* symbol/timeframe to the manifest's
  `host_symbol`/`host_timeframe` before launching the tester
  (`farmctl.py:3348-3354` and `:4091-4112`): if the work-item symbol equals the
  logical symbol and the manifest matches, `runner_symbol =
  basket_manifest["host_symbol"]`.
- **Stream resolution**: the tester writes TRADE_CLOSED / equity to a file keyed
  on `_Symbol` = host symbol (`Common\Files\QM\q08_trades\<ea_id>_<HOST>.jsonl`),
  NOT the logical composite. `aggregate.py` resolves the host path from the
  setfile and falls back to it when the logical-named stream is empty
  (`docs/ops/evidence/q08_basket_host_sym_stream_fix_2026-07-05.md`).
- **Symbol set for the phase**: `_basket_symbol_set(...)` marks an item as basket
  when `portfolio_scope=="basket"` OR payload has `host_symbol` OR the manifest
  `logical_symbol` matches, then returns the full member list
  (`farmctl.py:5135-5160`).
- **Q09 (portfolio)**: the same host-symbol aliasing lives in the shared
  `portfolio_common.load_streams()` choke point; a logical basket candidate is
  resolved to the host-keyed stream via `resolve_basket_stream_key()` scanning
  `; host_symbol:` in the setfiles, with a "newer file wins" rule between a
  durable logical stream and a volatile host stream
  (`docs/ops/evidence/b4e2a62b_q09_basket_host_symbol_review_2026-07-07.md`).

### 2.3 What breaks without it

- **`trades=0` → `INVALID` / `INFRA_FAIL`.** Documented root cause: for a basket
  EA the aggregator looked for a logical-composite stream file that never exists,
  because the EA emitted under the host symbol. Result:
  `verdict_reason=phase_runner_invalid_report`, `trades=0`, `equity_snaps=0`
  (`docs/ops/evidence/q08_basket_host_sym_stream_fix_2026-07-05.md:9-55`).
- **Q09 silent sleeve drop / `trade_count=0`** without the aliasing
  (`b4e2a62b...:23`).
- **RAM-guard mis-classification** if the payload lacks the basket markers — the
  worker would treat a 28-symbol load as a single-symbol run (see §5.1).

Governance note: `decisions/2026-07-15_multicurrency_logical_basket_workitem.md`
ratifies "exactly ONE logical work item per basket EA per phase; per-pair Q02+
fan-out is FORBIDDEN for basket-class EAs" and requires the EA ship
`basket_manifest.json` + register in `multisymbol_eas.txt`.

---

## 3. Framework helpers that already support several symbols in one EA

### 3.1 Basket order path — `framework/include/QM/QM_BasketOrder.mqh`

- `struct QM_BasketOrderRequest` (`:14-25`): `symbol`, `type`, `price`, `sl`,
  `tp`, `lots`, `reason`, **`symbol_slot`**, `expiration_seconds`.
- `QM_BasketOpenPosition(ea_id, news_mode, deviation, req, out_ticket)` (`:106`):
  the single per-leg entry point. In order it checks kill-switch (`:120`), news
  for `req.symbol` (`:126`), resolves the per-leg magic
  `QM_MagicChecked(ea_id, req.symbol_slot, req.symbol)` (`:138`), rejects a
  duplicate same-magic-same-symbol position (`:147`), applies the Q06 stress
  reject (memoized once per basket transaction, `:211-230`), sizes lots via
  `QM_LotsForRisk` if `req.lots<=0` (`:243`), and sends through
  `QM_TradeContextSend`.
- **Stress-reject granularity is per-basket, not per-leg** — memoized on
  `(ea_id, TimeCurrent())` (`:191-223`). The long comment `:153-210` is
  load-bearing: it assumes every basket caller opens ALL its legs inside ONE
  `OnTick`. A joint EA that opened legs across multiple ticks/bars would break
  that assumption; the comment names the exact callers it was verified against.

### 3.2 Equity-stop / ownership scan — `framework/include/QM/QM_BasketEquityStop.mqh`

- Basket-wide floating-PnL stop and take-profit that scans `PositionsTotal()` and
  keeps only positions this framework instance owns via
  `QM_FrameworkOwnsMagicSymbol(magic, symbol)` (`:45-111`). `_Enforce` (`:113`)
  and `_EnforceUnitsPerLot` (`:148`) close all owned legs on breach. This is an
  in-EA, basket-level equity guard (distinct from the account-level prop guard,
  §3.5).

### 3.3 Ownership resolver — `framework/include/QM/QM_Common.mqh`

- `QM_FrameworkOwnsMagicSymbol(magic, symbol)` (`:400-432`): true if magic is the
  host identity magic, OR a registered `(ea_id, slot)` context whose symbol
  matches, OR (basket mode only) magic falls in `[ea_id*10000,
  ea_id*10000+QM_MAGIC_SLOT_MAX]`, the slot is registered, AND the symbol is in
  the guard's allowed set. **Basket ownership only works when the symbol guard is
  in basket mode** (`QM_SymbolGuardIsBasket()`), i.e. `QM_SymbolGuardInit(list)`
  was called with >1 symbol.
- `QM_MagicFor(ea_id, slot)` (`:340-377`) records per-(magic,symbol) contexts and
  registers each with the kill switch — the mechanism that lets one EA own many
  magics.

### 3.4 Symbol guard + history preload — `framework/include/QM/QM_SymbolGuard.mqh`

- `QM_SymbolGuardInitSingle()` (`:46`) — the default; allowed set = `{_Symbol}`.
  `QM_FrameworkInit` calls it (`QM_Common.mqh:169`).
- `QM_SymbolGuardInit(const string &allowed[])` (`:57`) — basket opt-in; sets
  `g_qm_sg_is_basket = (n>1)` (`:65`). MUST be called AFTER `QM_FrameworkInit`
  (comment `:14-16`).
- `QM_BasketWarmupHistory(symbols, tf, warmup_bars)` (`:112`) — forces the tester
  to load each symbol's history via a throwaway `CopyClose`. Without it, basket
  EAs `fast-finish` with `NO_REAL_TICKS_MARKER_FAST_FINISH → INVALID` because
  `SymbolSelect` alone does not load tester history (comment `:100-108`). This is
  a REQUIRED call for any multi-symbol EA.
- `QM_SymbolAssertOrLog(symbol)` (`:146`) — throttled `SYMBOL_GUARD_VIOLATION`
  log; it does NOT block the MT5 data call, only surfaces it.

### 3.5 Risk sizer — account vs symbol — `framework/include/QM/QM_RiskSizer.mqh`

- `QM_LotsForRisk(symbol, sl_points)` (`:393`, plus overloads at `:450`, `:503`):
  sizes a per-SYMBOL lot from a risk-money budget and that symbol's tick
  value/volume constraints (`QM_SymbolRiskSnapshot`). The risk BUDGET is
  account-level; the lot QUANTIZATION is per-symbol.
- Per-trade cap: `QM_FrameworkSetRiskCapPct(cap_pct)` (`QM_Common.mqh:315-330`) —
  hard bounds `(0, 5.0]`; `cap_pct` above 5.0 or ≤0 returns false. The 5.0
  ceiling is OWNER-ratified and **must not be raised**. `cap_money =
  equity * cap_pct/100` and `QM_RiskSizerSetCapPct` is the PERCENT-mode rail.
  (Note: the `315` line here is the cap SETTER; the HARD-RULES constant reference
  in the task brief cites the same ceiling.)

### 3.6 News filter and the `symbol_slot` hazard — `framework/include/QM/QM_NewsFilter.mqh`

- The news filter is queried **per symbol string**, not per slot:
  `QM_NewsAllowsTrade2(symbol, utc, temporal, compliance)` and
  `QM_NewsAllowsTrade(symbol, utc, mode)`. Basket EAs call it per leg — e.g.
  QM5_10024 `Strategy_CheckAllNews` loops all legs (`:383-397`), QM5_1017
  `Strategy_NewsAllowsPair` loops both legs (`:385-391`).
- Index/CFD symbols map to their economy's currency for news via
  `QM_NewsIndexCurrencies` (`:317-337`) — e.g. NDX/SP500/WS30 → USD, GDAXI/GER40
  → EUR, JP225 → JPY. USDJPY resolves to base/quote USD+JPY (`:360-372`).
- **The `symbol_slot` hazard is NOT in the news filter itself.** `symbol_slot`
  lives on the order-request structs (`QM_EntryRequest.symbol_slot`
  `QM_Entry.mqh:20`; `QM_BasketOrderRequest.symbol_slot`
  `QM_BasketOrder.mqh:23`). MQL5 does NOT zero local structs, so an EA that
  reads an order request without setting `symbol_slot` sends stack garbage into
  `QM_MagicChecked(...)` → wrong/invalid magic. The fix shipped for the
  single-symbol path is the `QM_EntryRequest()` default ctor that sets
  `symbol_slot=0` (`QM_Entry.mqh:23-37`, "silent-zero-trades incident
  9e4cfedb1"). **`QM_BasketOrderRequest` has NO such default ctor**
  (`QM_BasketOrder.mqh:14-25` is a bare struct) — so a basket/joint EA MUST set
  `req.symbol_slot` explicitly for every leg (all shipped basket EAs do:
  10024`:285`, 1017`:440`, 10718`:296`). A joint EA that forgets this on any leg
  gets an undefined slot → `QM_BASKET_REJECTED_BROKER / magic_resolution_failed`
  or a cross-sleeve magic collision.

### 3.7 Prop-firm phase layer — `framework/include/QM/QM_PropFirm.mqh`

Account-level, symbol-agnostic; composes on top of the basket machinery.

- `enum QM_PropPhase { OFF=0, PHASE_1=1, PHASE_2=2, FUNDED=3 }` (`:120-126`).
  `prop_phase` is the sole selector (`:129`).
- Derived: `QM_PropTargetPct()` = 10 / 5 / 0 (`:171-181`); `QM_PropFlattenEnabled()`
  true only for PHASE_1/2 (`:185-188`).
- `QM_PropEntryAllowed(magic)` (`:540`): flattens on the **equity** trip
  (`ACCOUNT_EQUITY >= start*(1+target%)`) via `QM_PropFlattenAll(magic,...)`, then
  latches "won" only on realised **balance** ≥ target (review H4, `:577-601`).
  `magic==0` flattens ALL positions; a specific magic flattens only that magic —
  relevant to how a joint EA would flatten a whole account vs one sleeve.
- Cap validators (call in `OnInit` BEFORE `QM_FrameworkSetRiskCapPct`):
  `QM_PropPhaseValidateCap` (`:202`) — sprint phases refuse `cap==1.0` default
  unless `prop_allow_unit_risk` (H2), refuse a >1.0 cap without
  `prop_expected_login` when live (Finding 1), WARN above 4.0 (M2); FUNDED band
  `(0,1.0]`. `QM_PropPhaseValidateWeekend` (`:283`).
- State persists per `(ea_id, login, server)` under `FILE_COMMON`
  (`:362-409`) — one EA on two accounts is namespaced.
- **Wiring gap flagged in-file**: `QM_PropRiskBasis` is defined but NOT wired
  into `QM_Entry` sizing (`:481-491`, review L2); prop sizing still sizes off
  live equity. This is a documented known-incomplete, not a thing to rely on.

---

## 4. The magic-number registry

### 4.1 Format — `framework/registry/magic_numbers.csv`

Header (`:1`): `ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status`.
One row per `(ea_id, symbol_slot, symbol)`. `magic = ea_id*10000 + symbol_slot`
(e.g. `1017,...,26,NZDUSD.DWX,10170026`, `:467`).

### 4.2 Allocation formula and runtime verification

- Formula: `QM_Magic(ea_id, symbol_slot)` = `(long)ea_id*10000 + symbol_slot`,
  with `ea_id ∈ [QM_MAGIC_EA_ID_MIN, MAX]`, `slot ∈ [QM_MAGIC_SLOT_MIN,
  QM_MAGIC_SLOT_MAX]`, result must fit int32
  (`framework/include/QM/QM_MagicResolver.mqh:24-73`).
- `QM_MagicRegistered(ea_id, slot)` (`:75-92`) linear-scans the GENERATED arrays
  `QM_MAGIC_REG_EA_ID/SLOT/MAGIC[]` and returns true only if the row exists AND
  `QM_MAGIC_REG_MAGIC[i]==computed`. (The 511KB / ~350k-token size of
  `QM_MagicResolver.mqh` is this generated row table — do not `Read` it whole.)
- `QM_MagicChecked(ea_id, slot, expected_symbol)` (`:145-172`) = `QM_Magic` +
  `QM_MagicRegistered` + `QM_MagicCollisionWithForeignOpenPositions`. The
  collision check (`:99-143`) rejects if an open position with the SAME magic
  exists on a DIFFERENT symbol than `expected_symbol`. **Note: it does NOT verify
  that the registry row's `symbol` column matches `expected_symbol`** — the
  runtime binding that matters is `(ea_id, slot) → magic`; the CSV `symbol`
  column is allocation/audit metadata. Keeping leg symbol ↔ slot consistent is a
  build-time discipline, not a runtime check.
- `QM_MagicRegistryHash()` = `QM_MAGIC_REGISTRY_SHA256` (`:94-97`) — the
  generated table's fingerprint.

### 4.3 Order-of-operations for registering new magics

From the build prompt `tools/strategy_farm/prompts/codex_build_ea.md` (steps
`:495-516`) and Operating Rules (dirs → CSV → regen → verify → compile):

1. Reserve the `ea_id` row in `framework/registry/ea_id_registry.csv` if absent
   (`:495-496`).
2. For each target symbol reserve a slot in `magic_numbers.csv`, one row per
   `(ea_id, symbol, magic)`; **HARD ABORT on collision** (`:498-501`). HR5 =
   collision is a hard abort (`:44-45`).
3. **Before registering any symbol, verify it appears in
   `framework/registry/dwx_symbol_matrix.csv`** — the matrix is authoritative for
   tradability; never register a symbol not in it (`:82-108`). Tradability is
   checked against the matrix, never against notes (memory:
   `reference_dwx_sp500_unavailable`).
4. **Regenerate** `QM_MagicResolver.mqh` via
   `python C:\QM\repo\framework\scripts\update_magic_resolver.py` — the ONLY
   sanctioned mutation path; DO NOT hand-edit the `.mqh` (`:503-514`). It rewrites
   the row table, bumps `QM_MAGIC_REGISTRY_ROWS`, updates the SHA256.
5. Then create the EA dir / compile. Rule: **dirs → CSV → regen → verify →
   compile** (Operating Rules 2026-07-03).

Additional binding rule: magic-resolver regen / builds run **serially** (memory:
magic-resolver race 06-30; duplicate-build-dispatch 07-05/14 — before any
rebuild, grep `^<bare_id>,` and confirm `status=active`).

---

## 5. Known hazards that specifically bite multi-symbol EAs

### 5.1 RAM / launch_fault — 28-symbol loads are the 20-44GB class; test SERIALLY

- `decisions/2026-07-15_multicurrency_logical_basket_workitem.md:28-29`: "28-symbol
  loads are the 20-44GB class — test SERIALLY, never several concurrently →
  launch_fault wedge." Register the EA in `multisymbol_eas.txt`.
- Runtime enforcement: `tools/strategy_farm/terminal_worker.py:437`
  `MULTISYMBOL_REGISTRY_PATH = D:/QM/strategy_farm/state/multisymbol_eas.txt`
  (a runtime hint; NOT in the repo — file not found in tree, lives on the VPS).
  `_work_item_is_multisymbol(...)` (`:504-527`) treats an item as multi-symbol
  when `ea_id ∈ multisym_ids` OR payload `portfolio_scope=="basket"` OR
  `basket_manifest` present OR `basket_symbol_count > 1`. Build-time payload
  markers are authoritative even if the hint file is stale. A joint FTMO EA MUST
  carry those markers or the worker will not serialize/RAM-guard it.
- VPS ceiling: 8 cores / 63GB with a `ram_low_pause` throttle (task brief +
  memory `VPS ceilings 8c/63GB`).

### 5.2 host_symbol stream mismatch → trades=0 / INVALID / INFRA_FAIL

Covered in §2.3. Primary evidence:
`docs/ops/evidence/q08_basket_host_sym_stream_fix_2026-07-05.md` and
`docs/ops/evidence/b4e2a62b_q09_basket_host_symbol_review_2026-07-07.md`.
Related basket-Q08 incident docs in the same folder:
`12772_q08_basket_stream_diag_2026-07-05.md`,
`q08_basket_timeout_fix_2026-07-05.md`,
`q08_basket_host_log_deletion_loop_2026-07-05.md`.

### 5.3 Uninitialised `symbol_slot` → wrong magic (silent zero-trades class)

Covered in §3.6. `QM_BasketOrderRequest` has no default ctor; every leg must set
`symbol_slot`. Root-class incident: silent-zero-trades 9e4cfedb1 (fixed for
`QM_EntryRequest` at `QM_Entry.mqh:23-37`). Also memory
`project_qm_news_filter_index_defect_2026-07-05` ("agent EAs MUST set symbol_slot
or ZeroMemory the struct").

### 5.4 Basket history not loaded → fast-finish / NO_REAL_TICKS → INVALID

`SymbolSelect` alone does not load tester history; `QM_BasketWarmupHistory` must
be called after `QM_SymbolGuardInit` (`QM_SymbolGuard.mqh:100-141`). Also the
raw-symbol currency-lookup defect on JPY/CHF/CAD cross legs required a recompile
(`decisions/2026-07-15...:49-50`, cross-ref
`project_qm_infra_hardcore_three_causes_2026-07-14`).

### 5.5 Q06 stress reject assumes all legs open in ONE OnTick

`QM_BasketOrder.mqh:153-210`. The memoized-per-basket stress draw is only
correct if every leg of a logical entry opens inside a single `OnTick` (same
`TimeCurrent()`). A joint EA that staggers leg entries across ticks/bars would
either under- or over-reject under Q06/Q07. The comment enumerates the exact
callers it was verified against.

### 5.6 Partial-fill / single-leg exposure

QM5_1017 rolls the whole pair back if only one leg is open
(`Strategy_ManageOpenPosition:530-537`, `Strategy_ExitSignal:544-548`). QM5_10024
opens legs on a best-effort `any_opened` loop (`:250-291`) with no rollback — a
documented "any-open" caller class (`QM_BasketOrder.mqh:169-176`). A joint EA
must decide its own partial-fill policy; the framework does not impose one.

### 5.7 Slot↔symbol drift between EA constants and the registry

Because the runtime magic check keys on `(ea_id, slot)` and does NOT verify the
registry's `symbol` column (§4.2), a joint EA whose hardcoded leg `symbol_slot`
constants drift from the `magic_numbers.csv` rows will still resolve a magic — it
will just be the WRONG symbol's magic, silently. QM5_1017 defends with
`QM_MagicRegistered` asserts in `OnInit` (`:592-594`); a joint EA should do the
same per leg.

---

## 6. Explicit gaps (NOT ESTABLISHED — for the designer, not designed here)

- **Per-symbol strategy dispatch**: no shipped EA runs a *different* strategy per
  leg. All run one shared signal. Whether the `framework/include/QM/modules/`
  plug-in modules (`QM_Mod_*.mqh`, each sets `req.symbol_slot=0`,
  single-host-slot) can be composed multiple-per-EA is **NOT ESTABLISHED** — the
  ones seen are single-strategy hosts.
- **Intraday joint equity path in the tester as consumed by the pipeline**: a
  joint EA on one host chart WILL produce a single real account-equity path in
  MT5, but whether Q08/Q09 aggregation reads intratrade equity (vs TRADE_CLOSED
  snapshots) for a joint host is **NOT ESTABLISHED** here — it is exactly the gap
  the task cites (`a5768d03_equity_export_gap_2026-07-27.md`). Recon only; not
  resolved.
- **`multisymbol_eas.txt` current contents**: the file is runtime-only
  (`D:/QM/strategy_farm/state/...`), not in the repo; its current EA list was not
  read.
- **QM5_10308 / 1067 / 1070 exact shapes**: inventoried by basket-text match
  only, not opened.
