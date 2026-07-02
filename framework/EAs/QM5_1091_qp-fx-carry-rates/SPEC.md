# QM5_1091_qp-fx-carry-rates - Strategy Spec

**EA ID:** QM5_1091
**Slug:** qp-fx-carry-rates
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

The EA trades a monthly FX carry ranking. At the first D1 bar of each new month, it ranks USD, EUR, GBP, JPY, AUD, CAD, CHF, and NZD by the configured central-bank policy-rate inputs. For each registered USD pair, it buys exposure to a non-USD currency in the top three rates and sells exposure to a non-USD currency in the bottom three rates, translating inverse USD quotes into the matching MT5 BUY or SELL side. Existing positions are closed at the next monthly rebalance; entries use a 5.0x D1 ATR(20) hard stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | >= 1 | D1 ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | 5.0 | > 0 | ATR multiplier used for stop distance. |
| `strategy_spread_days` | 20 | >= 0 | Number of prior D1 bars used for median spread. |
| `strategy_spread_mult` | 3.0 | > 0 | Blocks entry when current spread is above this multiple of median spread. |
| `strategy_rebalance_hour` | 1 | 0-23 | Earliest broker hour on day 1 when monthly rebalance may fire. |
| `strategy_rate_usd` | 5.25 | policy-rate percent | USD policy-rate table value. |
| `strategy_rate_eur` | 4.50 | policy-rate percent | EUR policy-rate table value. |
| `strategy_rate_gbp` | 5.25 | policy-rate percent | GBP policy-rate table value. |
| `strategy_rate_jpy` | 0.10 | policy-rate percent | JPY policy-rate table value. |
| `strategy_rate_aud` | 4.35 | policy-rate percent | AUD policy-rate table value. |
| `strategy_rate_cad` | 5.00 | policy-rate percent | CAD policy-rate table value. |
| `strategy_rate_chf` | 1.75 | policy-rate percent | CHF policy-rate table value. |
| `strategy_rate_nzd` | 5.50 | policy-rate percent | NZD policy-rate table value. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - USD-quoted EUR leg from the card universe.
- `GBPUSD.DWX` - USD-quoted GBP leg from the card universe.
- `USDJPY.DWX` - inverse-quoted JPY leg from the card universe.
- `AUDUSD.DWX` - USD-quoted AUD leg from the card universe.
- `USDCAD.DWX` - inverse-quoted CAD leg from the card universe.
- `USDCHF.DWX` - inverse-quoted CHF leg from the card universe.
- `NZDUSD.DWX` - USD-quoted NZD leg from the card universe.

**Explicitly NOT for:**
- Non-USD FX crosses - the card maps high/low-yield currencies against USD only.
- Non-FX `.DWX` symbols - the edge is a currency policy-rate carry ranking.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

Q02 queue repair note: obsolete H1 backtest setfiles from the initial May scaffold
were retired on 2026-07-02. This strategy is monthly/D1 by card and by
implementation; Q02 must use the seven `*_D1_backtest.set` files only.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | about one month |
| Expected drawdown profile | ATR-bounded FX carry drawdowns during carry unwind regimes |
| Regime preference | carry / cross-sectional ranking |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** Quantpedia encyclopedia
**Pointer:** https://quantpedia.com/strategies/fx-carry-trade and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1091_qp-fx-carry-rates.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1091_qp-fx-carry-rates.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | b5638b41-c48e-4743-bed6-f3fec4a782d2 |
| v2 | 2026-07-02 | Q02 queue repair | Removed stale H1 setfiles and re-pointed open Q02 rows to canonical D1 setfiles |
