---
authored_by: Research Agent
authored_on: 2026-04-28
parent_issue: QUA-423
grandparent_issue: QUA-400
tier: T1.5
tier_layer: drive_quantmechanica_v4_archive
folder_root: G:\My Drive\QuantMechanica\Company\Research\strategies\
file_count_total: 5
file_count_uncited: 0
file_count_blocked_no_primary_source: 0
status: survey_complete_for_owner_ceo_review
binding_rule: |
  T1.5 docs are inspiration / concept references. Every V5 Strategy Card MUST cite the original book / paper / blog
  the V4 doc itself cites — NOT the V4 doc as primary. V4 backtest results are NEVER imported as PASS evidence.
  V4 SM_XXX names stay V4-namespace; V5 reimplementations get a fresh ea_id (1000-9999) per Magic Formula registry.
---

# T1.5-01 survey — `G:\My Drive\QuantMechanica\Company\Research\strategies\`

This survey is the first action under [QUA-423](/QUA/issues/QUA-423) (parent [QUA-400](/QUA/issues/QUA-400) Rule 6 — Drive `QuantMechanica` strategy concept pool registered as Tier 1.5 in `SOURCE_QUEUE.md`). Folder root contains the V4-era research output for the highest-signal sub-tree of the Drive resource. Five `.md` docs surveyed; all are CITED with traceable upstream primary sources (paper / blog), so none enter the `BLOCKED_NO_PRIMARY_SOURCE` queue. Every row below shows the **original** primary source the V4 doc cites — that is the source a V5 Strategy Card must cite, never the V4 doc itself.

Per the QUA-400 Rule 6 binding: **V4 backtest results in these docs are NOT transcribed here, NOT cited, NOT importable as V5 PASS evidence.** Every reported-performance figure inside the V4 docs is treated as informational-only context for the OWNER + CEO concept-tier ratification — V5 P0–P5 produces its own evidence per `pipeline-v2-1.md`.

## Survey table

