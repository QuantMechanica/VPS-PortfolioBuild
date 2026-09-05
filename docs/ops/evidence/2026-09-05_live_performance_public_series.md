# Public live-performance series

Task `00eae593-c8b6-45ef-9400-6915d5603065`: REVIEW. The hourly snapshot producer now includes an aggregate `live-performance.json`. No deployment repository, live journal, account setting or website was modified.

The [dry run](2026-09-05_live_performance_dryrun.json) reproduces **−472.96 USD / 65 closed positions / 24 active days** for 2026-08-01 through 2026-09-04, exactly matching the requested attribution validation. Since the July 24 epoch it contains **−1,436.59 USD / 85 closes / 30 active days**, through the last governed close at 2026-09-04 18:00 UTC. Negative results are retained.

Positions join by native position identity. Opening identity determines attribution, so an EA-opened position with a zero-identity closing deal remains included. Manual positions and positions outside the existing roster are excluded. Lifecycle profit, commission, fees and swap are booked on the complete position's Prague closing day. Partially open positions wait for closure; duplicate deals, incomplete entry histories, inconsistent costs, over-closes and unsupported reversals fail closed. Cashflows and floating P&L are excluded. Zero-close calendar days extend only through the observed export day.

The earlier validator uses UTC date slicing, despite the task describing it as Prague attribution. All included closes in this particular input retain their date under the Prague conversion, so the reconciliation remains exact. A fixture crossing Prague midnight and a winter-clock fixture verify the requested behavior. Active days mean days with a governed close, including a zero-net close; the earlier validator counts nonzero net days, which happens to agree for this input.

The index starts at 100 before the epoch day's closes and adds cumulative closed P&L divided by **100,000 USD reference capital**. Daily points are closing values; the first point can differ from 100. This is explicitly stated in the public basis string. It is not a mark-to-market account equity series, an assertion of epoch equity, or the DARWIN investor return. The requested DARWIN performance page is linked without scraping. All aggregate values remain accompanied by that distinction.

The roster is the existing attribution pointer, whose `signed` flag is false. This work reproduces that roster and records its hash; it neither grants deployment approval nor treats the pointer as an OWNER signature. Complete lifecycle costs can predate the epoch for positions closing after it. This explains the difference from the M10 in-window cash-deal figure.

Implementation: `tools/strategy_farm/build_public_live_performance.py`, a closed public JSON schema and hourly export/staging/validation wiring. The public document has only the requested metadata, daily tuples and aggregate totals. It excludes accounts, identities, per-deal rows, symbols, sleeves and private paths.

Verification: **18 focused tests passed**; full positive schema and forbidden-field negative validation passed; three PowerShell scripts parsed; direct CLI stdout matched the dry run; both input hashes match the earlier validation and remained unchanged after execution. Details and hashes are in [verification](2026-09-05_live_performance_verification.json). Website integration and final presentation remain in REVIEW.
