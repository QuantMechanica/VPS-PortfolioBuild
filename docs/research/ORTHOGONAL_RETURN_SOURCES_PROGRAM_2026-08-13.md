# Orthogonal Return Sources Program — 2026-08-13

**Provenance:** OWNER ultracode directive 2026-08-13 ("neue orthogonale Rendite-Quellen").
Produced by a 10-agent adversarial workflow (run wf_6415745e-8ce): 6 independent finder
lenses (symbol expansion, SA/CS family rebalance, FTMO density, documented anomalies,
crisis alpha, internal reuse) -> dedup -> 3 adversarial critics (structural cause with
kill-default, DWX/cost feasibility, portfolio orthogonality) -> synthesis.
Funnel: 40 raw -> 39 deduped -> 18 survivors. Journal: session c0f49ed8, wf_6415745e-8ce.

Binding doctrine carried into every lens: structural cause mandatory (limit-to-arbitrage),
closed-bar mechanics, no ML, DWX-37 universe, frequency floor, index shorts EOD-flat
(swap), kill-list of closed research (ICT/SMC/FVG/DOW-masks/SL-tightening/Gold-Reaper).

## Ranked survivors

| # | Tier | Family | Name | Symbols | FTMO-density |
|---:|---|---|---|---|:---:|
| 1 | BUILD_CANDIDATE | TC-short | Vol-Gated Index Short — Intraday De-Risking Continuation (EOD-flat) | WS30.DWX, NDX.DWX, GDAXI.DWX, SP500.DWX, UK100.DWX | N |
| 2 | BUILD_CANDIDATE | CS | Market Intraday Momentum (indices, first-hour to last-hour) | WS30.DWX, UK100.DWX, SP500.DWX, NDX.DWX, GDAXI.DWX | Y |
| 3 | DATA_PROBE | MR | Intraday extension reversal to session anchor (evaporating-liquidity fade) | WS30.DWX, GDAXI.DWX, UK100.DWX | Y |
| 4 | BUILD_CANDIDATE | MR | Index cash-open gap fade (small-gap liquidity reversal) | GDAXI.DWX, WS30.DWX, UK100.DWX | Y |
| 5 | DATA_PROBE | SA | Gold-Silver Ratio Convergence Spread (XAU/XAG) | XAUUSD.DWX, XAGUSD.DWX | N |
| 6 | DATA_PROBE | CS | Local-currency intraday depreciation (session inventory premium) | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX | Y |
| 7 | RESEARCH_TICKET | MR | SNB-Backstop Franc-Strength Reversion (EURCHF) | EURCHF.DWX, USDCHF.DWX | N |
| 8 | DATA_PROBE | SA | SP500-NDX Intraday Dispersion Reversion (EOD-flat) | SP500.DWX, NDX.DWX | Y |
| 9 | DATA_PROBE | TC-short | Carry-Unwind JPY-Cross Short (risk-off currency crash momentum) | AUDJPY.DWX, NZDJPY.DWX, GBPJPY.DWX, EURJPY.DWX | N |
| 10 | RESEARCH_TICKET | SA | FX cross-sectional short-term reversal, full 28-pair G10 complex | EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, EURGBP.DWX, all G10 crosses (28) | Y |
| 11 | DATA_PROBE | SA | Trans-Tasman Terms-of-Trade Reversion (AUDNZD) | AUDNZD.DWX | N |
| 12 | DATA_PROBE | MR | Carry-Crash Liquidity Reversion (GBPJPY) | GBPJPY.DWX | N |
| 13 | RESEARCH_TICKET | CS | Scheduled Macro-Announcement Drift (news-calendar event motor) | SP500.DWX, NDX.DWX, GDAXI.DWX | N |
| 14 | BUILD_CANDIDATE | TC-short | Dollar-Smile Global-Stress USD Strength (short AUD/NZD vs USD) | AUDUSD.DWX, NZDUSD.DWX, EURUSD.DWX | N |
| 15 | DATA_PROBE | CS | Month-End WM/R 4pm London Fix FX Rebalancing | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX | N |
| 16 | DATA_PROBE | TC | Compression-gated opening-range breakout (Balke-fix, vol-in-not-vol-out) | WS30.DWX, GDAXI.DWX | Y |
| 17 | DATA_PROBE | TC | London-open Asian-range volatility breakout (GBP session burst) | GBPUSD.DWX, GBPJPY.DWX, EURGBP.DWX | Y |
| 18 | DATA_PROBE | MR | EIA-anchored natural-gas post-report reversal (event fade) | XNGUSD.DWX | N |

## Mechanization briefs (full)

### #1 — Vol-Gated Index Short — Intraday De-Risking Continuation (EOD-flat)

