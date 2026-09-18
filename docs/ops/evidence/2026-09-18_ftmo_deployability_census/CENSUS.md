# FTMO demo book deployability census — Q14-terminal qualified pool

Task `d33ec32e-9ac3-413b-801b-c5c124a2d351`. No MT5 process, chart, terminal file, or
AutoTrading state was touched. No source, registry, or set file was changed. Fable
executes any resulting change; this document proposes, it does not authorise.

**Scope note — concurrent work.** Commit `e0ba9fc32701` (2026-09-18T01:39:58Z, Claude
Fable 5.1, `feat(ftmo): roster-driven demo trial presets + package installer + governor
magic rebind + NDX alias + attached-dark flag`) landed 7 minutes after this task was
routed to me. It already closes `GAPS.md` G1, G3, G7 and G4.2 from
`docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/GAPS.md`: a roster-driven
`trial_setpath --roster` that rebinds bare-venue symbol inputs and refuses (rather than
silently darkening) an unmapped slot, a generalised `demo_install --package`, a
`governor_rebind` tool, a `US100 -> NDX` alias in `QM_MagicSymbolCanonical`, and
`demo_cycle.flag_attached_dark`. This census takes that tooling as given and supplies
what it did not itself produce: a full 26-sleeve sweep of the qualified pool (not just
the 8 `R2_capped` candidates) and a fix classification per sleeve.

---

## 1. Confirmation: 20048 and 13054 never opened (direct log evidence)

Read directly from the FTMO-Demo terminal's per-EA logs (not carried over from a prior
report):

| EA | log file | INIT_OK | TM_OPEN | ENTRY_ACCEPTED | last event (UTC) |
|---|---|--:|--:|--:|---|
| `QM5_20048_wti-preholiday` | `QM5_20048_ea-20048.log` | 5 | **0** | **0** | 2026-09-11T19:49:52.796Z |
| `QM5_13054_brent-tom-mom` | `QM5_13054_ea-13054.log` | 5 | **0** | **0** | 2026-09-11T19:49:53.578Z |

Confirmed. Both sleeves have initialised cleanly five times since 2026-09-11 and placed
zero orders. `20048`'s cause is a hardcoded `_Symbol != "XTIUSD.DWX"` gate
(`QM5_20048_wti-preholiday.mq5:143-147`). `13054`'s cause is different in kind: an
`input string strategy_host_symbol = "XTIUSD.DWX"` (line 47) left at its factory default
by the installed preset — no source literal blocks it, only the derivation.

The production ledger (`D:\QM\reports\state\ftmo_demo_cycle.json`, generated
2026-09-18T01:52:01Z, read-only) already carries the new `attached_dark` field for both
rows: `placements_observed=0`, `trading_days_observed=3`, `attached_dark=false`. That is
correct, not a bug — the default threshold is `DARK_AFTER_TRADING_DAYS=5`, and 3 has not
crossed it yet. It will within roughly two more trading days if left unfixed. Requirement
(4) — "demo_cycle should treat attached-but-never-trading as a material defect" — is
**already implemented** (`tools/strategy_farm/ftmo/demo_cycle.py:flag_attached_dark`,
same commit above); nothing further is needed from this task on that point.

---

## 2. Full qualified-pool sweep (26 sleeves)

Scope: `qualified_pool.pairs` in
`D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot\manifest.json`
(definition: contiguous Q02..terminal-gate PASS-class, `book_build_guard` predicate A).
Full detail and per-line source citations in `census.json`.

### Class definitions (the read-model)

| class | meaning | smallest fix |
|---|---|---|
| **A_DEPLOYABLE** | No symbol literal in trading logic; venue base name equals registry base name (or already live). | None — deploy via the roster-driven `trial_setpath` + `governor_rebind` tooling already in repo. |
| **B_INPUT_DEFAULT** | Symbol is a plain `input string strategy_..._symbol`, no hardcoded gate. | Include the row in the `--roster`; `trial_setpath.rebind_symbol_inputs()` rewrites the input to the venue name. No rebuild, no new identity. |
| **C_ALIAS_GAP** | No symbol literal, but the registry symbol is an index whose FTMO base name differs (`US30.cash`/`GER40.cash` vs `WS30`/`GDAXI`), and `QM_MagicSymbolCanonical()` has no alias for that pair (or has one but the binary predates it). | Add the missing base-pair alias to `QM_MagicSymbolCanonical()` (**ROT — registry/identity decision, OWNER-only**) and recompile the affected EA(s). No trading-logic change. |
| **D_SOURCE_LITERAL** | Hardcoded exact-string comparison against a `.DWX` name gates trading logic directly. | Rebuild against the OWNER 2026-09-06 symbol-as-input rule — **new identity, re-enters Q02** per company policy. Cheaper deployment-only alternative: drop/substitute the sleeve (OWNER roster decision). |

