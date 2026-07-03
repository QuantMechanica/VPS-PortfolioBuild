# D2-d Composite Package — OWNER Q12 Decision Package
**Date:** 2026-07-03  
**Task:** `106ed489-5914-497b-9ca0-9986372ec8d0`  
**Author:** Claude  
**Status:** REVIEW

---

## Purpose

Quantitative scenario analysis for the D2-d expansion of the live 13-sleeve D2-c book on
Darwinex Zero (account 4000090541, T_Live). Provides frozen-stream metrics for four
scenarios at constant total risk (9.75%) to inform OWNER's Q12 deployment decision.

No live changes, no T_Live writes. All presets are DRAFT_ONLY.

---

## Policy

| Parameter | Value |
|---|---|
| Total summed RISK_PERCENT | **9.75%** (invariant across all scenarios) |
| Per-sleeve hard cap | **1.0%** |
| Weighting | Capped inverse-volatility (iterative cap redistribution) |
| Base scenario | Variant-B-v2 snapshot `58c324cc-88a9-4e0e-bdbd-7fb941c5dfff` |
| Simulation capital | $100,000 |
| Span | 2017-10-19 → 2025-12-30 (~8.2 years, 99 months) |

---

## Scenario Definitions

| Scenario | Description | Sleeves |
|---|---|---|
| **S0** | Flat-13 baseline — current live book, 0.75% each | 13 |
| **S1** | Variant-B-v2 — capped inverse-vol, 13 sleeves | 13 |
| **S2** | D2-d-15 no-swap — S1 + admit 10919/XTIUSD + 10476/USDCAD, keep 10940 | 15 |
| **S3** | D2-d-15 swap — S2 with 10940/XAUUSD replaced by 12989/XAUUSD | 15 |

---

## Scenario Comparison Table

| Metric | S0 flat-13 | S1 Var-B-v2 | S2 15-no-swap | S3 15-swap |
|---|---:|---:|---:|---:|
| Annual return | **16.86%** | 10.61% | 12.10% | 12.68% |
| Sharpe | 1.442 | 1.674 | 1.978 | **2.027** |
| Max drawdown | 15.33% | 6.41% | 4.52% | 4.76% |
| Monthly VaR95 | 4.44% | 2.21% | 2.19% | **2.07%** |
| Worst day | -3.05% | -1.94% | -1.50% | -1.54% |
| Max pair-corr | n/a | n/a | 0.075 | 0.076 |
| Total net profit | $138,219 | $86,962 | $87,568 | $91,900 |
| Trade days | 1,800 | 1,800 | 1,824 | 1,826 |

