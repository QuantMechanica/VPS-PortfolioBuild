# Library Mining: Art Collins - Beating the Financial Futures Market (2006)

**Date:** 2026-06-26  
**Miner:** Codex Research  
**Source:** `C:/Users/Administrator/Downloads/beating-the-financial-futures-market-combining-small-biases-into-powerful-money-making-strategies-wiley-trading_compress.pdf`

## Scope

OWNER approved mining this source after the Downloads triage. This pass kept the batch deliberately small: three cards from one source, all D1/OHLC-only, all dedup-checked against existing `cards_approved`, `strategy-seeds/cards`, and `ea_id_registry.csv`.

## Dedup Summary

No direct approved card was found for:

- Collins 9-day 66 percent momentum
- Collins cups/caps target-stop variant
- Collins 1.5 daily range expansion

Closest neighbors were generic breakout, DeMark range-expansion, and price-pattern cards. None used Collins' exact formula combinations.

## Cards Drafted

| Strategy ID | Slug | File | Verdict |
|---|---|---|---|
| SRC08_S01 | `collins-66mom` | `strategy-seeds/cards/collins-66mom_card.md` | NEW DRAFT |
| SRC08_S02 | `collins-cupcap` | `strategy-seeds/cards/collins-cupcap_card.md` | NEW DRAFT |
| SRC08_S03 | `collins-15rex` | `strategy-seeds/cards/collins-15rex_card.md` | NEW DRAFT |

## Rejected / Deferred

| Candidate | Reason |
|---|---|
| Second High/Low exit family | Better treated as an exit wrapper or P3 exit variant, not a standalone inefficiency. |
| Four-day 200 percent range expansion | Similar family to `collins-15rex`; defer until first range-expansion card is tested. |
| Intraday Dow-Spoo / open-reference systems | R3/time-session handling and intraday latency make them lower priority than the D1 cards. |
| Soybean seasonal systems | Commodity-specific futures seasonality is not directly DWX-native. |

## Build Recommendation

1. Review `collins-66mom` first. It is the most distinctive, simple, and index-relevant of the three.
2. Build only one Collins card initially. If it dies before Q04, build `collins-cupcap`; keep `collins-15rex` as third.
3. Do not create more Collins cards until at least one of these reaches a meaningful pipeline verdict.

## Risk Notes

- Collins' book results are historical futures tests through 2005; treat performance claims as source evidence only, not validation.
- The V5 ports intentionally add framework constraints: Friday close, news blackout, one-position-per-magic, no pyramiding.
- D1 CFDs differ from exchange-traded futures sessions. Q02/P2 must verify session-close definitions and broker daily candle behavior before interpreting results.
