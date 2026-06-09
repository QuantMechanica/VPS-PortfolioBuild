# QM5_10717_edgelab-xsec-fx-momentum - Strategy Spec

**EA ID:** QM5_10717
**Slug:** edgelab-xsec-fx-momentum
**Source:** Menkhoff, Sarno, Schmeling, Schrimpf (2012) and QuantMechanica Edge Lab Direction 1 thesis T1
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA runs as a single D1 FX8 basket strategy. On each Monday D1 rebalance it computes each of the eight major currencies' mean return versus the other seven currencies over 63 closed daily bars. It closes the prior basket, skips new exposure when basket realized volatility is in its trailing top decile, then opens two legs: long the strongest currency against the weakest, and long the second strongest against the second weakest. Each leg has a hard stop at 2.0 x ATR(20) on D1 and no take-profit, averaging, grid, or martingale logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_days` | 63 | >= 1 | D1 return lookback for currency strength ranking. |
| `strategy_rebalance_dow` | 1 | 0-6 | Broker day-of-week for weekly rebalance, with Monday = 1 in MT5. |
| `strategy_atr_period` | 20 | >= 1 | ATR period for hard per-leg stop placement. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple for hard stop distance. |
| `strategy_deviation_points` | 30 | >= 1 | Maximum execution deviation in points for basket orders. |
| `strategy_volfilter_enabled` | true | true/false | Enables the momentum-crash realized-volatility guard. |
| `strategy_vol_window` | 20 | >= 2 | D1 return window for realized volatility. |
| `strategy_vol_percentile_days` | 252 | >= 20 | Trailing sample used to estimate the volatility percentile. |
| `strategy_vol_skip_pct` | 0.90 | 0.0-1.0 | Skip threshold for top-decile realized volatility. |
| `strategy_max_spread_points` | 0 | >= 0 | Optional spread blocker; 0 keeps it disabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX8 pair used for host chart, ranking, volatility filter, and possible trade leg.
- `GBPUSD.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `AUDUSD.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `NZDUSD.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `USDJPY.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `USDCHF.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `USDCAD.DWX` - FX8 pair used for ranking, volatility filter, and possible trade leg.
- `EURGBP.DWX` - FX8 cross used for ranking and possible trade leg.
- `EURJPY.DWX` - FX8 cross used for ranking and possible trade leg.
- `EURCHF.DWX` - FX8 cross used for ranking and possible trade leg.
- `EURAUD.DWX` - FX8 cross used for ranking and possible trade leg.
- `EURNZD.DWX` - FX8 cross used for ranking and possible trade leg.
- `EURCAD.DWX` - FX8 cross used for ranking and possible trade leg.
- `GBPJPY.DWX` - FX8 cross used for ranking and possible trade leg.
- `GBPCHF.DWX` - FX8 cross used for ranking and possible trade leg.
- `GBPAUD.DWX` - FX8 cross used for ranking and possible trade leg.
- `GBPNZD.DWX` - FX8 cross used for ranking and possible trade leg.
- `GBPCAD.DWX` - FX8 cross used for ranking and possible trade leg.
- `AUDJPY.DWX` - FX8 cross used for ranking and possible trade leg.
- `AUDCHF.DWX` - FX8 cross used for ranking and possible trade leg.
- `AUDNZD.DWX` - FX8 cross used for ranking and possible trade leg.
- `AUDCAD.DWX` - FX8 cross used for ranking and possible trade leg.
- `NZDJPY.DWX` - FX8 cross used for ranking and possible trade leg.
- `NZDCHF.DWX` - FX8 cross used for ranking and possible trade leg.
- `NZDCAD.DWX` - FX8 cross used for ranking and possible trade leg.
- `CADJPY.DWX` - FX8 cross used for ranking and possible trade leg.
- `CADCHF.DWX` - FX8 cross used for ranking and possible trade leg.
- `CHFJPY.DWX` - FX8 cross used for ranking and possible trade leg.

**Explicitly NOT for:**
- Non-FX8 symbols - the ranking formula depends on USD, EUR, GBP, JPY, CHF, AUD, NZD, and CAD only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | About 1 week between Monday rebalances |
| Expected drawdown profile | FTMO-aware relative FX basket with volatility guard for momentum-crash periods |
| Regime preference | Cross-sectional currency momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** card frontmatter does not provide a separate source_id
**Source type:** paper and OWNER Edge Lab thesis
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10717_edgelab-xsec-fx-momentum.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10717_edgelab-xsec-fx-momentum.md`

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
| v1 | 2026-05-31 | Initial build from card | 9f1105b7-07e7-4d56-a977-20249cc7a79a |
| v2 | 2026-06-09 | Rebuild in place from approved card | 156f675d-d1ca-4dda-ba6e-97713eadab4b |
