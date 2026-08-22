# SP-C3 concentration and common-tail limits — implementation evidence

Date: 2026-08-22  
Router task: `4fab7ffd-903c-4218-b2d2-12746839f2ee`  
Lane: Codex implementation after Claude design commit `93005f2d9`  
Disposition: `IMPLEMENTED_FOR_REVIEW` (no pipeline verdict; no live action)

## Authority boundary

The implementation follows
`docs/ops/SP-C3_CONCENTRATION_TAIL_LIMITS_DESIGN_2026-08-22.md`. The threshold
file is deliberately marked `PROPOSED_OWNER_RATIFICATION_REQUIRED` and binds
application authority to `OWNER_ONLY`. An unratified policy cannot make a book
builder-eligible. The tools emit `deployment_action=NONE` and
`autotrading_action=NONE`; no live weight, terminal, or AutoTrading state was
changed.

## Durable implementation

- `concentration_tail.py` evaluates stop-risk concentration by symbol, asset
  class, strategy family, and dominant broker-wall entry session. It also
  calculates exact-count per-sleeve worst-5% tail membership, common-tail days
  with `K=ceil(n/3)`, the worst common-tail portfolio loss, historical daily
  VaR95, and a clearly labelled non-provider D-Leverage-like
  `stop-risk-sum / VaR95` visibility proxy.
- Missing sealed OOS streams, missing entry-time evidence, ambiguous dominant
  sessions, or invalid bindings produce `UNKNOWN` and fail closed.
- DXZ and FTMO dry-run builders now include the report, machine-readable
  `concentration_reject` rows, and eligibility gating after existing selection
  logic. The dual-book schema and validator reject absent/invalid evidence and
  prohibit eligibility under an unratified policy.
- The periodic portfolio report always publishes the concentration block and
  writes dated/latest Markdown panels in addition to JSON.
- `concentration_tail_limits.v1.json` reproduces the Claude-proposed caps:
  symbol 40%, asset class 60%, family 50%, session warning 60% / breach 70% of
  the 2.5% book stop-risk budget, and common-tail loss capped at 80% of the
  venue 5% daily-loss limit. These remain proposals, not OWNER-ratified limits.

## Recorded live-book observation (read-only)

Inputs were the recorded manifest
`D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` and
24 sealed OOS streams from
`D:\QM\reports\portfolio\dxz_final_20260719`. The report binds the manifest,
policy, symbol matrix, and EA registry by path, size, and SHA-256.

- Evaluation window: 2017-10-09 through 2025-12-30 (2,028 calendar rows).
- Recorded planned stop-risk sum retained: 9.7499%.
- Metals plus energy: 4.0134% stop risk, or 41.16349911% of recorded book risk.
- XAUUSD: 2.1156% stop risk, or 21.69868409% of recorded book risk.
- Historical daily VaR95 loss: 0.31186656%; D-Leverage-like visibility proxy:
  31.26305046 (explicitly not a provider metric).
- Common-tail result: K=8, 70 common-tail days, worst loss 0.56095653% versus
  the proposed 4.0% cap (`PASS`).
- Concentration result: `BREACH`, with 11 machine-readable rejects. Because the
  policy is also unratified, `builder_eligible=false` regardless of a clean
  result.

Durable outputs:

- `docs/ops/evidence/2026-08-22_sp_c3_live_book_concentration_report.json`
- `docs/ops/evidence/2026-08-22_sp_c3_live_book_concentration_panel.md`

A DXZ builder dry run against the same sealed stream bundle completed without
side effects and returned `CONCENTRATION_CAP_BREACH`; its inverse-vol proposal
showed 40.73236552% metals+energy and 21.63658066% XAUUSD, with 11 rejects.

## Focused verification

```text
python -m py_compile <five modified portfolio modules>
PASS

python -m pytest -q \
  tools/strategy_farm/tests/test_concentration_tail.py \
  tools/strategy_farm/tests/test_dual_book_builders.py \
  tools/strategy_farm/tests/test_portfolio_periodic_report.py
23 passed, 1 skipped in 0.88s

python -m json.tool tools/strategy_farm/config/concentration_tail_limits.v1.json
PASS

python -m json.tool tools/strategy_farm/config/dual_book_manifest.v1.schema.json
PASS

git diff --check -- <SP-C3 explicit pathspecs>
PASS (line-ending notices only)
```

The tests cover same-symbol rejection, cloned-family rejection, exact
three-day common-tail construction, missing-stream fail-closed behavior, a clean
four-sleeve ratified-policy fixture, the recorded 41%/21.7% visibility values,
and the rule that the proposed policy can never mint builder eligibility.

