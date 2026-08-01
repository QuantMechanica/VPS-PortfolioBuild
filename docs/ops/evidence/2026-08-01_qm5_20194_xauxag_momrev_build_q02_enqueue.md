# QM5_20194 XAU/XAG momentum-reversal build and Q02 enqueue

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20194_xauxag-momrev`

Strategy ID: `BIANCHI-MOMREV-2015_XAU_XAG_S02`

## Outcome

One new low-frequency structural commodity candidate was researched, carded,
allocated, built, strictly compiled, and handed to the paced Q02 fleet. At a
genuine broker-month transition it ranks synchronized XAU and XAG completed
12-month and 18-month log returns. It opens an opposite-leg package only when
the two horizon ranks disagree: follow the 12-month winner and fade the
18-month winner. Same-rank and tied states remain flat.

This is a relative-value construction, not evidence of dollar, beta, factor,
market, or portfolio neutrality. No profitability, decorrelation, or
certification result is claimed. Q01 is `PASS`; Q02 was enqueued exactly once.

## Source and approval boundary

The governed packet is
`strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`. Its primary source is
Bianchi, Drew, and Fan (2015), "Combining Momentum with Reversal in Commodity
Futures," *Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`.

The packet records a complete accepted-manuscript review, explicit gold and
silver membership in the source universe, and the bounded 2026-08-01 S02
extraction. The source supports the 12-month momentum / 18-month reversal
double-sort method. It does not test this two-CFD XAU/XAG carrier, QM hard
stops, fixed cash risk, Darwinex costs, package neutrality, or portfolio
correlation. A public-source refresh attempted through the deterministic
reader was deferred by source policy and was not used as substitute evidence.

Durable G0 approval is
`decisions/2026-08-01_qm5_20194_xauxag_momrev_g0.md`. Card-schema and G0 lints
both pass with no missing section or ML hit.

## Frozen mechanic

- Logical basket: `QM5_20194_XAU_XAG_MOMREV_D1`; tester host:
  `XAUUSD.DWX` D1.
- Traded slot 0: `XAUUSD.DWX`, magic `201940000`; traded slot 1:
  `XAGUSD.DWX`, magic `201940001`.
- Decision: first tradable host D1 bar after an actual broker-month change.
- State: synchronized completed month-end closes at 0, 12, and 18 months;
  endpoints more than 10 calendar days from their boundary fail closed.
- Entry: long XAU/short XAG when XAU wins at 12 months and loses at 18;
  reverse when XAG does. Ties and rank agreement remain flat.
- Attempt state: consume and persist the period before history, signal, news,
  spread, sizing, or order gates; no same-month retry.
- Risk: one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally by risk across independent
  `3.5 * ATR(20,D1)` hard stops.
- Exit: next broker-month transition or 35-calendar-day stale guard, plus hard
  stops and immediate partial/orphan-package repair.
- Both news axes, legacy news mode, Friday close, and stress rejection are OFF.
- Density prior: approximately 5-9 packages/year after warm-up; Q02 retires
  below five completed packages/year.

All strategy and framework inputs used by the Q02 setfile are runtime-locked.
No parameter sweep or standalone-leg test is authorized.

## Non-duplicate boundary

Before card allocation, `research_dedup_check.py check` returned no exact slug
or strategy-ID duplicate. Its expected fuzzy sibling was
`QM5_13120_energy-momrev`, which applies the same source method to XTI/XNG.
Manual review resolved that sibling by carrier: S02 is a new XAU/XAG
relative-rank state.

Closer XAU/XAG systems use a different state variable: gold/silver ratio
reversion, OLS/quantile convergence, same-calendar ranks, pure 1/3/12-month
momentum, or factor-residual idiosyncratic volatility. This build retains the
otherwise absent strict 12/18 opposite-rank interaction. Changing either
horizon, carrier, cadence, direction, or package construction requires a new
card. Realized book correlation remains a downstream portfolio-gate question.

## Allocation and build commits

- G0/source/card commit: `4c649196f`.
- Active EA/magic rows and deterministic resolver update: `7aa109fe4`.
- EA/SPEC/manifest/EX5/fixed-risk setfile build commit: `212f9db97`.

The candidate build guard passed for approved G0 status, EA directory, EA ID,
slug, and registry rows. Resolver lookup contains the two unique active magic
routes above.

