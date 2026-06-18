# QM5_1357_as-pragmatic-aa — Strategy Spec

**EA ID:** QM5_1357
**Slug:** `as-pragmatic-aa`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9` (see `strategy-seeds/sources/2df06de7-6a3a-5b06-9e6d-446d1a01fab9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

AllocateSmartly / Vojtko-Javorska "Pragmatic Asset Allocation" realized as its
mechanical core: a dual-momentum (relative + absolute) rotation across four
asset-class proxies with a monthly rebalance. On the first closed D1 bar of each
broker-time calendar month, each proxy is ranked by its 12-month price change
(252 D1 bars). A proxy is HELD long only if it ranks within the top 2 by momentum
AND it closed above its own 12-month simple moving average; otherwise that sleeve
goes to cash (flat). A held sleeve is exited at the next monthly evaluation when
it loses selection (drops out of the top-2 rank or falls below its 12-month SMA).
Long-only, ATR(20)×3.0 D1 protective stop per leg, no intramonth trailing/partial.

Each of the four proxies trades on its own magic slot (one position per magic per
leg) using the per-instance basket pattern; the cross-sectional rank is computed
across the whole basket from each instance after a single closed-D1-bar gate.

Note: the card's yield-curve regime branch (10y vs 3m Treasury) and its IEF/BIL
bond/T-bill defensive sleeves are NOT realizable on `.DWX` (no rate/bond/yield
feed — see § 3 and basket_manifest notes); the risk-vs-defensive switch is
realized implicitly by the absolute-momentum SMA filter routing non-trending
proxies to cash, with XAUUSD as the sole routable defensive asset class.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_lookback_days` | 252 | 60-504 | 12-month relative-momentum lookback in D1 bars |
| `strategy_sma_filter_days` | 252 | 60-504 | 12-month SMA absolute-momentum qualification length (D1 bars) |
| `strategy_top_n` | 2 | 1-4 | Number of top-ranked qualified proxies to hold each rebalance |
| `strategy_atr_period` | 20 | 5-100 | ATR length (D1) for the protective stop |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | ATR multiple for the per-leg protective stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100, equity risk proxy (maps card QQQ); live-tradable
- `WS30.DWX` — Dow 30, US large-cap equity proxy (maps card ACWI/broad); live-tradable
- `GDAXI.DWX` — DAX 40, ex-US developed-equity proxy (maps card EEM/global); live-tradable
- `XAUUSD.DWX` — gold, the routable defensive asset class (maps card GLD); live-tradable

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only / non-routable for live; omitted so the basket stays live-promotable
- Bond / T-bill symbols (IEF/BIL) — no routable `.DWX` bond proxy exists; dropped (FLAG)
- Treasury-rate / yield-curve inputs — no `.DWX` rate or yield feed (invariant #11); branch dropped (FLAG)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | cross-symbol D1 reads across the 4-proxy basket for ranking |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~4-12 (monthly rebalance; sleeve turnover only on rank/SMA changes) |
| Typical hold time | weeks to months (held to monthly rebalance) |
| Expected drawdown profile | moderate; absolute-momentum SMA filter de-risks to cash in downtrends |
| Regime preference | trend-following / tactical asset allocation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Source type:** paper (Quantpedia / SSRN) via AllocateSmartly strategy page
**Pointer:** https://allocatesmartly.com/pragmatic-asset-allocation-from-vojtko-and-javorska-of-quantpedia/ ; SSRN abstract_id=4487804
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1357_as-pragmatic-aa.md`

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
| v1 | 2026-06-18 | Initial build from card | claude-build-lane |
