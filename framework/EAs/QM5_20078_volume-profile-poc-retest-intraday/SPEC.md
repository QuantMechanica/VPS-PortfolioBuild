# QM5_20078: Volume Profile POC Retest

**EA ID:** QM5_20078
Approved card: docs/strategy_card.md; designated G0 amendment accepted in task
6c5219a9-ed29-4e82-acd0-ca949571271f on 2026-09-22. Build task 751d8eb5.

## 1. Strategy Logic

M15 closed-bar support/resistance retest of the prior complete weekday session's
POC. Sessions are 06:00–21:00 broker time; Monday uses Friday. Fewer than 60
positive-volume M1 observations disables the following session. Incomplete
history synchronization retries on the next closed bar. Session levels stay
fixed. The M1 midpoint allocates tick volume into 50 equal-width bins; the high
endpoint clamps to bin 49. POC ties choose lower price. Descending-volume bins,
with lower-price ties, accumulate 70%; VA boundaries enclose the selected bins.
Tick volume is a proxy, not exchange volume.

Replay all completed current-session M15 bars after each new bar. Previous
close (first bar: session opening quote) above POC plus low <= POC consumes the
BUY event, mirrored for SELL. A consumed event remains spent even if news,
spread, RSI, session-age or position filters reject it. Replay restores this
state after restart. Initial attachment skips the current forming bar. Entry
requires four completed session bars and at least one hour elapsed.

BUY needs current completed close above POC and completed H1 EMA200, bullish
body and closed M15 RSI14 >45. SELL mirrors with RSI <55. All ATR/RSI/EMA inputs
are closed shift 1 with framework warmup probes. RSI endpoints 0/100 are valid.
VA width must be >=0.5 closed D1 ATR14. Current spread must be <=1.5 times median
spread of 20 completed M15 bars. Missing or zero median fails closed.

Executable quote must remain on the correct POC side. BUY SL=max(E-A,P-0.5A),
SELL SL=min(E+A,P+0.5A), where A is closed M15 ATR14. SL never widens. Hard TP
is E +/-2A. A completed close reaching VAH (BUY)/VAL (SELL) exits sooner when
that target is nearer. The time stop uses 24 actual M15 bars since entry.
All positions of this symbol/magic close at session end, per tick before
entry/news gates; delayed ticks and next-session restarts also close stale
positions. Standard framework kill, Friday, MAE, transaction and timer hooks
remain active. One position per registered magic.

News boundary: the framework exposes PRE30_POST30, not PRE15_POST15. Default
uses the stricter 30-minute window covering the card's 15-minute minimum, plus
DXZ compliance. Both axes remain inputs for governed Q09 testing. This disclosed
implementation convention requires independent build review; no gate is waived.

## 2. Parameters

ATR/RSI 14; H1 EMA 200; RSI BUY >45, SELL <55; fixed bins 50; VA coverage .70;
stop multipliers 1 ATR / .5 ATR around POC; TP 2 ATR; VA-width minimum .5 D1 ATR;
spread median multiplier 1.5; max hold 24 M15 bars; min session age 4 bars;
min profile observations 60. Periods and counts bounded by configuration guard.

## 3. Symbol Universe
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX.
Seven distinct registered slots; presets carry the allocator's slot mapping.

## 4. Timeframe
M15 only. Prior-session profile uses closed M1; bias closed H1; width closed D1.
All civil-time boundaries use broker time, without local-time/DST conversion.

## 5. Expected Behaviour
At most one consumed event per side per session, at most two potential entries.
The card's 30 trades/year/symbol is an unmeasured prior. Build/logic tests are not
profitability tests. Economic validation and payout probability remain pending.

## 6. Source Citation
Approved card docs/strategy_card.md, source ID
6e967762-b26d-59a3-b076-35c17f2e7c36; retained Forex Factory volume-profile cluster
attribution and Steidlmayer conceptual lineage. No new authenticated source
retrieval or verified historical performance is claimed. Arithmetic and boundary
amendments are bound to the independent designated G0 review above.

## 7. Risk Model
RISK_FIXED=1000, RISK_PERCENT=0 for baseline tests. Framework sizing uses
entry-to-SL distance; no averaging, martingale, grid, partial exits or stop
widening. This build confers no live or paid-Challenge approval.
