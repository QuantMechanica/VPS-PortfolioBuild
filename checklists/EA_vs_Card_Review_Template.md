# EA-vs-Card Review Template (CTO)

Purpose: reusable pre-smoke review checklist for every Development EA against its approved Strategy Card.

Use this template before Pipeline-Operator runs P1 smoke.
Fail any unchecked mandatory item with explicit line-cited findings and return to Development.

## Review Metadata

```yaml
issue_id: QUA-XXX
review_date: YYYY-MM-DD
reviewer_agent: CTO
strategy_card_path: /abs/or/repo/path/to/card.md
ea_path: /abs/or/repo/path/to/ea.mq5
ea_id: 0000
symbol: EURUSD.DWX
timeframe: H1
decision: APPROVE | REJECT
```

## Source Evidence

- Strategy Card citation anchors:
  - Entry section lines: `L__-L__`
  - Exit section lines: `L__-L__`
  - Filters section lines: `L__-L__`
  - Management section lines: `L__-L__`
- EA code citation anchors:
  - Entry module lines: `L__-L__`
  - Exit module lines: `L__-L__`
  - No-Trade module lines: `L__-L__`
  - Management module lines: `L__-L__`

## Mandatory Checklist (Hard Gate)

- [ ] Entry rules match card exactly (line-cited card + code evidence)
- [ ] Exit rules match card exactly (line-cited card + code evidence)
- [ ] Filters match card exactly (line-cited card + code evidence)
- [ ] Magic number assigned, registered, unique (`magic = ea_id * 10000 + symbol_slot`; collision check documented)
- [ ] `RISK_FIXED` and `RISK_PERCENT` inputs both present
- [ ] Friday Close hook present and default enabled (`friday_close_enabled = true` unless card documents exception)
- [ ] 4-module separation respected:
  - [ ] No-Trade module
  - [ ] Trade Entry module
  - [ ] Trade Management module
  - [ ] Trade Close module
- [ ] No hardcoded symbols (symbol passed as parameter/input; no literal tradable symbol constants)
- [ ] No external API calls (Darwinex MT5 native data only)
- [ ] No ML imports/usages (`tensorflow`, `torch`, `sklearn`, `keras`, `onnx`, or equivalent)
- [ ] Compile check clean: `0 errors, 0 warnings`

If any item above is unchecked, set `decision: REJECT`.

## V5 Hard Rules Conformance (CTO Guardrail Pass)

- [ ] Model 4 Every Real Tick requirement preserved for baseline backtests (no Model 1/2 allowance in this EA workflow)
- [ ] `.DWX` suffix convention preserved in research/backtest artifacts; no premature stripping in EA logic
- [ ] Enhancement Doctrine status recorded for this revision:
  - [ ] Exit-only modification (allowed without full invalidation)
  - [ ] Entry/filter modification (pipeline invalidation required)
  - [ ] Both changed in one revision (hard reject)
- [ ] Gridding behavior (if present) documents strict 1% cap fallback
- [ ] Scalping behavior (if present) flags mandatory P5b stress requirement

## Scale-Invariance Check (Run Only For Systemic Re-run Requests)

Fill this section before approving any re-run of a historic sweep caused by systemic code changes.

1. Change class:
   - [ ] Lot-size logic
   - [ ] Commission model
   - [ ] Spread/slippage model
   - [ ] Other systemic change: `...`
2. Metrics affected (explicit list): `...`
3. Gate impact analysis:
   - [ ] Affected metrics are used by target gate decision
   - [ ] Affected metrics are not used by target gate decision
4. Re-run decision:
   - [ ] Re-run required
   - [ ] Re-run not required (memo linked)
5. Evidence links:
   - Report/log/state references: `...`

Rule: if no affected metric changes a gate decision, do not re-run.

## Findings (Required if REJECT)

List findings ordered by severity. Every finding must cite file + line and violated rule.

```text
1) [severity] path/file.mq5:L123 - violation summary - rule reference
2) [severity] path/file.mq5:L456 - violation summary - rule reference
```

## Decision Summary

```markdown
Status: APPROVE | REJECT

- Result:
- Rationale:
- Next action owner:
- Next action:
- Evidence links (reports/logs/state):
```

