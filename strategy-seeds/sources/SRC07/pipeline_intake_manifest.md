# SRC07 Company Pipeline Intake Manifest

Generated: 2026-06-04
Status: DRAFT intake, not approved for build

## Draft Cards Created

| Strategy ID | Slug | Card | Recommended next gate | Notes |
|---|---|---|---|---|
| SRC07_S01 | fx-network-resid | strategy-seeds/cards/fx-network-resid_card.md | CEO/QB G0/G1 review | Strongest structural FX candidate; multi-symbol implementation complexity. |
| SRC07_S02 | asia-range-fade | strategy-seeds/cards/asia-range-fade_card.md | CEO/QB G0/G1 review | Strongest broad session-range family; validate true high/low and spreads. |
| SRC07_S03 | xau-pull-cont | strategy-seeds/cards/xau-pull-cont_card.md | CEO/QB forensic review before G0 | Highest raw edge but suspicious win rate; validate bid/ask first. |
| SRC07_S04 | news-surp-follow | strategy-seeds/cards/news-surp-follow_card.md | CEO/QB G0/G1 review | Event sleeve; custom news calendar dependency and low sample count. |

## Required Before EA Build

- CEO accepts `SRC07` as an internal empirical source.
- Quality-Business reviews whether internal empirical source quality is sufficient for G1.
- CEO/CTO allocate `ea_id` only after card approval.
- Cards remain `DRAFT` until explicit approval.
- No `qm-build-ea-from-card` skill should be used on these cards yet.

## Suggested Order

1. `asia-range-fade` — simpler, broad, easiest to validate in MT5.
2. `xau-pull-cont` — highest raw edge, but first run forensic bid/ask validation.
3. `fx-network-resid` — best structural edge, more complex multi-symbol EA.
4. `news-surp-follow` — later diversifier after event timestamp validation.
