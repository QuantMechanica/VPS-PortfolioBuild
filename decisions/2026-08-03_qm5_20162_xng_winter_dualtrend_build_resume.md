# QM5_20162 XNG Winter Dual-Trend Build Resumption

Date: 2026-08-03

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, carrying forward the committed G0 approval in
`strategy-seeds/cards/approved/QM5_20162_xng-winter-dualtrend_card.md`.

## Decision

Complete the previously scaffolded but unbuilt
`QM5_20162_xng-winter-dualtrend` candidate and hand exactly one fixed baseline
to Q02. The candidate is long `XNGUSD.DWX` only during November through March
when the last completed D1 close, SMA(21), SMA(84), and both five-bar SMA
slopes form the approved rising stack. It exits on season or trend
invalidation, after 35 calendar days, at the framework Friday close, at the
hard stop, or under the kill switch.

The committed preflight state contains the approved card, source packet,
EA-registry row, magic row `201620000`, generated resolver entry, and a partial
`.mq5`, but no `.ex5`, canonical setfile, Q01 PASS, or Q02 work item. Finishing
those missing artifacts is new build work; this decision does not allocate a
new EA ID or create a parameter variant.

## Source Boundary

The governed composite packet is
`strategy-seeds/sources/EIA-MOP-XNG-WINTER-DUALTREND-2026/source.md`:

- U.S. EIA documents recurring winter heating-demand seasonality in natural
  gas.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), documents own-return continuation across liquid futures, including
  commodities.

The 21/84-D1 moving-average stack, five-bar slopes, CFD carrier, ATR stop,
Friday segmentation, and fixed-risk implementation are disclosed QM
hypotheses. No source return, trade count, WTI/XNG-specific alpha, drawdown,
or portfolio-correlation result transfers to this build.

## Non-Duplicate Boundary

- `QM5_12567_cum-rsi2-commodity` is a short-horizon cumulative-RSI pullback
  above a slow price filter; this candidate has no oscillator or pullback.
- `QM5_12702_xngusd-winter-withdrawal-long` uses a monthly winter decision and
  one price/SMA confirmation; this candidate requires a completed daily
  21/84 trend stack with both five-bar slopes rising.
- `QM5_20063_xng-tsmom3m` and `QM5_20204_xng-tsmom1m` use unconditional
  monthly own-return signs in both directions; this candidate is winter-only,
  long-only, and Friday-segmented.
- `QM5_20164_xng-summer-dualtrend` is the disjoint May-September carrier of
  the same source family. It cannot enter during this candidate's
  November-March window.

The exact slug and strategy ID already resolve to the canonical `QM5_20162`
registry allocation. No second allocation is authorized.

## Safety Boundary

Authorize card-schema repair without economic-rule change, one branch-only EA
build, strict compile, one `RISK_FIXED=1000` backtest setfile, and one paced
Q02 enqueue. Both news axes are OFF, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This excludes live/demo/shadow setfiles, `T_Live`, AutoTrading, deploy or
T_Live manifests, portfolio admission, portfolio-gate edits, correlation
waivers, manual tester launches, and post-result parameter rescue.
