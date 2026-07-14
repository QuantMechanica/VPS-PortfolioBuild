# FTMO XAU US-close overnight Q02 - 2026-07-10

## Verdict

`QM5_13125_xau-usclose-ovnt` is `Q02 FAIL` and retired. No Q04 or later phase
was run.

The native real-tick model-4 reports looked viable only because the custom
`XAUUSD.DWX` symbol charged neither commission nor swap. The pooled native
result was 1,371 trades, PF 1.293 and USD 60,572.98 net. Re-costing every
round trip to the current FTMO XAU/USD specification produces PF 0.971 and
USD -6,978.62 net.

## Cost basis

FTMO's official symbols endpoint reported the following XAU/USD values on
2026-07-10:

- contract size: 100
- digits: 2
- commission: 0.0014 percent per side
- long swap: -75.93 points

The reconciler retains native tick bid/ask spread, pairs each entry and exit,
applies commission to entry and exit notional, and applies one swap unit per
crossed weekday rollover with three units on Wednesday. The fixed current swap
is a deployment-cost stress across history, not a claim about historical FTMO
swap schedules. A second variant uses the internal conservative 5-bp
round-trip notional commission and reaches PF 0.961.

Official sources:

- `https://ftmo.com/en/symbols/`
- `https://ftmo.com/wp-json/ftmo/symbols`

## Year results

| year | trades | native PF | native net | FTMO-cost PF | FTMO-cost net | commission | swap |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2019 | 198 | 1.33 | 9,235.96 | 0.80 | -7,381.56 | 535.54 | -16,081.97 |
| 2020 | 179 | 1.28 | 7,678.28 | 0.99 | -453.29 | 332.80 | -7,798.77 |
| 2021 | 202 | 1.00 | -31.28 | 0.75 | -10,222.03 | 429.95 | -9,760.80 |
| 2022 | 200 | 1.00 | -70.29 | 0.75 | -9,788.31 | 404.45 | -9,313.57 |
| 2023 | 196 | 1.33 | 9,570.03 | 0.97 | -1,038.78 | 468.36 | -10,140.45 |
| 2024 | 199 | 1.77 | 19,616.47 | 1.43 | 12,000.77 | 413.74 | -7,201.96 |
| 2025 | 197 | 1.52 | 14,573.81 | 1.33 | 9,904.57 | 351.86 | -4,317.38 |

The improvement in 2024-2025 does not rescue a pooled strategy that loses
under current deployment economics and has four of seven individual years at
or below PF 0.99 after costs.

## Evidence

- machine artifact: `artifacts/ftmo_xau_usclose_overnight_q02_costed_2026-07-10.json`
- reconciler: `tools/strategy_farm/portfolio/ftmo_report_cost_reconcile.py`
- tests: `tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py`
- strict compile: `framework/build/compile/20260710_205251/QM5_13125_xau-usclose-ovnt.compile.log`

T1-T5 only were used. T6-T10, T_Live, the FTMO terminal, AutoTrading, and live
accounts were not touched.
