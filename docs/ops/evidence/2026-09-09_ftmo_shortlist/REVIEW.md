# FTMO cost triage — zero-pair prospective roster

Task 54729be7-8082-4a8c-afcf-e4497e6d9f4a. REVIEW; cost closure remains incomplete.
`comparison.csv` covers all 16 frozen intake pairs. Seven have exact-hash exposed
streams; nine have no exposed cost stream in this intake and are explicitly
unscored. No new holdout, native run, terminal initialization, or download occurred.

`compare.py` validates each stream against the published September 5 hash, reuses
the existing full-lifecycle exporter, and replaces the provisional triple weekday
with September 6 native metadata. MT5 Sunday=0 becomes Python Monday=0; oil's
native 5 is Friday, Python 4. Source commission/swap are replaced, not charged
twice. FTMO commission remains the dated provider projection, never a realized
broker fee. Native account terms identify Standard, 1:100, not Swing. Snapshot
and account terms are historical observations, not a fresh account attestation.

| Pair | Trades | Provisional USD/target lot RT | Net / closed daily DD | Disposition |
|---|---:|---:|---:|---|
| 10706 GBPUSD | 360 | 40.10 | 2.94 | Investigate current identity and matched costs |
| 11421 EURUSD | 91 | 31.73 | 0.60 | Execution canary prerequisite; investigate costs |
| 11422 USDCAD | 195 | 58.34 | 1.11 | Investigate account-currency tick conversion |
| 13054 XTIUSD | 82 | 27.67 | 2.07 | Investigate Friday rollover and lot/contract mapping |
| 1537 XAGUSD | 96 | -113.67 | -0.39 | Exclude: already negative before spread |
| 20048 XTIUSD | 60 | 13.15 | 1.35 | Lower cost headroom; shares oil exposure |
| 21505 XAGUSD | 116 | 53.87 | 0.19 | Weak return/DD after holding costs |

These are different instruments: USD/lot is a within-instrument cost sensitivity,
not a universal cross-instrument risk score. Closed daily drawdown excludes open
floating losses and is not FTMO equity drawdown. Frequency uses the observed
first-entry/last-exit span, not a certified full test window; holding hours and
the actual dates are in the CSV. The figures cannot be extrapolated as returns.

13054's native Friday rollover correction is +224.63 USD, producing provisional
net 4,475.45; 20048 changes +40.20. Silver 1537 remains about -1,876.79 USD.
The JSON contains sensitivity at an additional 0,1,2,5,10,20,50 USD per target lot
RT. The USD/lot column is also the break-even additional spread-plus-slippage
cash burden under this historical projection. Negative headroom is not recoverable
by charging additional positive costs. No unknown cost is silently filled with zero.

21 pairwise closed-day cash correlations are reported with common calendar spans
and zero-filled non-exit days. They range roughly -0.031 to +0.133. These sparse
realized series are not concurrent mark-to-market risk evidence. Multiple USD
legs, oil sleeves and silver sleeves share risk despite low closed-day correlation.
An eventual roster requires common intraday equity, pending stop-risk and stress
exposure. No weights or portfolio loss promises are assigned.

**Selected roster: zero.** The four listed investigation pairs are data-closure
priorities inherited from the task, not an accepted shortlist. Their current
binary, execution and full cost identities remain unresolved; no native
qualification batch is authorized by this report.

## Small remaining acquisition and reuse

Use existing native receipts and the already-running collector. For only GBPUSD,
EURUSD, USDCAD and USOIL.cash, the next read-only specification receipt must contain
lot minimum/step/maximum, point, tick size and profit/loss tick values in account
currency, contract size, swap mode and daily multipliers, quote/server/UTC clock,
and margin-calculation evidence for an explicit notional. The September 6 receipt
has contract size, digits, profit currency, long/short swap and triple day; it
does not contain those missing lot/tick/margin fields. Do not infer them.

Realized commission requires actual broker DEAL_COMMISSION/DEAL_FEE linked to
symbol, direction, volume and timestamp from existing fills. If no suitable fill
exists, it remains missing; this task never generates a trade to measure a fee.
Slippage likewise needs signal/request/ack/fill timestamps and executable quotes.

Reuse M08's frozen FTMO minutes and the governed export/backfill path for the
same four instruments. Demand same instrument, overlapping UTC minutes, attested
broker/DST conversion and point-to-price normalization before estimating a delta.
M08's original overlap is zero and recorded Z labels were not certified UTC.
Do not reuse those point distributions as a cash spread adjustment.

Parent 3032534e remains Claude's active backfill task. Its newer dependency
f6d18a6e is REVIEW with 296/300 download hours resolved and 32 tests; this supersedes
the old 50%-failure projection. No second 37-symbol download was started. Request
the four-symbol overlap through that existing path after its price-scale and
reconciliation checks, then rerun `compare.py` with a new explicitly bound version.
The signed 2017–2025 archive and active backtests remain untouched.
