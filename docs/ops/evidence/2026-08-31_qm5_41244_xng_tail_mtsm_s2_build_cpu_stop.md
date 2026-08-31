# QM5_41244 XNG Tail-MTSM S2 Source Build And CPU-Ceiling Stop

Date: 2026-08-31  
Branch: `agents/board-advisor`  
Outcome: `SOURCE_CARD_BUILD_STATIC_PASS_COMPILE_PENDING_Q02_NOT_ENQUEUED_CPU_CEILING`

## Concrete edge

`QM5_41244_xng-tail-mtsm-s2` is a new structural, low-frequency natural-gas
sleeve. On each exact `XNGUSD.DWX` D1 label it sums 30 completed simple
returns, calculates five-return upper and lower partial moments, compares them
with separate no-lookahead nearest-rank 80th percentiles from 252 older
observations, and applies the exact MTSM-S2 map:

- both tails: flat;
- lower-tail only: long;
- upper-tail only: short;
- neither tail: follow the 30-return sign, with zero mapped short.

The single authorized preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` hard stop, an eight-day
survivor repair, a 1,500-point spread ceiling, current news
`PRE30_POST30/DXZ`, and Friday close at broker hour 21.

This is not a profitability, decorrelation, or portfolio-admission claim.

## Source and non-duplicate boundary

The governed complete-read packet
`strategy-seeds/sources/LIU-MTSM-2021/source.md` traces to Liu, Lu, and Wang
(2021), “Asymmetry, tail risk and time series momentum,” *International Review
of Financial Analysis* 78, 101938, DOI
`10.1016/j.irfa.2021.101938`. The packet supports the 30/5/80 partial-moment
state machine. XNG, the single Darwinex CFD carrier, the bounded 252-sample
reference, fixed-dollar risk, ATR stop, spread cap, and Friday packaging are
explicit QM translations.

The pre-allocation receipt
`artifacts/qm5_xng_tail_mtsm_s2_preallocation_dedup_20260831.json` found no
exact identity across 4,743 registry rows, 1,381 cards, and 45 Strategy Wiki
nodes. Its only fuzzy matches were the approved and flat copies of the
intended `QM5_13108` WTI parent. This locked XNG carrier port is mechanically
distinct from certified `QM5_12567`, which is long-only cumulative-RSI2
pullback logic under a 200-D1 trend state and has no asymmetric partial-moment
target map.

## Governed identity and implementation

- Approved card:
  `strategy-seeds/cards/approved/QM5_41244_xng-tail-mtsm-s2_card.md`.
- Active registry route: `XNGUSD.DWX`, slot 0, magic `412440000`.
- MQ5 SHA-256:
  `f1e3a407c0a42f94cfaa75788edc2e223787173590defee40dd20fbd41a76398`.
- Backtest setfile SHA-256:
  `8d7ef7bec335cf97161a5f859b28e1d91d76603e0eee976c445bb3cf43ae0e57`.
- The source persists each eligible D1 attempt before quote, spread, ATR,
  news, sizing, or submission. A nonzero label encountered with owned
  exposure is also consumed, making same-side retention, repairs, and the
  no-same-label-reversal boundary restart-safe.
- Malformed, duplicate-magic, wrong-symbol, invalid-side, invalid-volume,
  invalid-open-price, stopless, and stale owned exposure is closed through the
  framework transaction manager. Unrelated magic numbers are untouched.

Relevant branch commits:

- `baf544d81b` — reputable-source approval and dedup receipt;
- `ec2f685116` — EA identity reservation;
- `df21850371` — G0-approved Strategy Card;
- `643288defb` — governed magic allocation and resolver regeneration;
- `15dcf34e67` — EA source, SPEC, fixed-risk setfile, and reference tests;
- `94be2c0c78` — exact source-hash-bound compile release receipts;
- `8c95a219e0` — canonical SPEC section alignment.

## Verification completed

- Approved-card schema lint: PASS.
- EA build prerequisite guard: PASS.
- `validate_spec_doc.py`: PASS, 1/1.
- Independent reference suite: PASS, 6/6.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations.
- `validate_build_guardrails.py --max-news-stale-hours 336`: PASS, zero
  findings for source and setfile.
- Governed allocator: one active `412440000` row, resolver retained the row,
  and status-aware magic collisions remained zero.

The repository-wide legacy registry validator remains baseline-failing on
unrelated malformed historical rows; it emitted no 41244-specific finding.

## Compile handoff

Direct strict compilation stopped before MetaEditor with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal processes were alive.
No retry or process mutation occurred. The prescribed governed alternative is
work item `c1cf84b8-49a0-4517-9386-504bd20419bf`; its source-hash dry run
matched, its activation hold was released, and at the stop boundary it was
still pending with attempt count zero, no claimant, no verdict, and no
evidence path. No `.ex5` exists, so Q01 PASS is not claimed and the setfile's
build hash remains pending.

## Mandatory CPU stop

A fresh five-sample whole-host check returned:

```text
samples_pct = 98.34, 99.90, 96.88, 94.43, 89.95
mean_pct    = 95.90
max_pct     = 99.90
ceiling_pct = 97.00
ceiling_hit = true
```

The OWNER mission requires stopping at the backtest CPU ceiling. Therefore no
Q02 row was inserted and no tester, dispatcher, pump, pipeline verdict,
optimization, or portfolio gate was run. The approved card remains truthful:
`q01_status: PENDING`, `q02_status: NOT_ENQUEUED`.

## Safe continuation

Allow only the exact governed compile work item above to finish. Require a
source-fresh `COMPILE_OK`, strict build PASS, and committed EX5 before changing
Q01. After host load clears, repeat the 97% CPU admission check and enqueue
exactly one Q02 baseline from the committed D1 fixed-risk setfile. Do not use a
manual terminal, toggle AutoTrading, touch `T_Live`, create a live preset,
change a deploy/live manifest or portfolio gate, or infer decorrelation before
Q09 evidence.
