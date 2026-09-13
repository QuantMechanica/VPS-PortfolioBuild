# DXZ Live Book v2 — Portfolio Fit Report (Q15 step 3)

**Order:** `decisions/2026-09-13_owner_book_order_dxz.md` (`OWNER-ORDER: BOOK_BUILD dxz 2026-09-13`).
**Author:** Claude, factory-analysis lane, 2026-09-13. **Mode:** read-only analysis / dry-run.
**Nothing here is applied.** No T_Live write, no AutoTrading, no farm-DB write, no verdict or gate change.
Every number below cites the file it came from.

---

## 0 · Verdict in one paragraph

The 26 Q14-qualified pairs **cannot be turned into an applyable book v2 today**, and the reason is not
a judgement call — three fail-closed gates say no, and a fourth is an evidence gap:

1. **10 of the 26 pairs have no usable sealed daily stream** (`stream_gaps.json`). Only 16 can be
   weighted at all.
2. On identical sealed history the 16-sleeve (and the 18-sleeve variant) proposal is **materially
   worse than the live 24-sleeve book** on all three not-worse checks → `NOT_WORSE_BAR_NOT_MET`.
3. The SP-C3 concentration evaluation returns `CONCENTRATION_CAP_BREACH` — but so does the **current
   live book** under the same policy, so this one is a governance scale mismatch, not a property of
   the proposal (§6).
4. The shipped builder `build_book_dxz.py` **cannot compute any roster that differs from the
   incumbent** (§3). That is a tool defect on the book path, newly demonstrated.

Recommendation: do **not** cut the book over to v2. Close the stream gap first (cheap, §2), then
re-run; and take the two structural decisions in §10 (duplicate sleeve 41221, concentration-policy
scale) before any cutover.

---

## 1 · Pool — the 26 qualified pairs

`python tools/strategy_farm/book_build_guard.py --status --venue dxz --db-path D:/QM/strategy_farm/state/farm_state.sqlite --order-dir decisions`

```json
{ "allowed": true, "distinct_eas": 26, "qualified_pairs": 26,
  "order_artifact": "C:\\QM\\repo\\decisions\\2026-09-13_owner_book_order_dxz.md",
  "reasons": [], "strategy_families": 21 }
```

Pool file: **`D:/QM/reports/portfolio/dxz_v2_20260913/pool.json`** (built with
`rebaseline_census.build_pairs` / `summarise_pair`, terminal gate resolved from the active v4 manifest
as **Q14 Best-Settings Head-to-Head**, role `SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT_Q11`).

**All 26 terminal verdicts are `KEEP_INCUMBENT`**, every one with reason code
`NO_CHALLENGER_BOTH_UPSTREAM_STAGES_NO_CHANGE` (Q12 `NO_FILTER_CHANGE` + Q13 `NO_PARAMETER_CHANGE`).
So the **winning settings are the incumbent/baseline set-file in every case — no challenger was
promoted anywhere in this cohort.** Terminal evidence is one
`D:\QM\reports\optimization_fork\<work_item_id>\receipt.json` per pair
(`qm.optimization-fork-no-change-receipt/v1`), each binding the parent `.ex5`, `.mq5`, set-file and
the Q12 pattern ancestor by SHA256. Per-pair ids and paths: `pool.json`.

Symbol distribution of the pool (26): XAUUSD 6, XTIUSD 6, EURUSD 3, XAGUSD 2, GBPUSD 2, USDJPY 2,
NDX 2, WS30 1, NZDUSD 1, USDCAD 1. (The task brief said "XTI ×7"; measured is **6**.)

---

## 2 · Streams — 16 bound, 10 STREAM_MISSING

`python tools/strategy_farm/assemble_stream_bundle.py --out D:/QM/reports/portfolio/dxz_v2_20260913/streams --db-path D:/QM/strategy_farm/state/farm_state.sqlite`
→ **bound 16, refused 10**, loader acceptance `verified: true`.
Bundle: `D:/QM/reports/portfolio/dxz_v2_20260913/streams/` (layout `QM/q08_trades/<ea>_<symbol>.jsonl`,
the layout `book_builder_common.load_daily` → `portfolio_common.load_streams` requires).
Manifest with per-pair source, seal hash and trade counts: `streams/bundle_manifest.json`.
Gap detail: **`D:/QM/reports/portfolio/dxz_v2_20260913/stream_gaps.json`**.

