---
source_id: BOROWSKI-WTI-H2M-2016
title: Crude-oil second-half-of-month return asymmetry
publisher: Journal of Management and Financial Sciences, SGH Warsaw School of Economics
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016
open_full_text_url: https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EFFECTS_IN_MARKETS_OF_FUTURE_CONTRACTS
strategy_ids: [BOROWSKI-WTI-H2M-2016_S01]
---

# Borowski WTI Second-Half-of-Month Source Packet

The complete Borowski (2016) peer-reviewed article was reviewed. Section 4.4
reports NYMEX crude-oil futures average daily returns of `-0.0148%` for days
1-15 and `-0.0824%` for days 16-month-end over 1983-03-30 to 2016-03-31.
The difference is explicitly not significant (`p=0.5271`).

The card therefore treats days 16-month-end as a weak, structural calendar
falsification hypothesis, not a proven edge. The broad uncorrected calendar
search, normality assumption, pre-2016 endpoint, futures/CFD basis, broker-day
mapping, financing and roll construction are binding kill risks. The fixed
risk ATR stop and execution guards are QM plumbing, not source claims.

Repository-wide searches found no WTI short entered on broker day 16 and held
until the first D1 bar of the next month. The OWNER mission approves one locked
RISK_FIXED build and Q02 test only; it does not authorize live deployment,
AutoTrading, T_Live, manifests, portfolio admission, or gate changes.
