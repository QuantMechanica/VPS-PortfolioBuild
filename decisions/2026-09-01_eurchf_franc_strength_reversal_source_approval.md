# EURCHF Franc-Strength Reversal - Source Approval

Date: 2026-09-01

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize a manual tester run or work
above the active whole-host CPU ceiling.

Authority: the current explicit OWNER diversity and funnel-throughput mission
on branch `agents/board-advisor`. After proving that no clean priority-1
diverse build card and no genuine low-frequency priority-2 infrastructure
block remains, the mission authorizes one new structural, low-frequency edge
on an instrument absent from the certified book. It requires reputable-source
criteria and `RISK_FIXED` backtests and excludes portfolio-gate changes, live
manifests, `T_Live`, and AutoTrading.

## Candidate Identity

- proposed slug: `eurchf-franc-rev`
- proposed strategy ID: `AI-CODEX-EURCHF-FRANC-REVERSAL-20260901_S01`
- proposed source ID: `AI-CODEX-EURCHF-FRANC-REVERSAL-20260901`
- proposed symbol / host: exact `EURCHF.DWX`, H4, slot 0
- signal: long-only extreme EURCHF weakness measured against the prior forty
  H4 closes, admitted only in the lower decile of the prior 250-close range
  after a bullish closed-bar reversal

The deterministic registry owns the EA ID. This source decision neither
predicts nor reserves an identity.

## Approved Source Basis

Three bounded local records were read completely before this decision.

1. `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md`, SHA-256
   `5032C7492C5A57A71D46C4176E6D6E48A1312C566BFD28CB955B104D40E061BD`,
   is the durable OWNER-directed orthogonal-return program. Candidate 7 names
   the EURCHF H4 40-bar z-score, lower-250-bar-decile, bullish-reversal,
   long-only construction; its 2015 gap warning and post-floor regime concern
   are preserved rather than waved away.
2. `strategy-seeds/sources/EIA-SNB-XTI-USDCHF-RSPREAD-2026/source.md`, SHA-256
   `13974A44F4A509F63BF5F408FB2C89CC6F7F35A96EDAF0339B0358A260679BC8`,
   records official EIA/SNB lineage and the bounded finding that CHF safe-haven
   response varies by counter-currency and strengthens during stress. It does
   not claim this EURCHF reversal rule.
3. `strategy-seeds/sources/EIA-SNB-WTI-CHF-2026/source.md`, SHA-256
   `F2337C442501B941D0FB6BE72DB3A1F14657999AAD4AF642B085B5988D39B707`,
   independently preserves the official SNB safe-haven citation and the rule
   that no external SNB or macro feed enters an EA at runtime.

The public-source router was run against the official SNB safe-haven and
target-zone pages. Both returned `PERMISSION_REQUIRED` with
`lead_status=DEFERRED:SOURCE_POLICY`; the exact receipts are stored beside the
source packet. No proxy, scraper, cached mirror, or alternate downloader was
used. Consequently, this decision imports no unreviewed full-paper claim,
coefficient, intervention effect, profitability result, or post-2015 edge.

The price rule is transparent pre-result QuantMechanica synthesis. The source
lineage supports only the CHF stress carrier and why one-sided EURCHF tail
behavior is economically interesting. Q02 must establish activity and
economics; Q04 must establish temporal robustness; Q05-Q07 must expose the gap
tail; and Q09 alone may establish portfolio complementarity.

## Locked Mechanic

On each new exact `EURCHF.DWX` H4 bar, use only completed H4 bars:

1. Let `C0` be the just-completed close. Compute the mean and population
   standard deviation of the forty closes immediately before it,
   `C1..C40`. Require positive finite prices and positive finite deviation.
2. Set `z=(C0-mean(C1..C40))/stdev_pop(C1..C40)`.
3. Compute `lo=min(C1..C250)` and `hi=max(C1..C250)`. Require `hi>lo` and
   `C0 <= lo + 0.10*(hi-lo)`.
4. Define the bullish reversal exactly as the just-completed bar closing above
   its open and above the immediately preceding close.
5. BUY only when `z < -2.0`, the lower-decile condition holds, and the bullish
   reversal holds. There is no short signal, confirmation symbol, averaging,
   retry, scale-in, pyramid, grid, or martingale.
