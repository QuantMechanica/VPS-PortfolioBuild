# QM5_9194_mql5-rvgi-cci — Strategy Spec

**EA ID:** QM5_9194
**Slug:** `mql5-rvgi-cci`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades mean-reversion reversals confirmed by three oscillator/trend conditions on the H1 timeframe. A long entry fires when price is below the 30-period SMA (mean-reversion context), the CCI(14) crosses upward out of oversold territory (previous bar CCI ≤ −100, current bar CCI > −100), and the RVGI main line crosses above its signal line on the same closed bar. Short entry is the mirror: price above SMA(30), CCI crosses downward from ≥ +100 to < +100, and RVGI main crosses below signal. Stop loss is set at ATR(14) × 1.5 from entry; take profit is 2R (twice the stop distance). An optional ATR(14) trailing stop activates once a position develops profit. Positions are also closed on an opposite-direction confluence signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 30 | 10–100 | SMA period for trend-filter reference |
| `strategy_cci_period` | 14 | 5–50 | CCI period for oscillator extreme-exit signal |
| `strategy_rvgi_period` | 10 | 5–30 | RVGI main-line SMA length |
| `strategy_atr_period` | 14 | 5–30 | ATR period for stop-loss sizing and trailing stop |
| `strategy_atr_sl_mult` | 1.5 | 0.5–4.0 | Stop loss = ATR × multiplier |
| `strategy_min_atr_ratio` | 0.5 | 0.1–1.0 | Skip trade if ATR(14) < median ATR(100) × ratio |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major liquid forex pair; sufficient H1 bar volume for CCI/RVGI reversal patterns
- `GBPUSD.DWX` — Major liquid forex pair; correlated volatility profile suitable for oscillator confluence
- `GDAXI.DWX` — DAX 40 index CFD; ported from GER40.DWX (not in dwx_symbol_matrix); GDAXI is the canonical DWX name for the German large-cap index

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; GDAXI.DWX used instead

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~24 |
| Typical hold time | Several hours to 1–2 days |
| Expected drawdown profile | Moderate; mean-reversion with ATR-scaled stops |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 50): Developing the RVGI, CCI and SMA Confluence Engine in MQL5", MQL5 Articles, 2025-11-19
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9194_mql5-rvgi-cci.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | 0f9c2953-91f6-4ad9-8c38-8e93b2fd09a0 |
