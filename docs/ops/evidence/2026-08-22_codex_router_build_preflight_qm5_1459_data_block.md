# Codex router build preflight — QM5_1459 persistent R3 data block

Date: 2026-08-22  
Role: Development / Codex  
Router task: `7830f003-6b91-4b15-b29d-4620e6a2172f` (`build_ea`, priority 50)  
EA: `QM5_1459_as-lumber-gold`  
Verdict: `PREBUILD_BLOCK_CARD_DATA_UNAVAILABLE`

## Outcome

The exact approved card, active EA-ID row, directory slug, and 13 active magic rows now exist. The build remains deterministically blocked by the card's required data, reproducing the decision in `docs/ops/evidence/2026-07-25_qm5_1459_r3_data_gate_block.md`.

The card frontmatter explicitly declares `r3_data_available: FAIL`: generic front-month lumber and IEF/intermediate-Treasury data are absent from `framework/registry/dwx_symbol_matrix.csv`, with no approved custom-symbol series. Its body and G0 reasoning call R3 `UNKNOWN` pending those series. The approved weekly rule cannot be evaluated or traded faithfully without both the lumber signal leg and the Treasury allocation leg.

## Focused verification

| Check | Result |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1459_as-lumber-gold.md` |
| Card SHA-256 | `68e1a3eeadaf0b16adf5273f482252e02abee91252c74cef65289b1a47a1a65e` |
| Card identity / G0 | exact `QM5_1459` / `as-lumber-gold`; `APPROVED` |
| Card R3 | frontmatter `FAIL`; body/G0 reasoning `UNKNOWN` pending data |
| Canonical EA-ID row | 1 active exact-slug row |
| Canonical magic rows | 13 active exact-slug rows |
| Required lumber series in symbol matrix | absent |
| Required IEF/Treasury series in symbol matrix | absent |
| Existing source | tracked auto-generated TODO skeleton; SHA-256 `08e37143feb0c0623a54d3ada67823888082efcc27065efcc025c945b8752c1b` |
| EX5 / SPEC / setfiles | 0 / 0 / 0 |

The 13 registered rows cover generic available index, FX, and gold symbols. They do not supply the missing lumber or Treasury instruments. Substituting a different commodity or a registered equity/FX symbol would change the approved strategy mechanics.

No build check, compile, setfile generation, smoke, pipeline phase, source, registry, resolver, terminal, `T_Live`, or AutoTrading mutation was performed. This is a precondition failure, not a compile or pipeline verdict.

## Required upstream remediation

Research/OWNER must either provide validated registry-approved custom-symbol history for the lumber signal and Treasury allocation leg, approve and normalize a revised card with explicit mechanical substitutes, or reject/retire the unavailable strategy. A fresh build should be routed only after that governed disposition.
