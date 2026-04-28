# V5 Portfolio Fit Baseline — 2026-04-28

> Author: Quality-Business agent (`0ab3d743`).
> Issue: QUA-431 — first issue on spawn per `paperclip-prompts/quality-business.md` Charter § "First Issues on Spawn".
> Purpose: snapshot the V5 portfolio composition so future Strategy Card G0 reviews are measured against actual portfolio shape, not abstract caps.
> Scope: ratified Strategy Cards in build / pilot as of 2026-04-28. Not a P9 portfolio-construction artifact.

## 1. In-scope strategies

Source of truth for ratified ea_id allocations: `framework/registry/ea_id_registry.csv` at main `347f1fa5` and the QUA-308 reconciliation note (`docs/ops/QUA-308_EA_ID_REGISTRY_RECONCILIATION_2026-04-28.md`). Card-status fields drift across worktrees — registry status `active` + QUA-276 CEO interim-G0-APPROVED is the binding signal for SRC01_S01..S05. SRC04 S02a/S02b are `DRAFT` cards but in pilot per QUA-390.

Excluded from snapshot (advisory):
- `1001 breakout-atr` (`strategy_id: TBD`) — framework smoke EA, not a ratified strategy.
- All other DRAFT cards under `strategy-seeds/cards/` not in pilot or build (Chan SRC02/SRC05 batch, Lien SRC04 cards beyond S02a/S02b, etc.) — they have not crossed G0.

## 2. Per-strategy attributes

| ea_id | strategy_id | slug | author | timeframe | market | style | g0_status |
|---|---|---|---|---|---|---|---|
| 1002 | SRC01_S01 | davey-eu-night | Davey (2014 App B) | M105 (105-min bars) | currency_futures (Darwinex proxy: EURUSD.DWX) | mean-reversion (intraday limit-order) | APPROVED (CEO interim, QUA-276) |
| 1006 | SRC01_S02 | davey-eu-day | Davey (2014 App C) | H1 (60-min bars) | currency_futures (Darwinex proxy: EURUSD.DWX) | mean-reversion (momentum-gated) | APPROVED (CEO interim, QUA-276) |
| 1003 | SRC01_S03 | davey-baseline-3bar | Davey (2014 App A § Strategy 1) | TBD (sweep H1/H4/D1/W1; D1 default) | TBD (instrument-agnostic; CTO-pick basket: US500 / EURUSD / GOLD candidates) | mean-reversion (3-bar consecutive-direction reversal) | APPROVED (CEO interim, QUA-276) |
| 1004 | SRC01_S04 | davey-es-breakout | Davey (2014 App A § Strategy 4) | TBD (chart `_Period`; ES daily lineage → D1 default) | equity_index (Darwinex proxy: US500.DWX) | breakout (range-break + reverse-on-opposite) | APPROVED (CEO interim, QUA-276) |
| 1005 | SRC01_S05 | davey-worldcup | Davey (2014 Ch 3) | D1 (daily bars) | multi-asset futures basket (currency / equity-index / rates / agri / metal — pending Darwinex proxy mapping at G0 implementation) | trend-following (48-bar close-breakout, 30-bar RSI-filtered) | APPROVED (CEO interim, QUA-276) |
| TBD | SRC04_S02a | lien-dbb-pick-tops | Lien (2015 Ch 9) | D1 (NY 17:00 close) | forex (EURUSD / USDJPY / GBPUSD / USDCHF / AUDUSD / NZDUSD / USDCAD) | mean-reversion (Bollinger-band reclaim from outer-band zone) | DRAFT card; in pilot via QUA-390 |
| TBD | SRC04_S02b | lien-dbb-trend-join | Lien (2015 Ch 9) | D1 (NY 17:00 close) | forex (USDJPY / GBPUSD / EURUSD / USDCHF / AUDUSD / NZDUSD / USDCAD) | breakout / trend-join (Bollinger-band reclaim after 2-bar opposite dwell) | DRAFT card; in pilot via QUA-390 |

Total in-scope: **7 strategies** (5 Davey-derived + 2 Lien pilot).

Counting convention for caps: each strategy_id counts once; multi-instrument baskets (S05) count under their broadest market category, with a secondary breakdown noted. Equal-weighting used because no V5 P9 portfolio weights have been ratified yet — this is a count-based shape baseline, not an equity-weighted distribution.

## 3. Cap-utilization analysis

### 3.1 Timeframe distribution (cap: max 30% in any single timeframe)

| Timeframe | Count | % | Strategies |
|---|---|---|---|
| D1 | 3 (5 with S03/S04 defaults) | 43% (71%) | S05 + Lien S02a + Lien S02b (+ S03 / S04 if defaults stand) |
| H1 (60-min) | 1 | 14% | S02 |
| M105 (105-min, nonstandard) | 1 | 14% | S01 |
| TBD (sweep / chart-period) | 2 | 29% | S03, S04 |

- Cap utilization (lower-bound, only TF-specified strategies counted): **D1 = 43%, exceeds 30% cap by 13 pts.**
- Cap utilization (upper-bound, S03 + S04 default to D1): **D1 = 71%, exceeds 30% cap by 41 pts.**
- Headroom on H1: 16 pts. Headroom on M105: 16 pts.

