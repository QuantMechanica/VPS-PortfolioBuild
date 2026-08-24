# QM5_41139 WTI Daily Pseudomedian Build — CPU Ceiling Handoff

Status: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## Candidate

- EA: `QM5_41139_wti-mdaily-hl-mom`
- Strategy: `MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01`
- Symbol/timeframe: `XTIUSD.DWX`, `D1`
- Magic: `411390000`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

The EA forms daily log returns from the immediately completed broker month, computes the exact median of every inclusive pairwise average `(r[i] + r[j]) / 2`, and follows that Hodges–Lehmann-style pseudomedian sign for one broker month. It is a direct WTI structural sleeve and does not duplicate the existing XAU/XAG two-leg reversion candidate or the existing raw-median WTI candidate. Portfolio correlation remains a downstream Q09 determination; no decorrelation claim is made here.

## Provenance and committed construction

- Source approval and pre-allocation dedup: `fd8b238d4`
- Reproducible source packet: `bb2a24a4c`
- EA ID reservation: `31e93f219`
- Approved G0 card: `c90bce304`
- Governed scaffold: `2ed1459e4`
- Magic allocation and exact card copy: `b4d81e496`
- Source implementation and fixed-risk setfile: `c9de910e4`
- MQ5 SHA-256: `0A7A6207C7B5D81B3162E89C797DEA1A4B4EECFC63FD4273BADBFBA8EC55E0C3`

Primary rationale is anchored in the peer-reviewed time-series-momentum evidence of Moskowitz, Ooi, and Pedersen (2012), which explicitly includes crude oil, and the peer-reviewed WTI daily-return treatment of Meek and Hoelscher (2023). The exact pseudomedian transformation is disclosed as an untested QM implementation choice rather than a sourced empirical claim.

## Deterministic source checks

- Card lint: PASS; zero missing sections and zero forbidden-ML hits.
- Independent reference vectors: 13 PASS, 0 FAIL, including a vector that distinguishes the pairwise-average pseudomedian from the ordinary raw-return median.
- SPEC validator: PASS (1/1).
- Build guardrails: PASS; zero findings.
- Symbol scope: `SINGLE_SYMBOL_OK`; zero violations.
- Approved card and EA documentation copy: byte-identical.
- No `.ex5` existed and no ad hoc compile was attempted.

## Binding CPU stop

At `2026-08-24T05:22:35.0975435Z`, the five-sample host CPU check returned `100.0, 100.0, 100.0, 99.9, 100.0` percent: average `99.98%`, maximum `100.0%`. This exceeds the `97.0%` claim ceiling and is also above the `90.0%` resume threshold.

Per the fleet pacing constraint, no governed compile item, Strategy Tester run, or Q02 item was enqueued. Q02 requires a strict compile PASS with a bound `.ex5`, so enqueueing it now would violate the build boundary.

## Safe continuation

After sustained host CPU falls below `90.0%`, enqueue exactly one source-fresh governed compile. Only a strict compile PASS with the bound `.ex5` may authorize exactly one Q02 work item. Do not touch T_Live, AutoTrading, the portfolio gate, or the T_Live manifest.
