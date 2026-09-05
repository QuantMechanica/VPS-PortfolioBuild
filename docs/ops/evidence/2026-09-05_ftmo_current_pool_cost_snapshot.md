# FTMO Current-Pool Cost Snapshot — 2026-09-05

## Verdict

`PASS_PROVISIONAL_ROLLOVER` for commission-and-swap projection; `ABSTAIN` on fully cost-adjusted performance and any purchase decision. The dated JSON covers all six instruments and eight current-pool sleeves. The public FTMO API does not expose the triple-swap weekday, and the matched FTMO-versus-Darwinex M1 spread sample is still absent. No purchase, deployment, or live-trading authority is created.

Machine-readable artifact: `docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json`.

## Provider evidence and normalization

The official FTMO symbols API was retrieved at `2026-09-05T04:24:16Z` (HTTP 200, 232,485 bytes, SHA-256 `07cad5b22514bda4fc013972f9473997c1e820d134733a1ab7cb58a90e94db66`). Selected source fields are preserved verbatim in the JSON and normalized with explicit units. The API is the current-term authority; the FTMO 25 September 2025 update is retained as historical corroboration. FTMO's account-specification FAQ says the exact instrument specification must be checked in the client platform and states Swing leverage up to 1:30. Darwinex's official execution-cost page is context only and is not substituted for FTMO terms.

| Pool symbol | FTMO code | Commission round trip | Swap long / short, points | Contract / tick | Swing margin |
|---|---|---:|---:|---:|---:|
| GBPUSD | GBP/USD | USD 5 / target lot | -6.70 / -5.20 | 100,000 / USD 1.00 | 3.3333% |
| EURUSD | EUR/USD | USD 5 / target lot | -13.29 / +0.17 | 100,000 / USD 1.00 | 3.3333% |
| USDCAD | USD/CAD | USD 5 / target lot | +0.71 / -12.00 | 100,000 / CAD 1.00 | 3.3333% |
| NZDUSD | NZD/USD | USD 5 / target lot | -4.82 / -1.36 | 100,000 / USD 1.00 | 3.3333% |
| XAGUSD | XAG/USD | 0.0014% notional / side | -23.05 / +0.32 | 5,000 / USD 5.00 | 6.6667% |
| XTIUSD | USOIL.cash | 0 | +5.83 / -35.11 | 100 / USD 0.10 | 6.6667% |

Swap units are `POINTS_PER_TARGET_LOT_PER_ROLLOVER_UNIT`. Wednesday triple rollover is retained as an explicitly provisional internal convention, not represented as a public-provider fact.

## Diff from 2026-07-30

Coverage changes from two of eight current-pool sleeves to eight of eight. EURUSD, GBPUSD, USDCAD, NZDUSD, and XAGUSD are added; the prior non-pool USDJPY and XAUUSD rows are outside this snapshot. For XTIUSD, swap long changes from `+4.22` to `+5.83` and swap short changes from `-26.80` to `-35.11`; commission remains zero.

## Dry-run through the existing cost path

The consumer loaders now unwrap the dated root schema and accept both percent-per-side and flat-USD-round-trip commission. The same trade-cost functions used by the cost-adjusted exporter produced this commission-and-swap-only replay. Same-second Q08 closes are included for commission with zero rollover duration. Spread delta is deliberately `MISSING`, so these values are not full FTMO net results.

| Sleeve | Trades | Source net | FTMO net before spread | Delta | FTMO commission | FTMO swap |
|---|---:|---:|---:|---:|---:|---:|
| 10706:GBPUSD | 360 | 69,101.93 | 65,196.75 | -3,905.18 | -8,128.84 | -6,317.51 |
| 11421:EURUSD | 91 | 4,162.83 | 3,605.91 | -556.92 | -568.19 | -1,408.39 |
| 11422:USDCAD | 195 | 18,310.48 | 15,074.15 | -3,236.33 | -1,291.94 | -3,713.89 |
| 11910:NZDUSD | 63 | 2,425.19 | 2,014.27 | -410.92 | -260.94 | -570.96 |
| 13054:XTIUSD | 82 | 4,831.28 | 4,250.82 | -580.46 | 0.00 | -581.38 |
| 1537:XAGUSD | 96 | 3,647.61 | -1,876.79 | -5,524.40 | -47.13 | -5,477.40 |
| 20048:XTIUSD | 60 | 1,164.28 | 1,277.85 | +113.57 | 0.00 | +113.15 |
| 21505:XAGUSD | 116 | 7,223.85 | 911.67 | -6,312.18 | -54.52 | -6,257.66 |

The two XAGUSD sleeves turn sharply worse before spread, making them the first specification and cost-reconciliation targets. The small XTIUSD improvement is swap-direction dependent and must not be interpreted as a full cost advantage.

## Verification

Focused checks validate the exact schema and pool membership, enforce commission/swap/contract/tick/margin units, reject non-finite numbers and duplicate JSON keys, prove flat commission is consumable, and reproduce every projection row from hash-bound Q08 streams.

## OWNER actions

1. Confirm triple-swap weekday and all six exact symbol specifications inside the FTMO client platform.
2. Export or screenshot those specifications as durable evidence.
3. Obtain matched-session FTMO-versus-Darwinex M1 spread calibration for these six symbols.
4. Refresh the official symbols API and rerun the projection immediately before any purchase authorization.

Until all four are complete, the decision remains `ABSTAIN`; purchases and live use remain false.