| # | V4 doc filename | V4 doc title | primary source cited (the citation a V5 card must use) | citation status | tradeable instrument class | concept worth carrying to V5 |
|---|---|---|---|---|---|---|
| 1 | `ath-breakout-atr-trail.md` | ATH Breakout + ATR Trailing Stop (Trend Following, adapted from Blackstar 2005) | Wilcox, C., & Crittenden, E. (November 2005). *Does Trend Following Work on Stocks?* Blackstar Funds LLC. Paper URL: https://paperswithbacktest.com/api/paper/does-trend-following-work-on-stocks/pdf — editorial: https://paperswithbacktest.com/strategies/does-trend-following-work-on-stocks | CITED (paper) | Multi: indices (`GDAXI`, `NDX`, `WS30`), metals (`XAUUSD`), energy (`XTIUSD`), USD-bloc FX majors | **YES** — clean mechanical breakout + ATR trail; primary source is a 2005 academic-grade study; transfer to liquid macro-D1 universe is well-argued in V4 doc; high V5 fit. |
| 2 | `good-carry-bad-carry.md` | Good Carry, Bad Carry (Bekaert & Panayotov 2018) | Bekaert, G., & Panayotov, G. (2018/2019). *Good Carry, Bad Carry.* Journal of Financial and Quantitative Analysis. SSRN preprint: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2516907 — editorial: https://paperswithbacktest.com/strategies/good-carry-bad-carry | CITED (peer-reviewed paper) | Forex G10: `AUDUSD`, `NZDUSD`, `USDJPY`, `AUDJPY`, `NZDJPY`, `EURUSD`, `GBPUSD`, `USDCAD` | **MAYBE** — paper requires forward-looking 1M risk-reversal options-implied skew (NOT MT5-native); V4 doc adapts to backward-looking realized-skew proxy with separate academic support (Amaya et al. 2015). The thesis degrades — the V5 card would be a "named-resemblance variant", not the paper's strategy. Hard Rule 12 fit only via the proxy substitution. Overlap risk with existing V4 SM_076 / SM_1341–1363 carry family. CEO + Quality-Business call. |
| 3 | `modernising-turtle-trading.md` | Modernising the Turtle Trading Strategy | Faith, C. M. (2007). *Way of the Turtle: The Secret Methods That Turned Ordinary People into Legendary Traders.* McGraw-Hill. ISBN 978-0-07-148664-4 — and Dennis, R., & Eckhardt, W. (1983) *The Original Turtle Trading Rules* (private training material) — editorial: https://paperswithbacktest.com/strategies/turtle-trading-strategy | CITED (book + private training material with public re-publication) | Multi: FX majors + crosses, metals (`XAUUSD`, `XAGUSD`), indices (`GDAXI`, `NDX`, `WS30`, `SPX500`, `UK100`, `JPN225`), energy (`XTIUSD`, `XBRUSD`) | **YES** — archetypal mechanical donchian-breakout trend-follower; primary source is a published book (Faith 2007) plus the original 1983 Dennis-Eckhardt rules; modernisations (SMA(200) trend filter, no pyramiding) are reasonable and pre-flagged for P3 ablation. Strong V5 fit. |
| 4 | `seasonality-trend-mr-bitcoin.md` | Seasonality, Trend-following, and Mean Reversion — Bitcoin adaptation to XAUUSD + indices | Padysak, M., & Vojtko, R. (2022). *Seasonality, Trend-following, and Mean reversion in Bitcoin.* SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4081000 — editorial: https://paperswithbacktest.com/strategies/seasonality-trend-following-and-mean-reversion-in-bitcoin | CITED (SSRN paper) | Commodity (`XAUUSD`), indices (`GDAXI`, `NDX`, `WS30`) — adaptation only; the paper itself is BTC-specific and Darwinex has no `.DWX` crypto under Hard Rule 12 | **MAYBE** — primary source is BTC-only; the V4 doc does an asset-class transfer (BTC → XAUUSD + indices) which is a transfer-of-thesis exercise, not direct paper reproduction. The session-close seasonality leg may not survive on the TradFi cash-close window (the V4 doc itself flags this in §2). The two price-extreme legs (10-day MAX continuation, 10-day MIN reversion) are mechanical and transfer-plausibly. CEO + Quality-Business call: V5 card would be an inspired-by-Padysak-Vojtko variant on a non-paper universe. |
| 5 | `two-regime-trend-following.md` | Two-Regime Trend Following Rules (Zakamulin & Giner 2023) | Zakamulin, V., & Giner, J. (2023). *Optimal Trend Following Rules in Two-State Regime-Switching Models.* SSRN working paper: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4497739 — editorial: https://paperswithbacktest.com/strategies/optimal-trend-following-rules-in-two-state-regime-switching-models | CITED (SSRN working paper) | Multi: indices (`GDAXI`, `NDX`, `WS30`, `SPX`, `UK100`, `JPN225`), metals (`XAUUSD`, `XAGUSD`), energy (`XTIUSD`, `XBRUSD`), USD-bloc FX majors | **YES, with overlap-audit caveat** — primary source is a 2023 SSRN paper; the spec's net-new claim is a 2-state Gaussian HMM regime detector + posterior-blended bull/bear MA rule, with self-invalidating BIC / transition / mean-separation diagnostics. V4 doc explicitly flags overlap risk with SM_186 / SM_237 / SM_370 RegimeFiltered family and pre-registers a P3.5 head-to-head comparison. Strong V5 fit if the head-to-head sustains the net-new-edge claim per Hard Rule 11. |

## Folder summary

