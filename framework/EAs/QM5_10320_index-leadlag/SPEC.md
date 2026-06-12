# QM5_10320_index-leadlag - Strategy Spec

**EA ID:** QM5_10320
**Slug:** `index-leadlag`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades M1 index lead-lag moves during the US cash open and European close overlap windows. It reads the most recent closed M1 return for a leader index and opens a follower trade in the same direction when the leader move exceeds 0.20 x ATR(14) normalized by leader price and the follower has moved less than half that amount. Positions close after 5 M1 bars, or earlier if the follower catches up to 75% of the leader move or the leader reverses through zero. The stop is 0.60 x ATR(14) on the traded follower symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_leader_primary` | `SP500.DWX` | DWX symbol | Primary leader index. |
| `strategy_leader_secondary` | `NDX.DWX` | DWX symbol | Secondary leader index. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for signal threshold and follower stop. |
| `strategy_lead_atr_mult` | 0.20 | 0.01-5.00 | Normalized leader ATR threshold multiplier. |
| `strategy_follower_max_frac` | 0.50 | 0.00-1.00 | Maximum follower move already allowed at entry. |
| `strategy_catchup_frac` | 0.75 | 0.10-2.00 | Follower catch-up fraction that triggers exit. |
| `strategy_stop_atr_mult` | 0.60 | 0.10-5.00 | Follower ATR stop multiplier. |
| `strategy_max_hold_bars` | 5 | 1-60 | Maximum holding time in M1 bars. |
| `strategy_us_open_start_hhmm` | 1530 | 0000-2359 | Broker-time start of US cash-open window. |
| `strategy_us_open_minutes` | 60 | 1-1440 | Length of US cash-open window. |
| `strategy_eu_close_start_hhmm` | 1630 | 0000-2359 | Broker-time start of European close window. |
| `strategy_eu_close_minutes` | 60 | 1-1440 | Length of European close window. |
| `strategy_missing_bar_lookback` | 10 | 2-60 | M1 bar freshness check length. |
| `strategy_spread_samples` | 64 | 1-64 | Rolling samples per minute-of-day for spread percentile filter. |
| `strategy_spread_min_samples` | 5 | 1-64 | Warmup samples before enforcing the percentile threshold. |
| `strategy_spread_percentile` | 60.0 | 0-100 | Maximum rolling minute-of-day spread percentile. |
| `strategy_daily_stop_limit` | 3 | 1-20 | Stop-loss count that blocks new entries for the day. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX follower port for the card's GER40 leg.
- `UK100.DWX` - FTSE 100 follower leg named in the card.
- `SP500.DWX` - S&P 500 leader, registered for the full portable index basket.
- `NDX.DWX` - Nasdaq 100 leader and alternate US index leader.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable aliases; the canonical S&P 500 custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | `up to 5 M1 bars` |
| Expected drawdown profile | Intraday stopped trades capped by 0.60 x ATR and daily stop-count block. |
| Regime preference | Lead-lag momentum during US open / European close overlap. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** `paper`
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2225753`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10320_index-leadlag.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | 44c730cb-f5f2-4fc7-9f61-c976b114069d |