- **Tier:** BUILD_CANDIDATE · **Family:** TC-short · **Symbols:** WS30.DWX, NDX.DWX, GDAXI.DWX, SP500.DWX, UK100.DWX · **FTMO-density:** no
- **Source:** Moskowitz, Ooi & Pedersen, 'Time Series Momentum', JFE 2012; Barroso & Santa-Clara, 'Momentum has its moments', JFE 2015
- **Brief:** D1 regime gate arms only when ATR(14) percentile-rank >=70th over 100d AND D1 close < EMA(50); on an H1 bar closing below both the trailing 6-bar low and the session opening-range low, enter short with a 1.5xATR(H1) stop, manage to 2R or ATR-trail, and HARD-FLAT at session close so no overnight index-short swap is ever paid. Symbols WS30 (cheapest $0.70 RT), NDX, GDAXI, SP500, UK100; H1 entry with D1 gate; ~40 lumpy trades/yr (a DXZ orthogonality sleeve, not a density motor). Structural cause: vol-target and risk-parity mandates must mechanically de-gross as realized vol rises, becoming forced price-insensitive sellers that make downside continuation structurally stronger (Moskowitz-Ooi-Pedersen; Barroso-Santa-Clara).
- **Why orthogonal:** Fires ONLY in the high-vol downtrend regime where the long-XAU/index TC book bleeds, is short-only and intraday, and the ATR-percentile+below-EMA50 gate keeps it flat (near-zero bleed) the rest of the time — the best worst-regime complement in the slate and it attacks the sparse short-side gap.
- **Next action:** Draft strategy card now; the one open item (does the vol-gate hold the DD tail) is exactly what Q05 tests — the fix Balke lacked. Cap aggregate risk-off beta jointly with #29/#32 at portfolio admission.

### #2 — Market Intraday Momentum (indices, first-hour to last-hour)

- **Tier:** BUILD_CANDIDATE · **Family:** CS · **Symbols:** WS30.DWX, UK100.DWX, SP500.DWX, NDX.DWX, GDAXI.DWX · **FTMO-density:** yes
- **Source:** Gao, Han, Li & Zhou, 'Market Intraday Momentum', Journal of Financial Economics 129(2), 2018
- **Brief:** At the close of the first cash-session bar compute first-hour return r1 normalized by ATR(20) with a volatility floor to skip flat opens; at the last-hour window go long if r1>+theta and short if r1<-theta, then close on the session-close bar (EOD-flat, zero index swap). Symbols WS30/UK100 (unused, cheap) plus SP500/NDX/GDAXI; M30/H1; ~150/yr, FTMO density-fit. Cause: late-informed institutions and infrequent rebalancers concentrate execution at the open and the close, so the first-hour order imbalance leads a same-direction close program and liquidity providers leaning against it are paid inventory risk into the close (Gao-Han-Li-Zhou, JFE 2018).
- **Why orthogonal:** A session-clock intraday signal closed EOD-flat carries zero overnight index beta and keeps producing on choppy days when the multi-day XAU/index swing bloc makes nothing; runs on WS30/UK100 that are absent from the live book.
- **Next action:** Draft card now; validate per-symbol (documented weaker outside the US session, so DAX/UK100 variants may be thinner) and confirm post-2018 persistence and DST-clean session-open timestamping at Q02.

### #3 — Intraday extension reversal to session anchor (evaporating-liquidity fade)

- **Tier:** DATA_PROBE · **Family:** MR · **Symbols:** WS30.DWX, GDAXI.DWX, UK100.DWX · **FTMO-density:** yes
- **Source:** Nagel, 'Evaporating Liquidity', Review of Financial Studies 2012; Jegadeesh, JF 1990
- **Brief:** Define session anchor = session-open price; when intraday |price-anchor| >= k*ATR(H1) with no fresh high-impact news and the trend-day gate not tripped, fade back toward the anchor (partial-retrace target, bounded (k+delta)*ATR stop), max 2 entries/day, mandatory EOD-flat. Symbols WS30/GDAXI/UK100; H1; ~170/yr density. Cause: short-horizon reversal is compensation for liquidity provision that strengthens precisely when liquidity is scarce (Nagel 'Evaporating Liquidity' RFS 2012; Jegadeesh 1990), so it pays most in the stressed regimes the trend book struggles in.
- **Why orthogonal:** Counter-trend intraday liquidity-provision premium is orthogonal to the multi-day trend factor and strengthens in stress; but it sits in the same index-intraday-MR cluster as #16, so redundancy is the live risk.
- **Next action:** PROBE: prototype the extension-fade and compute its daily-return correlation to the #16 gap-fade on GDAXI/WS30/UK100 over 2015-2025; build only if |corr| < 0.4, otherwise fold into #16 and keep whichever survives cost-adjusted Q08 cleaner. Open-price anchor is a VWAP approximation to note in the card.

### #4 — Index cash-open gap fade (small-gap liquidity reversal)

- **Tier:** BUILD_CANDIDATE · **Family:** MR · **Symbols:** GDAXI.DWX, WS30.DWX, UK100.DWX · **FTMO-density:** yes
- **Source:** Lou, Polk & Skouras, 'A tug of war: Overnight versus intraday expected returns', JFE 2019; gap-fill mechanics per Kaufman, 'Trading Systems and Methods', 2013
- **Brief:** On the first cash-session H1 bar compute gap = open - prior_session_close in D1-ATR(14) units and trade ONLY when band_lo <= |gap| <= band_hi (skip micro-gaps with no edge and large news gaps which are information, not inventory), entering opposite the gap toward the prior close with a hard stop at gap*1.2 beyond the open, one shot/day, EOD-flat plus news-calendar suppression. Symbols GDAXI/WS30/UK100; H1 session-anchored; ~130/yr density. Cause: overnight dealer and futures-maker inventory imbalance concentrates at the liquid cash auction and reverts intraday as inventory is worked off — a liquidity-provision premium retail gap-chasers structurally keep supplying (Lou-Polk-Skouras JFE 2019; Kaufman 2013).
- **Why orthogonal:** Same-day gap-fade on unused indices is short-horizon liquidity provision whose sign is set by overnight inventory, structurally decoupled from multi-day trend PnL and best-paid on the choppy days the trend book bleeds; the exclude-large-news-gap rule is the structural distinction that makes it a real source, not a pattern.
- **Next action:** Draft card now; the band calibration must be a fixed ATR-relative rule (OOS-tested across vol regimes, not tuned to one) and confirm the open-auction spread on UK100 (highest RT cost) does not eat the gap-fill. Serial down-gap regimes (2020-03, 2022) are the tail the 1.5x SL + EOD-flat must contain.

