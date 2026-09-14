# FTMO book v2 inputs — ticket ac25ebea

Claude task `ac25ebea-9ad3-45e9-b213-c324987eb0ee` (BOOK SPRINT F2, cutover Sun
2026-09-20). Read-only throughout: no DB write, no terminal, no freeze change, no
invented costs.

- **(1) Cost/swap snapshot** — `cost_snapshot_provenance.md` +
  `ftmo_book_symbol_cost_snapshot_v2.json` (sha256
  `a24a0ce4a3306acf2e15caee26eb8f4f976eb55baae568259858a70fdbf4c1fb`). The ticket's
  premise ("native specs captured 2026-09-06, Track B") does not match what actually
  exists — documented precisely, not silently corrected. v2 is a field-by-field,
  provenance-tagged refresh: 5/10 required base symbols now covered (up from 3/10 in
  v1), 2 of those gaining real native commission for the first time; 5 symbols
  (USDCAD, NZDUSD, XAGUSD, WS30, NDX) remain genuinely uncovered and are listed, not
  invented.
- **(2) FUND_SCORE coverage** — `fund_score_coverage.md`. All 26 Q14-qualified pairs
  checked against `fund_scores.json`: 24/26 scored, all far below the 1.0 floor
  (0.0148–0.2223); 2/26 (20266:XTIUSD, 21507:XAUUSD) have no score at all because their
  Q08 trade stream was never exported — both trace to the exact window-sweep
  prescreen-skip blocker that ticket 7d9dd3b5 (Q08 DSR sweep-arm context repair) is
  separately fixing.
- **(3) Builder dry-run command** — `builder_dry_run_command.md`. Full command prepared
  with a schema-verified `--roster` (the DXZ v2 28-sleeve manifest), the new v2 cost
  snapshot, and an honest inventory of the two still-missing inputs (`--correlation`,
  `--bootstrap-result`). Not executed — the fund-score floor alone already determines
  `BAR_NOT_MET`, independent of those two inputs, so running it now would only reproduce
  a known result at the cost of a state-touching invocation.

## Bottom line for whoever reviews F2

The FTMO book v2 cannot pass its own admission bar today on fund-score grounds alone —
every qualified pair is roughly 5–70x below the required floor, not marginally short.
Closing (2)'s two missing-stream pairs depends on ticket 7d9dd3b5. Closing the remaining
cost-coverage gap in (1) needs a net-new native or website capture for 5 symbols,
specifically WS30 and NDX (currently zero data anywhere). Neither of these is something
this read-only ticket can close by itself; both are named precisely so F3 (the actual
dry-run + bar-status decision) starts from real inputs, not an assumed-complete picture.
