# Pre-FOMC Event-Flat — `.DWX` Research Receipt

Date: 2026-07-10  
Status: promising exploratory survivor; DRAFT `_v2` amendment; not pipeline or live evidence

## Outcome

The secret-mission strategy is not a new strategy lineage. Deduplication found the existing
registered and G0-approved `QM5_12971_spx-pre-fomc-drift`. The exact event-flat realization is
therefore documented as a DRAFT `_v2` amendment in
`strategy-seeds/cards/QM5_12971_spx-pre-fomc-drift.md`; no EA ID was allocated and no registry
row was added.

## Frozen Mechanic

1. Use `SP500.DWX` H1 and official regular FOMC decision dates only.
2. Buy at broker 21:00 on calendar day D-1.
3. Close at broker 20:00 on decision date D, about one hour before the statement.
4. Emergency stop: entry minus 2.0 times prior completed D1 ATR(14).
5. One long position, no TP, trailing, scale, averaging, grid, martingale, or event-direction bet.
6. If the exact entry opportunity is missing, skip; never make up or select dates by P&L.

## Source Reconciliation

Lucca and Moench define a long-only S&P 500 holding window ending before scheduled FOMC
announcements and report a strong 1994-2011 effect. Kurov, Wolfe, and Gilbert extend the sample
through 2019 and find that the drift weakened materially after 2015, including meetings with
press conferences. The local 2018-2025 result is therefore a small-sample contradiction worth
reviewing, not a reason to omit the published decay evidence.

Primary references:

- David O. Lucca and Emanuel Moench, *The Pre-FOMC Announcement Drift*, Journal of Finance
  70(1), 329-371, DOI `10.1111/jofi.12196`; New York Fed Staff Report 512.
- Alexander Kurov, Marketa Halova Wolfe, and Thomas Gilbert, *The Disappearing Pre-FOMC
  Announcement Drift*, Finance Research Letters 40, 101781, DOI
  `10.1016/j.frl.2020.101781`.
- Board of Governors of the Federal Reserve System, official FOMC meeting calendars and
  historical materials.

## Valid Test Boundary

- Terminal: `D:\QM\mt5\T_Export` only.
- Symbol: `SP500.DWX` only.
- Timeframe: H1.
- Model: HCC/Model 1; T_Export has no custom real-tick database.
- Risk: fixed USD 250 in the exploratory prototype.
- Binary: identical across DEV, validation, untouched OOS, and descriptive full run.
- T1-T10 and T_Live: not used for valid evidence.
- Tester-only guard: initialization fails outside `MQL_TESTER`.

## Chronological Results

| Window | Trades | Net USD | PF | Win rate | Equity DD | Verdict |
|---|---:|---:|---:|---:|---:|---|
| DEV 2018-07 to 2021 | 25 | +53.10 | 1.1048 | 56.00% | 0.29% | pass, marginal |
| Validation 2022-2023 | 15 | +442.40 | 5.64 | 80.00% | 0.14% | pass |
| Untouched OOS 2024-2025 | 16 | +292.94 | 2.03 | 68.75% | 0.22% | pass |
| Descriptive full 2018-2025 | 56 | +788.44 | 1.89 | 66.07% | 0.29% | promising only |

Full-run cost columns: commission `-7.60` USD; swap `-151.21` USD; price P&L before those
columns `+947.25` USD. Net by year: 2018 `+72.68`; 2019 `-122.40`; 2020 `+171.90`; 2021
`-69.08`; 2022 `+333.21`; 2023 `+109.19`; 2024 `+271.41`; 2025 `+21.53`.

## Calendar Integrity Finding

The frozen array contains 57 eligible dates, while the full test recorded 56 entry opportunities
and 56 trades. The missing exact-clock opportunity is the 2023-12-13 decision. The current
fail-closed rule skips it. Before any formal run, the reason must be classified as session history,
bar availability, or implementation behavior; no synthetic trade may be inserted.

## Frozen Evidence

| Artifact | SHA256 |
|---|---|
| `PRE_FOMC_FLAT.mq5` | `DB8ACA87DF6A5569AC22CE6338CA98EF97F15DF89A94B137CA4F69E82DCA6166` |
| T_Export `PRE_FOMC_FLAT.ex5` | `189ECBBC3D19BDEFFA55F57706D9B35B5CCFBC37786357218B6DB6BA48E6DEA7` |
| full report | `129CA1A00F6CAA70DAFFB42CF737C9A467B61FEE3CFAD61698B855A73A897035` |

Compile result: T_Export MetaEditor build 5833, 0 errors, 0 warnings.

Evidence paths:

- `.private/secret_strategy_lab/MISSION_REPORT_2026-07-10.md`
- `.private/secret_strategy_lab/pre_fomc_flat/RESEARCH_SPEC.md`
- `.private/secret_strategy_lab/pre_fomc_flat/runs/dev2018_2021/report.htm`
- `.private/secret_strategy_lab/pre_fomc_flat/runs/validation2022_2023/report.htm`
- `.private/secret_strategy_lab/pre_fomc_flat/runs/oos2024_2025/report.htm`
- `.private/secret_strategy_lab/pre_fomc_flat/runs/full2018_2025/report.htm`
- `.private/secret_strategy_lab/pre_fomc_flat/SHA256SUMS.txt`

## What This Does Not Prove

- Fifty-six trades do not establish a stable modern anomaly.
- The large validation PF is driven by only 15 trades.
- Two calendar years lost money and 2025 was only marginally positive.
- Model 1 cannot satisfy V5's Model 4 requirement.
- The USD 250 research risk setting is not the V5 USD 1,000 baseline.
- The official calendar currently ends in 2025 in the frozen prototype.
- The result conflicts with published post-2015 decay evidence and is exposed to false-positive,
  timing, session, and financing-cost risk.

## Required Next Gate

1. OWNER + Quality-Business review the DRAFT `_v2` amendment.
2. Independently audit all official dates, exclusions, decision times, broker DST, and the missing
   2023-12-13 opportunity.
3. Rebuild only after explicit amendment approval; preserve the existing `QM5_12971` EA ID.
4. Run the V5 fixed USD 1,000 baseline and Model 4 where valid `.DWX` real ticks exist.
5. Pre-register timing/ATR neighborhoods and evaluate plateau behavior without choosing dates.
6. Run cost, news-mode, and full pipeline gates before any portfolio consideration.
