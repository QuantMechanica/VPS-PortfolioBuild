# Turn-of-month index build preflight — task 9e872ce2

Date: 2026-07-17  
Router task: `9e872ce2-5e53-4c78-97ed-a4248fef4f0c` (`build_ea`, Codex)  
Requested card: `docs/research/CARD_DRAFT_TURN_OF_MONTH_INDEX_LONG_2026-07-16.md`

## Outcome

**STOP — not build-eligible.** The `qm-build-ea-from-card` preflight prohibits implementation
unless the Strategy Card is approved and CEO + CTO have allocated an EA ID with complete registry
and magic rows. This routed draft fails those prerequisites, so no EA source, registry row, magic
row, binary, setfile, terminal process, backtest, or pipeline state was created or changed.

## Mandatory preflight

| Check | Evidence | Verdict |
|---|---|---|
| Approved Strategy Card | Draft line 3 is `status: DRAFT_FOR_APPROVAL`; no approval trail is present. | **FAIL** |
| Allocated EA ID | Draft line 4 is `ea_id: TBD`. | **FAIL** |
| Canonical approved-card location | Routed input is under `docs/research/`, not `strategy-seeds/cards/<slug>_card.md` or the approved-card store. | **FAIL** |
| EA registry row | Exact slug `turn-of-month-index-long` has no row in `framework/registry/ea_id_registry.csv`. | **FAIL** |
| Magic rows | Exact slug has no `(ea_id, symbol_slot, symbol)` rows in `framework/registry/magic_numbers.csv`. | **FAIL** |
| Slug/name limits | Slug is 24 characters (limit 16). `QM5_NNNN_turn-of-month-index-long` is 33 characters (compiled-name limit 32). | **FAIL** |
| Requested symbols/data | Card requests `DE40.DWX` and `NDX.DWX`. The history registry has no `DE40.DWX` D1 row; the canonical DAX symbol is `GDAXI.DWX`. | **FAIL** |
| Mandatory OOS window | Card mandates 2015–2025. Registered D1 history starts in 2018 for `GDAXI.DWX` and 2021 for `NDX.DWX`. The gate cannot be executed as written. | **FAIL** |

The failed symbol/data checks do not authorize alias creation, history invention, window weakening,
or substitution. Those require card approval and data-governance decisions before Development.

## Duplicate/variant adjudication required

The draft describes a long-only D1 equity-index turn-of-month window driven by mechanical pension
and fund inflows, with a time exit, optional SMA regime gate, and optional ATR protection. This is not
a demonstrably new family relative to already approved and built EAs:

- `QM5_12847_turn-of-month-sp500` is approved, registered for SP500/NDX/WS30/GDAXI, compiled, and
  already has Q02–Q09 evidence. Its deterministic mechanic enters on an Nth-last trading day and
  exits on trading day 3 of the next month. The new draft changes the entry default, SMA length, and
  primary market, but retains the same cause, direction, timeframe, calendar clock, and NDX/GDAXI
  universe.
- `QM5_9931_bandy-turn-of-month-overlay-index` is an approved and compiled long-only D1 index
  turn-of-month overlay using last/first trading-day windows, an SMA gate, an ATR stop, and a window
  or time exit.
- `QM5_10023_rw-eom-flow` is compiled and enters long SP500/NDX/WS30 before month-end, then exits on
  the first trading day of the following month.

This does not by itself reject a deliberately pre-registered variant. It means CEO + Quality-Business
must explicitly adjudicate novelty and whether the requested last-day/first-three-day DE40 emphasis
should be a parameterized experiment on an existing EA or a separately approved card/ID. Development
must not decide that allocation implicitly by writing code.

## Coordination required before reroute

1. CEO + Quality-Business approve or reject the card and record the duplicate/variant rationale.
2. Resolve the mandatory 2015–2025 falsification window against actual registered history; do not
   silently shorten the OOS gate.
3. Use the canonical symbol name (`GDAXI.DWX`) or complete the separate custom-symbol validation and
   registry process for `DE40.DWX`.
4. Choose a compliant slug of at most 16 characters.
5. CEO + CTO allocate the EA ID; add the matching `ea_id_registry.csv` row and active magic rows for
   every approved symbol slot.
6. Place the approved card in the canonical card path, with slug/card/registry identity aligned.
7. Only then reroute a `build_ea` task to Development.

## Focused verification

Read-only checks performed from `C:/QM/repo`:

- Draft front matter confirms `DRAFT_FOR_APPROVAL`, `ea_id: TBD`, target symbols, and D1 timeframe.
- Exact-slug searches of both allocation registries return zero rows.
- History registry confirms `GDAXI.DWX,D1,2018,2026` and `NDX.DWX,D1,2021,2026`, with no
  `DE40.DWX,D1` row.
- Existing approved card, registry rows, EA source/binary, and farm evidence for QM5_12847 were
  inspected.
- Existing source/binary and strategy specs for QM5_9931 and QM5_10023 were inspected.

No compilation or backtest was run because the mandatory build preflight failed before scaffolding.
