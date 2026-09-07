# QM5_11421 Signature Panel v3 canary

- Router task: `4bdcbb91-075f-4e93-b4b6-294c0d5776ab`
- OWNER instruction: `2026-09-07T07:00:00Z`
- Date: `2026-09-07`
- State: `REVIEW`
- Scope: presentation-only source revision, artifact-only compile, and FTMO demo-only install

## Result

Signature Panel v3 replaces the uniform v2 text block with a real table hierarchy. On charts at least 1200 pixels wide it uses two 524-pixel columns inside a 1090-by-550 panel; narrower charts use the same sections in one 548-by-970 stacked column. Section bars, separate left-aligned labels, right-aligned values, 20-pixel row rhythm, Consolas numeric values, and limited semantic colour make the surface scannable without changing trading logic.

The first two lines answer the primary questions: whether the EA may trade and the exact per-magic net P/L. The full hierarchy is `STATE`, `PERFORMANCE`, `RISK / ROOM`, `POSITION / ORDERS`, `NEXT`, `HEALTH`, and `IDENTITY`.

## Design research

The requested design skill was not installed in this headless lane, so the implementation used a first-party online reference study plus the repository's v2 information architecture. Seven references were reviewed before implementation.

| Reference | What was adopted | What was rejected |
|---|---|---|
| [MQL5 Trade Dashboard MT5](https://www.mql5.com/en/market/product/80097), rated 4.95 at review time | Compact on-chart risk, P/L, position, and limit visibility; clear grouping around risk management | Trading buttons, close-all actions, basket/grid controls, hotkeys, external promotion, and any state-changing UI |
| [MQL5 EA Dashboard MT5](https://www.mql5.com/en/market/product/162320) | Performance inventory: win rate, profit factor, expectancy, average win/loss, streaks, drawdown, and daily stats | User-defined analytical values without an explicit history provenance contract and alert/action controls |
| [MQL5 Breakout Panel EA](https://www.mql5.com/en/market/product/151231) | Simple white bordered panel and at-a-glance tabular grouping | Multi-symbol scanner controls, arrows/emojis, and non-ASCII object text |
| [FTMO Account MetriX](https://ftmo.com/en/blog/account-metrix-a-tool-for-analysing-and-improving-your-trading/) | Balance, equity, unrealised P/L, open-trade direction/size/time/P&L/duration, and performance stability as primary facts | Journal, screenshots, and large charts that do not fit a compact EA overlay |
| [FTMO Trading Objectives](https://ftmo.com/en/trading-objectives/) | Daily-loss and maximum-loss room belong near the trading decision | Pretending an EA-local sleeve value is account-level room when the governor is unbound |
| [IBKR TWS Monitor panel](https://www.interactivebrokers.com/campus/trading-lessons/getting-started-with-monitor-panel/) | Group headers, stable columns, portfolio P/L near account values, and colour only for directional/state meaning | Sorting, configuration menus, tabs, and interactive order controls |
| [Material Design data tables](https://m1.material.io/components/data-tables.html) | Left-aligned text labels, right-aligned numeric values, consistent row spacing, and low-contrast rules | Hover, selection, menus, and other web interaction states unavailable or inappropriate in a read-only MT5 overlay |

## Data and refresh contract

Performance is computed only from terminal deal history after `HistorySelect(0, TimeCurrent())`:

- Deals are filtered by the resolved logical magic.
- Cash result is the exact sum of `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE`.
- Deals are grouped by `DEAL_POSITION_ID`; identifiers still open are excluded from closed-trade statistics.
- Closed trades are ordered by actual close time for best/worst, last result, and current/longest win/loss streaks.
- Maximum drawdown is peak-to-trough on the cumulative closed-P/L curve, with current floating P/L for the same magic appended as the final curve point. Its percentage denominator is the exact equity captured when the panel attaches.
- Account today's P/L is the cash result of all buy/sell deals since broker-day midnight; the remaining performance fields are scoped to this magic.
- History is scanned at most every 30 seconds. `OnTradeTransaction` only invalidates the cache; rendering and the next scan remain on `OnTimer`. There is no history scan or panel call in `OnTick`.
- History failure renders `N/A (history unavailable)` and cannot fail EA initialization or change an order.

## Shared formats

One formatter family in `QM_ChartPanel.mqh` supplies every panel number:

- Numbers: `100.000,00`
- Percentages: `0,31 %`
- Money: account currency plus signed de-DE value, for example `EUR +12.345,67`
- Pips: one decimal, for example `0,2 pip`
- Durations: `hh:mm`, including durations beyond 24 hours
- Broker datetimes: `yyyy-mm-dd hh:mm BT`

`QM_PanelFormatterSelfTest()` is executed by the native header compile probe and covers grouping, decimal commas, negative values, percentages, and duration output.

## Full panel mockup

The values below are realistic samples, not runtime evidence. Every final section is filled to make the intended hierarchy and alignment reviewable without attaching the EA.

```text
QM | QUANTMECHANICA
Trading NO | Net P/L EUR +12.345,67

STATE | MAY I TRADE?                         POSITION / ORDERS | THIS MAGIC
Trading             NO | NEWS_BLACKOUT       Position 1  EURUSD.DWX BUY 0,80 @ 1.16420 | SL 1.15820 TP 1.17620 | EUR +428,40 (+0,11 %) | 18:42
News       BLOCK | LIVE MT5 NATIVE |          Position 2  NONE
             HIGH USD event/name unavailable Position 3  NONE
             in 00:18                         Order 1     EURUSD.DWX ORDER_TYPE_BUY_STOP 0,80 @ 1.16920 | SL 1.16120 TP 1.17920 | EXP 2026-09-08 00:00 BT
Governor  UNBOUND | legacy execution contract Order 2     NONE
Kill switch                         ARMED      Order 3     NONE
Filters    FRI OK 108:31 | SPREAD PASS
           0,2 pip/25,0 pip | SESSION N/A     NEXT
                                               Next decision  2026-09-08 00:00 BT | 14:31
PERFORMANCE | THIS MAGIC                       Last signal    NONE | squeeze_not_ready | 2026-09-07 00:00 BT
Trades T/A/All                  2 / 7 / 124
Wins / losses              83 / 41 | 66,94 %  HEALTH
Net P/L       EUR +12.345,67 | +3,09 % attach EQ
Gross + / -           EUR +18.000,00 / EUR -5.654,33
PF / expectancy       3,18 / EUR +99,56 per trade
Avg win / loss         EUR +216,87 / EUR -137,91
Max drawdown                 EUR 2.100,00 | 0,53 %
Streaks now / max              NOW W3 / L0 | MAX W8 / L4
Best / worst             EUR +940,20 / EUR -511,80
Last trade  EUR +210,40 | 2026-09-06 16:42 BT | DEAL_REASON_TP
Account     BAL EUR 412.345,67 | EQ EUR 412.774,07 | TODAY EUR +638,80

RISK / ROOM                                  Heartbeat       OK | TICK 00:00 | CONNECTION UP
Next-trade risk  RISK_PERCENT 0,31 % |       Calendar        LIVE MT5 NATIVE OK
                 EFFECTIVE 0,31 %
Daily / total room EUR 19.842,10 | 4,81 % /  IDENTITY
                   N/A (governor unbound)     EA        QM5_11421 | ohlc-daily-squeeze-reversal-d1 | v5.0
Open risk to SL              EUR 480,00 | 0,12 %
                                               Chart     EURUSD.DWX / D1 | MAGIC 114210000
                                               Environment DEMO | LOGIN ****6732 | FTMO-Demo
                                               Build/license 9d55ea09 | LICENSE_FULL
                                               Support   Support: MQL5 comments/messages
```

## Safety invariants

- Legacy `QM_ChartUI` remains suppressed before framework initialization when the signature panel is enabled.
- Object text is forced to printable ASCII.
- Panel initialization and history errors are fail-inert; they never fail the EA or alter trading state.
- Panel rendering is timer-only and tester-inert.
- The Color-on-White chart scheme and exact snapshot/restore behaviour remain unchanged.
- No trade call, DLL, external URL, or trading-logic change was added.
- `qm_news_stale_max_hours=336` remains unchanged.
- Canonical `framework/EAs/*.ex5` files were not written.

## Build, guardrails, and installation

- Python acceptance: `5 passed`.
- Static v3 acceptance: PASS for ASCII, read-only contract, timer fixture, tester inertness, table grid, required sections, de-DE formatters, performance cache, namespace, and light scheme.
- Header probe: `D:/QM/ftmo/compile_probe_panel_v3_header_20260907_r3`; `0 errors, 0 warnings`; EX5 SHA-256 `ccaf6553efac9d0eb601ef13c5e8222b536b2b72879f717036419e3594ae666f`.
- Full canary: `D:/QM/ftmo/compile_probe_panel_v3_20260907`; `0 errors, 0 warnings`; EX5 SHA-256 `9d55ea09263be14a6781b64a60d66f8956eaded7eff36f42e136b705b92f4b22`.
- Canonical `validate_build_guardrails.py` PASS on the isolated source and all 23 QM5_11421 factory set files; zero findings and stale-news ceiling 336.
- Installed binary hash equals the full-canary artifact hash.
- Both demo presets carry build `9d55ea09`; their verified SHA-256 is recorded in `install_receipt.json`.
- The previous v2 binary and both presets are recoverable under `_pre_panel_v3_11421_20260907_0723Z`.
- The FTMO terminal was already running. It was not started, stopped, restarted, or attached automatically. AutoTrading was not changed.

## Expected object census

Enabled v3 creates zero `QM5_UI_11421_*` objects and 87 objects in exactly one `QM_SIG_11421_<magic>_*` namespace: five shell objects, fourteen section objects, and sixty-eight label/value cells. `Shutdown()` deletes the complete owned prefix. Runtime census remains an OWNER visual re-attach check.

## OWNER re-attach (three lines)

1. On the existing FTMO demo EURUSD.DWX D1 chart, remove QM5_11421 and attach `Experts/QM_FTMO/QM5_11421_ohlc-daily-squeeze-reversal-d1` again.
2. Load `QM5_11421_EURUSD_D1_live_trial.set`; confirm `qm_show_chart_panel=true`, `qm_apply_chart_scheme=true`, and build `9d55ea09`.
3. Leave AutoTrading in its current state; confirm one light v3 panel, aligned sections/values, populated performance facts, zero legacy overlap, and report a screenshot/object census for close-out.

## Review boundary

This is an OWNER-visible canary in `REVIEW`. It is not a fleet rollout, pipeline verdict, live-book authorization, or permission to touch other sleeves.
