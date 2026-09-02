# QM5_41309_wti-mlz76-tr - Strategy Spec

**EA ID:** QM5_41309

**Slug:** `wti-mlz76-tr`

**Strategy ID:** `AI-CODEX-WTI-MLZ76-TREND-20260902_S01`

**Source:** `AI-CODEX-WTI-MLZ76-TREND-20260902`

**Author:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct twenty-one consecutive completed broker-month-end closes. Convert
them to twenty chronological adjacent log returns and encode positive returns
as `1` and negative returns as `0`. A return whose absolute value is at most
`1e-12` invalidates the signal and consumes the month flat.

Parse the twenty-bit word with the exact LZ76 unique exhaustive-history rule.
At phrase start `p`, take the shortest nonempty `S[p..q]` absent from the
prefix `S[0..q-1]`, whose final character is immediately before `q`. Only the
terminal suffix may be appended when no new phrase exists before word end.
Follow the newest twelve-month WTI return sign for one month only when the raw
component count is at most six. Complexity and momentum magnitude never scale
risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 20 | completed adjacent monthly log returns |
| `strategy_complexity_ceiling` | 6 | inclusive raw LZ76 component-count gate |
| `strategy_sign_epsilon` | `1e-12` | fail-closed return-sign tie band |
| `strategy_momentum_months` | 12 | newest return count used for side |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral-direction band |
| `strategy_history_bars` | 1000 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol, Clock, and Formula

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `413090000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the D1 boundary.
- Every current-month price is excluded.

For completed endpoints `c[0..20]` in oldest-to-newest order:

```text
r[i] = ln(c[i+1] / c[i]), i=0..19
S[i] = 1 iff r[i] > +1e-12
S[i] = 0 iff r[i] < -1e-12
```

For each phrase start `p`, select the least length `L>=1` for which
`S[p:p+L]` does not occur at any candidate start strictly less than `p`.
Those candidates are exactly the substrings contained in the prefix ending
before the proposed phrase's terminal bit. Append the whole remaining suffix
only if no such `L` exists. Require exact phrase reconstruction and raw
complexity `C(S)` in `[2,9]`.

```text
qualified = C(S) <= 6
mom12     = sum(r[8..19])

BUY  iff qualified and mom12 > +1e-12
SELL iff qualified and mom12 < -1e-12
FLAT otherwise
```

The method fixture `0011011101110110` must parse as
`0|01|10|111|01110110`, with `C=5`. The equal-sign-count/equal-run-count
boundary pair is also locked:

```text
00000001101110100100 -> 0|0000001|10|111|010|0100   -> C=6 (admit)
00000001101110101000 -> 0|0000001|10|111|010|100|0  -> C=7 (reject)
```

All inputs and intermediate values must be finite. Missing, duplicate,
nonconsecutive, stale, nonchronological, nonpositive, tied, or malformed data
fail closed. Return, sign, and phrase strings are diagnostic only.

## 4. Entry and Risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualified month can open one market position with a
frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Existing
owned exposure or foreign `XTIUSD.DWX` exposure blocks entry. Framework quote,
contract, tick, volume, sizing, and margin guards remain authoritative.

Both news axes and legacy news are OFF. Friday close and stress rejection are
disabled. A nonnegative spread no greater than 1,500 points is allowed.

The normalized broker-month attempt is persisted before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or order gates. A failed gate cannot
cause a same-month retry. The entry month is persisted only after a confirmed
fill and can be recovered from matching position-deal history after restart.

## 5. Management and Exit

An owned position closes on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Missing or inconsistent
position, stop, side, entry-time, or entry-month state triggers a defensive
strategy close. There is no target, trail, break-even, partial close,
complexity exit, opposite-signal exit, intramonth flip, Friday flatten, retry,
scale-in, grid, martingale, or pyramid.

The framework kill switch and broker hard stop remain authoritative. Runtime
uses MT5-native price, calendar, ATR, quote, position, deal, and terminal-global
state only; no futures chain, API, file, inventory, optimizer, portfolio state,
randomized tie breaker, compression library, or trained artifact is allowed.

## 6. Expected Activity and Kill Criteria

Exact pre-data enumeration of all `2^20=1,048,576` binary words admits
590,076 (`56.2740325928%`) at `C<=6`, or 6.7529 qualifying states per twelve
attempts. The count distribution is locked in the reference fixture. These are
combinatorial facts, not WTI performance evidence.

Retire on zero positions, fewer than five completed positions in any full
scored post-warm-up year, nonpositive governed economics, nondeterminism, or
any formula, fixed-risk, hard-stop, lifecycle, or downstream gate failure.
Q09 alone may establish or reject portfolio diversification.

## 7. Source and Non-Duplicate Boundary

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/source.md`.
Szczepanski supports the precise finite-word parsing rule and component count;
Lempel and Ziv provide original-method provenance; Moskowitz, Ooi, and Pedersen
support monthly own-return continuation and explicit WTI membership. None
tests this exact conjunction, ceiling, CFD implementation, or risk contract.

The canonical dedup receipt is
`artifacts/qm5_wti_mlz76_tr_preallocation_dedup_20260902.json`. This differs
from ordinal-entropy, sign/run, sign-count, sign-vote, pure WTI trend,
distribution, scale, calendar, event, and channel families. Certified
`QM5_12567` is a long-only short-horizon XNG oscillator pullback.

## Framework Alignment

- `Strategy_NoTradeFilter`: exact identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, sign tie rejection, exact LZ76 parser/reconstruction,
  component boundary, momentum side, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side verification,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit; framework close
  helpers carry the authorized reasons.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413090000`; Q01 pending |