| pair | status | source / reason |
|---|---|---|
| 1537:XAGUSD, 10700:XAUUSD, 10706:GBPUSD, 11421:EURUSD, 11422:USDCAD, 11708:EURUSD, 11910:NZDUSD, 12710:XTIUSD, 13013:NDX, 13054:XTIUSD, 13213:USDJPY, 20048:XTIUSD, 21505:XAGUSD, 41219:XAUUSD, 41221:EURUSD | BOUND | `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\*.jsonl`, content hash == the Q08 `portfolio_stream.content_sha256` sealed under the **current Q14 identity** |
| 11881:GBPUSD | BOUND | `C:\Users\…\MetaQuotes\Terminal\Common\Files\QM\q08_trades\11881_GBPUSD_DWX.jsonl` (exact content-hash match) |
| 9641:WS30, 10145:XAUUSD, 10403:XAUUSD, 10513:XAUUSD, 11660:NDX, 12849:XTIUSD, 12855:XTIUSD, 21501:USDJPY, 21507:XAUUSD | **STREAM_MISSING** | `sealed_stream_bytes_unavailable` — the Q08 aggregate pins a `content_sha256`, but no file with that hash exists anywhere (the `sleeve_streams` copy was never persisted / was removed; the volatile `Common\Files` copy has since been overwritten by a later run) |
| 20266:XTIUSD | **STREAM_MISSING** | `no_q08_stream_bound_to_identity` — its only `done`/PASS Q08 row (`87731bac…`, 2026-08-08) has **no evidence directory at all** under `D:\QM\reports\work_items\` |

**Recoverability (verified, not assumed):** for all 9 `sealed_stream_bytes_unavailable` pairs the Q08
baseline **`report.htm` still exists and still hashes to the `source_report_sha256` recorded in the Q08
aggregate** (checked file-by-file; see `stream_gaps.json` field
`recoverable_mt5_report_sha256_matches_seal_record: true`). Example:
`D:\QM\reports\pipeline\QM5_10403\Q08\_baseline\QM5_10403\20260826_014325\raw\run_01\report.htm`.
I did **not** reconstruct streams from those reports: an HTML deal table carries no `mae_acct`, no
`notional` and no `entry_time`, would not reproduce the pinned `content_sha256`, and would silently
degrade the SP-C3 tail evidence. That would be fabrication dressed as evidence. The correct fix is a
cheap append-only Q08 re-run per pair (§10 A1).

---

## 3 · Build — the shipped builder refuses this roster (tool defect)

```
python tools/strategy_farm/portfolio/build_book_dxz.py \
  --roster D:/QM/reports/portfolio/dxz_v2_20260913/roster_v2.json \
  --incumbent D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json \
  --stream-root D:/QM/reports/portfolio/dxz_v2_20260913/streams_build_A \
  --total-risk-pct 9.75 --sleeve-cap-pct 1.0 --as-of 2026-09-12 \
  --out-dir D:/QM/reports/portfolio/dxz_v2_20260913/build --order-dir decisions \
  --book-db D:/QM/strategy_farm/state/farm_state.sqlite
```

exit **2**, transcript `build/build_book_dxz_stderr.txt`:

```json
{ "status": "INPUT_INVALID",
  "error": "proposal and incumbent did not resolve to the identical common-day grid" }
