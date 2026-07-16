---
card_id: month-end-fx-rebalancing
status: DRAFT_FOR_APPROVAL
ea_id: TBD
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX]
timeframe: D1
priority_track: true
origin: FX_EDGE_DISCOVERY_SCIENTIFIC_FRAMEWORK_2026-07-16 (family #2, top directional calendar edge)
---

# Month/Quarter-End FX Hedge-Rebalancing Flow

## thesis
Hedged foreign-equity mandates must restore their FX hedge ratio at month-end. When global equities
**rose** over the month, the value of the foreign-equity book rose, so hedgers must **sell the foreign
currency / buy USD** at the month-end WMR 16:00 London fix to re-hedge → the **USD tends to strengthen
into month-end after strong-equity months** (and the foreign currency weakens); the reverse after weak
months. This is a **mandatory, price-inelastic fiduciary flow**, not a bet — which is exactly why it
persists despite being fully public (Melvin & Prins 2015, *J. Financial Markets*; the surviving residual
of the WMR-fix literature after the 2015 window reform killed the intraday scalp). Arbitrage does not
close it because the counterparty *must* transact regardless of price.

## market_universe
The liquid foreign-vs-USD majors with the largest hedged-mandate exposure: **EURUSD, GBPUSD, AUDUSD**
(each is "foreign currency / USD", so the flow acts on the base). Quarter-end (Mar/Jun/Sep/Dec) is the
stronger, cleaner signal (bond + equity rebalancing) and may be run as a stricter high-conviction subset.

## timeframe
**D1** signal and execution. Enter in the **last 1–2 trading days of the calendar month**, ideally into
the London 16:00 fix window; hold across the turn; exit **1–3 trading days into the new month** once the
rebalancing flow is complete. ~12 trades/yr/pair (month-end) or ~4/yr/pair (quarter-end-only variant) →
**low frequency, low cost drag** — the whole point (survives the ~4.5-pip FX round-trip hurdle).

## entry
Global-equity-month proxy = monthly return of a broad index available in the DWX tester
(**NDX.DWX** monthly close-to-close, or WS30/SPX proxy). On the penultimate month-end trading day:
- if index_month_return > +θ  → **SHORT** the foreign major (long USD),
- if index_month_return < −θ  → **LONG** the foreign major (short USD),
- else no trade.
θ is a small threshold (e.g. 0.5×monthly ATR of the index) — **one primary parameter** (low freedom).

## exit
Time-based: flat by the close of the **N-th trading day of the new month** (N=2 default). Optional
protective SL at k×ATR(20) of the pair (wide — this is a flow trade, not a tight-stop scalp). No fixed
pip target; the edge is the turn-of-month flow, captured by the calendar window, not a price level.

## risk
`RISK_FIXED` for backtests / `RISK_PERCENT` live, hard ≤1% per sleeve. Position sized off the ATR-based
SL. PORTFOLIO_WEIGHT per admission.

## filters
- Month-end / quarter-end calendar window only (broker-time month boundaries; mind GMT+2/+3 US-DST).
- High-impact news blackout via the framework news filter (order the Friday-close/flatten BEFORE the
  news return — see the no-weekend ordering-gap fix).
- Optional: skip months where the index return is within the θ dead-band (no clear rebalancing pressure).

## falsification
If, over full DWX history with the ~$45 FX round-trip commission injected, the calendar-conditioned
turn-of-month expectancy is **not** net-positive and reasonably stable across the sub-periods (Q08
seasonal/regime), **kill it**. Specifically: the "strong-equity-month → month-end USD strength" sign must
hold out-of-sample; if the sign is unstable or the net edge < cost, the mechanism is not present in our
data and the card is retired. (This is a *directional* claim with a clean null — ideal for honest testing.)

## q08_q11_risks
- **LOW_SAMPLE** by design (~12/yr/pair) — acceptable per OWNER 2026-07-16 (≥6 trades/yr admissible);
  pool the 3 pairs + quarter-end for statistical power.
- **Regime dependence**: the flow can invert in stressed months (forced de-risking overwhelms
  rebalancing) — expect `8.10_regime_crisis` scrutiny; report regime-split P&L.
- **Correlation**: the 3 pairs share the USD leg → internally correlated; for the book this is **one
  orthogonal bet** (turn-of-month USD flow), uncorrelated with our trend/mean-reversion/carry sleeves —
  which is precisely its portfolio value (Part V of the framework: orthogonality > standalone Sharpe).

## implementation_notes
- Read the index proxy via `iClose(NDX.DWX, PERIOD_MN1, ...)` or aggregate D1→monthly in-EA; guard for
  missing bars (MN1 untestable on DWX — derive monthly from D1 per QM precedent).
- Trading-day counting must use the pair's own D1 bar stream (skips weekends/holidays), not calendar days.
- Single primary parameter θ + exit-day N + ATR mult → **≤3 real degrees of freedom** (low overfitting
  surface; strong DSR posture given few trials needed).
- Compile via `compile_one.ps1`; real-tick Model 4; inject the FX commission at Q04+.

## why this is the right next build (framework linkage)
Ranked **#2 overall / #1 directional calendar edge** in the FX-family survey (below only carry, which
needs a rate-differential data feed our stack lacks). It is: a **named non-discretionary flow** (III.2),
**low-frequency/cost-friendly** (I.3), **low-parameter** (strong DSR), and **orthogonal** to every
current book sleeve (V). It is the cleanest available shot at *adding a genuinely independent structural
edge* to the DXZ book.
