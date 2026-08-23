# Public EA showcase renderer — REVIEW handoff

- Router task: `cc61dbf2-501a-4b31-bf9a-c1f5404f0004`
- ToDo: `QM-TODO-20260823-514`
- Branch: `agents/board-advisor`
- Status: renderer complete; publication remains gated

## Outcome

Implemented `tools/strategy_farm/public_ea_showcase.py` as a standalone,
staging-only HTML renderer. It does not read or filter internal Strategy Cards,
EA source, the farm database, deployment manifests, live terminals, or the
internal archive page. Its only accepted input is the exact reduced schema
`qm.public-ea-showcase-projection.v1`.

No individual EA showcase is emitted in the current projection. The router
payload states that the product EAs and per-EA rights clearances do not yet
exist, so the durable current projection has an empty `items` list. The staged
index says that no EA currently satisfies every publication gate; it does not
guess a candidate or expose a coverage-only archive card.

## Fail-closed renderer contract

For every page, the projection must explicitly prove all of:

- current live-book membership;
- actual traded-live status;
- marketplace-candidate status;
- product-EA readiness;
- `rights_status: CLEARED` for that EA.

The renderer then accepts only the public thesis, risk profile, behaviour,
failure modes, evidence chain, separately typed track records, and an optional
clean official MQL5 Market product URL. Unknown fields are rejected rather than
dropped. In particular, internal rule fields such as `entry_rules` cannot be
passed through accidentally.

Additional invariants:

- every metric-bearing backtest or live record references an opaque published
  `rpt_*` evidence ID with a matching evidence type;
- gate, out-of-sample, cost-model, and drawdown evidence classes are mandatory;
- backtest and live records render under separate headings and carry explicit
  `BACKTEST — NOT LIVE` / `LIVE — REAL ACCOUNT RECORD` badges;
- a missing public live record is disclosed, never synthesized from backtest;
- thesis/risk/behaviour/failure copy is number-free so numeric claims can occur
  only in evidence-bound records;
- absolute paths, UUIDs, internal EA IDs, legacy P-phase names, code/formula
  syntax, credentials, endpoints, and private-storage markers fail the whole
  render before any file is written;
- output under `public-data/` is refused. The tool has no publish, Git, MQL5,
  MT5, Netlify, or network action.

## Durable current-state render

Input:
`docs/ops/evidence/cc61dbf2_public_ea_showcase_empty_projection_2026-08-23.json`

Staging output:
`D:/QM/exports/website_contract_preview/ea_showcase/render_8e83fd74d2324692/`

- pages: `0`
- `index.html` SHA-256:
  `63464c82d822f1347f7449f75f96ad56a00bbbb13ab6bd4cece97b770a10412a`
- `manifest.json` SHA-256:
  `f3375bed72b416f4906478a1a8412a20ceed08a72c1699b9a0394726fb0a576f`

## Verification

```text
python -m py_compile tools/strategy_farm/public_ea_showcase.py tools/strategy_farm/tests/test_public_ea_showcase.py
PASS

python -m pytest tools/strategy_farm/tests/test_public_ea_showcase.py -q
25 passed in 1.09s

python -m pytest tools/strategy_farm/tests/test_public_ea_showcase.py tools/strategy_farm/tests/test_website_archive_contract.py -q
85 passed in 2.19s

python tools/strategy_farm/public_ea_showcase.py --projection docs/ops/evidence/cc61dbf2_public_ea_showcase_empty_projection_2026-08-23.json --out-dir D:/QM/exports/website_contract_preview/ea_showcase
pages=0, render_id=8e83fd74d2324692
```

The focused negative suite covers missing rights/product/live eligibility,
unknown internal-rule fields, internal paths and IDs, unevidenced numeric copy,
legacy phase names, build-manual syntax, missing evidence classes, mixed or
mismatched track-record provenance, unsafe MQL5 URLs, and attempted output to
the live public-data tree.

## Handoff

Claude may provide the reduced projection and approved public copy after the
product and rights prerequisites are durable per EA. OWNER/close-out review
must decide when any non-empty projection may be connected to a publishing
workflow. This task did not publish a page, create an MQL5 listing, alter the
live book, enable AutoTrading, or touch a terminal.
