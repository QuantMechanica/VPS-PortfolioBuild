# QM5_1226 XTI Q02 infrastructure recovery — 2026-07-11

## Outcome

`QM5_1226_psaradellis-oil-channel` is rebuilt for `XTIUSD.DWX` D1 and queued
for Q02 as work item `682a3aff-bf5c-4ed5-b32e-7570710e18ee`. This advances a
structural crude-oil sleeve outside the index/metal/XNG concentration of the
current survivor set.

The EA is based on Psaradellis, Laws, Pantelous, and Sermpinis, “Performance of
Technical Trading Rules: Evidence from the Crude Oil Market,” *European Journal
of Finance* (2019), SSRN 2832600. Its approved 55-day breakout, 20-day exit,
and 3×ATR(20) stop were not retuned.

## Coordination and selection

- An owned farm lease and `triage_failure` task were acquired before edits.
- At enqueue, an immediate DB transaction found no pending/active Q02 item and
  no competing active agent task for `QM5_1226`.
- All 12 prior Q02 items ended `INFRA_FAIL`; their terminal condition was
  `summary_missing_retries_exhausted` and none produced a usable report.
- The only higher-priority approved backlog cards required unavailable DWX
  inputs (lumber/rates) or duplicated the concentrated index/metal class.

## Repair

The stale build repeatedly performed raw series reads and recomputed bounded
channels during tick processing. The repair now consumes one framework D1
new-bar edge, caches the 55/20-bar state via `QM_ReadBar`, and evaluates both
closed-bar rules from that state. Tick-level risk management and closed-bar
exits run before entry-only news gates.

The Q01 spec now contains the required seven sections. A new canonical
`XTIUSD.DWX` D1 backtest setfile uses `RISK_FIXED=1000` and
`RISK_PERCENT=0`; the EX5 was rebuilt strictly. No strategy parameter changed.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Spec validator | PASS | required sections and EA identity present |
| Build guardrails | PASS | approved card, EA ID, magic row, setfile, and source constraints |
| Strict build check | PASS, 0 failures/warnings | `D:\QM\reports\framework\21\build_check_20260711_000113.json` |
| Strict compile | PASS, 0 errors/warnings | `D:\QM\reports\compile\20260711_000014\summary.csv` |
| Model-4 smoke, two runs | infrastructure PASS; deterministic valid reports | `D:\QM\reports\smoke\QM5_1226\20260711_000213\summary.json` |

The 2024 smoke had zero trades in both runs and therefore honestly records
`MIN_TRADES_NOT_MET`. It had no OnInit failure, missing report, history error,
or log bomb. Because this is a low-frequency D1 edge, there was no smoke retry
or parameter adjustment; the farm-standard 2017–2022 Q02 window is the economic
test.

## Enqueue path and scope

The `farmctl build-ea` wrapper stopped before mutation because this legacy
approved card predates the required
`expected_trades_per_year_per_symbol` frontmatter field. The approved card was
left immutable. Under the existing repair claim, the standard Q02 work-item
materializer selected only `XTIUSD.DWX`, the canonical setfile, and the
2017–2022 history window; the payload retains the farm's existing/default
20-trades/year diagnostic and is diversity-priority tracked.

No backtest CPU ceiling was reached. T_Live, AutoTrading, live setfiles, deploy
manifests, and the portfolio gate were not touched.

Machine-readable evidence is in
`artifacts/qm5_1226_q02_infra_recovery_20260711.json`.
