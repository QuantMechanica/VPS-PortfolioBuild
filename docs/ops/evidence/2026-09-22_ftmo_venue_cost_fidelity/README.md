# FTMO venue-cost fidelity — D2g6

- Router task: `73434cab-cf1c-4c17-8a11-9ca52c11d99e`
- Authority: `OWNER-DEC-FTMO-FINAL-MEGA-20260921`
- Verdict: **ABSTAIN_NO_ELIGIBLE_VENUE_DELTA**
- Read-model label: `VENUE_ADJUSTED` (separate from the preserved `FINANCED` headline)
- Terminal authority: read-only history attachment to a pre-existing FTMO demo process; no order, terminal start, `T_Live`, AutoTrading, roster, gate, or incumbent-weight change.

## Decision

The requested FTMO spread measurements exist, but the evidence does not support a
numerical FTMO-minus-Darwinex charge. Each requested symbol has 99,999 FTMO M1
observations. USDJPY, XAUUSD and USDCAD have no immutable Darwinex M1 spread snapshot;
GBPUSD and EURUSD have Darwinex snapshots from disjoint date ranges and therefore zero
exact matched minutes. The D2g6 collector records account/position census but not
request-price versus fill-price, so slippage is also `UNMEASURED`.

The governed rule is fail-closed: only `max(0, p90(FTMO_bps - DXZ_bps))` over at
least 60 exact matched minutes may become an additive simulator charge. Independent-
period quantile differences are descriptive only. The eligible spread and slippage
tables are consequently empty; a zero in those JSON objects would falsely claim a
measured zero and is not used.

## Measured FTMO spreads

Values are round-trip basis points. The full 24-hour breakdown and source bindings are
in `measurements.json`; `spread_comparison.csv` is the compact decision table.

| Symbol | M1 rows | p50 | p75 | p90 | 21Z p90 | 22Z p90 | 23Z p90 | Darwinex comparison |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| USDJPY | 99,999 | 0.186793 | 0.249689 | 0.442122 | 6.275030 | 0.317026 | 0.478690 | UNMEASURED; no DXZ spread snapshot |
| GBPUSD | 99,999 | 0.151213 | 0.224680 | 0.376379 | 10.939237 | 0.378768 | 0.303857 | ABSTAIN; 100,000 DXZ rows, 0 matched minutes |
| XAUUSD | 99,999 | 1.019116 | 1.111690 | 1.199750 | UNMEASURED (0 rows) | 1.344901 | 1.242210 | UNMEASURED; no DXZ spread snapshot |
| USDCAD | 99,999 | 0.281017 | 0.355520 | 0.433633 | 7.835741 | 0.446619 | 0.495075 | UNMEASURED; no DXZ spread snapshot |
| EURUSD (shadow) | 99,999 | 0.000000 | 0.000000 | 0.087727 | 5.260825 | 0.087957 | 0.086036 | ABSTAIN; 94,575 DXZ rows, 0 matched minutes |

The elevated 21Z values for four FX symbols document rollover widening. XAUUSD has no
21Z bars in this extract, so that cell remains unmeasured rather than imputed.

## Simulator and publication

`book_sim.py` now accepts mutually exclusive per-symbol additive tables through
`--spread-bps-rt-by-symbol` and `--slippage-usd-per-lot-rt-by-symbol`, either inline
JSON objects or JSON-file paths. Symbol lookup normalizes `.DWX` aliases. The existing
uniform research flags remain available. Stream P/L already includes Darwinex
execution, so the new values are additive venue deltas only and are never stacked with
the uniform flags.

Because no venue delta passed the evidence rule, the sensitivity ladder is an explicit
identity/abstention rather than a fabricated 0.5x/1.0x/1.5x result. The financed engine
was nevertheless rerun with 40,000 base paths and the existing five paired marginal
seeds at 40,000 paths each:

| Quantity | Result |
|---|---:|
| `P_FIRST_NET_FTMO_PAYOUT_LCB` | 0.8762 |
| `P_CHALLENGE_PASS` | 0.9565 |
| Daily-loss breach | 0.0000 |
| Maximum-loss breach | 0.0188 |
| Expected progress, USD/business day | 27.503667 |
| Additional measured spread drag | UNMEASURED / not charged |
| Additional measured slippage drag | UNMEASURED / not charged |

These are the zero-additional-charge financed reference values, **not** a validated
FTMO-adjusted economic headline. Fable/OWNER must not treat the 0.8762 LCB as venue-
adjusted until matched venue data exist.

The separate `venue_adjusted` block was published atomically to
`D:/QM/reports/state/ftmo_book_current.json`. The publisher hashes all non-venue fields
before and after the update; their canonical SHA-256 is
`d81cc7ce47d8ad7c651fa545e0cb430fe27987a4688d059aecaf641f85276e21`.
The `FINANCED` headline and every other state field were preserved.

## Cost sensitivity

The exposure-only diagnostic (one hypothetical additive basis point, not a measured
charge) identifies `13213_USDJPY_H1` as dominant: USD 8,643.283154 over the fixed
window, followed by `10706_GBPUSD_H1` at USD 5,652.547457. The three XAU sleeves total
USD 1,811.520279. Thus the velocity sleeve is the primary unresolved venue-cost risk;
gold is third at the symbol-group level.

## Provenance and bindings

- FTMO query: pre-existing PID 11756, server `FTMO-Demo`, masked login `*******732`,
  queried `2026-09-21T20:40:55Z`; inferred broker wall-clock offset UTC+3 with 55-second
  latest-bar lag on all five symbols. `orders_sent=0`, `autotrading_touched=false`.
- Measurement SHA-256:
  `8a4459878f45e3b41b871018bab157cfabe662146e736d871eeba4d53c620f2a`.
- Book simulation SHA-256:
  `73802b4d1b4e2ecf280944dacdaf0da26958c2df655fc0fd7e1fc6a2b8821409`.
- Marginal simulation SHA-256:
  `cfac766e372d335225387e5cfc3681c1cf74dc9788925f4b83ede37a98a34d14`.
- Evidence state snapshot SHA-256:
  `b2a04985fac465d8f54499356ed168265b81939f50cf8c41b8206506a1e32e1e`.
- Financed streams manifest SHA-256:
  `0d4b845c1dc39cb3af09f00a6cd240a0e861b1d1ca74d1cf0e2452573d830633`.

## Verification

Focused verification after implementation:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_book_sim.py tools/strategy_farm/tests/test_ftmo_venue_cost_fidelity.py tools/strategy_farm/tests/test_ftmo_venue_cost_publish.py -q -p no:cacheprovider
19 passed

python -m py_compile tools/strategy_farm/ftmo/book_sim.py tools/strategy_farm/ftmo/venue_cost_fidelity.py tools/strategy_farm/ftmo/venue_cost_publish.py
PASS
```

Tests cover matching-only delta eligibility, non-overlap abstention, rollover buckets,
server-clock normalization, per-symbol charging, `.DWX` alias handling, inline/file
CLI tables, negative/duplicate refusal, uniform/table mutual exclusion, no double
charge, financed-only publication, and preservation of non-venue state.

## Remaining dependency

Collect at least 60 exact concurrent M1 minutes on both venues for each D2g6 symbol and
capture request-to-fill execution telemetry by symbol. Re-run the same evaluator only
after those evidence gaps close; until then `VENUE_ADJUSTED` remains an explicit
abstention and the purchase-packet execution-cost uncertainty is unresolved.
