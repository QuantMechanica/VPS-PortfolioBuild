# Downloads PDF Mining Priorities - 2026-06-26

## Access

- Source folder: `C:/Users/Administrator/Downloads`
- Inventory: 284 PDFs, about 1.5 GB.
- Text extraction works with Python `pypdf` / `pdfplumber`. No Dropbox hydration issue here.
- Existing repo mining already covers a large part of the obvious library: Connors, Wilder, Singh, Unger, Katz/McCormick, ICT/MMM, Turtle, Trend Bible.

## What is already mostly covered

| Source family | Status |
|---|---|
| Connors / Alvarez | Already mined in `LIBRARY_MINING_connors-short-term-strategies-2009_2026-06.md`; many Connors-family cards exist. |
| Wilder | Already mined; primary-source RSI failure swing exists as `QM5_12547`. |
| Katz / McCormick | Already mined; `QM5_12544` to `QM5_12546` exist. |
| Singh, 17 Proven Currency Strategies | Already mined; several proposed cards, many rejected for news/discretionary/intraday issues. |
| Unger brochure / BST transcript | Already mined; no new rule-complete source beyond duplicate Daily Factor. |
| Naked Forex | Key setups already carded: Last Kiss, Big Shadow, Kangaroo Tail, Wammie/Moolah, Big Belt. Further mining is likely duplicate-heavy. |
| Kathy Lien / BKForex | Double BB and X-Treme Fade variants already carded; Asia/Tokyo session ideas partially covered. |
| Chan | Many Chan cards already exist from book/blog. The book still has useful validation/risk ideas, but fewer fresh DWX-ready cards. |
| Katsanos Intermarket | At least one high-value card exists: `QM5_12542_katsanos-gold-multidiv-d1`. Low-frequency and gold-cluster risk remain. |
| Ichimoku | Codebase survivor family already exists (`QM5_10513`, `QM5_12568`); book can improve fidelity but is not the fastest new-edge source. |

## Highest new-potential source

### 1. Art Collins - `beating-the-financial-futures-market-combining-small-biases-into-powerful-money-making-strategies-wiley-trading_compress.pdf`

Why it matters:
- Search found only a passing mention in existing cards, no dedicated Art Collins card family.
- The PDF is rule-dense and includes TradeStation formulas in the appendix.
- This is a rare source with many explicit mechanical rules, not just chart examples.

Best first candidates:

| Candidate | Mechanic | Why first |
|---|---|---|
| 9-day 66% momentum system | Compare close location vs 9-day high/low, enter on stop at fraction of opposite-side distance, stop at 1.32x range measure. | Fully mechanical appendix code; trend/momentum family, possible cross-asset port. |
| 1.5 daily range expansion | Trade next bar stop at open +/- 1.5x prior range with close-vs-average regime side. | Simple volatility breakout; likely portable to NDX/GDAXI/WS30/XAU/XTI. |
| Cups and Caps overnight/day | Three-bar local cup/cap pattern, enter close/next bar, optional stops/targets. | Distinct short-horizon reversal pattern; not obviously duplicated. |
| Second high/low exit family | Exit after second favorable high/low following entry. | Could be used as an exit variant/wrapper, not necessarily a standalone card. |

Recommendation: mine at most 3 cards from Collins first. Do not overproduce; the appendix has many variants and will invite curve-fit sprawl.

## Second-tier source

### 2. Keith Fitschen - `Building Reliable Trading Systems - Tradable Strategies That Perform As They Backtest and Meet Your Risk-Reward Goals 2013.pdf`

Why it matters:
- Good development methodology and robust-system discipline.
- Contains explicit examples: countertrend Donchian stock/index system, commodity trend-following baseline, bar-scoring approach.

Risk:
- Much of the book is system-development methodology, not standalone published strategy evidence.
- Bar-scoring is mechanically interesting but may become a feature-selection engine if not tightly fixed.

