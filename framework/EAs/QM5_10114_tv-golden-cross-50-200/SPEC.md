# QM5_10114_tv-golden-cross-50-200 — Strategy Spec

**EA ID:** QM5_10114
**Slug:** `tv-golden-cross-50-200`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728`
**Author of this spec:** Development (Claude)
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Long entry fires when the 50-bar SMA crosses above the 200-bar SMA on the last closed H4 bar (golden cross). No short entries are taken. The position is held until the 50-bar SMA crosses below the 200-bar SMA (death cross), at which point the long is closed at market. A catastrophic stop-loss is placed 4×ATR(14) below the entry ask price to limit maximum drawdown per trade. Entries are skipped when the broker spread exceeds 10% of the protective stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 50 | 10–100 | SMA fast period for golden/death cross detection |
| `strategy_slow_period` | 200 | 50–500 | SMA slow period for golden/death cross detection |
| `strategy_atr_period` | 14 | 5–30 | ATR lookback for catastrophic stop sizing |
| `strategy_atr_sl_mult` | 4.0 | 2.0–8.0 | Stop distance = mult × ATR below entry |
| `strategy_spread_filter_pct` | 0.10 | 0.0–0.5 | Skip entry if spread > pct × stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index CFD; large-cap US equity; classic golden-cross venue (backtest-only)
- `NDX.DWX` — Nasdaq 100 index CFD; tech-heavy US equity; strong trend behaviour suits SMA crossover
- `WS30.DWX` — Dow Jones 30 index CFD; blue-chip US equity; diversifies US index exposure
- `GDAXI.DWX` — DAX 40 index CFD; European large-cap; ported from card's GER40.DWX (not in DWX matrix)

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; ported to GDAXI.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 |
| Typical hold time | days to weeks |
| Expected drawdown profile | low-frequency; single position at a time; stop at 4×ATR |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** forum/script
**Pointer:** ChartArt, "Golden Cross, SMA 200 Moving Average Strategy", TradingView, 2016-06-19, https://www.tradingview.com/script/6ZReHYKn-Golden-Cross-SMA-200-Moving-Average-Strategy-by-ChartArt/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10114_tv-golden-cross-50-200.md`

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
| v1 | 2026-06-10 | Initial build from card | 999d30ee-ad1f-4ab5-9758-1f6b5e658c94 |