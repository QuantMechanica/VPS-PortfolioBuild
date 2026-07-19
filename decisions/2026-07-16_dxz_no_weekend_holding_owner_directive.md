# DXZ / Prop-Compatible No-Weekend-Holding OWNER Directive — 2026-07-16

Status: **OWNER_DIRECTIVE_RECORDED_UNSEALED**  
Runtime effect: **NONE** — documentation and future qualification contract only

## Decision

The OWNER explicitly requires no weekend position exposure for the current
DarwinexZero repair cohort and the intended prop-firm-compatible variants.
The selected execution semantics are:

- `FRIDAY_CLOSE_ENABLED=true`;
- latest normal framework safety cutoff: broker hour `21`; an explicit Card or
  strategy exit may close earlier (for example the 10706 weekly exit);
- on holidays or early-close sessions, the effective cutoff is the earlier of
  the applicable earlier Card/strategy cutoff, broker hour `21`, and the final
  tradable session before the weekend, as bound by the qualification calendar;
- all positions must be flat before the weekend market closure;
- no strategy entry, pending order or other mechanism may recreate weekend
  exposure after the Friday close gate.

This resolves the substantive Friday choice for `10706:GBPUSD.DWX H1`,
`10939:GBPUSD.DWX H4` and `12567:XAUUSD.DWX D1`. It does not approve their
remaining Card, risk, news, source/binary, data, identity or cost gates.

## Rationale

The OWNER's stated purpose is to avoid weekend-gap risk and retain portability
to prop-firm account types that prohibit weekend holdings. This is an internal
risk policy and remains binding even where a particular evaluation or account
type would permit weekend positions.

FTMO's current published rule is narrower than a universal prohibition:
weekend restrictions apply to funded Standard accounts, not to the Evaluation
Process or Swing accounts. The stricter QuantMechanica policy is therefore a
deliberate portability/risk choice, not a claim that every prop programme has
the same rule:
<https://ftmo.com/en/faq/do-i-have-to-close-my-positions-overnight-or-before-the-weekend/>.

## Evidence and sealing consequence

Source of directive: OWNER statement in the active QuantMechanica session on
2026-07-16: Friday close exists to avoid weekend gaps and prepare for prop firms
where weekend holdings are not allowed.

This Markdown record is not a cryptographic OWNER signature. Each qualifying
bundle must still bind the exact directive through the packet's external
OWNER trust mechanism and a signed/hash-pinned receipt. Until then the state is
`OWNER_DIRECTIVE_RECORDED_UNSEALED`, never qualification `PASS`.

No Card, EA, preset, MT5 terminal, order, risk setting, deployment or
AutoTrading state was changed when recording this decision.