### Table

| ea_id | EA | registry symbol | FTMO venue symbol | class | note |
|--:|---|---|---|---|---|
| 1537 | aa-vol-sma10 | XAGUSD.DWX | XAGUSD | A | 1 literal is a data-integrity guard, not a trade gate (see §3) |
| 9641 | bandy-cci-extreme-fade-mr-index | WS30.DWX | US30.cash | **C** | needs `US30<->WS30` alias (does not exist yet) |
| 10145 | tsm-meanret | XAUUSD.DWX | XAUUSD | A | R2 sleeve #6, VERIFIED |
| 10403 | et-turtle20x | XAUUSD.DWX | XAUUSD | A | |
| 10513 | mql5-ichimoku | XAUUSD.DWX | XAUUSD | A | |
| 10700 | tv-liq-break | XAUUSD.DWX | XAUUSD | A | R2 sleeve #3, VERIFIED |
| 10706 | tv-mon-ls | GBPUSD.DWX | GBPUSD | A | live, trading |
| 11421 | ohlc-daily-squeeze-reversal-d1 | EURUSD.DWX | EURUSD | A | live (R0), trading |
| 11422 | williams-18ma-outside-bar-entry-d1 | USDCAD.DWX | USDCAD | A | live, trading; alias-registry hygiene gap only (G6) |
| 11660 | pp-wedge | NDX.DWX | US100.cash | **D** | exact-literal gate; alias exists in header but binary predates it and the gate is separate anyway |
| 11708 | anon-market-squeeze-d1 | EURUSD.DWX | EURUSD | A | |
| **11881** | **connors-rsi2-mean-reversion** | GBPUSD.DWX | GBPUSD | **D** | **new finding** — exact-literal 12-symbol table, slot 1 = `GBPUSD.DWX` |
| 11910 | larry-williams-18ma-2outside-bars-d1 | NZDUSD.DWX | NZDUSD | A | live (R0); zero recent placements is a signal gap, not a symbol gate |
| 12710 | commodity-tsmom-12m-atr | XTIUSD.DWX | USOIL.cash | **D** | exact-literal gate; also Q08 FAIL_SOFT stream |
| **12849** | **brent-tsmom12m** | XTIUSD.DWX | USOIL.cash | **D** | **new finding** — exact-literal gate |
| **12855** | **brent-nov-fade** | XTIUSD.DWX | USOIL.cash | **D** | **new finding** — exact-literal gate |
| 13013 | grimes-trendday-v2 | NDX.DWX | US100.cash | **C** | cleanest NDX sleeve — literal-free, only needs recompile for the alias that already exists |
| 13054 | brent-tom-mom | XTIUSD.DWX | USOIL.cash | **B** | confirmed dark today (§1) |
| 13213 | balke-gmt3-range-breakout | USDJPY.DWX | USDJPY | A | R2 sleeve #1, VERIFIED |
| 20048 | wti-preholiday | XTIUSD.DWX | USOIL.cash | **D** | confirmed dark today (§1) |
| 20266 | collins-66mom | XTIUSD.DWX | USOIL.cash | **D** | exact-literal gate |
| 21501 | balke-gmt3-range-breakout-ppcensus | USDJPY.DWX | USDJPY | A | |
| 21505 | xag-weekly-lowvol-momentum | XAGUSD.DWX | XAGUSD | **B** | attached (R0), 0 placements/3 trading days — consistent with input-default darkness |
| **21507** | **qs-kama-trend-xau** | XAUUSD.DWX | XAUUSD | **D** | **new finding** — exact-literal gate on both entry and exit paths |
| 41219 | cum-rsi2-commodity-requal8 | XAUUSD.DWX | XAUUSD | A | |
| 41221 | ohlc-daily-squeeze-reversal-d1-requal8 | EURUSD.DWX | EURUSD | A | |

**Class counts: A=16, B=2, C=2, D=8.**

Eight of 26 qualified-pool sleeves (31%) are source-literal-gated. Four of those eight
(`11881`, `12849`, `12855`, `21507`) were **not** previously documented in
`GAPS.md`/`PACKAGE.md`, which only examined the 8 `R2_capped` candidates plus the 2
already-dark R0 sleeves. This changes the denominator for future roster construction:
literal-gating is a broad pre-2026-09-06 construction pattern across this pool's
commodity and index sleeves (and now confirmed on two of three metals/majors sleeves
too, `11881` GBPUSD and `21507` XAUUSD), not a narrow three-EA exception.