### #5 — Gold-Silver Ratio Convergence Spread (XAU/XAG)

- **Tier:** DATA_PROBE · **Family:** SA · **Symbols:** XAUUSD.DWX, XAGUSD.DWX · **FTMO-density:** no
- **Source:** Ciner (2001), Journal of International Financial Markets, Institutions and Money; Batten, Lucey, Peat & Vigne (2018) precious-metals cointegration
- **Brief:** On D1 closed bars compute r = ln(XAU) - ln(XAG) and a 60-bar rolling z; when |z|>2 open a dollar-neutral two-leg spread (short the rich metal, long the cheap, each ATR-risk-parity sized), exit when |z|<0.5 or a 40-bar time-stop or a per-leg 3xATR catastrophe stop, no pyramiding. Symbols XAUUSD.DWX + XAGUSD.DWX; D1; ~18/yr (a DXZ diversifier, not density). Cause: silver's thin freely-floating investment supply is dominated by retail and leveraged-ETF momentum that overshoots the monetary signal gold sets while physical/lease-carry caps convergence-arb capital, so the ratio mean-reverts slowly (Ciner 2001; Batten-Lucey-Peat-Vigne 2018).
- **Why orthogonal:** Dollar-neutral GSR has ~zero beta to the gold price LEVEL, so it is a genuine partial hedge to the 9-sleeve XAU-trend concentration (the book's only correlated component >0.15) AND adds to the scarce SA-of-one family, rather than another metals-directional bet.
- **Next action:** PROBE before build: measure the post-2011 reversion half-life of the log(XAU/XAG) z-score and the hit-rate of |z|>2 reverting to |z|<0.5 within 40 D1 bars; build only if reversion still holds post-2011 (the 30->125->65 decade trend is the risk). Admit this ONE GSR spec over killed dups #8/#20.

### #6 — Local-currency intraday depreciation (session inventory premium)

- **Tier:** DATA_PROBE · **Family:** CS · **Symbols:** EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX · **FTMO-density:** yes
- **Source:** Breedon & Ranaldo, 'Intraday patterns in FX returns and order flow', JMCB 2013; Ranaldo, JBF 2009
- **Brief:** On H1, at each currency's LOCAL session open take a fixed-direction short-local-currency position and flatten at local session close (EOD-flat), with a slow trend filter to avoid fighting a macro trend, an m*ATR(H1) worst-session stop, and news suppression on local ECB/BoE/BoJ/CPI. Symbols EURUSD/GBPUSD/USDJPY (short EUR at European open, short GBP at London open, long USD across Tokyo); H1 session round-trip; ~220/yr with a session-bounded worst-day = ideal FUND_SCORE shape.
- **Why orthogonal:** A documented microstructure session-clock effect (dealers charge an inventory/funding premium for forced local-hours flow) with a steady-median small-worst-day profile the FTMO book lacks, and the book has no intraday-FX-direction sleeve.
- **Next action:** PROBE: compute the mean per-session directional drift in bps 2015-2025 and compare to .DWX spread + ~$5 RT commission; build only if gross edge clears ~2x cost, since cost is the single biggest failure mode (effect decayed with electronification). Structural cause, not a data-mined window, is the kill-list defense.

### #7 — SNB-Backstop Franc-Strength Reversion (EURCHF)

- **Tier:** RESEARCH_TICKET · **Family:** MR · **Symbols:** EURCHF.DWX, USDCHF.DWX · **FTMO-density:** no
- **Source:** Mirkov, Pozdeev & Soderlind (2019), Journal of International Economics; Hertrich & Zimmermann (2017)
- **Brief:** H4 40-bar z-score on EURCHF: long-only when z<-2 AND price in the lower decile of the trailing 250-bar range AND a bullish closed-bar reversal; single entry, exit z>-0.5 or ATR target, with a HARD ATR stop below the entry swing low. Symbols EURCHF.DWX (USDCHF confirmation); H4; ~25/yr. Cause: the SNB is a price-insensitive counterparty leaning against excessive franc strength, supplying one-sided mean-reversion (Mirkov-Pozdeev-Soderlind 2019).
- **Why orthogonal:** Franc strength peaks in global risk-off, exactly when the long-XAU/index book bleeds, so it is a regime complement on an unused currency; the 2015 -30% gap tail is the dominant hazard.
- **Next action:** RESEARCH: decide the capped-loss, no-averaging, small-size architecture with explicit gap-tail modeling, and confirm the reversion edge still exists post-2015 now that the SNB runs no hard floor — a design decision plus regime-confirmation before a card can be drafted.

### #8 — SP500-NDX Intraday Dispersion Reversion (EOD-flat)

- **Tier:** DATA_PROBE · **Family:** SA · **Symbols:** SP500.DWX, NDX.DWX · **FTMO-density:** yes
- **Source:** Lo & MacKinlay (1990), Review of Financial Studies (contrarian-reversion basis, adapted to a two-index intraday pair)
- **Brief:** H1 EOD-flat: each session compute cumulative-from-open dispersion disp = ret_NDX - ret_SP500, band = k*rolling 20-session intraday sigma; when disp>+band short NDX/long SP500 (dollar-neutral by ATR/tick-value), reverse when disp<-band, exit on convergence inside 0.25*band or forced session close, no entries in the final hour. Symbols SP500.DWX + NDX.DWX; H1; ~120/yr. Cause: the two benchmarks share ~90% beta but ETF creation/redemption and tech-headline rotation push NDX intraday off SP500 and the basket stat-arb that would close it is unavailable to MT5 flow.
- **Why orthogonal:** Market-neutral with zero net index beta and zero overnight exposure, on an intraday cross-index dispersion axis nothing in the book trades; adds the scarce SA family.
- **Next action:** PROBE: measure mean convergence of |disp| after it exceeds the band, in index points, against combined NDX+SP500 RT cost (up to $5.50+$5.50); build only if the per-trade edge clears the double spread — the ~90% common beta makes this a likely cost-negative failure.

### #9 — Carry-Unwind JPY-Cross Short (risk-off currency crash momentum)

- **Tier:** DATA_PROBE · **Family:** TC-short · **Symbols:** AUDJPY.DWX, NZDJPY.DWX, GBPJPY.DWX, EURJPY.DWX · **FTMO-density:** no
- **Source:** Brunnermeier, Nagel & Pedersen, 'Carry Trades and Currency Crashes', NBER Macroeconomics Annual 2008
- **Brief:** D1: require (a) target cross below its 20-day low, (b) broad JPY strength (mean 5-day return of AUDJPY/NZDJPY/CADJPY/EURJPY <= -1.0%), (c) 10-day vol > 60-day median, then SHORT the highest-beta carry cross (AUDJPY/NZDJPY) with a 2*ATR stop, exiting on ATR-trail, a 10-day time-stop, or a re-close above the 20-day midline. Symbols AUD/NZD/GBP/EUR-JPY; D1; ~12/yr lumpy. Cause: JPY is the archetypal funding currency, so a vol spike forces a violent simultaneous carry unwind = mechanical JPY buying (Brunnermeier-Nagel-Pedersen 2008).
- **Why orthogonal:** No JPY-cross short or carry-crash exposure in the book, and correlation to the long-trend bloc turns negative in risk-off clusters — a distinct currency-crash-momentum source that fills the short-side gap.
- **Next action:** PROBE: snapshot AUDJPY/NZDJPY short swap on .DWX (SYMBOL_SWAP not yet captured — shorting the high-yielder pays adverse carry) and confirm bounded-window carry bleed < crash-capture expectancy; cap aggregate risk-off beta jointly with #28/#32. Distinct from the #7 GBPJPY reversion-long.

### #10 — FX cross-sectional short-term reversal, full 28-pair G10 complex

- **Tier:** RESEARCH_TICKET · **Family:** SA · **Symbols:** EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, EURGBP.DWX, all G10 crosses (28) · **FTMO-density:** yes
- **Source:** Jegadeesh, JF 1990 (short-term reversal); Menkhoff, Sarno, Schmeling & Schrimpf, JF 2012 (FX RV premium)
- **Brief:** Weekly (closed D1, Monday rebalance): rank all 28 DWX FX pairs by trailing 5-day return neutralized to a common numeraire, go long bottom-quintile losers / short top-quintile winners equal-ATR-risk, hold 5 days, re-rank, with a per-pair min-move filter (5d move > m*ATR) to drop noise trades. Symbols all 28 G10 pairs incl unused CHF/CAD/NZD crosses; D1 weekly; ~60/yr signal cadence. Cause: dealers absorbing a crowded one-week directional flow mark the pair away from fair value and it reverts as inventory is worked off (Jegadeesh 1990; Menkhoff et al 2012).
- **Why orthogonal:** Dollar-neutral cross-sectional reversal harvests a relative-value liquidity premium nearly independent of the directional trend bloc, adds the scarce SA family across entirely-unused crosses.
- **Next action:** RESEARCH: cross-sectional baskets are Verbund/backtest-only in V5 (live = 1 EA/symbol), so decide the operationalization — validate as a research signal and deploy as a portfolio-weight scheme, with a trend-regime overlay for the strong-USD windows (2014-15) where weekly reversal inverts to momentum.

### #11 — Trans-Tasman Terms-of-Trade Reversion (AUDNZD)

- **Tier:** DATA_PROBE · **Family:** SA · **Symbols:** AUDNZD.DWX · **FTMO-density:** no
- **Source:** Chen & Rogoff (2003), 'Commodity currencies', Journal of International Economics
- **Brief:** D1 single-symbol AUDNZD: 60-bar rolling z, fade z>+2 short / z<-2 long single-entry, exit |z|<0.5 or 30-bar time-stop with a ~2.5x ATR(14) stop, plus a regime guard taking entries only when 60-bar realized vol is below its 250-bar median. Symbols AUDNZD.DWX; D1; ~30/yr. Cause: the bounded RBA-RBNZ rate differential and relative terms-of-trade anchor the near-substitute cross to a mean-reverting level (Chen & Rogoff 2003).
- **Why orthogonal:** Market-neutral to USD, global risk beta and XAU/index trend; single-symbol (no double spread) and a distinct pair from the existing cointegration sleeves.
- **Next action:** PROBE: correlation/dup check of a prototyped AUDNZD MR against live AUDCAD MR sleeve QM5_11165, and confirm the z-reversion edge on this low-vol near-substitute pair survives .DWX spread after the vol-gate thins frequency. Admit this ONE AUDNZD spec over killed dup #10.

### #12 — Carry-Crash Liquidity Reversion (GBPJPY)

- **Tier:** DATA_PROBE · **Family:** MR · **Symbols:** GBPJPY.DWX · **FTMO-density:** no
- **Source:** Brunnermeier, Nagel & Pedersen, 'Carry Trades and Currency Crashes', NBER Macro Annual 2008
- **Brief:** H4 GBPJPY: detect a liquidation cascade (close < close[6]-3*ATR(14) within 6 bars AND RSI(14)<15), enter LONG on the first subsequent bar that closes above its open and prior high (stabilization), single entry with NO averaging, exit at 0.382 retrace of the drop or a 20-bar time-stop with a hard ATR stop below the cascade low. Symbols GBPJPY.DWX; H4; ~12/yr. Cause: forced carry-unwind deleveraging overshoots because sellers are price-insensitive, and re-entry is slow, paying a liquidity/short-vol premium (Brunnermeier-Nagel-Pedersen 2008).
- **Why orthogonal:** Long-the-bounce liquidity provision fires in the carry-unwind risk-off regime that is the trend book's worst; GBPJPY is unused. Complements (opposite side of) the #29 short-the-crash sleeve.
- **Next action:** PROBE: event-study the cascade-bounce trigger on GBPJPY 2015-2025 for expectancy and, critically, its correlation to the book's worst days — it must diversify, not add tail-correlated risk. ~12/yr raises DSR scrutiny, so a full-history study (not tuning) is mandatory.

### #13 — Scheduled Macro-Announcement Drift (news-calendar event motor)

- **Tier:** RESEARCH_TICKET · **Family:** CS · **Symbols:** SP500.DWX, NDX.DWX, GDAXI.DWX · **FTMO-density:** no
- **Source:** Savor & Wilson, JFQA 48(2), 2013; Lucca & Moench, JF 70(1), 2015 (pre-FOMC drift)
- **Brief:** H1 EOD-flat, two variants tagged off the news CSV: (a) pre-announcement drift long the index into a scheduled major US release then flat before the print, (b) post-release continuation taking the sign of the release-bar move for N hours. Symbols SP500/NDX/GDAXI; H1; ~30/yr. Cause: the bulk of the equity premium accrues on ~30 scheduled macro-announcement days as compensation for resolvable macro risk (Savor-Wilson 2013).
- **Why orthogonal:** Clocked to the macro-release calendar, not price trend, and monetizes the underused news CSV; generalizes the single pre-FOMC NDX sleeve across release types.
- **Next action:** RESEARCH: design the release set (NFP/CPI/ECB) and index choice to be provably NON-duplicative of the live pre-FOMC NDX sleeve, and lean on the broad Savor-Wilson announcement-day premium rather than FOMC alone (pre-FOMC drift weakened post-2015). Citation set is complete; the open item is the anti-duplication design decision.

### #14 — Dollar-Smile Global-Stress USD Strength (short AUD/NZD vs USD)

- **Tier:** BUILD_CANDIDATE · **Family:** TC-short · **Symbols:** AUDUSD.DWX, NZDUSD.DWX, EURUSD.DWX · **FTMO-density:** no
- **Source:** Jen 'dollar smile' framework (Morgan Stanley, 2001-); Avdjiev, Du, Koch & Shin, AER:Insights 2019; Maggiori, AER 2017
- **Brief:** D1: global-stress gate (SP500 < 50-day SMA AND SP500 20-day return < 0) plus broad USD strength (mean 5-day return of EURUSD/GBPUSD/AUDUSD <= -1.0%), signal on AUDUSD/NZDUSD closing below its 20-day low, then SHORT AUD/NZD (long USD) with a 2*ATR stop, exit ATR-trail / 10-day time-stop / gate-clear. Symbols AUDUSD/NZDUSD/EURUSD; D1; ~10/yr lumpy. Cause: in extreme risk-off a worldwide USD funding/collateral shortage forces dollar buying regardless of US fundamentals, with AUD/NZD the classic high-beta casualties (Avdjiev et al 2019 CIP deviations; Maggiori 2017).
- **Why orthogonal:** Deliberately expressed against AUD/NZD/EUR (not JPY/CHF) to capture the commodity/China/funding-shortage axis and stay decorrelated from the JPY (#29) risk-off sleeve; shorting the higher-yielder gives FAVORABLE carry, and no USD-funding exposure exists in the book.
- **Next action:** Draft card now (mechanics + citations complete, favorable carry avoids the swap-killer); the only portfolio constraint is capping aggregate risk-off beta with #28/#29 in deepest sell-everything episodes.

### #15 — Month-End WM/R 4pm London Fix FX Rebalancing

- **Tier:** DATA_PROBE · **Family:** CS · **Symbols:** EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX · **FTMO-density:** no
- **Source:** Melvin & Prins (2015), 'Equity hedging and exchange rates at the London 4pm fix', Journal of Empirical Finance 30
- **Brief:** H1 intraday, no overnight: on the last business day of the month take the sign of SP500 month-to-date return as an equity-performance proxy, enter EURUSD/GBPUSD (or short USDJPY) ~2h before the DST-aware 16:00 London fix, exit on the H1 bar after the fix, one trade per symbol/month. Symbols EURUSD/GBPUSD/USDJPY; H1; ~12/yr. Cause: passive funds and hedge overlays mechanically sell USD at the WM/R fix to restore hedge ratios when foreign equities rose — mandate-forced, price-insensitive flow (Melvin & Prins 2015).
- **Why orthogonal:** Sign is driven by monthly equity performance and fix mechanics, not FX trend/carry, and it is a different flow from gotobi (domestic 5/10-day fix); a distinct calendar diversifier.
- **Next action:** PROBE: test the MTD-equity-sign fix-window trade on the post-2015 sub-sample only; the 2013 fix reform smeared the print over a 5-min window, so build only if a residual edge survives post-reform (H1 granularity + noisy sign are the risks).

### #16 — Compression-gated opening-range breakout (Balke-fix, vol-in-not-vol-out)

- **Tier:** DATA_PROBE · **Family:** TC · **Symbols:** WS30.DWX, GDAXI.DWX · **FTMO-density:** yes
- **Source:** Toby Crabel, 'Day Trading with Short Term Price Patterns and Opening Range Breakout', 1990 (NR7)
- **Brief:** M15 opening range then H1 management on WS30/GDAXI: take the breakout ONLY when today's OR width is in the bottom tercile of the trailing 20-session ranges AND D1 ATR is below its median (compression gate), stop at the opposite OR side (tight), target 1-2x OR width or trail, EOD-flat, one shot/day. Symbols WS30/GDAXI; M15/H1; ~95/yr. Cause: compressed openings leave calendar-forced pre-open limit-order imbalance uncleared, which resolves as a directional first-hour expansion (Crabel NR7 1990); the vol-gate inverts Balke's failure (breakouts in HIGH vol died at Q05 DD).
- **Why orthogonal:** Weak orthogonality caveat — this is TC, the family the book is already 38% concentrated in; the compression gate makes it fire on quiet-open days the trend engines ignore, but that is the whole bet.
- **Next action:** PROBE: prototype and measure daily-return correlation to the XAU/index TC bloc; admit only if <0.15, else it merely deepens TC concentration. If admitted, validate the gate holds the Q05 DD tail via honest walk-forward — never TP re-opt or SL-tightening (kill-list).

### #17 — London-open Asian-range volatility breakout (GBP session burst)

- **Tier:** DATA_PROBE · **Family:** TC · **Symbols:** GBPUSD.DWX, GBPJPY.DWX, EURGBP.DWX · **FTMO-density:** yes
- **Source:** Ranaldo, JBF 2009; Ito & Hashimoto, NBER WP 2006 (intraday FX seasonality)
- **Brief:** H1: build the Asian-session range, and at London open on the first H1 close beyond it enter in the break direction, gated to require the Asian range width < p*ATR(D1) (a compressed coil), stop at the opposite Asian-range side, target q*range or trail, EOD-flat, one shot/day, news-suppressed. Symbols GBPUSD/GBPJPY/EURGBP; H1; ~140/yr. Cause: FX volume/volatility step-changes at London open as European real-money flow arrives, releasing accumulated thin-hours imbalance (Ranaldo 2009; Ito-Hashimoto 2006).
- **Why orthogonal:** GBP-complex pairs are entirely unused and this is an intraday session-timed burst on a different clock and currency bloc from the daily XAU/index trend; but it is TC and conceptually overlaps #16.
- **Next action:** PROBE: prototype and verify low realized correlation to the #16 compression-ORB before admitting both; GBPJPY wide spread and London false-breaks are the erosion risks. Must not collapse into a session-window over-fit (kill-list).

### #18 — EIA-anchored natural-gas post-report reversal (event fade)

- **Tier:** DATA_PROBE · **Family:** MR · **Symbols:** XNGUSD.DWX · **FTMO-density:** no
- **Source:** Ederington & Lee, JF 1993; Gay, Simkins & Turac, Journal of Futures Markets 2009 (EIA gas price impact)
- **Brief:** M15 trigger / H1 manage on XNGUSD, EIA-day only: measure the initial post-release impulse, and if |impulse| >= s*ATR (overreaction) with no continuation on the next bar, fade toward the pre-release price with a hard stop beyond the impulse extreme, partial-retrace target, EOD-flat, no position without the scheduled event. Symbols XNGUSD.DWX; M15/H1; ~45/yr. Cause: the scheduled EIA number forces simultaneous rehedging in a thin high-gamma market, overshooting fair value before liquidity providers reload (Ederington-Lee 1993).
- **Why orthogonal:** Single-event weekly fade tied to a specific release is timing-orthogonal to every trend/session sleeve and to the running XNG VoV/rank motors, which are not event-clocked.
- **Next action:** PROBE: full-history event study of XNG post-EIA-print behavior 2015-2025 to settle DIRECTION (fade vs continuation) with positive expectancy net of severe print slippage — this candidate contradicts killed #14 on the same event, so the sign must be established empirically, not asserted, before any build. Keep this fade over #14 only if the study confirms reversal.

## Coverage gaps (explicitly unfilled)

- NO steady-density SA/CS motor survived: the scarce-family survivors are all low-frequency (GSR #1 ~18/yr, AUDNZD #2 ~30/yr), cost-fragile (SP500-NDX dispersion #9, ~90% common beta), or Verbund/backtest-only (FX XS reversal #38). The book's structural SA-of-one gap is only partially addressed — none of the lenses produced a high-density, cost-robust statistical-arbitrage sleeve.
- NO steady short-side density: every short survivor (#28, #29, #32) is lumpy crisis-alpha that fails the FTMO steady-median FUND_SCORE test. There is a genuine gap for a non-crisis, everyday short-side density source, but the index-swap constraint plus TC-long concentration make it structurally hard — worth an explicit design ticket rather than leaving it implicitly unfilled.
- Index-intraday-MR CLUSTER redundancy: #16, #19 (and killed #34/#39, plus TC #17/#21) all fade index intraday microstructure on the same GDAXI/WS30/UK100 symbols with the same choppy-day payoff. The slate's apparent breadth here is likely 1-2 independent sources after mutual-correlation pruning — a cross-candidate correlation matrix (not per-candidate Q08) is the missing step no lens performed.
- Silver (XAGUSD) has NO standalone directional or MR source: it appears only as the hedge leg of the GSR spread. XAGUSD is an unused tradable symbol with distinct industrial-demand/retail-overshoot dynamics that no candidate mined on its own.
- Energy (XTI/XNG) orthogonal space is empty: every energy candidate was killed (broken oil-gas tether, overlap with running motors, or contested EIA direction). Aside from the contested EIA fade (#22, itself a DATA_PROBE), the commodity lane produced no genuinely new orthogonal energy source — an untapped axis given XTIUSD/XNGUSD are in-universe.
- Cross-asset lead-lag beyond oil->CAD is unexplored: the only cross-asset channel attempted (#6 WTI->USDCAD) was killed. Channels like gold->AUD, index->FX-risk-proxy, or XAU-vol->JPY were never proposed, leaving the entire cross-asset-diffusion family a coverage gap.
- Tick-volume is unused as a signal input: ground truth confirms OHLCV + tick volume is available, but no candidate used volume/participation as a filter or trigger (e.g. volume-confirmed liquidity provision, low-volume gap-fade quality). A cheap orthogonality lever the lenses ignored.
- Hard data ceilings acknowledged, not fillable: no bond/rates instruments, no options/vol-surface, no single-stock or order-flow, no fundamentals feed exist in the 37-symbol DWX universe — so entire orthogonal families (curve trades, vol-risk-premium harvesting, dispersion on real constituents) are permanently out of reach and should be documented as structural, not retried.

## Rejected appendix — do not re-litigate

- **FTSE London-Open International-Repricing Fade (UK100)** — Traded mechanism is just an open gap-fade redundant with cleaner siblings (#16/#34); the FTSE-GBP-inverse story is decorative (the fade exploits gap reversion, not composition) and it runs on the single highest-RT-cost index where open spreads may eat the edge.
- **Dow Price-Weight Distortion Intraday Fade (WS30)** — False cause — a high-priced constituent moving a price-weighted index is the index correctly reflecting its definition, not a reverting mispricing; fails limit-to-arb and reduces to generic RSI2 intraday index MR overlapping the existing SP500 cumRSI2 sleeves.
- **WTI-to-Loonie Petro Lead-Lag (USDCAD)** — Ferraro-Rogoff-Rossi (2015) finds oil->FX predictability is essentially contemporaneous and fails OOS at the daily horizon — the exact lead-lag traded is what the cited paper says is NOT exploitable; the muted-reaction filter is load-bearing and inverts in USD-driven regimes (2022).
- **Gold-Silver Ratio Reversion (XAU/XAG dollar-neutral)** — Duplicate of the #1 GSR spread (same D1 dollar-neutral gold-silver z-reversion, 100 vs 60 lookback); only one GSR sleeve can enter.
- **AUDNZD Policy-Differential Band Reversion (near-substitute exploited)** — Duplicate of the #2 AUDNZD single-instrument differential-band reversion; adaptive-mid + vol-gate is a minor spec difference, not a second return source.
- **Oil-to-Gas Ratio Seasonal-Band Reversion (XTI/XNG deseasonalized)** — The oil-gas tether empirically broke with shale (~2009) so the reversion anchor no longer exists; deseasonalizing a broken relationship doesn't restore it, and the candidate self-flags highest overlap with the running XTI/XNG lane plus a wide-spread illiquid XNG leg.
- **Turn-of-Month Equity Index Drift (intraday, EOD-flat)** — The ToM premium is overnight-concentrated (Lou-Polk-Skouras); forcing EOD-flat to dodge index swap discards the component that carries it, leaving a near-zero intraday residual; heavily published (Ariel/McConnell-Xu) and decayed post-2000.
- **EIA Weekly Natural-Gas Storage Post-Report Drift** — Direction (underreaction/continuation) is asserted, not sourced — Linn & Zhu (2004) is about report-day volatility, not directional drift — and it directly contradicts #22 (fade) on the same event, signalling the sign is fit.
- **Pre-Holiday Equity Index Drift (short-covering into closure)** — ~9/yr across two symbols is ~4-5/symbol, at or below the 5/yr economics floor; one of the most-published/arbitraged calendar anomalies (Ariel 1990), materially decayed, and intraday-only capture discards the overnight-gap portion carrying most of the effect.
- **Gold/silver ratio intraday mean-reversion (relative-value spread)** — Mechanism mismatch — the gold-silver convergence premium operates over days, not intraday where the metals move ~1:1 and ratio deviation is noise; two-leg metals execution with punitive RT commission against a sub-noise edge is cost-negative and redundant with the D1 GSR sleeve.
- **Turn-of-Month index long (calendar-flow window)** — Multi-day index LONG hold pays the index overnight swap the cost model says kills index holds, likely exceeding the decayed ToM residual; ~12/yr/symbol fails density and all ToM index sleeves fire the same dates (correlated ~= one slot).
- **FX Short-Term Momentum after Large Moves (unused crosses)** — FX momentum is a documented decayed/crowded factor post-2008 (Menkhoff et al., conceded) and lives at 3-12mo not H4; at short horizons FX is more reversal than continuation, so the continuation sign contradicts the better-supported reversal candidates.
- **Precious-Metals Autumn/Seasonal-Demand Calendar** — Adds LONG-XAU beta to the already-dominant XAU concentration — opposite of the orthogonality mandate (candidate calls itself 'weakest orthogonality of the slate'); ~6/yr fails density and it rests on a single paper (Baur 2013) with thin OOS.
- **Gold Haven Long — Conditional on Equity Drawdown** — Adds LONG-XAU exposure into the dominant concentration and the anti-extension filter is mitigation not guarantee; gold sells FIRST in acute liquidation (margin-driven) whipsawing the entry, ~10/yr, wrong direction for the mandate.
- **CHF Safe-Haven Strength Burst (short risk/CHF crosses)** — SNB intervention is a two-way tail leaning AGAINST franc strength (the 2015 floor hazard, opposite direction to and directly conflicting with #3), so short-risk/CHF can be crushed in a floor regime; adverse swap, lumpy ~10/yr, and double-counts risk-off beta with #29/#32.
- **Defensive RV Spread — Long XAU / Short Index (two EAs, backtest-only)** — Author-declared BACKTEST-ONLY: the multi-day index-short leg pays the prohibitive overnight swap the cost model says kills such holds, so it can only be a portfolio-analysis construct, not a live-deployable return source.
- **Index overnight-gap fade (resurrect QM5_1277 Chan buy-on-gap, 5-index stack)** — Fades ALL gaps beyond a threshold INCLUDING large news gaps — the exact fade-against-real-news failure mode #16 explicitly excludes; the LOW_FREQ retirement never established a surviving edge, and reaching the claimed 200/yr requires loosening the threshold that likely killed it. Fold the 5-index density lever into #16.
- **Turn-of-month index inflow, regime/vol-gated (resurrect QM5_20026)** — The D1 multi-day hold TD-1 through TD+3 is an overnight index hold with no EOD-flat, violating the binding index-swap constraint; the SMA200+ATR-ceiling gate is a legitimate lever but the venue overnight cost is fatal, ~24/yr fails density, and ToM sleeves are cross-symbol correlated.
- **MACD-divergence exhaustion reversal, re-homed to FX (resurrect QM5_12544)** — Already died Q04 on all three symbols tried; the FX re-home is admitted speculation ('genuine hypothesis, not a proven fix'), the cause is generic 'exhaustion', and MACD-divergence is param-fragile indicator-lore that overfits — a reputable source (Katz) doesn't rescue a gate-failed detector.
- **AUD/NZD/CAD commodity-currency-bloc cointegration spread, D1->H4 (resurrect QM5_10009)** — Died Q04 (robustness) and D1->H4 re-timing doesn't fix a robustness failure — a macro commodity-currency cointegration operates on daily+ horizons, so H4 adds microstructure noise and three-leg .DWX spread cost, not signal; the AUD-NZD leg is near-degenerate leaving only CAD with independent information.
- **Index opening-range false-break FADE, volatility-contraction gated** — Core mechanism ('initial break runs the stops then reverts') is a relabeled ICT stop-hunt / liquidity-grab, kill-list-adjacent even under Crabel NR7 dressing, and it is redundant with #19 on the same index-MR axis; the valuable Q05-DD-breakout-inverse insight should inform #16/#19's design instead of standing as a separate stop-hunt sleeve.

## Dispatch plan (2026-08-13)

- BUILD_CANDIDATE #1/#2/#4/#14 -> one research_strategy card-drafting ticket each (citations from briefs; approve-card validator requires year+venue in prose).
- DATA_PROBE #3 (extension-fade vs gap-fade correlation) + #5 (GSR post-2011 half-life) -> one read-only codex probe ticket; build decisions gated on probe outcomes.
- Remaining DATA_PROBEs and RESEARCH_TICKETs queue behind the first wave; index-intraday-MR cluster (#3/#4/#8/#16) is capped to ONE surviving build until cross-correlations are measured.
- Research throttle note: dispatched under explicit OWNER directive 2026-08-13; reservoir rule not applicable to this program wave.