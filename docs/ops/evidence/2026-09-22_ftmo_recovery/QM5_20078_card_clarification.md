# QM5_20078: exact stop clarification for designated G0 review

Status: PROPOSED, not an approved amendment. Existing g0_status=APPROVED is
preserved. Registry allocation is complete; execution remains blocked on this
specific card-fidelity issue. Parent: df1cae9b; existing build: 751d8eb5.

The card simultaneously says BUY SL is the MINIMUM of two price levels and
whichever is closer. Those rules disagree whenever the levels differ. The
SELL text says closer. The current source remains a skeleton until resolved.

Proposed resolution: retain the explicit closer-stop intent symmetrically.
Let E be executable entry quote, P prior-session POC and A closed M15 ATR14.
BUY: SL=max(E-A, P-0.5*A). Require SL<E and E>P.
SELL: SL=min(E+A, P+0.5*A). Require SL>E and E<P.
This is the minimum positive stop DISTANCE, not minimum BUY stop PRICE.
Fix the card's wording and retain no-widening and the existing 2 ATR hard TP.

| Side | E | P | A | ATR level | POC level | Proposed SL |
|---|---:|---:|---:|---:|---:|---:|
| BUY | 101 | 100 | 4 | 97 | 98 | 98 |
| BUY | 105 | 100 | 4 | 101 | 98 | 101 |
| BUY | 102 | 100 | 4 | 98 | 98 | 98 |
| SELL | 99 | 100 | 4 | 103 | 102 | 102 |
| SELL | 95 | 100 | 4 | 99 | 102 | 99 |

Also correct the explanatory TP paragraph: close reaching VAH/VAL exits first
when nearer; the broker 2 ATR cap limits a farther value-area target. Retain
both executable rules. No economic thresholds change.

Implementation boundary conventions proposed for the same review:
- Compute only from the previous complete trading session 06:00-21:00 broker
  time. Weekend sessions are skipped; a sparse actual prior trading session
  with fewer than 60 positive-volume M1 bars disables the next session.
- Midpoint=(M1 high+low)/2. Fixed 50 bins, endpoint clamped to bin 49. POC ties
  select lower-index bin. Value-area ties sort lower price first; edges are
  outer boundaries of the selected bin set. Tick volume is a stated proxy.
- First down-touch from above consumes the BUY opportunity, even if another
  entry filter rejects it; mirror SELL. Reconstruct consumption since 06:00
  after restart. The first hour can consume a touch but cannot admit an entry.
- Use the last completed H1 EMA, M15 RSI/ATR and D1 ATR available at decision
  time; map the card's bar-close [0] notation to completed MT5 shift 1.
- The session-close exit runs every tick before entry/news filters. Freeze
  entry ATR for hard SL/TP and measure the 24-bar time stop in actual M15 bars.

Required reviewer action: accept an exact durable card amendment or specify a
single alternative equation. Then resume the EXISTING 751d8eb5 build task;
do not allocate another EA or enqueue the rejected duplicate 12038.
