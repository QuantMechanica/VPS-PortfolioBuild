# FTMO book v2 — FUND_SCORE coverage of the 26 qualified Q14 pairs

Ticket `ac25ebea-9ad3-45e9-b213-c324987eb0ee`, item (2). Read-only: no DB write, no
terminal, no freeze change.

## The 26 pairs

`docs/ops/evidence/2026-09-13_dxz_book_v2/pool.json` — `qualified_pairs: 26`, the set of
`(ea_id, symbol)` whose `highest_contiguous_valid_gate` / `terminal_gate` is `Q14` with
`disposition: REUSABLE` (`all_terminal_verdicts: ["KEEP_INCUMBENT"]`).

## Coverage against `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json`

Population: 128 sleeves, `FUND_SCORE_FLOOR = 1.0` (from
`tools/strategy_farm/portfolio/build_book_ftmo.py`). Matched by `sleeve` key
(`"<ea_id>:<symbol_base>"`, e.g. `1537:XAGUSD`):

| sleeve | fund_score | vs. floor (1.0) | upstream step if missing/unscorable |
|---|---:|---|---|
| 1537:XAGUSD | 0.1312 | BELOW_FLOOR | — |
| 9641:WS30 | 0.1617 | BELOW_FLOOR | — |
| 10145:XAUUSD | 0.1577 | BELOW_FLOOR | — |
| 10403:XAUUSD | 0.0491 | BELOW_FLOOR | — |
| 10513:XAUUSD | 0.0757 | BELOW_FLOOR | — |
| 10700:XAUUSD | 0.2223 | BELOW_FLOOR | — |
| 10706:GBPUSD | 0.1069 | BELOW_FLOOR | — |
| 11421:EURUSD | 0.0156 | BELOW_FLOOR | — |
| 11422:USDCAD | 0.1577 | BELOW_FLOOR | — |
| 11660:NDX | 0.0946 | BELOW_FLOOR | — |
| 11708:EURUSD | 0.0651 | BELOW_FLOOR | — |
| 11881:GBPUSD | 0.1541 | BELOW_FLOOR | — |
| 11910:NZDUSD | 0.0947 | BELOW_FLOOR | — |
| 12710:XTIUSD | 0.0905 | BELOW_FLOOR | — |
| 12849:XTIUSD | 0.0706 | BELOW_FLOOR | — |
| 12855:XTIUSD | 0.1243 | BELOW_FLOOR | — |
| 13013:NDX | 0.0148 | BELOW_FLOOR | — |
| 13054:XTIUSD | 0.0243 | BELOW_FLOOR | — |
| 13213:USDJPY | 0.1447 | BELOW_FLOOR | — |
| 20048:XTIUSD | 0.0330 | BELOW_FLOOR | — |
| **20266:XTIUSD** | — | **NO ROW** | No `sleeve_streams/QM/q08_trades/20266_*.jsonl` exists (verified: not present among the 128 exported streams). Root cause: the Q08 window-sweep census cell for this arm (`buy_010`) is not `done` — same blocker ticket 7d9dd3b5 (Q08 DSR sweep-arm context repair) is fixing: `INCOMPLETE_TRIAL:DL089:PATTERN:buy_010`. Fix order: 7d9dd3b5 resolves the cell → Q08 trades stream export runs → fund_scores.py can score it. |
| 21501:USDJPY | 0.1447 | BELOW_FLOOR | — |
| 21505:XAGUSD | 0.1235 | BELOW_FLOOR | — |
| **21507:XAUUSD** | — | **NO ROW** | Same pattern as 20266: no exported Q08 trades stream. Root cause: cell `2c1a2b99` (`sell_032`/2025) held `PRESCREEN_SKIPPED`, also ticket 7d9dd3b5's scope: `INCOMPLETE_TRIAL:DL089:PATTERN:sell_032`. Same fix order as above. |
| 41219:XAUUSD | 0.0986 | BELOW_FLOOR | — |
| 41221:EURUSD | 0.0156 | BELOW_FLOOR | — |

## Result

**0 of 26 qualified pairs clear `FUND_SCORE_FLOOR = 1.0`.** 24/26 have a real, scored
`fund_score` between 0.0148 and 0.2223 (roughly an order of magnitude below the floor);
2/26 (20266:XTIUSD, 21507:XAUUSD) have no score at all because their Q08 trade stream was
never exported — both trace to the exact same window-sweep prescreen-skip blocker as
ticket 7d9dd3b5. This matches (and gives the row-by-row detail behind) the sprint log's
summary "FTMO builder BAR_NOT_MET (fund scores 0.05–0.09 vs floor 1.0)"
(`docs/ops/BOOK_SPRINT_2026-09-20.md`, 2026-09-14 20:5xZ entry) — the true range is
0.0148–0.2223, still uniformly and by a wide margin below the 1.0 floor; no pair is close.

**No invented scores.** Every number above is read verbatim from
`fund_scores.json`; the two missing rows are reported as missing, not backfilled or
estimated.
