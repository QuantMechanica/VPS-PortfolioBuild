# Option B fresh card re-intake evidence — task ae0b2ab6

Date: 2026-08-26  
Agent: Codex  
Branch: `agents/board-advisor`  
Router task: `ae0b2ab6-26bf-41b7-8d91-2e315093226c`  
Disposition: three fresh-ID drafts prepared for independent G0 review; no G0 verdict recorded here.

## Authority and scope

The durable authority is `decisions/2026-08-26_owner_registry_gap_option_b.md`. OWNER selected Option B: rebuild the three strategy ideas through normal card intake, independent G0 review, and governed identity minting. The receipt explicitly forbids reanimating old reservations 1001, 1015, or 1016.

The `qm-strategy-card-extraction` preflight was applied. The authority record was read first, then each bounded source was read completely before drafting:

- `breakout-atr`: complete internal specification `strategy-seeds/specs/ath-breakout-atr-trail.md` (237 lines), including its Wilcox/Crittenden research ancestry and explicit DWX adaptation boundary.
- `lien-perfect-order`: Kathy Lien chapter 16 boundary in `strategy-seeds/sources/SRC04/raw/full_text.txt`, lines 5749-5863 (definition, five rules, examples, and closing risk/frequency note).
- `lien-carry-trade`: Kathy Lien chapter 18 boundary in `strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt`, lines 71-455.
- SRC04 source authority and book metadata: `strategy-seeds/sources/SRC04/source.md`.

## Breakout source status

The historical ea-id row for 1001 used `strategy_id=TBD`; it is not treated as provenance. Git history contains no tracked `framework/EAs/QM5_1001_*` implementation to recover. The new candidate is therefore labeled as a QuantMechanica internal construction sourced from the existing ATH-breakout/ATR-trail specification, itself explicitly adapted from Wilcox and Crittenden (2005). No old implementation, identity, approval, or paper performance result is inherited.

## Drafts placed in governed review intake

All paths are under the required `D:/QM/strategy_farm/artifacts/cards_review/` pool and use deterministic `PENDING_*` identities. No ea-id registry or magic registry row was allocated.

| Candidate | Review artifact | SHA-256 |
|---|---|---|
| `breakout-atr` | `D:/QM/strategy_farm/artifacts/cards_review/PENDING_D7B1FC80_breakout-atr.md` | `EEF6ED115DD74A3D4B782ADF4DD0CFAC9A44C007C29E03D85FD03364CF9CC807` |
| `lien-perfect-order` | `D:/QM/strategy_farm/artifacts/cards_review/PENDING_33F6DE13_lien-perfect-order.md` | `8346A9E2019D7B99CFE8F599AAF725C5E2C4CCBFC6817A7ADF8B073FC1316011` |
| `lien-carry-trade` | `D:/QM/strategy_farm/artifacts/cards_review/PENDING_E7D0E62C_lien-carry-trade.md` | `9C47334F3C7BF0296AC29F9F8B666A0E6D72DE2BE67A892C70695DE13F48160B` |

Each draft contains literal timeframe tokens, an explicit `.DWX` target universe, reproducible source citations, deterministic entry/exit/stop/sizing rules, a mandatory news blackout with stale ceiling no greater than 336 hours, fixed-risk backtest semantics (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), and explicit bans on ML, martingale, grid, averaging, scale-in, and HFT.

The Lien adaptations expose two review-sensitive source constraints rather than hiding them:

- Perfect Order retains the five-SMA stack, five-bar delay, rising ADX above 20, formation-extreme stop, and full-order-break exit; ambiguous source fallback language is resolved fail-closed rather than invented.
- Carry Trade uses broker-native converted swap plus a completed-bar FX-volatility proxy because governed historical bond-yield data is absent. Standard Friday close remains enabled even though Lien describes a six-month horizon; independent G0 must decide whether that constraint destroys identity.

## Verification

The following checks completed successfully for all three drafts:

1. `python C:/QM/repo/framework/scripts/skill_card_schema_lint.py --card <card>`: `status=ok`, no forbidden ML-library hits, no missing `Hypothesis`, `Rules`, or `Risk` sections.
2. `farmctl.strategy_card_schema_issues(...)`: empty issue list.
3. `farmctl.check_card_heading_language(...)`: `ok=true`, no unmapped or non-English headings.
4. Fingerprint census across `cards_review` and `cards_approved`: zero exact duplicate fingerprints for all three new drafts.
5. Frontmatter census: each draft uses its `PENDING_*` identity and `g0_status=PENDING_REVIEW`; none uses ea-id 1001, 1015, or 1016.

Exact-fingerprint absence is not an admission verdict. The cards instruct G0 to compare against the material near-duplicate families, especially `QM5_12399`, `QM5_11888`, `QM5_1127`, `QM5_1091`, `QM5_1095`, and `QM5_20292`.

## Handoff

The router task is returned to `REVIEW` with the first draft as its primary artifact and a verdict naming the three-card packet. This transition starts the normal independent G0 review flow; it does not approve a card, mint a fresh QM5 identity, authorize a build, or touch any pipeline verdict.