6. Read frozen `ATR(14,H4)` on the signal bar. Set the structural stop below
   the signal low by `0.25*ATR`; enforce a minimum entry-stop distance of
   `1.25*ATR`, and reject an entry whose required distance exceeds
   `2.50*ATR`. Attach the normalized broker hard stop before send.
7. Attach a frozen target at `entry + 1.50*ATR`. Exit earlier on the first
   completed H4 bar with the same prior-forty-bar z-score above `-0.50`, after
   eighteen H4 periods of elapsed time, or through framework Friday close,
   kill switch, hard stop, or hard target.
8. Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Both news axes are OFF for the locked baseline so no
   external calendar is a hidden signal; Q09 owns news-mode sensitivity.

The 250-close range is a closing-price range, not a high-low price envelope.
The current signal bar is excluded from every reference sample. Signal
magnitude never scales risk.

## Activity And Risk Boundary

The source program's roughly twenty-five-trade estimate is an ordering prior,
not evidence. The build records a conservative 12-25 entries per full year,
and the current activity contract retires any full post-warm-up year with
fewer than ten distinct entry days.

The 2015 EURCHF discontinuity is a dominant falsification hazard. A broker
hard stop caps requested risk but cannot guarantee fill price through a gap.
No hard floor, permanent SNB backstop, intervention timing, or post-2015
stationarity is assumed. Q04-Q07 failure is terminal for this locked card; no
threshold rescue is authorized.

## Non-Duplicate Decision

The canonical checker scanned 4,775 registry identities, 1,411 card files,
and all 45 Strategy Wiki nodes. It found no exact or fuzzy identity. Evidence:
`artifacts/qm5_eurchf_franc_rev_preallocation_dedup_20260901.json`, SHA-256
`D78071AA44A69A45F5133709888CCD2B2E5684DF0539494B13B2CC95040FA80E`.

Manual semantic review fixes the load-bearing boundaries:

- `QM5_35008_short-term-bollinger-reversion-system` is symmetric M15
  Bollinger/RSI evening reversion over three FX symbols. This candidate is
  EURCHF-only, H4, long-only, uses an ex-current 40-close z-score plus a
  250-close location gate, and has no session or RSI condition.
- `QM5_1012_lien-fader` uses D1 low-ADX state, a prior-day range false break,
  and an opposite-range H1 trigger. This candidate has no ADX, prior-day
  false-break, or resting opposite-range order.
- `QM5_1011_lien-inside-day-breakout` follows a multi-inside-day volatility
  breakout. This candidate fades an extreme only after a bullish reversal.
- `QM5_30006` is an H1 ADX/MA grid blueprint; `QM5_31006` is an M15 stochastic
  Asian-session scalper; `QM5_38007` is an ATR-grid blueprint. Their cadence,
  direction logic, risk architecture, and banned grid families differ.

Verdict:
`DISTINCT_EURCHF_H4_LONG_ONLY_EXCURRENT_ZSCORE_LOWER_DECILE_BULLISH_REVERSAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_UNTESTED_MECHANIZATION_AND_POST_FLOOR_REGIME_RISK`: the
  complete durable OWNER research program and two complete local official-
  source packets establish CHF safe-haven lineage and the exact proposed
  research ticket. They do not establish this trading rule or post-2015
  profitability; the translation is disclosed as untested synthesis.
- R2 `PASS`: reference sample, population deviation, strict z threshold,
  lower-decile close range, reversal, side, ATR stop/target, risk, and exits
  are deterministic and locked before Q02.
- R3 `PASS`: `EURCHF.DWX` is canonical in
  `dwx_symbol_matrix.csv` and supplies native H4 OHLC/ATR for research. The
  matrix has no confirmed live-order alias, which is irrelevant to Q02 but
  remains a hard block for any later live packaging.
- R4 `PASS`: completed OHLC, fixed-window arithmetic, ATR risk, positions,
  quotes, and framework state only; no trained output, adaptive parameter,
  external runtime feed, grid, martingale, averaging, or pyramid.

## Safety Boundary

Approved: one registered V5 identity, one source/card extraction, one
non-live build, deterministic reference checks, strict Q01, one canonical
`RISK_FIXED` EURCHF H4 backtest set, and one paced Q02 enqueue if CPU admission
allows.

Not approved: source-site scraping, manual backtests, optimization, threshold
rescue, live/demo/shadow/stress presets, portfolio admission, portfolio-gate
edits, correlation waivers, deploy/live manifests, `T_Live`, AutoTrading,
terminal control, or any action above Q02.
