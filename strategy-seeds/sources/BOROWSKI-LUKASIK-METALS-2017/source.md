---
source_id: BOROWSKI-LUKASIK-METALS-2017
title: Analysis of Selected Seasonality Effects in the Following Metal Markets
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://econjournals.sgh.waw.pl/JMFS/article/download/740/643/
strategy_ids:
  - BOROWSKI-LUKASIK-METALS-2017_S01
  - BOROWSKI-LUKASIK-METALS-2017_S02
---

# Gold/Silver weekend differential source

Borowski and Lukasík (2017), *Journal of Management and Financial Sciences*,
27, 59-86, is a peer-reviewed open-access study of gold, silver, platinum,
palladium and copper calendar returns. The complete paper was reviewed.

Table 5 rejects zero weekend return for gold (`p=0.001138788`) but not silver
(`p=0.323175`). Table 7 reports Friday-close to Monday-open means of `0.0294%`
for gold and `0.0223%` for silver. The paper concludes that the weekend effect
occurred for gold and copper, not silver, platinum or palladium.

QM mechanizes two falsification candidates. The first enters at broker Friday 21:00, BUY XAU and
SELL XAG with equal USD notionals and a shared fixed-risk budget; close both at
the first Monday H1 bar. The short-silver hedge is a QM market-neutral
translation that isolates gold's source-supported weekend effect from broad
precious-metal beta; it is not claimed as a source-tested portfolio.

The second tests the paper's directly reported copper weekend effect without a
hedge: BUY XCUUSD.DWX at broker Friday 21:00 and close at the first Monday H1
bar. It uses one fixed-risk ATR stop and one position per magic. This is a
separate commodity exposure and does not infer copper behavior from the gold
result.

Limitations are binding: sample dates and settlement boundaries differ from
Darwinex CFDs, the gross XAU-XAG mean differential is small, financing/gaps and
two-leg costs may dominate, equal-notional is not a fitted beta, and the paper
does not prove post-publication persistence. No parameter sweep is authorized.

R1 tier B: named authors, peer-reviewed journal and complete official PDF. R2:
fixed weekday/hour, directions, sizing, stops and exit. R3: synchronized
XAUUSD.DWX/XAGUSD.DWX history is already used by registered baskets. R4:
calendar and ATR only; no ML, grid, martingale or external runtime feed.

Repository-wide search found ratio-reversion, threshold-cointegration and
stochastic XAU/XAG baskets, plus outright XAU Friday logic, but no XAU-long /
XAG-short Friday-close-to-Monday-open package. Q02 and Q09 remain authoritative.

This authorizes research/backtest only. No live set, T_Live action, deploy
manifest, portfolio-gate modification or correlation waiver is authorized.
