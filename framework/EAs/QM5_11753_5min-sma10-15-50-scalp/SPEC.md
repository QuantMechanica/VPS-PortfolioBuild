# QM5_11753_5min-sma10-15-50-scalp — Strategy Spec

**EA ID:** QM5_11753
**Slug:** 5min-sma10-15-50-scalp
**Source:** 5fa014bc-031b-548a-8e5a-9b6ce6b1b2c1 (see `strategy-seeds/sources/5fa014bc-031b-548a-8e5a-9b6ce6b1b2c1/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the M5 chart using three simple moving averages. A long setup requires the last closed candle to close above SMA(50), SMA(10), and SMA(15), with its low above both short SMAs so the candle fully cleared them after the prior candle had not yet cleared the pair. A short setup is the mirror image: the last closed candle closes below all three SMAs, its high is below both short SMAs, and the prior candle had not yet cleared below the pair. Entries are market orders on the next bar; exits are the framework-managed SL/TP, with no additional discretionary close rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 10 | >=1 | Fast SMA used in the clearance test. |
| `strategy_mid_sma_period` | 15 | >=1 | Middle SMA used in the clearance test. |
| `strategy_trend_sma_period` | 50 | >=1 | Trend-bias SMA; price above is bullish and price below is bearish. |
| `strategy_atr_period` | 14 | >=1 | ATR lookback for factory SL/TP distances. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Stop-loss distance as a multiple of ATR(14). |
| `strategy_atr_tp_mult` | 4.0 | >0 | Take-profit distance as a multiple of ATR(14). |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card target; liquid major FX pair available in the DWX matrix.
- `GBPUSD.DWX` — card target; liquid major FX pair available in the DWX matrix.
- `USDJPY.DWX` — card target; liquid major FX pair available in the DWX matrix.
- `USDCHF.DWX` — card target; liquid major FX pair available in the DWX matrix.
- `AUDUSD.DWX` — card target; liquid major FX pair available in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` — the card specifies FX majors, not equity indices.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX` — metals and energy contracts are outside the card's FX scalping universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Not specified in frontmatter; expected to be short intraday because the source is a 5-minute scalping strategy. |
| Expected drawdown profile | Not specified in frontmatter; factory fixed-risk ATR stop caps individual trade risk. |
| Regime preference | Trend-following / momentum continuation after full candle clearance of SMA(10) and SMA(15). |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 5fa014bc-031b-548a-8e5a-9b6ce6b1b2c1
**Source type:** anonymous web/PDF strategy note
**Pointer:** `440084498-5-Minute-Forex-Scalping-Strategy-pdf.pdf`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_11753_5min-sma10-15-50-scalp.md`

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
| v1 | 2026-06-11 | Initial build from card | d7f223c3-fbaf-4245-9609-99afd8a858a6 |
| v2 | 2026-06-11 | Rework body-clearance interpretation after smoke trade-count review | 50e56bf2-04b6-4bdf-bab8-15ff816a076c |
| v3 | 2026-06-11 | Rework entry to require prior-bar SMA-pair cross plus card high/low clearance | acfba687-4608-4acc-8b48-b26b93630c5f |
