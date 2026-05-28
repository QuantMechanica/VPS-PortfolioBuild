# QM5_10409_et-openpct-orb - Strategy Spec

**EA ID:** QM5_10409
**Slug:** `et-openpct-orb`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA records the mapped day-session open for each index CFD. At the afternoon arming time it calculates a buy stop at `SessionOpen * 1.0033` and a sell stop at `SessionOpen * 0.9967`, rounded to tick size. If price has already crossed one trigger at arming time, it enters at market in that direction. The unfilled opposite trigger is used as the protective stop, and any open trade is closed at the mapped 15:00 CST-equivalent exit time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_us_open_hhmm` | 1530 | 0-2359 | Broker-time US index session open used to record SessionOpen. |
| `strategy_us_arm_hhmm` | 2000 | 0-2359 | Broker-time US index arming time equivalent to 13:00 CST. |
| `strategy_us_last_entry_hhmm` | 2159 | 0-2359 | Latest broker time to place or trigger the daily bracket on US indices. |
| `strategy_us_exit_hhmm` | 2200 | 0-2359 | Broker-time US index time exit equivalent to 15:00 CST. |
| `strategy_dax_open_hhmm` | 900 | 0-2359 | Broker-time DAX session open used to record SessionOpen. |
| `strategy_dax_arm_hhmm` | 1330 | 0-2359 | Broker-time DAX arming time mapped by elapsed-session offset. |
| `strategy_dax_last_entry_hhmm` | 1529 | 0-2359 | Latest broker time to place or trigger the daily DAX bracket. |
| `strategy_dax_exit_hhmm` | 1530 | 0-2359 | Broker-time DAX time exit mapped by elapsed-session offset. |
| `strategy_buy_mult` | 1.0033 | >1.0 | Session-open multiplier for the buy trigger. |
| `strategy_sell_mult` | 0.9967 | 0.0-1.0 | Session-open multiplier for the sell trigger. |
| `strategy_atr_period` | 20 | 1+ | M1 ATR period for stop-distance rejection. |
| `strategy_max_stop_atr_mult` | 2.5 | >0.0 | Reject the day when trigger-to-trigger stop distance exceeds this ATR multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol; matches the source index-futures large-cap exposure and is valid for backtest.
- `NDX.DWX` - Nasdaq 100 index CFD; liquid US large-cap index proxy.
- `WS30.DWX` - Dow 30 index CFD; liquid US large-cap index proxy.
- `GDAXI.DWX` - DAX index custom symbol; nearest available DWX matrix symbol for the card's GER40 target.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.
- `SPX500.DWX` - unavailable phantom S&P 500 variant; canonical symbol is `SP500.DWX`.

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
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from afternoon trigger until opposite stop or mapped session exit. |
| Expected drawdown profile | Regime sensitive because fixed percentage triggers can overtrade low-volatility sessions. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/simple-system-for-beginners-monthly-results.39031/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10409_et-openpct-orb.md`

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
| v1 | 2026-05-25 | Initial build from card | bb1de9ee-dde2-4bc7-8d29-3508b0383d99 |
