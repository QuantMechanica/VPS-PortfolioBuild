# QM5_21521 WTI weekly flow-regime switch — G0 decision

Date: 2026-08-14

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 handoff if
the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
2026-08-14. The mission requires one new structural low-frequency commodity
edge, reputable-source criteria, `RISK_FIXED` backtests, committed
non-duplicate work, and a paced Q02 enqueue. It forbids live, AutoTrading,
portfolio-gate, and `T_Live` manifest mutations.

## Candidate

- EA: `QM5_21521_wti-flow-switch`
- Strategy ID: `ZHAO-ST-MOMREV-2026_XTI_S05`
- Source ID: `ZHAO-WTI-FLOWSWITCH-2026`
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `215210000`
- Driver: on one consumed evaluation per broker week, continue the latest
  completed five-D1 WTI return when its same-window native tick-volume sum is
  in the bottom quartile of 40 earlier disjoint five-bar windows; fade the
  return when volume is in the top quartile; remain flat in the middle half
- Lifecycle: frozen `2.75 * ATR(14,D1)` hard stop, five-completed-D1-bar
  maximum hold, standard two-axis news gate, 400-point spread ceiling, and
  framework Friday close

## Approved source boundary

The complete governed research note
`D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`,
the canonical family record
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`, and
the two bounded tail translations for `QM5_21504` and `QM5_21520` were read
before this decision. The single bounded lineage for this card is
`strategy-seeds/sources/ZHAO-WTI-FLOWSWITCH-2026/source.md`.

The source is Zhao, Ding, Yu, and Kang (2026), "Momentum and Reversal on the
Short-Term Horizon: Evidence from Commodity Markets," SSRN 6425598, DOI
`10.2139/ssrn.6425598`. Accessible metadata and abstract/methodology summaries
support two narrow findings: the residual component of weekly commodity
returns positively predicts the following week's return, while the
speculative-flow component reverses. The source decomposition uses investor
positions, which QM does not have as an approved runtime feed.

Native MT5 tick volume is therefore a disclosed conditioning proxy, not the
paper's signal. Bottom-quartile volume is treated as a falsifiable candidate
for a residual-dominated WTI week; top-quartile volume is treated as a
falsifiable candidate for a flow-dominated week. The source does not specify
the proxy, WTI carrier, quartile cutoffs, stop, spread ceiling, hold, expected
performance, or portfolio correlation. No source result transfers to this
card.

On 2026-08-14 the deterministic QM URL router classified direct retrieval of
the canonical SSRN URL as `PERMISSION_REQUIRED`, adapter `generic`, state
`ROUTER_ONLY`, and lead status `DEFERRED:SOURCE_POLICY`. No proxy,
authentication, cached mirror, or access-control workaround was used.

## Locked rule

At the first processed D1 bar after a genuine framework broker-week
transition:

1. Persist the new week as attempted before history, signal, news, spread,
   quote, sizing, or order checks. There is no same-week retry.
2. Load exactly 205 completed WTI D1 bars and require strictly descending
   timestamps, positive finite closes, and positive tick volume.
3. Compute `weekly_return = Close[0] / Close[5] - 1` and sum native tick
   volume over bars 0 through 4.
4. Form 40 earlier, non-overlapping five-bar tick-volume sums from bars 5
   through 204. Compute
   `rank = 100 * count(baseline_sum <= current_sum) / 40`, ties included.
5. If `rank <= 25`, follow the sign of `weekly_return`. If `rank >= 75`,
   trade against its sign. A zero return or middle rank consumes the week
   flat. Return magnitude and volume rank never scale risk.
6. Open at most one slot-0 WTI position with `RISK_FIXED=1000`, a frozen
   `2.75 * ATR(14,D1)` broker hard stop, no take-profit, and a 400-point
   spread ceiling.
7. Close after five completed D1 bars, at the hard stop, or through framework
   Friday close. There is no opposite-signal, target, trailing, break-even,
   partial, scale-in, grid, martingale, or pyramid rule.

## Reputable-source criteria

- R1 PASS: one attributable working paper with authors, date, URL, DOI,
  retrieval boundary, complete governed note, and bounded source packet.
- R2 PASS: completed-bar support, disjoint volume windows, empirical rank,
  ternary direction, attempt clock, stop, hold, spread, and sizing are fixed.
- R3 PASS for the disclosed proxy: WTI D1 close and native tick volume are
  available in MT5; no COT, investor position, file, API, or external feed is
  required.
- R4 PASS: fixed arithmetic and thresholds only, with no trained output,
  PnL-dependent fitting, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The deterministic pre-allocation checker scanned 4,393 EA-registry rows and
489 root cards, found no exact slug or strategy-ID collision, and returned
expected fuzzy Zhao-family neighbors. Manual mechanic review resolves them:

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback above a slow trend filter. This candidate is weekly, symmetric,
  raw-return based, and conditioned only by disjoint tick-volume rank.
- `QM5_13049_xti-1w-mom-vol` follows only thresholded five-day WTI moves in a
  low realized-volatility state and permits a signal exit. This candidate has
  no move threshold, realized-volatility statistic, or signal exit.
- `QM5_13050_xti-1w-rev-vol` fades only thresholded five-day WTI shocks in a
  high realized-volatility state and permits a mean-reversion exit. This
  candidate has no shock threshold, realized-volatility statistic, or
  mean-reversion exit.
- `QM5_21504_xng-flowrev` implements only the top-volume fade tail on XNG;
  `QM5_21520_xng-flow-mom` implements only the bottom-volume continuation
  tail on XNG. This candidate is one WTI ternary state machine that assigns
  opposite directions to both disjoint tails and explicitly consumes the
  middle half flat. It is not a carrier-only copy of either one-tail sleeve.
- Existing WTI trend, seasonality, EIA-event, expiry, carry, relative-value,
  and robust-momentum builds do not rank disjoint five-bar tick-volume windows
  or switch continuation versus reversal by opposite volume tails.

Verdict:
`CLEAN_WTI_WEEKLY_TWO_TAIL_FLOW_REGIME_SWITCH_AFTER_SOURCE_FAMILY_REVIEW`.

## Allocation and kill boundary

The deterministic allocator reserved `QM5_21521` on 2026-08-14. The two
quartile tails imply roughly 20-26 eligible weeks per full post-warm-up year
before execution gates; this is a prior, not test evidence. Q02 must retire
the card below five completed trades per full post-warm-up year or on
nonpositive governed economics. Do not move either quartile boundary, change
the five-bar construction, collapse the middle state, or alter either tail's
direction to rescue failure.

WTI supplies a distinct physical-energy carrier from the certified
XAU/SP500/NDX/XNG book, but G0 does not assert realized independence. Q09
alone may accept or reject portfolio correlation.

## Safety boundary

Create only one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, or optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. If the paced factory CPU ceiling is binding
before enqueue, stop without starting, stopping, reserving, reaping, or
reprioritizing any terminal.