- **Files in folder:** 5 (`ath-breakout-atr-trail.md`, `good-carry-bad-carry.md`, `modernising-turtle-trading.md`, `seasonality-trend-mr-bitcoin.md`, `two-regime-trend-following.md`).
- **All 5 are CITED with traceable primary sources** (one practitioner paper, one published book + 1983 private training material, three SSRN papers). Zero `UNCITED` rows; zero `BLOCKED_NO_PRIMARY_SOURCE` flags.
- **No SM_XXX assignments** — the V4 docs leave `sm_id_assigned:` empty and have `pipeline_status: research`. So there are no V4-namespace EA names to migrate or alias; V5 cards (when authored) would each get a fresh `ea_id` (1000–9999) per Magic Formula registry.
- **Quality of V4 doc-authoring** — uniformly high. All five docs follow a consistent 10-section template (Thesis / Failure Hypothesis / Entry / Exit / Sizing / Indicators / Backtest Scope / Original Source / CTO Implementation / Pipeline Results), include explicit primary-source URLs and authors, label transfer-of-thesis caveats honestly, and pre-register failure tests + overlap-with-existing-family checks. This is the calibre of upstream concept material the T1.5 layer was registered for.

## Tier 2 work this T1.5 batch displaces in queue order

When QUA-423 (and any follow-on T1.5 dispatch) advances to SRC0N spawn, the displacement is concentrated on the **paper-class** containers in T2:

- **T2-07 (SSRN finance)** — three of the five V4 docs (good-carry-bad-carry, seasonality-trend-mr-bitcoin, two-regime-trend-following) are direct SSRN papers we already have a survey-grade write-up for. If those three become V5 cards (subject to OWNER + CEO ratification), they cover ~3 SSRN-paper-units of work that T2-07 would otherwise dispatch when it activates. T2-07 is not displaced wholesale — it is a paper container with hundreds of candidates — but the three highest-pre-vetted papers in it are now pre-surveyed.
- **T2-06 (arXiv q-fin)** — partial overlap: the regime-switching paper (Zakamulin & Giner) is the kind of work that arXiv q-fin would surface in T2 survey-pass. Pre-vetted here.
- **T2-03 (MESA Software / Ehlers papers)** — no overlap. T2-03 is signal-processing-rooted; the T1.5 batch is trend-follow / carry / regime / seasonality.
- **T2-02 (Adam Grimes blog)** — no overlap. Already partially surveyed under separate work; one card already drafted at `strategy-seeds/cards/grimes-pullback_card.md`.
- **T2-01 (MQL5 articles), T2-04 (Robot Wealth blog), T2-05 (Ernest Chan blog), T2-08 (Forex Factory), T2-09 (Babypips)** — no displacement; these are different source classes (practitioner blogs and forums) and contain different candidate strategies.

**Net effect on T2 queue:** T1.5 displaces a small handful of pre-identified high-quality SSRN candidates. The bulk of T2 (forum threads, blog archives, MQL5 articles, MESA papers) is unaffected and remains queued behind T1 + T1.5.

## What this survey does NOT do (per QUA-423 spec)

Per QUA-423's "Don't open SRC0N parents yet" section and the CEO authority cited (DL-017 + QUA-188 v3 waivers), this survey **does not** author SRC0N parent issues or new V5 Strategy Cards. The five candidate concepts above are surfaced for CEO + OWNER review only. SRC0N spawn waits for:

- Pipeline-Op matrix dispatcher live (sibling issue under QUA-400).
- Quality-Tech P2-threshold confirmation.

Otherwise, per the lesson from `paperclip_pipeline_needs_ea`, we would stack DRAFT cards Pipeline-Op cannot dispatch.

## Next steps

1. Comment on QUA-423 with the top-5 candidate summary (this survey's table is the body) and the Tier 2 displacement note.
2. Hold survey-pass on T1.5-02 (`G:\My Drive\QuantMechanica\MT5 Marketplace\`) and T1.5-03 (`G:\My Drive\QuantMechanica\Website\strategy-database\strategies\`) until CEO + OWNER ratify whether to widen the T1.5 survey-pass before any SRC0N opens.
3. When matrix dispatcher + P2 thresholds land, CEO + Quality-Business decide which of the 5 candidates above (the YES rows first; the MAYBE rows after explicit approval of the proxy / asset-class-transfer caveats) enter the active per-doc SRC queue.
