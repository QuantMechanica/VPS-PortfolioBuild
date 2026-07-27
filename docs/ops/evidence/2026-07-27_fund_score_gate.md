# FUND_SCORE factory capability — 2026-07-27

## Result

Implemented as a screening-only metric. `fund_score.py` wraps the established
`challenge_book_60d.py` / `sleeve_improvement_targets.py` engine; it does not
maintain a second calendar, dormancy, eligibility, or rolling-window model.

Surfaces:

- `python tools/strategy_farm/farmctl.py fund-score --ea QM5_9936 --symbol USDJPY`
- `--refresh-cache` writes
  `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json`
- each dashboard render refreshes that cache and the portfolio sleeve table
  exposes `FUND_SCORE`

The cache is the full machine-readable 192-stream table, including every
UNSCORABLE row and its reason. It is not stored in a verdict table and contains
`gate_override_allowed:false`; structurally it cannot promote or alter a gate.

## Scored sleeves

| Sleeve | med60 | \|worst day\| | wDD p90 | FUND_SCORE |
|---|---:|---:|---:|---:|
| 9936:USDJPY | 3.3425 | 1.7644 | 8.1822 | 0.4085 |
| 13301:GDAXI | 1.8330 | 1.8451 | 5.0892 | 0.3602 |
| 10700:XAUUSD | 1.1058 | 2.0160 | 4.9744 | 0.2223 |
| 13213:USDJPY | 1.7965 | 1.9006 | 9.4541 | 0.1900 |
| 10848:XAUUSD | 1.1730 | 2.0290 | 6.7547 | 0.1737 |
| 10145:XAUUSD | 0.3283 | 0.9982 | 1.5076 | 0.1642 |
| 13108:XTIUSD | 0.3171 | 1.0000 | 2.0671 | 0.1534 |
| 11063:USDJPY | 0.8841 | 3.0494 | 5.3292 | 0.1450 |
| 10553:XAUUSD | 0.9697 | 2.8785 | 7.4569 | 0.1300 |
| 9403:GDAXI | 0.6325 | 3.0057 | 5.1672 | 0.1052 |
| 10291:SP500 | 0.3236 | 1.2144 | 3.2864 | 0.0985 |
| 10183:XAUUSD | 0.1898 | 0.9968 | 0.9698 | 0.0949 |
| 12969:USDJPY | 0.1867 | 1.0097 | 0.7709 | 0.0925 |
| 13036:GDAXI | -0.0413 | 0.9930 | 2.4358 | -0.0170 |
| 10128:XAUUSD | -0.0719 | 0.9971 | 1.6604 | -0.0359 |

No sleeve reaches 1.0. Of all 192 streams, 15 are scored, 70 are explicitly
`UNSCORABLE:entry_time_incomplete`, and 107 are
`UNSCORABLE:challenge_engine_ineligible` (gate/span/coverage eligibility retained
from the existing engine). Missing entry time is never treated as zero exposure.

## Verification

```
python tools/strategy_farm/farmctl.py fund-score \
  --ea QM5_9936 --symbol USDJPY --refresh-cache
python -m py_compile tools/strategy_farm/portfolio/fund_score.py \
  tools/strategy_farm/dashboards/render_dashboards.py \
  tools/strategy_farm/farmctl.py
```

The query returned 0.408504 for 9936:USDJPY with all three components, matching
the independently published 0.41. Compilation passed. No database row, gate
verdict, queue, terminal, or live setting was changed.
