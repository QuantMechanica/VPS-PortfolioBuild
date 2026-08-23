# QM5_37004 build commission — Strategy Card contract blocker

- Task: `6d2369c0-a412-427e-afab-8c5feed10cc3`
- EA: `QM5_37004_volatility-targeted-momentum-kelly`
- Lane: Codex build
- Date: 2026-08-23
- Verdict: **BLOCKED_CARD_INCOMPLETE — no source or binary accepted**

## Decision

The approved Strategy Card is not mechanically complete enough to implement the
strategy named by the commission without inventing material signal and sizing
rules. The existing MQ5/EX5 therefore remain the previously reviewed,
non-conforming artifacts; this pass deliberately made no EA, setfile, registry,
or binary change.

This is a build-input blocker, not a pipeline verdict. No backtest, terminal,
AutoTrading, or live state was started or changed.

## Binding gaps

1. The sizing equation at approved-card line 76 uses
   `0.5 * (p - (1-p)/b)`, but neither `p` nor `b` is defined anywhere in the
   card or its parameter table. The performance claims at lines 64-66 cannot be
   silently promoted to sizing constants: the card's own G0 reasoning says its
   source PF/win-rate claims are ignored as unevidenced.
2. The thesis and SPEC call for “12-month exponential momentum,” but the card
   supplies no return transform, decay factor/half-life, normalization, or
   closed-form estimator. The current source instead uses the endpoint
   difference `Close[1] - Close[253]`; choosing an EMA, EWMA return sum, or
   exponentially weighted regression would produce materially different entry
   signals.
3. The volatility leg does not define whether the 20-day standard deviation is
   based on simple or log returns, sample or population variance, or how invalid
   and near-zero volatility is handled. The card also supplies no leverage cap,
   negative-Kelly behavior, or exact rule for reconciling its dynamic weight
   with the V5 `RISK_FIXED` backtest contract.

Required upstream remediation is an amended, OWNER-approved card that defines
those mechanics and invalid-data behavior explicitly. The build can then repair
the separately known loss-limit and management-order defects without guessing.

## Current artifact identity (inspection only)

- MQ5 SHA-256: `a79cd51d70b8ada686a08524c44de9603e3092df6a4c3c6f8e282a57485e2f60`
- EX5 SHA-256: `d46a00aeb2ac49268c66d3b0b98a570228c357f5eaf7003ea5b95ad3def3456a`
- Prior mandatory Codex review:
  `docs/ops/evidence/c344bb4a_qm5_37004_gemini_build_codex_review_2026-08-18.md`
- Prior review verdict: `CHANGES_REQUIRED`; it identified the absent
  volatility/Kelly model, endpoint momentum substitution, missing risk rails,
  and entry filters preceding open-position management.

These hashes are recorded only to identify what was inspected. They are not an
acceptance, rebuild, or evidence that the EX5 implements the approved card.

## Focused verification

Executed from `C:/QM/repo` on 2026-08-23:

| Check | Result |
|---|---|
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_37004_volatility-targeted-momentum-kelly` | **FAIL**: the approved 2.0% entry halt, 2.5% daily hard stop, and 5.0% total-drawdown stop are absent |
| `validate_build_guardrails.py` on MQ5 and all four sets | **PASS**: 336-hour news ceiling and fixed-risk preset guardrails remain intact |
| `validate_spec_doc.py` on the EA directory | **PASS** (document shape only) |
| Targeted git status on the EA directory | clean before and after this decision |

The static hardening failure confirms the existing implementation remains
unacceptable. Compilation was intentionally not requested because there is no
faithful source remediation to compile until the card contract is completed.
