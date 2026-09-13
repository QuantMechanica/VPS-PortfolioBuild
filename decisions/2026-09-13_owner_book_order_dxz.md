# OWNER Book-Build Order -- dxz -- 2026-09-13

- Venue: dxz
- Effective date: 2026-09-13
- Author: OWNER (chat order 2026-09-13 ~15:0xZ, recorded by Orchestrator Claude)
- Generated (UTC): 2026-09-13T14:51:07+00:00
- Session: https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE
- Generator: tools/strategy_farm/mint_owner_book_order.py

The line below is the machine-checked authorization token. book_build_guard
(_find_owner_order, book_build_guard.py:116) requires it verbatim (stripped),
with venue and date taken from THIS file's name. Do not edit it by hand.

OWNER-ORDER: BOOK_BUILD dxz 2026-09-13

## What this authorizes

Entry into book-build ANALYSIS (dry-run/analytic) for the dxz venue on the
effective date, and nothing more. See docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md
section 2 for the full ceremony step list.

## What this does NOT authorize

Live weights, T_Live writes, AutoTrading, or a risk-freeze lift. Each of those
remains a separate OWNER act.

## Signing

This order is effective only when the OWNER COMMITS this file into decisions/
with an explicit pathspec. Minting alone authorizes nothing.

## Provenance (Orchestrator record of the OWNER instruction)

OWNER, chat 2026-09-13 ~15:0xZ (verbatim): "Berechne gleich alles! Es ist der Markt geschlossen, also lass uns das Buch updaten!"
Context: the Orchestrator had proposed (same chat, minutes earlier) the two-step "bereinigen + Buch v2 aus den 26
qualifizierten Paaren, Cutover mit 14-Tage-Min-Lot-Burn-in" and asked for the direction; the OWNER ordered the
computation and the book update. Same authority pattern as decisions/DL-089 (OWNER chat quote) and the 2026-07-24
manifest ("countersigned via chat"). The OWNER signs the deploy manifest and flips AutoTrading himself (ROT).
Recorded by: Claude (Orchestrator), session above. Guard census at order time: qualified_pairs=26, distinct_eas=26,
strategy_families=21 (book_build_guard --status --venue dxz, 2026-09-13 14:5xZ).