**Risk flag:** under the upper-bound assumption (S03 D1 default + S04 ES daily default), the V5 portfolio shape is heavily D1-clustered. The cap was designed to prevent a single market-day timing window from dominating fill / news risk. Mitigation paths at P3 sweep: push S03 to H4 default if edge survives, and/or accept the cluster with a documented risk-mode override at P9.

### 3.2 Market distribution (cap: max 40% in any single market)

| Market | Count | % | Strategies |
|---|---|---|---|
| forex / currency_futures (EUR-pair-dominant) | 4 | 57% | S01, S02, Lien S02a, Lien S02b |
| equity_index | 1 | 14% | S04 |
| multi-asset basket | 1 | 14% | S05 |
| TBD (instrument-agnostic) | 1 | 14% | S03 |

- Cap utilization: **forex / currency_futures = 57%, exceeds 40% cap by 17 pts.**
- Within-forex concentration: **EUR-pair (S01, S02 both EURUSD; Lien S02a/S02b examples include EURUSD as primary) is structurally the dominant exposure.** Even if S02a/S02b deploy on a multi-major basket, three of four forex strategies anchor on EURUSD examples in source.
- Headroom on equity_index: 26 pts. Headroom on multi-asset basket: 26 pts.

**Risk flag:** the 57% forex weight is largely an artifact of source choice (Davey App B/C are explicitly Euro futures; Lien Ch 9 is FX-only). Future Strategy Card G0 reviews should weight non-forex sources (e.g., Chan SRC05 equity / futures / pair-trading) to rebalance.

### 3.3 Style distribution (cap: max 50% in any single style)

| Style | Count | % | Strategies |
|---|---|---|---|
| mean-reversion | 4 | 57% | S01, S02, S03, Lien S02a |
| trend-following / breakout | 3 | 43% | S04, S05, Lien S02b |

- Cap utilization: **mean-reversion = 57%, exceeds 50% cap by 7 pts.**
- Headroom on trend / breakout: 7 pts.

**Risk flag:** mean-reversion edge tends to share regime-failure modes (volatility spike / trend continuation past mean). 57% mean-reversion concentration means a single regime shift can hit four strategies simultaneously — this is the most worrying concentration of the three caps from a portfolio-survivability angle.

## 4. Cap-violation summary (advisory — no retroactive G0 rejection)

| Cap | Limit | Current (lower / upper) | Status |
|---|---|---|---|
| Timeframe | 30% max in any one TF | 43% / 71% D1 | OVER |
| Market | 40% max in any one market | 57% forex (EUR-cluster) | OVER |
| Style | 50% max in any one style | 57% mean-reversion | OVER |

All three binding caps are currently exceeded. Per task boundary (`## Boundary` in QUA-431), no retroactive G0 rejection is implied; this is the measurement baseline.

## 5. Implications for forward G0 reviews

QB will apply these baseline numbers to upcoming Strategy Card reviews (SRC02 Chan QT, SRC03 Williams, SRC04 Lien beyond S02a/b, SRC05 Chan AT WS, T1.5/T2/T3 future cards):

1. **Bias toward non-forex / non-D1 cards.** A D1 forex mean-reversion card going forward needs a clearly differentiated edge mechanism vs the existing four mean-reversion D1/H1 forex strategies, or REJECTED on `duplicate-archetype`.
2. **Bias toward non-mean-reversion styles.** A mean-reversion card needs to demonstrate a meaningfully different trigger family (not "yet another Bollinger band reclaim") to clear `duplicate-archetype`.
3. **Equity-index, commodity, pair-trade, statistical-arb cards have natural headroom** and should be processed without portfolio-fit drag (still need edge / source / verifiable-claim checks).
4. **Multi-asset basket strategies (like S05) carry a counting ambiguity.** QB will need a P9 weighting policy from OWNER + CEO before this baseline can convert to equity-weighted percentages. For now, count-based equal-weighting is the binding convention.

## 6. Open questions for CEO + OWNER

- Q1: Equal-weight vs proposed-magic-allocation weighting for cap counting? (`paperclip-prompts/quality-business.md` § "Portfolio-fit metrics" reads as equity-weighted; current snapshot is count-weighted because no V5 weights are ratified.)
- Q2: Does S05's multi-asset basket count as one strategy or N strategies (one per instrument)? Current baseline counts as one.
- Q3: Are the 3 "OVER" caps an immediate stop-gate for new SRC02 / SRC04 / SRC05 cards in the same archetype, or are they advisory until V5 enters P9? QB recommends advisory for build, gating at P9.
- Q4: SRC04 Lien S02a/S02b are pilot-status (DRAFT cards). Should they count toward cap baselines pre-pilot completion? Current baseline includes them (consistent with task scope).

## 7. Next-action

- QUA-431: comment with file path + commit SHA, leave issue `in_review` for CEO acknowledgement.
- QB onboarding 2 (separate issue): define reputable-source criteria with CEO + OWNER.
- QB onboarding 3 (separate issue): propose first month's review template.
- Future heartbeat: refresh this baseline whenever a new G0 APPROVED card lands or a P9 portfolio decision is taken. Filename pattern: `portfolio_baseline_<YYYY-MM-DD>.md`.

— End of baseline.
