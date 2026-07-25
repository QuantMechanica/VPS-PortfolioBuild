# STR-086 — FINAL reconciled spec (build authority)

EA: QM5_20139 `dibs-inside-bar-h1` · TF H1 · Cohort: EURUSD.DWX,
GBPUSD.DWX (non-JPY; JPY-00:00-anchor = variant).

## Day state

- Anchor: 06:00 UTC via QM_BrokerToUTC (NY-close GMT+2/+3); at the
  first H1 bar whose UTC open-hour ≥ 6 begins the DIBS day; record
  dayOpen = that bar's open. Day roll clears IB/pending state.
- Setup window: IBs closing ≤ strategy_window_hours (9) after the
  anchor (FLAGGED bounded projection; 6/10 = Q03 sweep).

## Setup (closed-bar)

- IB: High[1] ≤ High[2] AND Low[1] ≥ Low[2] (inclusive).
- Consecutive-IB run: only the FIRST (largest) IB of the run is
  tradable until a non-inside bar resets the chain (source verbatim).
- Long trigger T_L = ib.high + 1 pip + setupSpread, eligible only if
  T_L > dayOpen. Short trigger T_S = ib.low − 1 pip, eligible only if
  T_S < dayOpen. One side eligible → single stop order; both (IB spans
  the open) → OCO pair, cancel the other on fill (source verbatim).
- Long SL = ib.low − 1 pip; short SL = ib.high + 1 pip + setupSpread.
- setupSpread = Ask − Bid at order creation (MT5 Ask-trigger semantics
  make the Bid break the IB top by ~1 pip before entry — 03 #3).

## Management (netted; QM5_20101/20098 partial machinery)

- R = |fill − initial SL|. At +1R favorable executable price: close 50%
  of ORIGINAL volume once (volume-step normalize down, keep ≥ min lot;
  if no valid partial, skip + log). Initial SL untouched at the event.
- Runner: per closed H1 bar, ratchet SL to MA20(H1, close) value when
  it tightens and is broker-valid. Tighten-only. FLAGGED: source
  example shows the MA20 on a daily chart; H1 mapping = interpretation;
  initial-stop-only = labeled variant.
- Pending cancel: window end, day roll, replacement by a newer valid
  first-IB setup, or side-eligibility loss. No bar-count expiry.
- One live position per magic/symbol; fresh setup allowed after a
  completed exit inside the window; no auto-reverse, no add-ons.

## Inputs

```
strategy_open_utc_hour = 6
strategy_window_hours = 9
strategy_break_buffer_pips = 1.0
strategy_partial_r = 1.0
strategy_partial_fraction = 0.50
strategy_runner_ma_period = 20
```

## Hooks

Filter: H1/params/warmup ≥ 2 days + MA20 handle. Entry: returns false —
pending-order state machine lives in manage (house pattern for stop-
order strategies; skeleton entry gate would consume the edge). Manage:
day state, IB detect, OCO placement/cancel, 1R-partial once-latch with
per-bar retry pacing, MA20 ratchet. Exit: false. News: default
fail-closed. NO QM_IsNewBar(); own static guards; ZeroMemory(req) +
symbol_slot; QM_EXIT_PARTIAL events.
