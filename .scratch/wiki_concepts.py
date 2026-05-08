import os

wiki_base = "G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki"
concept_dir = os.path.join(wiki_base, "concepts")

concepts = [
    {
        "slug": "mean-reversion",
        "name": "Mean Reversion",
        "definition": "A strategy entering when price deviates from its statistical mean, expecting reversion back to that mean.",
        "market_logic": "Short-term price deviations above/below equilibrium tend to revert. Strongest when spread/price has a stationary distribution (half-life finite). Fails when a structural break makes the mean itself non-stationary.",
        "indicators": ["[[indicators/bollinger-bands]]", "[[indicators/zscore]]", "[[indicators/kalman-filter]]"],
        "examples": [
            ("[[strategies/QM5_1017_chan-pairs-stat-arb]]", "GLD/GDX cointegration stat-arb"),
            ("[[strategies/chan-at-bb-pair]]", "Bollinger-band on OLS-hedged pair spread"),
            ("[[strategies/chan-at-fx-coint-pair]]", "Forex cointegration pair"),
            ("[[strategies/chan-at-kf-pair]]", "Kalman-filter dynamic hedge MR"),
            ("[[strategies/davey-baseline-3bar]]", "3-bar pattern with MR exit"),
            ("[[strategies/QM5_1009_lien-fade-double-zeros]]", "Fade round-number levels"),
            ("[[strategies/QM5_1012_lien-fader]]", "Failed-breakout fade"),
            ("[[strategies/lien-dbb-pick-tops]]", "DBB band reclaim tops/bottoms"),
        ],
        "related": [
            ("[[concepts/pair-trade]]", "specialisation: pair MR uses two-leg spread"),
            ("[[concepts/range-trade]]", "range trade exploits bounded MR zone"),
            ("[[concepts/breakout]]", "opposite: breakout bets mean will NOT hold"),
        ],
        "fail_modes": "Mean is non-stationary (regime shift). Strategy loses money as spread expands indefinitely. No native stop-loss in Chan-class MR is the canonical ruin mode.",
        "sources": [
            ("[[sources/chan-algorithmic-trading-2013]]", "Ch 3-5: Bollinger bands + Kalman + calendar spread"),
            ("[[sources/chan-quantitative-trading-2009]]", "Ch 3: cointegration + stat-arb"),
            ("[[sources/davey-building-algo-trading-systems]]", "Appendix A: baseline 3-bar"),
        ],
    },
    {
        "slug": "breakout",
        "name": "Breakout",
        "definition": "A strategy entering when price breaks through a defined support/resistance level, betting on directional continuation.",
        "market_logic": "Consolidation periods compress volatility; breakouts above/below the range signal new information or momentum. The underlying assumption is that the breakout represents a genuine directional move, not noise.",
        "indicators": ["[[indicators/donchian-channel]]", "[[indicators/atr-stop]]", "[[indicators/inside-day-pattern]]"],
        "examples": [
            ("[[strategies/QM5_1004_davey-es-breakout]]", "S&P 500 futures channel breakout"),
            ("[[strategies/QM5_1013_lien-20day-breakout]]", "20-day Donchian channel breakout on FX"),
            ("[[strategies/QM5_1014_lien-channels]]", "Narrow channel range breakout on FX"),
            ("[[strategies/QM5_1011_lien-inside-day-breakout]]", "Inside-day narrow range breakout"),
            ("[[strategies/williams-vol-bo]]", "Larry Williams volatility expansion breakout"),
        ],
        "related": [
            ("[[concepts/mean-reversion]]", "opposite: breakout bets on continuation vs. reversion"),
            ("[[concepts/volatility-filter]]", "breakout strategies use volatility as trigger/filter"),
            ("[[concepts/trend-following]]", "breakout can initiate a trend-following position"),
        ],
        "fail_modes": "False breakout / whipsaw. Price breaks the level then reverses, triggering stop. Most common in low-volatility, ranging markets.",
        "sources": [
            ("[[sources/davey-building-algo-trading-systems]]", "Appendix A: ES breakout baseline"),
            ("[[sources/lien-day-trading-forex-market]]", "Ch 9-10: 20-day, inside-day, channels"),
        ],
    },
    {
        "slug": "pair-trade",
        "name": "Pair Trade / Statistical Arbitrage",
        "definition": "A strategy simultaneously long one instrument and short a correlated instrument, profiting when the spread between them reverts.",
        "market_logic": "Two economically linked instruments share a long-run equilibrium. Short-term divergences in their spread represent temporary imbalance that markets correct. The spread is stationary (or half-life finite) while individual legs are non-stationary.",
        "indicators": ["[[indicators/zscore]]", "[[indicators/ols-hedge-ratio]]", "[[indicators/kalman-filter]]", "[[indicators/cointegration-test]]"],
        "examples": [
            ("[[strategies/QM5_1017_chan-pairs-stat-arb]]", "GLD/GDX cointegration stat-arb with cadf test"),
            ("[[strategies/chan-at-bb-pair]]", "Bollinger-band on OLS-hedged GLD/USO pair"),
            ("[[strategies/chan-at-fx-coint-pair]]", "Forex cointegration pair"),
            ("[[strategies/chan-at-kf-pair]]", "Kalman-filter dynamically-hedged pair"),
            ("[[strategies/chan-at-spy-arb]]", "SPY proxy arb vs S&P futures"),
            ("[[strategies/chan-at-roll-arb-etf]]", "ETF roll return arbitrage"),
        ],
        "related": [
            ("[[concepts/mean-reversion]]", "pair trade is MR applied to a spread"),
            ("[[concepts/range-trade]]", "spread is effectively range-trading between two legs"),
        ],
        "fail_modes": "Cointegration breakdown (fundamental divergence between the two legs). GLD/GDX 2008: mining-stock discount blew out permanently. Position runs to ruin if hold-to-expiry discipline is absent.",
        "sources": [
            ("[[sources/chan-quantitative-trading-2009]]", "Ch 3: cadf cointegration + stat-arb"),
            ("[[sources/chan-algorithmic-trading-2013]]", "Ch 3-5: Bollinger pairs, Kalman pairs, FX pairs"),
        ],
    },
    {
        "slug": "trend-following",
        "name": "Trend Following / Momentum",
        "definition": "A strategy entering in the direction of an identified price trend or momentum signal, betting on continuation.",
        "market_logic": "Prices exhibit serial autocorrelation over medium time horizons (momentum). Trend followers capture the middle of large moves. Fails in choppy / mean-reverting markets where trends do not persist.",
        "indicators": ["[[indicators/moving-average]]", "[[indicators/atr-trailing-stop]]", "[[indicators/donchian-channel]]"],
        "examples": [
            ("[[strategies/chan-at-ts-mom-fut]]", "Time-series futures momentum"),
            ("[[strategies/chan-at-xs-mom-fut]]", "Cross-sectional futures momentum"),
            ("[[strategies/chan-at-xs-mom-stock]]", "Cross-sectional stock momentum"),
            ("[[strategies/chan-at-vx-es-roll-mom]]", "VX/ES roll return momentum"),
            ("[[strategies/chan-at-fstx-gap-mom]]", "Futures opening-gap momentum"),
            ("[[strategies/QM5_1015_lien-perfect-order]]", "Moving average perfect-order trend entry"),
            ("[[strategies/QM5_1016_lien-carry-trade]]", "FX carry-direction trend-following"),
            ("[[strategies/williams-pro-go]]", "Larry Williams Pro-Go momentum entry"),
        ],
        "related": [
            ("[[concepts/breakout]]", "breakout often triggers trend-following entry"),
            ("[[concepts/mean-reversion]]", "opposite regime: trend fails when price reverts"),
        ],
        "fail_modes": "Whipsaw in ranging markets. ATR-based trailing stops get hit repeatedly. Cross-sectional momentum subject to factor crowding and sharp factor reversals.",
        "sources": [
            ("[[sources/chan-algorithmic-trading-2013]]", "Ch 4-5: cross-sectional + time-series momentum"),
            ("[[sources/lien-day-trading-forex-market]]", "Ch 13: perfect order + carry"),
            ("[[sources/williams-long-term-secrets]]", "Pro-Go entry technique"),
        ],
    },
    {
        "slug": "range-trade",
        "name": "Range Trade",
        "definition": "A strategy that buys at support and sells at resistance within a defined price range, profiting from the bounded oscillation.",
        "market_logic": "Many instruments oscillate between identifiable support and resistance zones for extended periods. Position sizing and stop placement based on the range width provide positive risk/reward.",
        "indicators": ["[[indicators/support-resistance-levels]]", "[[indicators/atr-stop]]", "[[indicators/session-open]]"],
        "examples": [
            ("[[strategies/QM5_1014_lien-channels]]", "Narrow channel range: buy support, sell resistance"),
            ("[[strategies/QM5_1010_lien-waiting-deal]]", "Wait for intraday session range, enter at best price"),
            ("[[strategies/chan-at-cal-spread]]", "Calendar spread oscillates within roll-return range"),
        ],
        "related": [
            ("[[concepts/mean-reversion]]", "range trade is a specific MR application within a bounded zone"),
            ("[[concepts/breakout]]", "breakout is what ends a range-trade regime"),
        ],
        "fail_modes": "Range breaks out (breakout mode replaces range mode). Stop is placed outside the range, so a genuine breakout always takes the stop.",
        "sources": [
            ("[[sources/lien-day-trading-forex-market]]", "Ch 10-11: channels and waiting-deal patterns"),
        ],
    },
    {
        "slug": "news-trade",
        "name": "News Trade",
        "definition": "A strategy entering positions based on anticipated or actual news events, exploiting the price impact of scheduled or surprise releases.",
        "market_logic": "High-impact news events (NFP, FOMC, CPI) cause predictable volatility expansion. Strategies can pre-position for directional bias or fade the initial spike once the dust settles.",
        "indicators": ["[[indicators/economic-calendar]]", "[[indicators/atr-stop]]"],
        "examples": [],
        "related": [
            ("[[concepts/volatility-filter]]", "news events are the primary driver of volatility spikes"),
            ("[[concepts/breakout]]", "news breakout: price breaks range on event release"),
        ],
        "fail_modes": "Slippage on the event spike makes the fill unacceptable. News events with pre-priced moves produce no edge on actual release.",
        "sources": [],
    },
    {
        "slug": "volatility-filter",
        "name": "Volatility Filter / Regime",
        "definition": "A mechanism (used as a primary signal or a filter) that identifies high/low volatility states to trigger entries or suppress trading.",
        "market_logic": "Volatility alternates between compression (squeeze) and expansion phases. Trading at the point of volatility expansion captures the largest directional moves. Low-volatility filters reduce whipsaw in quiet markets.",
        "indicators": ["[[indicators/atr-stop]]", "[[indicators/bollinger-bands]]", "[[indicators/historical-volatility]]"],
        "examples": [
            ("[[strategies/williams-vol-bo]]", "Enter when today's volatility expands beyond recent range"),
            ("[[strategies/williams-pinch-paunch]]", "Pinch-and-paunch volatility squeeze then expand"),
            ("[[strategies/lien-dbb-pick-tops]]", "Double Bollinger Band: outer/inner band zones"),
            ("[[strategies/lien-dbb-trend-join]]", "Double Bollinger Band trend-join using band zone as regime filter"),
        ],
        "related": [
            ("[[concepts/breakout]]", "volatility expansion often precedes/coincides with a breakout"),
            ("[[concepts/trend-following]]", "trend entries filtered by volatility expansion signal"),
        ],
        "fail_modes": "Volatility expansion that immediately collapses back (head-fake). Common after news spikes that reverse within the same session.",
        "sources": [
            ("[[sources/williams-long-term-secrets]]", "Vol-BO and Pinch-Paunch patterns"),
            ("[[sources/lien-day-trading-forex-market]]", "DBB strategy: outer/inner band zones"),
        ],
    },
]

