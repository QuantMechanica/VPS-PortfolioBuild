---
ea_id: QM5_12615
slug: tsmom-12m-cross-asset-basket
type: strategy
source_id: e5a3f925-5a9e-513d-9e70-5c7c70fa0e59
sources:
  - "[[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]"
target_symbols: [EURUSD.DWX, NDX.DWX, XAUUSD.DWX, XTIUSD.DWX]
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cross-asset-diversification]]"
  - "[[concepts/volatility-scaling]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/lookback-return]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (e5a3f925) referencing Moskowitz-Ooi-Pedersen JFE 2012 Section V with direct AQR URL; no secondary sources."
r2_mechanical: PASS
r2_reasoning: "Monthly sign(close[0] > close[252]) × vol-scalar per slot with ATR stop; 4 bounded magic slots; vol-resize trigger is deterministic (>25% scalar drift); no discretion."
r3_data_available: PASS
r3_reasoning: "EURUSD, NDX.DWX, XAUUSD, and XTIUSD.DWX are all live-tradable Darwinex CFD instruments; bond slot legitimately replaced by XTIUSD."
r4_ml_forbidden: PASS
r4_reasoning: "Vol-scalar uses only price-history stddev; optional correlation guard is also price-history only; four bounded magic slots enforce 1-position-per-magic; no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single MOP/JFE source_id+URL; R2 PASS deterministic monthly 252D return-sign plus vol-scaling per slot with ATR stop and 4 bounded magics, basket cadence supports >=2 trades/yr; R3 PASS EURUSD/NDX/XAUUSD/XTIUSD.DWX; R4 PASS no ML/PnL-adaptive sizing/martingale."
expected_pf: 1.3
expected_dd_pct: 18.0
---

# TSMOM 12-Month Cross-Asset Vol-Scaled Basket — EURUSD + NDX + XAUUSD + XTIUSD

## Quelle

