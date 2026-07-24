---
source_id: BOROWSKI-XBR-DOM17-2016
title: Brent-oil day-of-month seasonality - session dated the 17th
publisher: Journal of Management and Financial Sciences, SGH Warsaw School of Economics
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-22
primary_url: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016
open_full_text_url: https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EFFECTS_IN_MARKETS_OF_FUTURE_CONTRACTS
strategy_ids: [BOROWSKI-XBR-DOM17-2016_S01, BOROWSKI-XBR-DOM17-2016_S02]
---

# Borowski Brent Day-17 Source Packet

The complete Borowski (2016) article was reviewed. It is a named-author,
peer-reviewed empirical paper (tier B), not a trading track record. Section
4.3 uses Brent-oil futures from 1983-03-30 through 2016-03-31 and compares each
numbered calendar day's daily return with all other dates.

For Brent, 15 of 31 day means are positive. The paper reports the maximum as
`+0.3394%` on day 1 and the minimum as `-0.6962%` on day 17. Mean equality is
reported rejected for dates 8 (`p=0.0412`) and 26 (`p=0.0434`), not day 17.
The day-17 short is therefore an explicitly weak extreme-mean falsification
hypothesis, not a statistically established anomaly.

The article searches many commodities, months, weekdays, and 31 dates without
a reported family-wise correction, assumes normal return populations, ends in
2016, and does not establish transfer from a futures series to `XBRUSD.DWX`.
The exact 17th is never shifted. The one-session short, ATR stop, spread cap,
fixed sizing, news gate, and restart-safe monthly attempt marker are QM
mechanization, not source-authored alpha.

Repository-wide slug, card, EA, and registry searches found no exact Brent
day-17 short/next-D1-flat carrier. Existing Brent month, weekday, trend,
momentum, ratio, and relative-spread builds use different triggers and holds.
The source and mission authorize only a `RISK_FIXED` Q02 test, never live
deployment, AutoTrading, T_Live, a manifest, portfolio admission, or a
portfolio-gate change.

## Second extraction: Brent day 8 long

The same completed article reports Brent day 8 as a positive numbered-session
anomaly and rejects equality versus the other calendar dates at `p=0.0412`.
`BOROWSKI-XBR-DOM17-2016_S02` mechanizes that distinct result as a long
`XBRUSD.DWX` package opened only on a genuine D1 bar dated 8 and closed at the
next D1 boundary. No missing eighth is shifted. ATR risk, spread control,
restart-safe attempt state, and fixed sizing are disclosed QM plumbing.

Repository-wide exact-mechanic searches found no Brent day-8 long carrier.
The multiple-testing burden, futures/CFD basis, old sample, and transaction
costs remain binding Q02 kill risks.
