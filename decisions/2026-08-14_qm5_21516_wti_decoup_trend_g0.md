# QM5_21516 WTI Decoupled Trend G0 Authorization

Date: 2026-08-14

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_21516_wti-decoup-trend`. On the first processed WTI D1 bar after a genuine
broker-month transition, the candidate takes the sign of WTI's exact twelve
completed-month log return only when the latest 63 synchronized completed-D1
WTI and natural-gas simple returns have weak absolute Pearson correlation.
It buys WTI after a positive twelve-month return and sells WTI after a negative
return when `abs(rho_XTI_XNG) <= 0.30`; otherwise the month is consumed flat.

This is a predeclared crude-oil trend carrier with a weak-common-energy-state
gate. It is not evidence of profitability, low portfolio correlation, or
certification. It may proceed through bounded source/card extraction, schema
and G0 lint, deterministic registry and magic allocation, resolver generation,
strict compile, one `RISK_FIXED` backtest setfile, Q01 artifact validation, and
one paced Q02 enqueue if the research-terminal CPU ceiling is not binding.

## Approved Source Boundary

The governed primary source is Moskowitz, Ooi, and Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250. The
complete-paper record and retrieval hash are preserved in
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
The paper supplies only WTI membership, own-return sign direction, a twelve-
month formation horizon, and monthly renewal.

The structural context is Villar and Joutz (2006), U.S. Energy Information
Administration, "The Relationship Between Crude Oil and Natural Gas Prices,"
and Ramberg and Parsons (2012), "The Weak Tie Between Natural Gas and Oil
Prices," *The Energy Journal* 33(2), 13-35, DOI
`10.5547/01956574.33.2.2`. Their complete-read record is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
`4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
Those sources establish economic links, instability, decoupling, and weak
modern daily co-movement; they do not define a 63-day correlation gate or a
WTI trading return.

The bounded composite extraction is
`strategy-seeds/sources/MOP-EIA-WTI-DECOUP-2026/source.md`. No source return,
Sharpe ratio, drawdown, threshold, trade count, CFD result, or QM portfolio
correlation transfers.

## Locked Rule

At the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition:

1. Persist the broker month as attempted before history, signal, spread,
   quote, news, ATR, sizing, or order checks. There is no same-month retry.
2. Load bounded completed D1 history for `XTIUSD.DWX` and read-only
   `XNGUSD.DWX`; intersect exact timestamps and require strict chronology,
   positive finite closes, a latest common endpoint before the decision bar,
   and at most ten calendar days of endpoint staleness.
3. From the latest 64 common closes, form exactly 63 chronological simple
   returns per symbol. Calculate sample means, sample variances, sample
   covariance, and Pearson correlation. Zero variance or non-finite arithmetic
   fails closed.
4. Require `abs(rho_XTI_XNG) <= 0.30 + 1e-12`.
5. From the synchronized history derive exactly thirteen consecutive completed
   broker-month WTI endpoints ending in the immediately prior broker month.
   Calculate `trend = ln(C_last / C_first)` and cross-check it against the sum
   of the twelve monthly log returns.
6. Buy WTI when `trend > 0`; sell WTI when `trend < 0`; consume an exact zero,
   invalid state, or high-correlation state flat.
7. Open at most one slot-0 WTI position with one `RISK_FIXED=1000` budget, a
   frozen `3.5 * ATR(20,D1)` broker hard stop, no take-profit, and a 1,500-point
   spread cap. XNG is read-only and must never be ordered or assigned a magic.
8. Close before monthly replacement, after forty calendar days, or on malformed
   owned state. Friday close and both news axes are OFF.

Do not substitute a different trend horizon, correlation window, return type,
threshold, covariance convention, carrier, factor symbol, direction, risk
scale, stop, hold, retry, or calendar rule.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed JFE trend source with complete-paper evidence and
  explicit WTI membership, plus a complete U.S. government report and a
  peer-reviewed Energy Journal paper documenting a weak, unstable oil-gas tie.
- R2: PASS. Exact twelve-month trend, 63 synchronized daily returns, Pearson
  sample arithmetic, fixed absolute-correlation ceiling, consumed monthly
  attempt, direction, stop, spread, rollover, and stale guard are locked.
- R3: PASS for the disclosed CFD proxy. Registered `XTIUSD.DWX` and
  `XNGUSD.DWX` D1 histories provide every runtime field; XNG is read-only.
- R4: PASS. Deterministic native price/calendar arithmetic only, without
  trained output, prohibited signal indicators, external runtime data, grid,
  martingale, scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,388 EA-registry rows and 484
cards and returned `CLEAN` for slug `wti-decoup-trend`, strategy ID
`MOP-EIA-WTI-DECOUP-2026_S01`, and the full mechanic string. Manual review
separates the nearest families:

- `QM5_12603_wti-tsmom12m` is unconditional twelve-month WTI trend and never
  reads natural gas or conditions entry on synchronized return correlation.
- Shorter, longer, robust-location, voting, path-efficiency, calendar, weekday,
  and pullback WTI trend variants transform WTI's own path but do not enforce a
  weak XTI/XNG co-movement state.
- `QM5_20237_xtixng-ecm-rv` estimates and fades an oil-gas log-price residual
  with two traded legs; this candidate estimates daily return correlation only
  as an entry gate and trades WTI outright in its own trend direction.
- `QM5_12840_xti-xng-rspread`, oil/gas ratio, rank, beta, jump, volatility, and
  paired relative-value EAs trade cross-energy differences or factor states;
  they do not combine a source-exact twelve-month WTI trend with a fixed weak-
  correlation admission state.
- `QM5_12567_cum-rsi2-commodity`, the certified XNG sleeve, is short-horizon,
  long-only oscillator pullback logic on natural gas.

The WTI carrier, twelve completed-month sign, 63-return synchronized Pearson
state, absolute `0.30` ceiling, XNG read-only boundary, consumed monthly
lifecycle, and single-leg fixed-risk execution are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_WTI_WEAK_COMMON_ENERGY_CORRELATION_TREND`.

## Allocation And Kill Boundary

- deterministically allocated EA ID: `QM5_21516`;
- slug: `wti-decoup-trend`;
- strategy ID: `MOP-EIA-WTI-DECOUP-2026_S01`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `215160000`;
- read-only signal symbol: `XNGUSD.DWX`, with no magic or order authority;
- expected cadence: approximately five to nine completed positions per full
  post-warm-up year; and
- retire below five completed positions per year, on nonpositive governed
  economics, or at later portfolio-correlation rejection.

The weak-correlation gate is intended to avoid common oil/gas regimes, but it
does not establish low correlation to XAU, SP500, NDX, or the certified XNG
sleeve. Q09 alone can accept or reject realized overlap.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. If the paced research-terminal CPU ceiling is
binding before enqueue, stop and record the capacity state without starting,
stopping, reserving, or reaping any terminal.