- Source: [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- Paper: Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial
  Economics*, 104(2), 228–250.
- URI: https://www.aqr.com/insights/research/journal-article/time-series-momentum
- Key reference: Section V — "TSMOM Portfolio" — the paper's main result: a diversified
  vol-scaled TSMOM basket across equities, bonds, currencies, and commodities achieves
  annualized Sharpe ~1.4 (1985–2009), with maximum drawdown much lower than any single
  asset class alone. This card implements the cross-asset spirit using 4 available DWX
  instruments spanning FX (EURUSD), equity index (NDX.DWX), gold (XAUUSD), oil (XTIUSD).

## Mechanik

The paper's key result is that TSMOM's Sharpe ratio is dramatically amplified by combining
signals across uncorrelated asset classes using volatility-scaled sizing. The vol-scaling
ensures each asset contributes equal risk, not equal dollar exposure. This card implements
that directly with 4 DWX instruments (replacing the paper's bonds with oil, since bonds are
not available in DWX).

### Entry

On first bar of each calendar month, for each of the 4 assets:

```
lookback_bars = 252    // D1 bars ≈ 12 months
vol_window    = 63     // trailing vol estimation window (approx 3 months)
target_vol    = 0.10   // 10% annualized portfolio target vol (evenly allocated)
slot_target   = target_vol / 4  // 2.5% annualized target vol per slot

// Per-slot signal (independent of other slots)
signal[asset] = close_asset[0] > close_asset[lookback_bars] ? +1 : -1

// Per-slot realized vol
realized_vol[asset] = stddev(log_returns_asset, vol_window) × sqrt(252)

// Per-slot size scalar
vol_scalar[asset] = Min(slot_target / Max(realized_vol[asset], 0.005), 2.0)

// Final lot = base_lot × vol_scalar[asset] × signal[asset]
```

Magic number allocation (1-pos-per-magic):
- Slot 1: EURUSD → magic = ea_id × 10000 + 1
- Slot 2: NDX.DWX → magic = ea_id × 10000 + 2
- Slot 3: XAUUSD → magic = ea_id × 10000 + 3
- Slot 4: XTIUSD → magic = ea_id × 10000 + 4

Each slot trades independently. A slot is always active (either long or short) — positions
are only closed when direction reverses or SL is hit.

### Exit

Monthly rebalance per slot. Hard SL applies per slot intra-month.
Vol resizing at monthly check: if vol_scalar changes by > 25% vs current lot's implied scalar,
close and reopen at new size (this handles vol regime changes within a trend direction).

### Stop Loss

Per slot, ATR-based: SL = entry_price ± ATR(14, D1) × 3.0.
Different ATR values per instrument are expected (gold much larger than EURUSD pip scale —
this is handled by the vol-scalar and lot sizing).

### Position Sizing

RISK_FIXED = $1000 for backtest baseline (total across all 4 slots).
Per-slot base risk: $250.
Vol-scalar applied multiplicatively: effective per-slot risk = $250 × vol_scalar[asset].
Codex should compute base_lot from RISK_FIXED=250 per slot / (ATR(14) × point_value),
then apply vol_scalar before placing orders.

### Zusätzliche Filter

- Monthly trigger: `Month(Time[0]) != Month(Time[1])`
- News filter: standard QM news-blackout per active slot instrument
- Spread filter: skip entry if spread > 3× median spread for that instrument
- Correlation guard (optional, P3 sweep): if rolling 30-day correlation between any 2 active
  same-direction slots exceeds 0.80, reduce the smaller slot's size by 50%. This prevents
  inadvertent concentration in correlated crisis regimes. Implement as a configurable parameter
  (default: disabled; threshold: 0.80).

## Basket EA Notes

4-symbol basket EA. Serialized to ≤1 active in factory at a time per multi-symbol policy.
Codex implements as a single EA running on any chart, with 4 independent OnTick/OnBar handlers.
This is the richest card in this batch and most directly reflects the paper's main empirical result.

## Concepts

- [[concepts/time-series-momentum]] — primary; 12-month canonical signal across 4 asset classes
- [[concepts/cross-asset-diversification]] — primary; the key Sharpe amplification mechanism
- [[concepts/volatility-scaling]] — per-slot vol-targeted sizing as in MOP eq. (1)
- [[concepts/trend-following]] — secondary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named AQR authors, peer-reviewed JFE 2012, direct URL; Section V of paper is the specific basis |
| R2 Mechanical | PASS | Fully deterministic: sign(12m return) × vol-scalar per slot; monthly rebalance; bounded positions |
| R3 Data Available | PASS | EURUSD, NDX.DWX, XAUUSD, XTIUSD all live-tradable DWX instruments; bond slot replaced by XTIUSD |
| R4 ML Forbidden | PASS | Deterministic; rolling stddev only; 4 slots bounded; no martingale; vol-scalar is price-history only |

## Bond Slot Note

The paper uses 24 government bond futures across maturities in its diversified portfolio.
DWX CFD does not offer bond instruments. XTIUSD (WTI crude oil) is used as a commodity
replacement that maintains cross-asset diversification benefits. The paper also shows strong
commodity TSMOM (Table 2), so this substitution is justified within the paper's evidence.

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from MOP (2012) Section V, batch 1

## Verwandte Strategien

- [[strategies/QM5_12611_tsmom-12m-fx-sign-eurusd]] — single-asset 12m sign, EURUSD slot
- [[strategies/QM5_12612_tsmom-12m-vol-scaled-ndx]] — single-asset vol-scaled, NDX slot
- [[strategies/QM5_12613_tsmom-3m-commodity-xauusd]] — 3m commodity signal, XAUUSD slot
- [[strategies/QM5_12614_tsmom-6m-fx-basket-3pair]] — 6m FX-only basket

## Trade Frequency Note

Per slot: ~8 direction changes/year at 12-month lookback. Each slot is independently active
(always long or short), so there is no idle period. Across 4 slots: ~32 slot-level events/year.
For pipeline counting, each slot's trades are counted separately.

## Portfolio Correlation Note

The 4 assets chosen have historically low (or negative) pairwise correlations during trend phases:
- EURUSD/NDX: often inversely related (risk-on/off flows)
- XAUUSD/NDX: typically negative beta during stress
- XTIUSD/EURUSD: moderate positive in commodity-driven USD moves, otherwise low

This multi-directional structure means the basket can outperform single-asset TSMOM even
when 2 of 4 slots are on the losing side of their respective trends. The paper documents this
empirically: the cross-asset TSMOM Sharpe ≈ sum-of-singles Sharpe × sqrt(diversification ratio).

## Lessons Learned

*(populate during pipeline runs)*
