# FTMO readiness pack 1 — read-only validation

**Task:** `b5a4e196-4670-44b3-af12-1152b40824ed`  
**Verdict:** `PASS_WITH_RECONCILIATION_AND_OWNER_INPUTS_OPEN`  
**Machine-readable evidence:** `docs/ops/evidence/2026-09-05_ftmo_readiness_part1_validation.json`  
**Run output:** `D:/QM/reports/portfolio/live_attribution_20260905_054540/`

This run performed no write, start, stop, or configuration action against T_Live. It copied the already-produced AccountMonitor deal export and the read-only inventory result into the run directory, then analyzed those snapshots. It did not toggle AutoTrading and creates no purchase, deployment, or live-use authority.

## Result

The fresh AccountMonitor export is usable: 225 rows, last deal `2026-09-04T18:00:00Z`, SHA-256 `9a4cc7ba454767e36714d61dc9cd93e1ef6059ec9afaa3e1377091c6892966c7`. Grouping every deal by `position_id`, summing `profit + swap + commission + fee` through the exported `net_actual`, and taking ownership only from the unsigned pointer's 24 exact magics gives:

- `2026-08-01` through `2026-09-04`: 65 closed positions on 24 active close-days, **-$472.96**. This is **-$3.96** from the CEO audit's maintained **-$469** figure and is a practical reconciliation, with three additional post-audit dates and normal source-timing/rounding caveats.
- Annualized calendar-daily Sharpe over the same 35 calendar-day grid (zero days retained) is **-1.325**, iid day-bootstrap 95% CI **[-7.005, +3.825]** (`B=10,000`, seed `20260905`). This independently preserves the CEO audit's conclusion: the interval is too wide to establish or reject edge.
- The phrase “30 active days” is not a sufficiently exact window contract. Taking it literally as the latest 30 distinct governed close dates yields `2026-07-24` through `2026-09-04`, 85 positions and **-$1,436.59**, not -$469. Future maintained figures need an explicit start/end and zero-day policy.
- Exclusions are mechanical: one all-zero-magic closed position is excluded (**-$1,539.50**); the four named drift magics are excluded (**-$134.65** across three old closed positions). Drift last closes remain `106920005=2026-07-10`, `109400003=2026-06-30`; `104760004` and `107150004` still have no closed trade. None contaminated the August reconciliation window.
- The refreshed inventory remains `DRIFT`: 19 of 26 per-EA logs emitted within 36 hours; the deployment pointer is unsigned. This is a governance state, not permission to mutate T_Live.

## Governed attribution

The window is `2026-08-01..2026-09-04`. Sharpe uses one observation per calendar day, including zeros; the CI is a fixed-seed iid day bootstrap. A sleeve with no returns has no estimate. Very sparse sleeves can show one-sided or lattice-like intervals; those are arithmetic consequences of one or two active days and are not evidence of significance.

| EA | magic | symbol | closes | active days | net USD | swap USD | Sharpe | 95% CI |
|---:|---:|---|---:|---:|---:|---:|---:|---:|
| 1556 | 15560004 | XAUUSD | 2 | 2 | 126.42 | -2.47 | 1.95 | [-4.79, 4.79] |
| 1567 | 15670007 | EURUSD | 1 | 1 | -195.56 | 0.00 | -2.68 | [-5.62, -2.68] |
| 10403 | 104030002 | XAUUSD | 4 | 4 | 163.42 | -13.27 | 1.51 | [-3.83, 5.66] |
| 10440 | 104400003 | NDX | 5 | 5 | 193.83 | -2.39 | 2.38 | [-4.30, 5.78] |
| 10513 | 105130003 | XAUUSD | 1 | 1 | -230.84 | 1.65 | -2.68 | [-5.62, -2.68] |
| 10706 | 107060001 | GBPUSD | 5 | 5 | 226.95 | -8.95 | 2.43 | [-4.79, 5.84] |
| 10911 | 109110003 | GDAXI | 10 | 9 | 255.56 | 1.80 | 1.56 | [-6.05, 5.13] |
| 10919 | 109190001 | XTIUSD | 0 | 0 | 0.00 | 0.00 | — | — |
| 10939 | 109390001 | GBPUSD | 2 | 2 | -264.70 | -2.60 | -3.39 | [-5.70, -2.68] |
| 11132 | 111320000 | SP500 | 1 | 1 | -87.21 | -7.03 | -2.68 | [-5.62, -2.68] |
| 11165 | 111650000 | EURUSD | 2 | 2 | -29.23 | -3.12 | -1.38 | [-4.79, 4.79] |
| 11165 | 111650002 | AUDCAD | 3 | 2 | 96.85 | 8.00 | 1.09 | [-4.79, 4.79] |
| 11421 | 114210000 | EURUSD | 2 | 2 | -250.50 | 0.66 | -3.62 | [-6.19, -2.68] |
| 11421 | 114210003 | AUDUSD | 1 | 1 | 13.38 | 0.00 | 2.68 | [2.68, 5.62] |
| 11708 | 117080000 | EURUSD | 2 | 2 | -530.67 | 0.91 | -2.79 | [-5.62, -2.68] |
| 12567 | 125670002 | XNGUSD | 0 | 0 | 0.00 | 0.00 | — | — |
| 12567 | 125670003 | XAUUSD | 0 | 0 | 0.00 | 0.00 | — | — |
| 12778 | 127780000 | AUDUSD | 0 | 0 | 0.00 | 0.00 | — | — |
| 12969 | 129690000 | USDJPY | 0 | 0 | 0.00 | 0.00 | — | — |
| 12989 | 129890003 | XAUUSD | 0 | 0 | 0.00 | 0.00 | — | — |
| 13117 | 131170000 | EURGBP | 0 | 0 | 0.00 | 0.00 | — | — |
| 13128 | 131280000 | NDX | 0 | 0 | 0.00 | 0.00 | — | — |
| 13213 | 132130000 | USDJPY | 17 | 17 | 146.00 | 0.00 | 3.32 | [-1.98, 9.12] |
| 13301 | 133010010 | GDAXI | 7 | 7 | -106.66 | 0.00 | -2.70 | [-6.53, 3.36] |

