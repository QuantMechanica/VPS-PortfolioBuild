# QM5_20019 xauxag-wkend

Implements `BOROWSKI-LUKASIK-METALS-2017_S01`: a weekly equal-notional
XAUUSD.DWX long / XAGUSD.DWX short basket opened Friday 21:00 broker time and
closed on the first Monday H1 bar. Both legs share one fixed-risk budget.

The build is research-only. Friday close is disabled solely because holding
the Friday-close/Monday-open interval defines this strategy. Orphans,
notional mismatch, stale positions and invalid data fail closed. No live or
portfolio-gate artifact is part of this build.
