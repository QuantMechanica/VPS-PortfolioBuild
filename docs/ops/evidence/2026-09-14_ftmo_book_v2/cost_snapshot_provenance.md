# FTMO cost/swap snapshot refresh — provenance audit + gap report

Ticket `ac25ebea-9ad3-45e9-b213-c324987eb0ee`, item (1). Read-only: no DB write, no
terminal, no freeze change, no invented costs.

## The ticket's premise, corrected

The ticket asks to refresh `tools/strategy_farm/portfolio/build_book_ftmo.py`'s
`EXPECTED_COST_SNAPSHOT_SHA256` pin "from the native FTMO-Demo specifications captured
2026-09-06 (Track B)". Investigated directly (background research, not assumed):

- **What was actually captured 2026-09-06**:
  `docs/ops/evidence/2026-09-06_ftmo_demo_install/terminal_snapshot.json` — real,
  read-only native MT5 IPC data (login 1514536732, server FTMO-Demo), but only for 8
  symbols (`XAUUSD, GER40.cash, GBPUSD, EURUSD, USDCAD, NZDUSD, USOIL.cash, XAGUSD`), and
  only `digits/contract_size/currency_profit/swap_long/swap_short/swap_triple_day`. The
  file states outright: `"commission_contract": "NOT_EXPOSED_BY_SYMBOL_INFO"` — **no
  commission field exists in this capture at all**, and no lot/tick/margin fields either.
- **"Track B"** is not a 2026-09-06 thing. It is one of four workstreams
  (`FTMO_ACCELERATION_20260909`, program started 2026-09-09) — Track B =
  cost/shortlist, task `54729be7`, output `docs/ops/evidence/2026-09-09_ftmo_shortlist/`.
  Track B's own review explicitly *reuses* the 2026-09-06 capture and says it is
  insufficient: *"The September 6 receipt has contract size, digits, profit currency,
  long/short swap and triple day; it does not contain those missing lot/tick/margin
  fields. Do not infer them."* Track B's selected roster was **zero** as of its most
  recent evidence (2026-09-12).
- A **second, narrower** native follow-up on 2026-09-12
  (`docs/ops/evidence/2026-09-12_ftmo_native_cost_receipts/`) captured **real realised
  commission** for exactly 2 symbols (GBPUSD, EURUSD; ~5.01–5.03 USD/lot round trip from
  actual fills) — USDCAD had a cancelled pending order (no fill), USOIL.cash had no
  order at all.

So: no single complete "native spec" artifact exists to refresh from wholesale. This
audit instead does a **field-by-field, provenance-tagged** refresh — real native data
where it exists, the prior v1 (2026-07-30, website-scraped) value carried forward
unchanged where no native data exists, and a symbol left **out of `book3_normalization`
entirely** (not invented) where neither exists.

## What v1 actually covered (checked directly, not assumed from its size)

`docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json`'s
`book3_normalization` array — the thing the builder's `_cost_coverage()` actually reads
(`{row["dwx_symbol"] for row in payload["book3_normalization"]}`) — has **3 rows only**:
`USDJPY.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`. The 26-pair roster (see
`fund_score_coverage.md` in this directory) needs cost coverage for 10 distinct base
symbols: `XAGUSD, WS30, XAUUSD, GBPUSD, EURUSD, USDCAD, NDX, NZDUSD, XTIUSD, USDJPY`. v1
covered 3 of 10 before this refresh even started — this was already a much larger gap
than "the pin is stale."

## v2 (`ftmo_book_symbol_cost_snapshot_v2.json`, this directory)

sha256: `a24a0ce4a3306acf2e15caee26eb8f4f976eb55baae568259858a70fdbf4c1fb`

| dwx_symbol | in v1? | swap/contract source | commission source |
|---|---|---|---|
| USDJPY.DWX | yes | unchanged (not in native 8-symbol capture) | unchanged (v1 provider projection, 5 USD/lot flat) |
| XAUUSD.DWX | yes | **refreshed** (native 2026-09-06: swap_long -66.21→-93.0, swap_short -23.55→-10.4, triple_weekday Tue→Wed) | unchanged (v1 provider projection, 0.0014%/side — no native commission field exists for any symbol) |
| XTIUSD.DWX | yes | **refreshed** (native 2026-09-06 via USOIL.cash: swap_long 4.22→5.83, swap_short -26.8→-35.11, triple_weekday Tue→Fri) | unchanged (v1 "commission_free" — **still unverified**: the 2026-09-12 native receipt for USOIL.cash has zero fills) |
| GBPUSD.DWX | **no** | **new**, native 2026-09-06 | **new**, native 2026-09-12 realised commission (5.00854701 USD/lot RT, single lifecycle — flagged `REALIZED_NATIVE_SINGLE_OBSERVATION`, not a robust average) |
| EURUSD.DWX | **no** | **new**, native 2026-09-06 | **new**, native 2026-09-12 realised commission (5.02564103 USD/lot RT, same single-observation caveat) |
| USDCAD.DWX | **no** | native swap/contract exists but **excluded** | no commission data anywhere (order cancelled, no fill); also needs a CADUSD conversion rate this snapshot has no live source for |
| NZDUSD.DWX | **no** | native swap/contract exists but **excluded** | no commission receipt was ever captured for NZDUSD |
| XAGUSD.DWX | **no** | native swap/contract exists but **excluded** | no commission receipt was ever captured for silver |
| WS30.DWX | **no** | **excluded, no data anywhere** | only `GER40.cash` (DAX) was captured natively for indices, not WS30 — a net-new capture is required |
| NDX.DWX | **no** | **excluded, no data anywhere** | same as WS30 — net-new capture required |

**Net effect**: v2 covers 5 of 10 required base symbols (up from 3), with 2 of those 5
gaining real native commission for the first time. 5 symbols (USDCAD, NZDUSD, XAGUSD,
WS30, NDX) remain genuinely uncovered — this is the actual, current gap, not a stale-pin
problem alone. Per the roster in `fund_score_coverage.md`, symbols WS30/NDX belong to
sleeves 9641 (WS30) and 11660/13013 (NDX) — 3 of the 26 pairs; USDCAD/NZDUSD/XAGUSD
belong to 11422, 11910, and 1537/21505 — 4 more. **7 of the 26 qualified pairs (27%)
still have zero cost-model coverage after this refresh**, independent of and in addition
to the FUND_SCORE gate finding in `fund_score_coverage.md` (which already fails all 26
regardless of cost coverage).

## No invented values

Every commission/swap/triple-day figure in v2 traces to one of: the cited native IPC
capture, the cited native fill receipt, or the unchanged v1 provider-projection value
(itself sourced from FTMO's public API, dated, and already labeled as such in v1's own
`interpretation.swap_scope`). No symbol was assigned a value without a cited source; the
5 uncovered symbols are listed as excluded, not filled with a guess, zero, or a
neighboring symbol's figure.