```

**Root cause:** `build_dxz_manifest` calls `aligned_matrix` separately for the proposal keys and for
the incumbent keys (`build_book_dxz.py` ~L128-137). `aligned_matrix` → `portfolio_common.align`
builds its date grid from the **union of the days present in that subset only**, so two different
sleeve sets can only produce the same grid if they trade on exactly the same calendar days. The check
`if proposal_dates != incumbent_dates: raise` therefore rejects **every** roster that is not the
incumbent. The builder's defaults (`DEFAULT_ROSTER == DEFAULT_INCUMBENT`) are why this was never hit:
it has only ever been run as an incumbent self-comparison. This is gap **G8** of
`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` §6 turning up on the first real use.

**Second refusal, further down the same path:** `risk_freeze.assert_live_book_mutation_allowed(...)`
runs before `write_json`, and `python tools/strategy_farm/risk_freeze.py status` reports
`OWNER-DEC-RISK-FREEZE status=ACTIVE armed=2026-08-31T05:12:17Z`, all three lift conditions unmet.
So even with the grid fixed, no manifest may be minted until the OWNER lifts the freeze in writing.

**What I computed instead.** `docs/ops/evidence/2026-09-13_dxz_book_v2/analyze_book.py` reuses the
builder's own functions (`capped_inverse_vol`, `portfolio_daily`, `book_metrics`, `_gate`,
`_final_status`, `concentration_tail.evaluate`, `sleeve_bindings`) with **one documented deviation**:
proposal and incumbent are aligned on a **shared** grid — the union of trading days of *all* keys
inside the common window — which is what the comparison was always meant to be. Outputs are marked
`NOT_A_MINTED_MANIFEST` and live in `build/analytic_preview_manifest_{A16,B18}.json`.

Two variants:
* **A16** — the 16 identity-sealed pairs. Strictest evidence standard. Roster `roster_v2.json`,
  streams `streams_build_A/`.
* **B18** — A16 **plus** 10403:XAUUSD and 10513:XAUUSD, whose streams are taken from the incumbent's
  own sealed bundle `dxz_final_20260719` (they are live sleeves; their stream is sealed, just not under
  the *current* Q08 identity). Roster `roster_v2_variantB.json`, streams `streams_build_B/`.
  B18 is the only variant that contains all 6 live overlaps.

---

## 4 · Book metrics vs the incumbent — identical sealed history

Common window **2019-07-23 → 2024-12-06, 1368 trading days**, starting capital 100 000,
total risk 9.75 %, sleeve cap 1.0 %, weights = capped inverse vol on daily PnL.

| metric | **v2 A16** | **v2 B18** | **incumbent (live 24)** |
|---|---:|---:|---:|
| sleeves | 16 | 18 | 24 |
| sum RISK_PERCENT | 9.7500 | 9.7500 | 9.7499 |
| annual return % | 7.051 | 7.951 | **9.484** |
| max drawdown % | 6.861 | 4.883 | **2.408** |
| return / maxDD | 1.028 | 1.628 | **3.938** |
| worst day % | −1.542 | −1.387 | **−0.858** |
| Sharpe | 1.260 | 1.433 | **2.414** |
| net of cost (window) | 38 279 | 43 161 | **51 485** |
| ENB (weighted, corr-based) | 11.53 | 12.46 | — |

Not-worse gate (`_gate`, all three must hold): **A16 FAIL / FAIL / FAIL**, **B18 FAIL / FAIL / FAIL**.
→ `NOT_WORSE_BAR_NOT_MET` on the incumbent comparison, independently of the concentration verdict.

**Why.** The live book spreads 9.75 % over 24 sleeves and 12 symbols, several of them genuinely
orthogonal (GDAXI, SP500, XNGUSD, AUDCAD, EURGBP). The qualified pool is far narrower (9 symbols, half
its risk in energy + metals) and the 1.0 % cap concentrates weight into a handful of low-vol sleeves.
Cutting to v2 would drop **20 of 24 live sleeves** (A16 retains 4) or **18 of 24** (B18 retains 6) and trade a
2.41 % MaxDD book for a 6.86 % / 4.88 % MaxDD book at lower return.

---

## 5 · Correlation — one perfect duplicate, everything else orthogonal

Standard V4: `|r| < 0.5` on Q10/Q14 daily equity curves, min overlap 60 days
(`portfolio_correlation.py` floor). Computed pairwise on the shared 1368-day grid; per-pair co-active
day counts are stored alongside each r in `analytic_preview_manifest_*.json → correlation`.

* **max |r| = 1.0000 — `11421:EURUSD.DWX` vs `41221:EURUSD.DWX`, 67 co-active days (overlap floor met).**
  This is the only pair at or above 0.5 in either variant. The two sleeves are **the same strategy**:
  identical trade count (91), identical window (2018-05-11 → 2025-12-11), identical PF (1.1415),
  identical standalone MaxDD (5.9696 %), identical constant volume (1.25 lots).
  `QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8` is a requalification clone of
  `QM5_11421_ohlc-daily-squeeze-reversal-d1`. Admitting both **double-counts one edge**, allocates
  2 × 0.55 % (A16) to it, and breaches the Q15 `|r| < 0.5` hard rule. **This must be resolved before
  any book** — see §10 B1.
* Next-highest |r| values are all far below the floor: 0.171 (1537 vs 21505 XAGUSD, 21 co-active days),
  0.156 (12710 vs 13054 XTIUSD, 24 days), −0.126, 0.126, 0.100 …
* **Caveat, not a pass:** the co-active day counts for the sparse D1 sleeves are 5–24 days, far under
  the 60-day floor. Their near-zero r is the mechanical artefact the V4 decision warned about
  (runbook §3 V4 / gap G3) — read them as "no evidence of dependence", **not** as proven orthogonality.
  Only the dense pairs (e.g. 10706 vs 13213, 180 co-active days) carry a real estimate.

---

## 6 · Concentration, families, asset classes — and a policy-scale defect

`concentration_tail.evaluate` under the OWNER-ratified policy
`tools/strategy_farm/config/concentration_tail_limits.v1.json` (`status: OWNER_RATIFIED`,
stop-risk budget **2.5 %**, caps: symbol 40 %, asset-class 60 %, family 50 %, session warn/breach 60/70).

**A16 stop-risk by dimension (%):**
* symbol — XTIUSD 2.723, EURUSD 2.019, XAGUSD 1.370, XAUUSD 1.150, GBPUSD 0.772, NZDUSD 0.746,
  NDX 0.641, USDCAD 0.254, USDJPY 0.075 → **BREACH** (cap 1.0)
* asset class — fx 3.866, energy 2.723, metals 2.520, indices 0.641 → **BREACH** (cap 1.5)
* family — max `cum` 1.000 and `wti` 1.000 → **PASS** (cap 1.25)
* session — ASIA 7.440, US 2.235, EU 0.075 → **BREACH** (cap 1.75)
* tail — **PASS**: worst joint-tail day 0.676 % vs cap 4.0 %; 45 joint tail days, k=6.

**B18** is the same picture (metals rises to 3.143 with the two extra XAUUSD sleeves; tail worst day
1.083 %, still PASS).

**Control run — the current LIVE book fails the same caps.**
`docs/ops/evidence/2026-09-13_dxz_book_v2/check_incumbent_conc.py` →
`build/incumbent_concentration_control.json`: the deployed 24-sleeve book breaches **symbol,
asset_class, family *and* session** (fx 4.026, metals 2.116, family `cum` 1.726, `grimes` 1.476,
ASIA 4.508, US 4.572). **So `CONCENTRATION_CAP_BREACH` here is not a v2 property.** The ratified caps
are expressed as fractions of a **2.5 %** stop-risk budget while the ratified book risk (V6) is
**9.75 %**; any book spending 9.75 % across 3–4 asset classes breaches a 1.5 % asset-class cap by
construction. The two OWNER ratifications are numerically incompatible. This blocks
`APPLY_RECOMMENDED` for *any* book, v1 or v2 (§10 B2).

**Vault Q15 hard caps (family ≤ 3, symbol ≤ 2 EAs, 10–15 EAs) against the proposal:**
* EAs per symbol — A16: XTIUSD 3, EURUSD 3 (→ **breach ≤ 2**); XAUUSD 2, XAGUSD 2, GBPUSD 2 OK.
  B18: XAUUSD 4, EURUSD 3, XTIUSD 3 (→ **breach**).
* EAs per family — max 2 (`ohlc`: 11421 + 41221) → within ≤ 3.
* Book size — 16 / 18 sleeves vs the 10–15 band → **above the cap**.

**Symbol coverage.** v2 A16 covers 9 symbols; it **loses** GDAXI, SP500, XNGUSD, AUDCAD, AUDUSD,
EURGBP relative to the live book (12 symbols) and gains XTIUSD, XAGUSD, NZDUSD, USDCAD.

---

## 7 · Per-sleeve standalone economics (A16, from the sealed stream window at 1 %/trade)

Sorted by proposed weight. Full table incl. B18 in `analytic_preview_manifest_*.json → sleeves`.

| EA | symbol | magic | live? | w % | PF | standalone MaxDD % | trades | trades/yr | stream window |
|---|---|---:|:--:|---:|---:|---:|---:|---:|---|
| QM5_20048_wti-preholiday | XTIUSD | 200480000 | new | 1.0000 | 1.299 | 0.99 | 60 | 7.8 | 2018-04-02…2025-12-26 |
| QM5_41219_cum-rsi2-commodity-requal8 | XAUUSD | 412190000 | new | 1.0000 | 1.699 | 1.70 | 72 | 10.6 | 2019-01-25…2025-11-21 |
| QM5_11708_anon-market-squeeze-d1 | EURUSD | 117080000 | **LIVE** | 0.9193 | 1.107 | 4.52 | 173 | 23.1 | 2018-06-08…2025-12-05 |
| QM5_12710_commodity-tsmom-12m-atr | XTIUSD | 127100000 | new | 0.8901 | 1.680 | 1.38 | 82 | 11.4 | 2018-10-05…2025-12-05 |
| QM5_13054_brent-tom-mom | XTIUSD | 130540000 | new | 0.8329 | 1.373 | 2.08 | 82 | 10.5 | 2018-03-02…2025-12-30 |
| QM5_1537_aa-vol-sma10 | XAGUSD | 15370001 | new | 0.7933 | 1.260 | 2.71 | 96 | 15.8 | 2018-11-02…2024-12-06 |
| QM5_11910_larry-williams-18ma-2outside-bars-d1 | NZDUSD | 119100006 | new | 0.7457 | 1.150 | 3.85 | 63 | 8.8 | 2018-03-23…2025-06-05 |
| QM5_11881_connors-rsi2-mean-reversion | GBPUSD | 118810001 | new | 0.6828 | 1.244 | 4.19 | 99 | 13.4 | 2018-07-12…2025-12-02 |
| QM5_13013_grimes-trendday-v2 | NDX | 130130000 | new | 0.6412 | 1.316 | 3.54 | 70 | 9.6 | 2018-08-08…2025-11-28 |
| QM5_21505_xag-weekly-lowvol-momentum | XAGUSD | 215050000 | new | 0.5763 | 1.312 | 3.41 | 116 | 16.2 | 2018-07-27…2025-09-26 |
| QM5_11421_ohlc-daily-squeeze-reversal-d1 | EURUSD | 114210000 | **LIVE** | 0.5499 | 1.142 | 5.97 | 91 | 12.0 | 2018-05-11…2025-12-11 |
| QM5_41221_ohlc-…-requal8 **(duplicate of 11421)** | EURUSD | 412210000 | new | 0.5499 | 1.142 | 5.97 | 91 | 12.0 | 2018-05-11…2025-12-11 |
| QM5_11422_williams-18ma-outside-bar-entry-d1 | USDCAD | 114220004 | new | 0.2545 | 1.220 | 12.54 | 195 | 24.9 | 2018-03-02…2025-12-26 |
| QM5_10700_tv-liq-break | XAUUSD | 107000003 | new | 0.1499 | 1.301 | 15.40 | 373 | 45.7 | 2017-10-26…2025-12-24 |
| QM5_10706_tv-mon-ls | GBPUSD | 107060001 | **LIVE** | 0.0892 | 1.272 | 23.24 | 360 | 43.8 | 2017-10-10…2025-12-30 |
| QM5_13213_balke-gmt3-range-breakout | USDJPY | 132130000 | **LIVE** | 0.0750 | 1.085 | 29.41 | 1596 | 194.1 | 2017-10-09…2025-12-30 |

All 16 clear the ratified Q02 frequency floor (≥ 5 trades/yr); the thinnest is 20048 at 7.8/yr.
Standalone MaxDD is quoted at the backtest 1 %/trade basis, so the high figures (13213 29 %, 10706 23 %)
are exactly why capped inverse vol pushes them to 0.075 % / 0.089 % of book risk.

**Marginal contribution (leave-one-out, weights re-solved, ΔSharpe of the whole book, A16):**
positive contributors — 10700:XAUUSD +0.158, 12710:XTIUSD +0.113, 10706:GBPUSD +0.106,
13054:XTIUSD +0.105, 13013:NDX +0.101; **negative** — 13213:USDJPY −0.020 and the duplicate pair
11421 / 41221 at **−0.129 each** (removing either one *raises* book Sharpe, the signature of a
double-counted edge). Full table in `analytic_preview_manifest_A16.json → marginal_contribution`.

---

## 8 · The 6 overlaps with the live book

| pair | live magic | live RISK_PERCENT (07-24 manifest) | v2 target (B18) | in A16? |
|---|---:|---:|---:|:--:|
| 10403:XAUUSD | 104030002 | 0.2204 | 0.3315 | no (stream missing) |
| 10513:XAUUSD | 105130003 | 0.3050 | 0.4444 | no (stream missing) |
| 10706:GBPUSD | 107060001 | 0.0530 | 0.0803 | yes |
| 11421:EURUSD | 114210000 | 0.3364 | 0.4948 | yes |
| 11708:EURUSD | 117080000 | 0.5080 | 0.8273 | yes |
| 13213:USDJPY | 132130000 | 0.0431 | 0.0674 | yes |

Their magic numbers are already registered and active in `framework/registry/magic_numbers.csv`;
so are all 26 pool pairs — **no new slot allocation is required** and none was made. The roster files
carry `magic_number`, `magic_slot`, `proposed_slot` (populated only for non-live sleeves) and
`magic_slot_status: REGISTERED_ACTIVE` per sleeve; every magic satisfies `ea_id * 10000 + slot`.

---

## 9 · Burn-in variant (new sleeves at min lot, live overlaps at target)

`docs/ops/evidence/2026-09-13_dxz_book_v2/burnin.py` → `build/burnin_variant.json` (computed on **B18**,
the only variant containing all 6 live overlaps).

Sizing basis, from evidence not assumption: backtest streams run at `RISK_FIXED = 1000 USD` on
`initial_deposit = 100 000` (`framework/registry/tester_defaults.json`) = **1.0 %/trade**, and lots
scale linearly with `RISK_PERCENT`, so a trade of backtest volume *V* quantizes to 0.01 lots at
`0.01 / V` %. `QM_RiskSizerQuantizeLots` floors to the volume step and **returns 0.0 when the result is
below `SYMBOL_VOLUME_MIN`** (`framework/include/QM/QM_RiskSizer.mqh:210`) — i.e. under-sizing does not
clamp up, it silently skips the trade. Two bounds are therefore reported per sleeve.

| sleeve | basis | burn-in RISK_PERCENT |
|---|---|---:|
| 10403:XAUUSD, 10513:XAUUSD, 10706:GBPUSD, 11421:EURUSD, 11708:EURUSD, 13213:USDJPY | live, v2 target weight | 0.3315 / 0.4444 / 0.0803 / 0.4948 / 0.8273 / 0.0674 |
| 1537:XAGUSD | min lot (median trade) | 0.0769 |
| 10700:XAUUSD | min lot (median trade) | 0.0130 |
| 11422:USDCAD | min lot (median trade) | 0.0059 |
| 11881:GBPUSD | min lot (median trade) | 0.0200 |
| 11910:NZDUSD | min lot (median trade) | 0.0123 |
| 12710:XTIUSD | min lot (median trade) | 0.0667 |
| 13013:NDX | min lot (median trade) | 0.0105 |
| 13054:XTIUSD | min lot (median trade) | 0.0488 |
| 20048:XTIUSD | min lot (median trade) | 0.0606 |
| 21505:XAGUSD | min lot (median trade) | 0.0714 |
| 41219:XAUUSD | min lot (median trade) | 0.0714 |
| 41221:EURUSD | min lot (median trade) | 0.0080 |

**Sum RISK_PERCENT of the burn-in variant = 2.7112 %** (12 new sleeves 0.4655 % + 6 live sleeves
2.2457 %). On the stricter "*every* trade still ≥ 0.01 lots" basis the new sleeves total 0.2088 % and
the book sums to **2.4545 %**. Both are well inside the 9.75 % envelope, so a 14-day Q17 burn-in of the
new sleeves costs ≈ 0.47 % (or 0.21 %) of account risk on top of the retained live sleeves.

Caveat: this is derived from backtest lot sizes on `.DWX` custom symbols. Before staging, the per-symbol
`SYMBOL_VOLUME_MIN` / `SYMBOL_VOLUME_STEP` on the **live** Darwinex symbols must be read off T_Live
(read-only) and the numbers re-checked — a symbol with `volume_min = 0.1` would change its row.

---

## 10 · Blockers, and who must do what

**A — evidence gaps (orchestrator can commission today)**
* **A1 · 10 missing sealed streams.** 9 pairs need an append-only Q08 re-run to re-emit and re-seal the
  stream (`farmctl enqueue-backtest --append-only-rerun-of <q08 work item>`; ids in `stream_gaps.json`);
  `20266:XTIUSD` needs a full Q08 run (no evidence dir at all). Until then the book is 16/26, not 26/26.
* **A2 · the sealing step loses bytes.** The Q08 `portfolio_stream` block records
  `path: …\sleeve_streams\QM\q08_trades\<f>.jsonl` and `persisted: true`, yet for 9 pairs that file does
  not exist. Either the copy never happened or something prunes `sleeve_streams`. This will keep
  eating book evidence — worth a Codex `ops_issue`.
* **A3 · builder grid defect (§3).** `build_book_dxz.py` cannot evaluate any roster ≠ incumbent.
  Fix: align proposal and incumbent on one shared grid (the union over all keys in the common window),
  which is what the "identical sealed common history" contract means. Codex, and it is a prerequisite
  for **any** future book build.

**B — OWNER decisions (ROT, nobody else)**
* **B1 · duplicate sleeve.** `41221:EURUSD` is byte-for-byte the same edge as live `11421:EURUSD`
  (r = 1.0000). Admit only one. Recommendation: **keep the live 11421, drop 41221 from the pool**, and
  check the rest of the `*requal8` cohort for the same pattern before the next census.
* **B2 · concentration policy vs book risk.** The ratified 2.5 % stop-risk budget and the ratified
  9.75 % book risk cannot both hold; today's *live* book breaches the caps too. Either the caps are
  restated as fractions of the 9.75 % book risk, or the budget is raised, or the caps are declared
  advisory. Until this is settled `build_book_dxz.py` can never emit `APPLY_RECOMMENDED` — for any book.
* **B3 · risk freeze.** `OWNER-DEC-RISK-FREEZE` is ACTIVE with all three lift conditions unmet. No
  manifest may be minted or applied without a written OWNER lift.
* **B4 · the cutover itself.** On identical history v2 is worse than the live book on all three
  not-worse checks (§4). My recommendation: **do not cut over**. Close A1, resolve B1/B2, then re-run —
  and consider evaluating the *union* (live 24 + qualified new) rather than a replacement, since the
  loss comes from dropping 18 diversifying live sleeves, not from the new sleeves being bad.

**Unchanged by this report:** no gate threshold, no verdict, no queue row, no live weight, no preset,
no T_Live file, no AutoTrading state. Q16 (11 checks) and the deploy ceremony have not been entered.

---

## 11 · Artifacts

| what | path |
|---|---|
| qualified pool (26) | `D:/QM/reports/portfolio/dxz_v2_20260913/pool.json` |
| sealed stream bundle (16) + manifest | `D:/QM/reports/portfolio/dxz_v2_20260913/streams/` |
| stream gaps (10) | `D:/QM/reports/portfolio/dxz_v2_20260913/stream_gaps.json` |
| roster A16 / B18 | `…/roster_v2.json` · `…/roster_v2_variantB.json` |
| builder stream roots (+ per-file provenance) | `…/streams_build_A/` · `…/streams_build_B/` |
| official builder refusal transcript | `…/build/build_book_dxz_stderr.txt` |
| analytic preview manifests | `…/build/analytic_preview_manifest_A16.json` · `…_B18.json` |
| incumbent concentration control | `…/build/incumbent_concentration_control.json` |
| burn-in variant | `…/build/burnin_variant.json` |
| analysis scripts (reproduce everything above) | `C:/QM/repo/docs/ops/evidence/2026-09-13_dxz_book_v2/*.py` |
