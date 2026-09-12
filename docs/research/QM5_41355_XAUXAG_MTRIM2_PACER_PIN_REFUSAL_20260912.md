# QM5_41355 XAU/XAG MTRIM2 — PACER Input-Pin Refusal

Date: 2026-09-12
Branch: `agents/board-advisor`

## Outcome

`QM5_41355_xauxag-mtrim2-rv` was selected as the highest-value unclaimed
low-frequency market-neutral build with a completed governed compile and no
Q02 row. The farm build task
`8c04e456-4522-4bd4-a289-4fe6a50577ef` was atomically claimed before any
queue action. The pre-claim database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41355_q02_intake_claim_20260912T031904Z.sqlite`

The mandatory framework-input pin audit then refused the build. No compile
work or Q02 work was enqueued, and no tester was launched.

## Mandatory Audit

Command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41355_xauxag-mtrim2-rv/QM5_41355_xauxag-mtrim2-rv.mq5"
```

Result: exit code `1`, `ok=false`, predicate
`EA_FRAMEWORK_INPUT_PINNED`, `hit_count=8`.

Exact findings:

```text
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:203 framework-owned input guard comparison 'qm_rng_seed =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:224 framework-owned input guard comparison 'qm_news_temporal =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:225 framework-owned input guard comparison 'qm_news_compliance =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:226 framework-owned input guard comparison 'qm_news_mode_legacy =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:227 framework-owned input guard comparison 'qm_news_stale_max_hours =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:228 framework-owned input guard comparison 'qm_news_min_impact =='.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:229 framework-owned input guard comparison '!qm_friday_close_enabled'.
EA_FRAMEWORK_INPUT_PINNED: C:\QM\repo\framework\EAs\QM5_41355_xauxag-mtrim2-rv\QM5_41355_xauxag-mtrim2-rv.mq5:229 framework-owned input guard comparison 'qm_friday_close_hour_broker =='.
```

The source also conflicts directly with the binding PACER contract at line
222 by requiring `RISK_FIXED == 1000` instead of only `RISK_FIXED > 0`, at
line 223 by pinning `PORTFOLIO_WEIGHT`, and at line 230 by requiring
`qm_stress_reject_probability == 0` instead of checking only finiteness and
the inclusive `0..1` range. These observations do not weaken or replace the
eight exact tool findings above.

## Safety Boundary

- No enqueue-compile command was issued after the audit refusal.
- No Q02 row was created.
- No backtest or terminal process was launched.
- `T_Live`, AutoTrading, the portfolio gate, and deploy manifests were not
  touched.
- The EA source and its existing binary were not modified.
