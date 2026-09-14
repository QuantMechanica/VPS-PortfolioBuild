# FTMO book v2 — builder dry-run command + expected inputs

Ticket `ac25ebea-9ad3-45e9-b213-c324987eb0ee`, item (3). **Not executed** — this is the
prepared command + input inventory only, per the ticket's own instruction not to run it
while conditions are unresolved, and per this task's own "read-only" hard limit
independent of freeze state.

`tools/strategy_farm/portfolio/build_book_ftmo.py` is itself a **dry-run-only** manifest
builder (`"dry_run": True` is hardcoded at line 734 of the script; it never places an
order or mutates the live book) — but it does take `--book-db`/`--order-dir` and calls
`book_build_guard`/`risk_freeze.assert_live_book_mutation_allowed`, so it is treated here
as a state-touching command per this ticket's hard limits and left unexecuted.

## Prepared command

```
python tools/strategy_farm/portfolio/build_book_ftmo.py ^
  --roster "D:\QM\reports\portfolio\dxz_v2_20260913\build_28_r11\manifest_28_r11_full.json" ^
  --fund-scores "D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json" ^
  --cost-snapshot "C:\QM\repo\docs\ops\evidence\2026-09-14_ftmo_book_v2\ftmo_book_symbol_cost_snapshot_v2.json" ^
  --expected-cost-version-sha256 a24a0ce4a3306acf2e15caee26eb8f4f976eb55baae568259858a70fdbf4c1fb ^
  --correlation <MISSING, see below> ^
  --bootstrap-result <MISSING, see below> ^
  --as-of 2026-09-14 ^
  --out-dir "D:\QM\reports\portfolio\ftmo_v2_20260914_dryrun"
```

(`^` = Windows line continuation; all other flags — `--min-sleeves`, `--min-active-days-per-60d`,
`--max-pairwise-correlation`, `--account-weight-budget`, `--starting-capital`,
`--concentration-policy`, `--symbol-matrix`, `--stream-root`, `--book-db`, `--order-dir` —
left at script defaults, all read directly from `build_book_ftmo.py`'s own
`DEFAULT_*`/`ap.add_argument(..., default=...)` values; none re-derived or guessed here.)

## Expected inputs — status

| Input | Status | Detail |
|---|---|---|
| `--roster` | **available, schema-verified** | `D:\QM\reports\portfolio\dxz_v2_20260913\build_28_r11\manifest_28_r11_full.json` — the DXZ v2 28-sleeve builder's own full manifest (the same roster driving the DXZ book this sprint). Verified against `book_builder_common.resolve_roster()`: its `schema` (`qm.dual-book-manifest/v1`) is not the dual-book-roster schema that function special-cases, so it falls into the generic "conventional book manifest" path, which only requires a top-level `sleeves` list of `{ea_id, symbol, ...}` objects — confirmed present (28 rows, each carrying `ea_id`/`symbol`). The 26-pair Q14-qualified set in `fund_score_coverage.md` is a subset of this (28 minus the 2 DEFERRED_SYMBOL_LITERAL_FIX sleeves, 13054/21505). |
| `--fund-scores` | **available, and already checked** | Result: 0/26 clear the 1.0 floor — see `fund_score_coverage.md`. The builder will report `BAR_NOT_MET` on this input alone; running it will not change that outcome without new evidence. |
| `--cost-snapshot` | **available (v2, this ticket)** | `ftmo_book_symbol_cost_snapshot_v2.json`, sha256 `a24a0ce4a3306acf2e15caee26eb8f4f976eb55baae568259858a70fdbf4c1fb`. Covers 5/10 required base symbols — see `cost_snapshot_provenance.md`. The builder's `--expected-cost-version-sha256` guard must be updated to this hash (or the script's `EXPECTED_COST_SNAPSHOT_SHA256` constant re-pinned) before a real run would even pass the cost-version check; **not done here** (code change, out of this ticket's read-only scope). |
| `--correlation` | **MISSING — stale candidate found, not usable** | `D:/QM/reports/portfolio/ftmo_contract_v1_20260905/correlation_v4.json` exists but covers only 8 of the 26 pairs (`n_series: 8`, generated 2026-09-05, predates this roster). A current run needs `tools/strategy_farm/portfolio/portfolio_correlation.py` re-run against all 26 sleeve streams — not done here (would require running a script, out of read-only scope; also moot while every pair fails the fund-score floor). |
| `--bootstrap-result` | **MISSING — no candidate found at all** | Searched `D:/QM/reports/portfolio/` for any `*bootstrap*` artifact; none exists for this roster. |

## Why a dry-run is not worth executing yet

Independent of the two missing inputs above, `--fund-scores` alone already determines the
outcome: **every one of the 26 qualified pairs scores 0.0148–0.2223 against a 1.0 floor**
(`fund_score_coverage.md`) — this is the same magnitude as the sprint log's own
"BAR_NOT_MET (fund scores 0.05–0.09 vs floor 1.0)" note
(`docs/ops/BOOK_SPRINT_2026-09-20.md`). No correlation or bootstrap input changes a
fund-score floor check. Running the builder now would reproduce `BAR_NOT_MET` at cost —
worth doing once there is new fund-score evidence to test, not before.

## No invented inputs

Every path above is either read from `build_book_ftmo.py`'s own defaults, a file
confirmed to exist on disk (checked via `ls`/`find`, not assumed), or explicitly marked
missing with the exact search performed. Nothing was fabricated to make the command
"complete."
