# QM5_41243 WTI EIA Lag-2 Fade Build And CPU-Ceiling Stop

Date: 2026-08-31  
Branch: `agents/board-advisor`  
Outcome: `SOURCE_BUILD_STATIC_PASS_COMPILE_PENDING_Q02_NOT_ENQUEUED_CPU_CEILING`

## Concrete edge

`QM5_41243_wti-eia-lag2-fade-m5` is a new weekly WTI event-reaction sleeve.
On a standard Wednesday it consumes one decision at 10:35 New York, trades
opposite the strict sign of the completed 10:30-10:35 `XTIUSD.DWX` M5 bar,
and flattens at 10:45. It uses one frozen `3.0 * ATR(20,M5)` hard stop, no
target, and the fixed-risk baseline `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`.

This is not a profitability, decorrelation, or portfolio-admission claim.
The ordinary-Wednesday price proxy intentionally does not infer holiday-shifted
EIA releases.

## Source and non-duplicate boundary

The governed source packet is based on Ye and Karali (2016), *Energy
Economics* 59, 349-364, DOI `10.1016/j.eneco.2016.08.011`, the complete
authors' AAEA/WAEA poster, and the official U.S. EIA WPSR schedule. The card
discloses that an unconditional completed-CFD-bar fade is a QM translation,
not a rule prescribed by the paper.

The pre-allocation dedup receipt
`artifacts/qm5_wti_eia_lag2_fade_m5_preallocation_dedup_20260831.json`,
SHA-256
`856BD94846ADB0A82E31D6FD899F69DE285AA410511E2AF006FB7C764278BF44`,
found no exact match across 4,742 registry rows, 1,380 cards, and 45 Strategy
Wiki nodes. The mechanic is distinct from the existing pre-release straddle,
final-session continuation, D1 WPSR fade, M30 deep-reclaim fade, and the
negative-only 10:31-10:35 M1 continuation.

## Governed identity and implementation

- Approved card:
  `strategy-seeds/cards/approved/QM5_41243_wti-eia-lag2-fade-m5_card.md`.
- EA ID: `41243`; exact active slot-0 magic: `412430000` for
  `XTIUSD.DWX`.
- Source SHA-256:
  `9aac2436f185b120fb261fa3a78fc779556f1dfac949cf531a916eca3c6730f1`.
- Backtest-set SHA-256:
  `1a202daf9bdb99ad7e35da832f295258c21a9ce784dc84c68b134180f6caccf9`.
- The implementation persists both the consumed New York date and the
  expected long/short direction. Restart repair closes duplicate, wrong-symbol,
  wrong-direction, stopless, date-stale, 10:45-or-later, or twenty-minute-stale
  owned exposure.

Relevant branch commits include:

- `0144b8fbba` — reputable-source approval;
- `64a677b5ed` — bounded source extraction;
- `7ae32bb485` — EA identity reservation;
- `f72d37c529` — G0-approved card;
- `faf6489a17` — governed magic row and resolver receipts;
- `387be328f8` — EA source, SPEC, and fixed-risk setfile;
- `78a68329b4` — reference tests and canonical SPEC correction;
- `da45480e18` — exact-item governed compile release receipts.

## Verification completed

- Approved-card schema lint: PASS.
- EA build prerequisite guard: PASS.
- `validate_spec_doc.py`: PASS, 1/1.
- Reference suite: PASS, 7/7.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations.
- `validate_build_guardrails.py --max-news-stale-hours 336`: PASS, zero
  findings.
- Magic resolver regeneration retained `412430000`; status-aware collision
  count was zero.

Direct strict compilation correctly stopped before MetaEditor with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal processes were alive.
No terminal process was started, stopped, retried, or interrupted. The
required governed alternative was enrolled as exact work item
`5fd6138a-3427-40db-9b4d-6310ba485a62`; its source-hash-bound dry run passed
and its activation hold was released for the normal terminal-worker lease
path. At 2026-08-31T07:50:56Z it remained `pending`, unclaimed, with no
verdict or evidence path. No `.ex5` exists, so Q01 PASS is not claimed.

## Mandatory CPU stop

A fresh five-sample whole-host check at the handoff boundary returned:

```text
samples_pct = 82.72, 75.08, 86.48, 95.48, 99.61
mean_pct    = 87.87
max_pct     = 99.61
ceiling_pct = 97.00
ceiling_hit = true
```

The OWNER mission says to stop on the backtest CPU ceiling. Therefore no Q02
work item was enqueued and no backtest, pipeline verdict, optimization, or
portfolio gate was run. The approved card truthfully remains `q01_status:
PENDING` and `q02_status: NOT_ENQUEUED`.

## Safe continuation

After host load clears, allow only the exact governed compile work item above
to finish. Require a source-fresh `COMPILE_OK`, strict build PASS, and committed
EX5 before changing Q01. Then re-check the 97% CPU ceiling and enqueue one Q02
baseline using the committed M5 fixed-risk setfile. Do not use a manual
terminal, touch AutoTrading or `T_Live`, edit a live/deploy manifest, change
the portfolio gate, or infer decorrelation before Q09 evidence.
