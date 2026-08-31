# QM5_1538_aa-tsmom-1-3-12 — Strategy Spec

**EA ID:** QM5_1538
**Slug:** `aa-tsmom-1-3-12`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md`
**Last revised:** 2026-08-31

## 1. Strategy Logic

At the first D1 bar of each calendar month, calculate raw price returns over
21, 63, and 252 closed daily bars as deterministic broker-data proxies for
one, three, and twelve months. Each positive return contributes `+1`, each
negative return `-1`, and an unavailable or exactly zero return contributes
`0`.

- Enter long when the aggregate is at least `+2`.
- Enter short when the aggregate is at most `-2`.
- Hold cash for aggregate values `-1`, `0`, or `+1`.
- At each monthly rebalance, close a long below `+2` and close a short above
  `-2`; reverse only after the existing position closes successfully.
- Initial stop distance is `3.0 * ATR(20,D1)`.
- There is no intramonth strategy exit or take-profit; the position is
  revalidated monthly, subject to framework safety exits.

The 21/63/252-day mapping and raw-return calculation are the documented DWX
broker-data approximation authorized by the card. No risk-free series,
volatility scaling, dynamic leverage, ML, grid, or martingale logic is used.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_D1` | D1 only | Strategy and rebalance timeframe |
| `strategy_atr_period` | `20` | `> 0` | D1 ATR period |
| `strategy_lookback_1_days` | `21` | `> 0` and below the 3-month lookback | One-month daily-bar proxy |
| `strategy_lookback_3_days` | `63` | Above the 1-month and below the 12-month lookback | Three-month daily-bar proxy |
| `strategy_lookback_12_days` | `252` | Above the 3-month lookback | Twelve-month daily-bar proxy |
| `strategy_min_history_bars` | `260` | At least `strategy_lookback_12_days + 1` | Fail-closed history minimum |
| `strategy_stop_atr` | `3.0` | `> 0` | Initial stop distance in ATR |

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX` — liquid DAX equity-index proxy named by the approved target universe.
- `NDX.DWX` — liquid Nasdaq-100 equity-index proxy named by the approved target universe.
- `SP500.DWX` — canonical S&P 500 custom symbol named by the approved target universe.
- `UK100.DWX` — liquid FTSE-100 equity-index proxy named by the approved target universe.
- `WS30.DWX` — liquid Dow-30 equity-index proxy named by the approved target universe.
- `XAUUSD.DWX` — liquid gold proxy for the source's commodity class.
- `EURUSD.DWX` — liquid major-FX proxy for the source's currency class.
- `GBPUSD.DWX` — liquid major-FX proxy for the source's currency class.
- `USDJPY.DWX` — liquid major-FX proxy for the source's currency class.
- `USDCHF.DWX` — liquid major-FX proxy for the source's currency class.
- `AUDUSD.DWX` — liquid major-FX proxy for the source's currency class.
- `USDCAD.DWX` — liquid major-FX proxy for the source's currency class.
- `NZDUSD.DWX` — liquid major-FX proxy for the source's currency class.

All 13 symbols are present in `dwx_symbol_matrix.csv` and have distinct active
magic slots. The card's old SP500 routability caveat is superseded by the
current framework contract; deployment remains outside this build and still
requires the later gates and OWNER authorization.

**Explicitly not included:** bond futures are unavailable in the DWX matrix.
The card's narrative R3 examples also mention silver and oil, but the explicit
frontmatter `target_symbols` list does not target them; this build follows that
authoritative 13-symbol list without expanding the card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` plus `QM_CalendarPeriodKey(PERIOD_MN1)` current/prior-key comparison |
| Decision cadence | First D1 bar of each calendar month |
| Signal data | Closed D1 bars only |
| History minimum | 260 closed D1 bars |

## 5. Expected Behaviour

The EA should make at most one directional rebalance decision per symbol per
month. It holds an existing qualifying trend, exits a signal that no longer
has two agreeing horizons, and reverses only after a successful close. It
remains in cash when no two horizons agree. Intramonth price movement cannot
change the strategy signal; only framework safety controls remain active.

| Metric | Expected behaviour |
|---|---|
| Trades / year / symbol | `100` in card frontmatter; inconsistent with the monthly mechanic's maximum 12 entry decisions and flagged for reviewer/Q02 adjudication |
| Expected trade frequency | Not supplied in card frontmatter; the mechanical body permits one rebalance decision per month |
| Typical hold time | Not supplied in card frontmatter; mechanically one month or longer while at least two horizons retain direction |
| Regime | Not supplied in card frontmatter; the card body identifies persistent directional trends as the intended regime |
| Expected drawdown profile | Trend-following whipsaw losses in choppy regimes, bounded per trade by the initial 3 ATR stop |

### Framework alignment

| Card rule | Implementation surface |
|---|---|
| Monthly rebalance | `Strategy_EntrySignal` and `Strategy_ExitSignal` compare current/prior `QM_CalendarPeriodKey(PERIOD_MN1)` values |
| 1/3/12 return votes | `Strategy_EntrySignal` and `Strategy_ExitSignal` use pooled `QM_SMA(...,1,shift)` close readers |
| Long/short/cash thresholds | `Strategy_EntrySignal` and `Strategy_ExitSignal` |
| 3 ATR initial stop | `Strategy_EntrySignal` using framework `QM_StopATR` |
| One position per symbol/magic | `QM_TM_OpenPositionCount` plus framework entry checks |
| Fixed-risk backtest | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| News and operational safety | Canonical V5 skeleton news, kill-switch, Friday-close, and MAE hooks |

## 6. Source Citation

The approved card attributes the mechanic to Larry Swedroe's Alpha Architect
summary of Hurst, Ooi, and Pedersen's long-run trend-following evidence. The
durable source/card identity is `ede348b4-0fa7-5be1-baa8-09e9089b67b7` and
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md`.
R1 lineage is recorded and R2–R4 are PASS per
`artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | `32fe6e27-d811-4e58-947b-fe78e0269ee3` |
| v2 | 2026-08-31 | Use pooled framework readers, restart-safe monthly boundaries, and canonical entry-only news ordering | `b8761494-8807-41d8-b4a0-f1d4141588c4` |
