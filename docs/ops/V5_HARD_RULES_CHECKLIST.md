# V5 Hard Rules Checklist

Status: Canonical operational checklist for technical-side enforcement in QuantMechanica V5.
Owner: OWNER.
Last updated: 2026-04-27.

Use this checklist for EA specs, EA code reviews, framework changes, and pipeline operations.

## Checklist

- [ ] Model 4 Every Real Tick on all baseline backtests. Never Model 1/2.
- [ ] Every EA supports `RISK_FIXED` and `RISK_PERCENT` enum inputs.
- [ ] Fixed Risk `$1K` for backtest, Percent Risk for live (ENV-enforced via set-file header per [`framework/V5_FRAMEWORK_DESIGN.md`](/C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md)).
- [ ] `.DWX` symbol suffix in research/backtests; strip only at deploy packaging.
- [ ] Magic number schema: `ea_id * 10000 + symbol_slot`. Collision = hard abort, never silent overwrite.
- [ ] Enhancement Doctrine: exit-only modifications OK, entry-filter modifications kill trades. Never change both in one revision.
- [ ] Darwinex MT5 native data only; no external market APIs.
- [ ] 4-Module modularity per V5: No-Trade / Trade Entry / Trade Management / Trade Close.
- [ ] Friday Close enabled by default; per-EA disable allowed only when documented in Strategy Card.
- [ ] Gridding allowed with strict 1%-cap fallback.
- [ ] Scalping allowed only with mandatory P5b stress.
- [ ] Machine Learning forbidden in V5 (`build_check` enforces via import grep).
- [ ] No fantasy numbers: every claim cites a report/log/state entry.
- [ ] Stop digging: if a fix worsens outcomes, revert; do not double down.
- [ ] Material file deletion requires explicit OWNER authorization and verified targets.

## Enforcement Notes

- Source-of-truth governance remains OWNER-managed in `CLAUDE.md`, the process registry, and active runbooks.
- Worker instructions cannot override this checklist or introduce role-based approval gates.
- The EA-vs-Card review checklist remains separate and must be executed before Pipeline-Operator smoke testing.