---

## 3. The `1537` false positive, checked

`ea_symbol_literal_inventory.py` flags one `trading_logic_literal` at
`QM5_1537_MonthlySleeveCalendar.mqh:312`:

```mql5
if(host_name == "XAGUSD.DWX" && month_key >= 202501 &&
   bundle_sha != expected_bundle_sha)
  {
   FileClose(handle);
   return QM1537_CalendarFail("runtime_calendar_native_row_bundle_mismatch");
  }
```

`host_name` is the runtime chart symbol, and the branch is a data-integrity check for one
specific known-corrupted history bundle, additionally gated on `month_key >= 202501`. On
any symbol other than exactly `"XAGUSD.DWX"` — including FTMO's bare `"XAGUSD"` — the
branch does not fire; it neither blocks trading nor silently no-ops the strategy. Recorded
as A_DEPLOYABLE, not D, with this note attached so the classification isn't taken as an
unverified scanner pass-through.

---

## 4. The `C_ALIAS_GAP` sleeves in detail

`QM_MagicSymbolCanonical()` (`framework/include/QM/QM_MagicResolver.mqh:139-146`) is
called from every EA's `OnInit` via `QM_MagicChecked(ea_id, slot, _Symbol)`
(`QM_Common.mqh:273`), so its alias table gates **all** EAs, not just the ones with
hardcoded literals. Today it has exactly two base-pair aliases:

```
USOIL -> XTIUSD   (pre-existing)
US100 -> NDX      (added 2026-09-18T01:39:58Z, commit e0ba9fc32701)
```

`execution_symbol_aliases_v1.json` (the venue/qualification-evidence registry, a
*different* artifact used for symbol-existence probing, not runtime enforcement) already
lists `GER40.cash -> GDAXI.DWX` and `US30.cash -> WS30.DWX` for the `FTMO_TRIAL` venue —
so the evidence that these venue names exist and map correctly is already on file. The
gap is specifically in the **enforcement-time** canonicalisation function, which has no
`US30 <-> WS30` or `GER40 <-> GDAXI` pair. Consequence for this pool: `9641` (WS30.DWX,
literal-free) is blocked by this gap alone. No sleeve in this pool is GDAXI-registered, so
that half of the gap is inert for now but will bite the next GDAXI-registered admission.

`13013` (NDX.DWX, literal-free) is the cleanest sleeve to unblock: the alias it needs
already exists in the header (as of today), and its canonical `.ex5` (mtime 2026-08-03)
simply predates the change and needs a recompile — no source or registry work at all.
`11660` needs the same recompile for the alias but remains dark regardless because its
literal gate is a separate, independent blocker (Class D dominates).

---

## 5. Proposed smallest fix per class (summary)

1. **A_DEPLOYABLE (16 sleeves):** no fix needed. Deployable via the `trial_setpath
   --roster` + `governor_rebind` path from `e0ba9fc32701` whenever OWNER selects a
   roster.
2. **B_INPUT_DEFAULT (`13054`, `21505`):** include both rows in the next `--roster`
   derivation so `trial_setpath.rebind_symbol_inputs()` rewrites `strategy_host_symbol`
   to the venue name. Zero rebuild, zero new identity, cheapest fix in this census.
3. **C_ALIAS_GAP (`9641`, `13013`):** OWNER decision to add `US30<->WS30` to
   `QM_MagicSymbolCanonical()` (ROT-class per Hard Rules and the 2026-09-15 census's
   reasoning on the NDX case), then recompile `9641` and `13013` (and `11660`, though it
   stays dark until its literal is also fixed). No trading-logic change for any of the
   three.
4. **D_SOURCE_LITERAL (8 sleeves: `11660`, `11881`, `12710`, `12849`, `12855`, `20048`,
   `20266`, `21507`):** per company policy, a source rewrite to the OWNER symbol-as-input
   rule is a new binary identity and must re-enter the pipeline at Q02 — it is not a
   deployment-time fix and cannot be a precondition for the current book. The
   deployment-time alternative is to exclude these 8 from any FTMO roster until rebuilt
   and re-qualified; `PACKAGE.md` option 1/2 (drop or substitute) already covers this for
   the 3 that were in `R2_capped`, and this census extends the same treatment to the
   other 5.

---

## 6. Files

| file | contents |
|---|---|
| `CENSUS.md` | this document |
| `census.json` | machine-readable read-model, schema `qm.ftmo-deployability-census/v1`, all 26 rows with source citations |