for c in concepts:
    examples = "\n".join("- %s -- %s" % (ex[0], ex[1]) for ex in c["examples"])
    if not examples:
        examples = "- *No strategies in pipeline yet for this concept.*"
    related = "\n".join("- %s -- %s" % (r[0], r[1]) for r in c["related"])
    sources_text = "\n".join("- %s: %s" % (s[0], s[1]) for s in c.get("sources", []))
    if not sources_text:
        sources_text = "- *No sources yet.*"
    indicators = "\n".join("- %s" % i for i in c["indicators"])
    example_strats_yaml = "\n".join('  - "%s"' % ex[0] for ex in c["examples"])
    if not example_strats_yaml:
        example_strats_yaml = "  # no strategies yet"
    related_yaml = "\n".join('  - "%s"' % r[0] for r in c["related"])

    content = """---
type: concept
slug: {slug}
related_concepts:
{related_yaml}
example_strategies:
{example_strats_yaml}
last_updated: 2026-05-08
---

# {name}

## Definition (in einem Satz)
{definition}

## Marktlogik / Annahme
{market_logic}

## Typische Indikatoren / Mechanismen
{indicators}

## Beispiel-Strategien (in unserer Pipeline)
{examples}

## Verwandte Konzepte
{related}

## Bekannte FAIL-Modes
{fail_modes}

## Quellen die dieses Konzept beschreiben
{sources_text}

---

*Knoten-Pflege: bei jeder neuen Strategie, die unter dieses Konzept faellt, hier ergaenzen. Bei FAIL einer Beispiel-Strategie: in FAIL-Modes notieren.*
""".format(
        slug=c["slug"],
        name=c["name"],
        definition=c["definition"],
        market_logic=c["market_logic"],
        indicators=indicators,
        examples=examples,
        related=related,
        fail_modes=c["fail_modes"],
        sources_text=sources_text,
        related_yaml=related_yaml,
        example_strats_yaml=example_strats_yaml,
    )
    path = os.path.join(concept_dir, c["slug"] + ".md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("CONCEPT:", c["slug"])