## Exact holding-period and swap-exposure measurement

All eight selected native reports contain strict alternating `IN,OUT` deal lifecycles, with equal entry/exit counts and no overlap. Native MT5 `report.htm` does **not** expose `DEAL_POSITION_ID`; consequently, claiming a native position ID would be false. The validation derives a unique lifecycle key from the opening order, checks uniqueness, and pairs the immediately following `OUT`. This is exact for these eight observed sequences and is recorded as `derived_position_key`, not native provenance.

“Exposure days” below means broker-report calendar midnights crossed, a transparent rollover-risk proxy. “Swap trades” and “reported swap” are the actual native report fields. A zero reported swap on a multi-day custom-symbol backtest does not prove FTMO swap is zero.

| sleeve | trades | median hours | median days | mean midnights/trade | trades ≥1 midnight | swap trades | reported swap |
|---|---:|---:|---:|---:|---:|---:|---:|
| 10706:GBPUSD | 360 | 7.43 | 0.31 | 0.56 | 165 | 0 | 0.00 |
| 11421:EURUSD | 91 | 24.85 | 1.04 | 1.30 | 67 | 67 | -785.01 |
| 11422:USDCAD | 195 | 40.98 | 1.71 | 1.78 | 154 | 0 | 0.00 |
| 11910:NZDUSD | 63 | 116.92 | 4.87 | 2.76 | 53 | 53 | -252.27 |
| 13054:XTIUSD | 82 | 70.00 | 2.92 | 2.33 | 71 | 0 | 0.00 |
| 1537:XAGUSD | 96 | 48.00 | 2.00 | 1.88 | 80 | 0 | 0.00 |
| 20048:XTIUSD | 60 | 72.00 | 3.00 | 2.65 | 60 | 0 | 0.00 |
| 21505:XAGUSD | 116 | 116.00 | 4.83 | 4.09 | 116 | 0 | 0.00 |

Seven sleeves have a median above one day; even H1 sleeve 10706 crosses at least one calendar midnight in 165/360 trades. Swap is therefore material, especially for 11910 and 21505.

## Cost-source matrix and OWNER lookups

| source | hash | usable scope | limitation |
|---|---|---|---|
| `framework/registry/venue_cost_model.json` | `7dfafe53749e5c45be0cb37568b6e3491c109f546fafaf799f6ea82efdb688d7` | governed contract/commission context | every `swap_note` is null; not a swap source |
| `framework/registry/live_commission.json` | `119f795cefce2f819f0c7aae3bddb87affbffa771f596df48d182cf89989e197` | governed worst-case commission context | not FTMO per-symbol swap/margin evidence |
| `2026-07-30_ftmo_book3_symbol_cost_snapshot.json` | `7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280` | dated XTIUSD/XAUUSD/USDJPY snapshot | only XTIUSD belongs to the current eight; stale values |
| `2026-09-05_ftmo_current_pool_cost_snapshot.json` | `90421c5a3764b7f5ba6fb281a71bd27a54910c568341443f2b5389251bb8d99e` | all six instruments/eight sleeves; commission, swap, contract, tick, Swing margin | public API omits authoritative triple-swap weekday; spread comparison remains absent |

The September snapshot supersedes the readiness draft's “missing six swaps” statement for provisional analysis. Current public-API figures cover GBPUSD, EURUSD, USDCAD, NZDUSD, XAGUSD and USOIL.cash, but they do not close the client-platform or matched-spread evidence gaps.

Exact OWNER/client-platform lookup list before any purchase decision:

1. Confirm the triple-swap weekday and current specification for all six symbols in the FTMO client platform.
2. Export or screenshot those exact per-symbol client specifications.
3. Obtain matched-session FTMO-versus-Darwinex M1 spread calibration for all six symbols.
4. Refresh and hash-bind the official FTMO symbols API immediately before any OWNER-authorized purchase.

No value was invented for these open cells. The result remains analysis-only and does not authorize an FTMO purchase or live deployment.

## Reproduction and verification

```powershell
python tools/strategy_farm/portfolio/validate_ftmo_readiness_part1.py `
  --output-dir D:/QM/reports/portfolio/live_attribution_<timestamp> `
  --evidence-json docs/ops/evidence/2026-09-05_ftmo_readiness_part1_validation.json
```

The machine-readable artifact records SHA-256, size, and mtime for all 15 inputs, including each native report. Focused verification must check JSON schema/loadability, 24-roster completeness, attribution sum, exclusions, eight unique lifecycle sets, and byte identity of the D-drive snapshot.