Recommendation:
- Treat Fitschen as a filter/exit/risk methodology source first.
- Candidate card only if the exact countertrend Donchian or bar-scoring rules are source-complete and dedup-clean.

## Useful but lower-priority sources

| Source | Finding |
|---|---|
| Adam Grimes, `The Art and Science of Technical Analysis` | High-quality structure source. Existing survivor `QM5_10940` already captures nested pullback. Further Grimes mining should focus on variants around failed breakout / anti-climax / complex pullback, but dedup risk is high. |
| Ernest Chan, `Algorithmic Trading` | Book is readable and valuable. Many Chan cards exist. Roll-return futures momentum is interesting but needs futures curve/roll data unavailable in DWX; not a fast build. |
| `Trading with Ichimoku Clouds` | Can improve fidelity for Ichimoku variants, especially Chikou/Kijun exit variants, but existing Ichimoku survivor/ports are already stronger evidence. |
| Kathy Lien / `Day Trading and Swing Trading the Currency Market` | Useful for session/time-of-day FX ideas, but many Lien/BKForex/session cards already exist. Mine only if a specific uncarded rule is found. |
| `Sentiment in the Forex Market` | Conceptually useful but likely needs COT/SSI/sentiment data. Not DWX-native unless translated into price-only proxies. |
| `Intermarket Trading Strategies` | Already partially exploited via Katsanos gold multidiv. Further mining should target non-gold DAX/index systems to avoid more XAU clustering. |

## Operational notes

- Registry note: Claudes earlier G0 review said IDs `12544` to `12555` needed registration. Current registry now has rows for `12544` to `12552`, but the file mixes numeric IDs and `QM5_`-prefixed IDs in this block. Treat as a hygiene issue before dispatching any new mining batch.
- Do not mine image-only PDFs by memory or filename. Here the Downloads PDFs are readable; use actual extracted text/page evidence.
- Strong preference: one source, max three cards, then build/test. The portfolio problem is breadth of certified sleeves, not a larger untested card backlog.

## Claude prompt

```text
Du bist Research fuer QM5. Quelle ist OWNER-approved:
C:/Users/Administrator/Downloads/beating-the-financial-futures-market-combining-small-biases-into-powerful-money-making-strategies-wiley-trading_compress.pdf

Ziel: Extrahiere maximal 3 V5 Strategy Cards aus Art Collins, Beating the Financial Futures Market.

Arbeitsregeln:
1. Nutze nur echte PDF-Inhalte, bevorzugt die Appendix-TradeStation-Formeln. Keine Strategien aus Dateinamen oder Erinnerung.
2. Dedup zuerst gegen D:/QM/strategy_farm/artifacts/cards_approved und framework/registry/ea_id_registry.csv.
3. Priorisiere diese Kandidaten:
   - 9-day 66% momentum system
   - 1.5 daily range expansion
   - Cups and Caps overnight/day
   - Second high/low exit nur als Exit-Variante, nicht automatisch als eigene Card
4. R3/DWX-Port ehrlich machen: NDX.DWX, SP500.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX nur wenn OHLC-only und timeframe-kompatibel.
5. Keine Grid/Martingale/ML. Keine Parameter-Explosion; nimm die Buchdefaults und markiere Sweeps nur klein.
6. Jede Card braucht: Source page/table, exact rules, market universe, timeframe, exits/stops, expected trade frequency, dedup reasoning, R1-R4.
7. Maximal 3 Cards schreiben. Wenn weniger als 3 dedup-clean sind, stoppe und dokumentiere Rejects.

Nach Abschluss: schreibe eine kurze Mining-Notiz mit NEW / DUPLICATE / REJECT und einer Build-Empfehlung.
```

## Bottom line

Der Download-Ordner ist brauchbar. Der schnellste neue PDF-Hebel ist Art Collins, nicht die bereits stark geminten Standardquellen. Danach erst Fitschen/Grimes-Varianten, und nur dedup-streng.