## Q01 evidence

- Strategy-card schema lint: PASS; no missing sections or ML hits.
- G0 card lint: PASS.
- Candidate build guard: PASS.
- Basket symbol-scope validation: `BASKET_OK`, zero violations.
- Basket work-item routing tests: 15 passed.
- Magic-resolver strict/default and newline tests: 4 passed.
- Strict MetaEditor compile:
  `D:/QM/reports/compile/20260801_102443/summary.csv` -- PASS, zero errors,
  zero warnings.
- Strict compile log:
  `framework/build/compile/20260801_102443/QM5_20194_xauxag-momrev.compile.log`.
- Full strict V5 build check:
  `D:/QM/reports/framework/21/build_check_20260801_102502.json` -- PASS, zero
  failures, zero warnings.
- Setfile build hash:
  `ad9aeafa0172ad93571fc64ea37270253cb30e31c551294b895f10b6b67ca7a6`.

No manual smoke, tester, or backtest was launched.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `E68628EE817FEE2D82146D595FE4E5A13A2E2C2F69DE5B13EAF75E15AA4EF19E` |
| EX5 | `00B1CAF9B12AF6151BAE0B7934738A8C7A6E2FF4E5CF6189EB216136C4BCC809` |
| SPEC | `F88FAF6666D812C3FAEC4870C074AB1052FFE30BDEFC2F0F6D97B49651DAA8A1` |
| basket manifest | `C33C1B1A8511CBDE9ED9C8F151CBB730991417FFD81278AB9E0FE5914B19C632` |
| build-time card | `527EB7B2723C7409A97575D6736678FB0E424699362A1F95E3A8E2C5ED15ECA1` |
| backtest setfile | `415D87A66525E922CFACBEB1F39AECC78307A994F8AE5786C2D6F44071D43F62` |
| raw and approved cards after handoff | `8A9DC8605B2B13EEBDB0847EE8EE7D0BF129E11BD69C1EBCF124D7D8D02A9F2E` |
| source packet | `89DEFDC48F987E031830C95B976C236D569057DEEABE09A58D96C3A2687604C6` |

The raw and approved card copies were byte-identical at handoff confirmation.

## Paced Q02 handoff

The EA-and-symbol-scoped dry run selected exactly one never-tested logical
basket, zero stranded retries, and zero deferred promotions. Its queue snapshot
was 2,002 pending rows against the 7,000-row ceiling.

Initial apply attempts lost the healthy live factory mutation lock and made no
mutation. Ten terminal workers poll the same non-reentrant lock every 10 ms.
The final apply therefore waited for and held the real global mutation lock,
rechecked Factory OFF and the CPU ceiling under that lock, and ran the unchanged
canonical `sweep_enqueue_built_eas.py` body through a scoped reentrant adapter.
The adapter performed no direct SQL insertion and did not delete, replace, or
reap the lock; the canonical sweep retained its final Factory OFF check and
transactional insert.

The apply inserted exactly one row:

- work item: `b8ce6d6b-6b21-43ca-95f3-9f6baa46ed7e`;
- phase/kind: `Q02` / `backtest`;
- logical symbol/timeframe: `QM5_20194_XAU_XAG_MOMREV_D1` / D1;
- host: `XAUUSD.DWX`;
- basket symbols: `XAUUSD.DWX`, `XAGUSD.DWX`;
- setfile:
  `QM5_20194_xauxag-momrev_QM5_20194_XAU_XAG_MOMREV_D1_D1_backtest.set`;
- created: `2026-08-01T10:35:39+00:00`;
- status at confirmation: `pending`, attempt 0, unclaimed, no verdict;
- timeout: 450 minutes; and
- priority track: true.

The locked pre-insert capacity check found one non-live factory terminal,
below the seven-process CPU ceiling. One separate `T_Live` terminal was
observed and excluded by path. This work did not dispatch, reserve, start,
stop, or otherwise control a terminal.

## Safety and next gate

No live setfile, AutoTrading toggle, `T_Live` mutation, deploy manifest,
T_Live manifest, portfolio-gate change, portfolio admission, KPI claim,
correlation waiver, or certification record was created. The paced fleet owns
Q02. A Q02 pass would still not prove neutrality or book orthogonality; all
remaining gates, including portfolio correlation, remain unchanged.
