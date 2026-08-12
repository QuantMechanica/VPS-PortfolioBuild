# FTMO Strategy Source Map — deep-forum fan-out (2026-07-21)

**Authority:** OWNER 2026-07-21 — "Durchforste die hintersten Winkel, fremdsprachige Foren,
MQL5-Foren, Algorithmic-Trading-Foren, alles was mit FTMO / Prop-Firms zu tun hat, Futures,
Forex, Indizes, japanische Hausfrauentrades, koreanische Hebeleien, indische EAs, russische
System-Austrickser." Codex headless, Sol / gpt-5.6-sol, effort max, Claude orchestriert.

This map is the territory. It is consumed by a **fan-out of one headless Codex per cluster**.
It complements — and must NOT duplicate — the two Wave-1 Codex already running:
- `FTMO_BOOK_ARCHITECTURE` (MC-driven book design from existing evidence)
- `FTMO_STRATEGY_SOURCING` (SSRN academic candidates + ICT-holdout resume)

This wave mines **community / forum / foreign-language** territory instead: the practitioner
corners academia and our own pipeline never see.

## The prize (unchanged)

FTMO Phase-1 pass = **+10 %** on 100k demo within **≤30 days**, no 5 %-daily / 10 %-total
breach, target **P(pass) ≥ 0.80**. Our own MC proved the bottleneck is **DENSITY / CARRY, not
risk** (~$4.2k / 90 td vs $10k target). So the whole point of this mining is to find
**high-frequency, swap-free-preferred, positive-net-expectancy intraday sleeves** with a
*structural* reason to exist. See `FTMO_CHALLENGE_CAMPAIGN_2026-07-21.md`.

## Doctrine filter (applied by every cluster Codex — see SHARED_BRIEF.md)

- **KEEP:** fully-mechanical entry/exit/params; swap-free intraday-flat preferred; positive
  net expectancy AFTER FTMO commission (+swap if overnight); a **structural / limit-to-
  arbitrage** cause (order-flow, settlement, session-liquidity, index-rebalance, payment-
  window, macro-announcement); high density (tens–hundreds trades/yr).
- **REJECT:** grid / martingale / averaging-down / no-stop-loss; pure chart-pattern &
  "smart-money"/ICT with no structural cause (vault dead-lists these — see FX-edge doctrine);
  indicator-salad curve-fits; anything discretionary; anything without a verifiable citation.
- **Symbol mapping:** foreign-market ideas (NIFTY, KOSPI200, Nikkei225, USDINR) map onto the
  nearest tradable **.DWX** instrument (index → US500/US30/NAS100/GER40; JPY flow → USDJPY /
  JPY crosses) and the Codex must say so. `SP500.DWX` is backtest-only; FTMO requalifies on US500.

## The clusters (one headless Codex each)

| key | region / lang | primary sources | native edge-type | dedup / caution |
|-----|---------------|-----------------|------------------|-----------------|
| **prop-native** | Global / EN | r/FTMO, r/proptrading, r/Forex, r/algotrading, FTMO blog, PropFirmMatch & prop-firm forums, myfxbook systems, public prop Discord logs, YouTube "how I passed" breakdowns | how challenges are ACTUALLY passed: news-scalp, session breakout, high-density day-trading, risk-staging to +10 % fast | this is the most FTMO-direct cluster; cross-check every claim against our MC density finding |
| **india-intraday** | India / EN+HI | Zerodha Varsity, tradingqna.com, Streak, StockMock, TradingView India, quant blogs | **ORB (opening-range breakout)**, first-candle, VWAP-reversion, NIFTY/BankNifty/USDINR intraday — swap-free intraday index, extremely high density | map NIFTY/BankNifty → US500/US30/NAS100/GER40 .DWX; keep the *mechanism*, re-fit the level |
| **eastasia-retail** | Japan + Korea / JA+KO | Zai, Traders Web, oanda-lab, minkabu, note.com, 2ch/5ch FX boards; Naver cafes, KRX retail | Tokyo-fix (09:55 JST) flow, **gotobi** payment-window, JPY-cross session timing, Nikkei/KOSPI gap-fade — swap-free intraday JPY/index | dedup vs live **12969 gotobi** motor: EXTEND with *disjoint* windows/pairs, do NOT clone the live sleeve |
| **russia-mql** | Russia / RU | mql5.com/ru forum + Code Base, smart-lab.ru, forexsystems.ru, spekulant.ru, cmillion, tradelikeapro | deep MT5 automation; genuine session / news / breakout systems buried in a grid-heavy scene | **strictest** doctrine filter — the Russian scene is 90 % grid/martingale junk with a few real structural gems; reject aggressively |
| **futures-orderflow** | US / EN | elitetrader.com, futures.io (BigMikeTrading), NinjaTrader & TradeStation EasyLanguage libraries, TradingView | ES/NQ **opening-drive**, initial-balance, TICK/breadth, VWAP bands, gap-fill — swap-free (futures roll ≠ swap) | maps cleanly to our index .DWX; watch instrument-spec differences (tick value, RTH session) |
| **mql5-forexfactory** | Global / EN | MQL5.com EN forum + Code Base, ForexFactory, Forex-station EA mega-threads | London-open breakout, session-range, news-straddle, published build-ready MQL EAs | filter the published-EA junk hard; keep only mechanical session/structural with a cause |

## Fan-out mechanics (Claude runs this)

- One worktree + one detached `codex.cmd exec -m gpt-5.6-sol -c model_reasoning_effort=max`
  per cluster. Each writes `docs/research/FTMO_SOURCE_<KEY>_2026-07-21.md` + draft cards under
  `D:\QM\reports\state\ftmo_campaign_20260721\sources\cards_<key>\`.
- Wave-2 (Claude): dedup across all cluster outputs + the two academic/ICT Codex → allocate
  ea_ids → serial build wave on the highest marginal-density candidates → live-pipeline test.
- Wave-3: assemble book → MC-validate ≥ 0.80 / 30 d → OWNER admission (money gate).

## ★★ HARD RULE for every dispatched Codex

**NEVER run Factory_OFF / TestWindow_OFF / any factory isolation** (a prior ICT codex session
stranded the factory for hours doing exactly that). These Codex produce SPECS + DRAFT CARDS
only — no builds, no backtests. Any test needed is LISTED for Claude to route through the live
pipeline. Every citation real + verifiable; unreachable source → note it + use archive/mirror
or documented knowledge with a citation, or mark UNVERIFIED — **never fabricate**.