**Key takeaways:**
- S0 has the highest raw return but unacceptable MaxDD (15.33%) — the DXZ book is VaR-filled; this is the status quo risk profile.
- S1 (Variant-B) halved MaxDD to 6.41% at cost of annual return. Already ratified 2026-07-03.
- **S2 further reduces MaxDD to 4.52%** by adding two uncorrelated diversifiers (+XTIUSD +USDCAD).
- **S3 improves Sharpe to 2.027** by swapping 10940 (grimes-nested-pb H4/XAU, 35 trades) for 12989 (exit-surgery challenger, 51 trades). MaxDD 4.76% vs S2 4.52% — marginal tradeoff.
- Max pair-corr remains below 0.08 for both S2 and S3 (well within the book's orthogonality target).

---

## Sleeve Risk Tables

### S2 — 15 Sleeves, No Swap (risk_pct from capped inverse-vol)

| ea_id | Symbol | Slug | TF | Magic | RISK_PERCENT | Capped |
|---|---|---|---|---|---:|---|
| 10440 | NDX.DWX | mql5-ohlc-mtf | H1 | 104400003 | 0.1498% | |
| 10476 | USDCAD.DWX | mql5-pamxa | H1 | 104760004 | 0.2175% | NEW |
| 10513 | XAUUSD.DWX | mql5-ichimoku | D1 | 105130003 | 0.8172% | |
| 10692 | NDX.DWX | tv-ls-ms | H1 | 106920005 | 0.2045% | |
| 10715 | USDJPY.DWX | tv-asian-box | M15 | 107150004 | 0.3786% | |
| 10911 | GDAXI.DWX | grimes-complex-pb | H1 | 109110003 | 0.2906% | |
| **10919** | **XTIUSD.DWX** | **grimes-overshoot** | **H4** | **109190001** | **1.0000%** | **CAPPED / NEW** |
| 10939 | GBPUSD.DWX | grimes-context-pb | H4 | 109390001 | 0.4137% | |
| 10940 | XAUUSD.DWX | grimes-nested-pb | H4 | 109400003 | 0.6406% | |
| 11132 | SP500.DWX | tm-cum-rsi2 | D1 | 111320000 | 1.0000% | CAPPED |
| 11165 | AUDCAD.DWX | weiss-rsi-ma | H1 | 111650002 | 1.0000% | CAPPED |
| 11421 | AUDUSD.DWX | ohlc-daily-squeeze-reversal-d1 | D1 | 114210003 | 0.8482% | |
| 11421 | EURUSD.DWX | ohlc-daily-squeeze-reversal-d1 | D1 | 114210000 | 0.7890% | |
| 12567 | XAUUSD.DWX | cum-rsi2-commodity | D1 | 125670003 | 1.0000% | CAPPED |
| 12567 | XNGUSD.DWX | cum-rsi2-commodity | D1 | 125670002 | 1.0000% | CAPPED |
| | | | | **Sum** | **9.7497%** | |

### S3 — 15 Sleeves, 10940→12989 Swap

| ea_id | Symbol | Slug | TF | Magic | RISK_PERCENT | Capped |
|---|---|---|---|---|---:|---|
| 10440 | NDX.DWX | mql5-ohlc-mtf | H1 | 104400003 | 0.1534% | |
| 10476 | USDCAD.DWX | mql5-pamxa | H1 | 104760004 | 0.2227% | NEW |
| 10513 | XAUUSD.DWX | mql5-ichimoku | D1 | 105130003 | 0.8366% | |
| 10692 | NDX.DWX | tv-ls-ms | H1 | 106920005 | 0.2094% | |
| 10715 | USDJPY.DWX | tv-asian-box | M15 | 107150004 | 0.3876% | |
| 10911 | GDAXI.DWX | grimes-complex-pb | H1 | 109110003 | 0.2975% | |
| 10919 | XTIUSD.DWX | grimes-overshoot | H4 | 109190001 | 1.0000% | CAPPED / NEW |
| 10939 | GBPUSD.DWX | grimes-context-pb | H4 | 109390001 | 0.4236% | |
| 11132 | SP500.DWX | tm-cum-rsi2 | D1 | 111320000 | 1.0000% | CAPPED |
| 11165 | AUDCAD.DWX | weiss-rsi-ma | H1 | 111650002 | 1.0000% | CAPPED |
| 11421 | AUDUSD.DWX | ohlc-daily-squeeze-reversal-d1 | D1 | 114210003 | 0.8684% | |
| 11421 | EURUSD.DWX | ohlc-daily-squeeze-reversal-d1 | D1 | 114210000 | 0.8078% | |
| 12567 | XAUUSD.DWX | cum-rsi2-commodity | D1 | 125670003 | 1.0000% | CAPPED |
| 12567 | XNGUSD.DWX | cum-rsi2-commodity | D1 | 125670002 | 1.0000% | CAPPED |
| **12989** | **XAUUSD.DWX** | **grimes-nested-pb-v2** | **H4** | **129890003** | **0.5431%** | **SWAP-IN** |
| | | | | **Sum** | **9.7501%** | |

---

## S2 Delta vs S1 (Variant-B-v2)

Risk shifts driven by the two new sleeves consuming 1.2175% of the total budget
(10919 hard-capped at 1.0%, 10476 gets 0.2175%), causing all existing sleeves to compress
proportionally:

| ea_id | Symbol | S1 risk% | S2 risk% | Delta |
|---|---|---:|---:|---:|
| 10440 | NDX.DWX | 0.1983% | 0.1498% | **−0.0485%** |
| **10476** | **USDCAD.DWX** | 0.0000% | 0.2175% | **+0.2175% NEW** |
| 10513 | XAUUSD.DWX | 1.0000% | 0.8172% | −0.1828% |
| 10692 | NDX.DWX | 0.2707% | 0.2045% | −0.0661% |
| 10715 | USDJPY.DWX | 0.5011% | 0.3786% | −0.1224% |
| 10911 | GDAXI.DWX | 0.3846% | 0.2906% | −0.0940% |
| **10919** | **XTIUSD.DWX** | 0.0000% | 1.0000% | **+1.0000% NEW** |
| 10939 | GBPUSD.DWX | 0.5475% | 0.4137% | −0.1338% |
| 10940 | XAUUSD.DWX | 0.8478% | 0.6406% | −0.2072% |
| 11132 | SP500.DWX | 1.0000% | 1.0000% | 0.0000% |
| 11165 | AUDCAD.DWX | 1.0000% | 1.0000% | 0.0000% |
| 11421 | AUDUSD.DWX | 1.0000% | 0.8482% | −0.1518% |
| 11421 | EURUSD.DWX | 1.0000% | 0.7890% | −0.2110% |
| 12567 | XAUUSD.DWX | 1.0000% | 1.0000% | 0.0000% |
| 12567 | XNGUSD.DWX | 1.0000% | 1.0000% | 0.0000% |

---

## Stream Provenance (Frozen Snapshot)

All 16 streams are frozen copies. SHA256 hashes are reproducibility anchors.

| File | Trades | SHA256 (first 32 hex) | Source |
|---|---:|---|---|
| 10440_NDX_DWX.jsonl | 441 | `1a14322430634065...` | V2_FROZEN |
| 10476_USDCAD_DWX.jsonl | 233 | `419878e3d1d551b1...` | DURABLE_ROOT |
| 10513_XAUUSD_DWX.jsonl | 22 | `af8d0241cd21e37a...` | V2_FROZEN |
| 10692_NDX_DWX.jsonl | 443 | `149e83d2b960949c...` | V2_FROZEN |
| 10715_USDJPY_DWX.jsonl | 1,466 | `18fa7348202f2edc...` | V2_FROZEN |
| 10911_GDAXI_DWX.jsonl | 268 | `de53d18052af3362...` | V2_FROZEN |
| 10919_XTIUSD_DWX.jsonl | 29 | `2dbbdd1d2eaab4af...` | DURABLE_ROOT |
| 10939_GBPUSD_DWX.jsonl | 92 | `55a54176330827c3...` | V2_FROZEN |
| 10940_XAUUSD_DWX.jsonl | 35 | `2ef38c1fdb3c9703...` | V2_FROZEN |
| 11132_SP500_DWX.jsonl | 43 | `acd06e79d182b7ff...` | V2_FROZEN |
| 11165_AUDCAD_DWX.jsonl | 173 | `f55cdf573588c71b...` | V2_FROZEN |
| 11421_AUDUSD_DWX.jsonl | 53 | `5741ec494c4aa8bb...` | V2_FROZEN |
| 11421_EURUSD_DWX.jsonl | 58 | `ab5e22d9a7dd4bde...` | V2_FROZEN |
| 12567_XAUUSD_DWX.jsonl | 28 | `2572cf8cf16d9dec...` | V2_FROZEN |
| 12567_XNGUSD_DWX.jsonl | 20 | `dc3a99581539e1a0...` | V2_FROZEN |
| 12989_XAUUSD_DWX.jsonl | 51 | `c1f56840d6fe7ba7...` | DURABLE_ROOT |

Full hashes in `d2d_composite_metrics_2026-07-03.json` → `stream_hashes`.

---

## Artifacts

| Artifact | Path |
|---|---|
| Metrics JSON | `D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/d2d_composite_metrics_2026-07-03.json` |
| Frozen streams | `D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/frozen_streams/QM/q08_trades/` |
| S2 live presets (DRAFT) | `D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/staged_live_presets_s2/` (15 files) |
| S3 live presets (DRAFT) | `D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/staged_live_presets_s3/` (15 files) |
| Compute script | `D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/compute_d2d_composite.py` |
| Evidence (this doc) | `C:/QM/repo/docs/ops/evidence/D2D_COMPOSITE_PACKAGE_2026-07-03.md` |

---

## Reproducibility

```
python D:/QM/strategy_farm/artifacts/portfolio/d2d_composite_2026-07-03/compute_d2d_composite.py
```

Deterministic: reads only frozen snapshot files. Output JSON SHA256 anchors all inputs.

---

## Risks / Blockers for OWNER

1. **10919/XTIUSD hard-capped at 1.0%** — high vol; contributes diversification but is
   the maximum allocation allowed. Position will be large relative to its trade count (29
   trades over 8 years).

2. **10476/USDCAD strategy_params incomplete** — `card_defaults_source=not_found` for
   10919; set file uses AO+Stoch params for 10476 (from card) but 10919 params are
   card-defaults pending. Codex must verify/inject correct params before live deploy.

3. **S3 adds a third XAUUSD sleeve** — alongside 10513/XAUUSD and 12567/XAUUSD.
   Total XAUUSD exposure in S3: 0.8366% + 0.5431% + 1.0000% = 2.3797%.  OWNER should
   confirm comfort with this concentration before choosing S3 over S2.

4. **Presets are DRAFT_ONLY** — header explicitly flags `DO_NOT_COPY_TO_T_LIVE_WITHOUT_SIGNED_OWNER_MANIFEST`.
   Deploying any scenario requires a signed manifest per T_Live governance.

5. **DXZ VaR-filled** — book is at capacity; expansion requires orthogonal sleeves
   (confirmed: max_pair_corr = 0.075–0.076), not risk increase.

---

## Recommendation (for OWNER Q12)

**S3 is the strongest portfolio on Sharpe (2.027) and monthly VaR95 (2.07%)**,
and preserves orthogonality (max pair-corr 0.076). The tradeoff vs S2 is a marginal
MaxDD increase (+0.24pp) in exchange for a meaningful Sharpe improvement (+0.05) and
lower tail risk. S3 also removes the low-trade-count 10940 (35 trades) for a more
statistically robust challenger (12989, 51 trades) with the same strategy family.

**If OWNER approves S3:** Codex must verify 10919 strategy params, generate the signed
manifest, and run the T_Live deploy workflow per `decisions/2026-07-01_t_live_d2c_13sleeve_book.md`.

**If OWNER prefers S2:** Same workflow; 10940 stays in the book.
