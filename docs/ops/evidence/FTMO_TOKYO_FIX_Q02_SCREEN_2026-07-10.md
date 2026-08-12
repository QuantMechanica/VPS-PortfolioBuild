# FTMO Tokyo-Fix Q02 screen - 2026-07-10

## Verdict

`QM5_13122_tokyo-fix-5m` is `Q02 FAIL` and retired from FTMO book research.
The exact 09:50/09:55/10:00 JST rule is not stable after executable spread and
FTMO's published USDJPY commission. No clock shift, day subset, stop search, or
regime filter is authorized to rescue it.

## Build and execution

- Strict compile: PASS, 0 errors, 0 warnings.
- Model: MT5 model 4, native USDJPY.DWX M1 real ticks.
- Risk: `RISK_FIXED=1000` on a USD 100,000 test account.
- Cost basis: observed approximately USD 5 per lot round-trip in every
  decision-grade report, matching the current FTMO USDJPY symbol table.
- Repeated reports were deterministic.

The initial 2024 diagnostic passed `-CommissionPerLot 5` to `run_smoke.ps1`.
That parameter is additive to the canonical symbol commission and produced an
observed USD 15 per lot round-trip. Its native PF 0.70 is therefore stress
evidence, not the Q02 baseline. The clean source-fidelity rerun used the
canonical USD 5 round-trip schedule and news OFF.

## Valid results

| Year | Trades | PF | Net USD | Equity DD | DD % |
|---:|---:|---:|---:|---:|---:|
| 2019 | 469 | 0.88 | -2,972.38 | 4,261.61 | 4.24 |
| 2020 | 449 | 0.78 | -6,397.77 | 9,461.98 | 9.20 |
| 2021 | 446 | 0.85 | -3,116.81 | 5,264.83 | 5.26 |
| 2024 | 428 | 1.11 | +4,690.17 | 4,348.34 | 4.14 |
| **Pooled** | **1,792** | **0.927** | **-7,796.79** | n/a | n/a |

The operative runner threshold is PF >= 1.20. Three of four valid years lose
money, and even the best valid year remains below the gate.

## Excluded runs

- 2022/T4: `BARS_ZERO`, `INCOMPLETE_RUNS`.
- 2023/T5: `REPORT_MISSING`, `ACCOUNT_NOT_SPECIFIED`, `INCOMPLETE_RUNS`,
  `MODEL4_MARKER_REQUIRED`.

These are infrastructure failures and are not counted as strategy losses. A
retry cannot change the decision because the valid sample already fails the
PF gate by a wide margin.

Machine-readable evidence:
`artifacts/ftmo_tokyo_fix_q02_screen_2026-07-10.json`.

Official cost reference:
`https://ftmo.com/en/symbols/` (USDJPY commission: USD 5/lot).
