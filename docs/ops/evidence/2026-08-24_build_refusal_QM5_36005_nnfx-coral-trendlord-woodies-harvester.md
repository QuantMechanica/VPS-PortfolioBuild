# Build refusal — QM5_36005 NNFX Coral/Trend Lord/Woodies Harvester

**Ticket:** `build-QM5_36005_nnfx-coral-trendlord-woodies-harvester`  
**Date:** 2026-08-24  
**Disposition:** `BUILD_REFUSED_CARD_UNBUILDABLE`  
**Approved-card SHA-256:** `82135900487c2231096ff8fbc256da43a18a8a28033bd51971cf2e6610c348c4`

## Decision

The approved card cannot be translated mechanically and exactly without inventing
strategy logic. The ticket explicitly requires a refusal when rules are contradictory
or missing, so no EA, setfile, registry, generated resolver, test, compile, queue,
router, factory, verdict, database, or `T_Live` state was changed.

The worktree already contains a tracked EA from an earlier build even though the ticket
says the EA does not exist. That source is not accepted as a resolution of the card gap:
it introduces proxy algorithms and parameters that the approved card never defines.

## Exact blocking gaps

1. **Trend Lord has no mechanical definition.** The card uses only
   `TrendLord: BarColor == Green/Red` and requires those colors for entry and runner
   exit (`D:/QM/strategy_farm/artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md:76`,
   `:90`, `:93`, `:98`). It specifies no period, price source, smoothing formula,
   threshold, or deterministic rule mapping values to GREEN/RED. The tracked EA invents
   an LWMA(50)-slope proxy (`framework/EAs/QM5_36005_nnfx-coral-trendlord-woodies-harvester/QM5_36005_nnfx-coral-trendlord-woodies-harvester.mq5:38`,
   `:162-163`, `:189-190`), and its SPEC explicitly says reviewer confirmation is
   required because the card provides no formula (`framework/EAs/QM5_36005_nnfx-coral-trendlord-woodies-harvester/SPEC.md:22`).

2. **Waddah Attar Explosion is under-specified.** The card declares only
   `InpWAESens=150` (`card:164`) and tests `WAE > ExplosionLine` (`card:90`, `:93`).
   It provides no WAE equation, MACD fast/slow/signal periods, Bollinger period or
   deviation, dead-zone rule, units, or directional comparison. The tracked EA invents
   MACD 12/26/9 and Bollinger 20/2.0 inputs (`mq5:40-44`) and defines WAE as absolute
   MACD delta times sensitivity against Bollinger width (`mq5:185-187`). Those choices
   are plausible conventions, but they are not card-authorized rules.

3. **The Coral formula is internally inconsistent.** The card states
   `SMMA(P, 20, coeff=0.4)` (`card:76`) and declares only the smoothing-period input
   (`card:162`). Standard SMMA has no `coeff` argument, the price series `P` is not
   identified, and the card does not say whether `coeff=0.4` instead selects a Coral/T3
   recursive filter. The tracked EA chooses `QM_SMMA(... PRICE_CLOSE)` and silently drops
   the 0.4 coefficient (`mq5:161`), so it cannot be called an exact implementation.

4. **The runner lifecycle contradicts the enumerated exit rules.** The state diagram
   requires an unspecified `Trailing Trigger` and `STATE_TRAILING_STOP` (`card:148-153`),
   while the exact exit section names only TP1, the hard SL, and Trend Lord color change
   (`card:96-98`). No trailing trigger, distance, step, ATR multiple, or precedence is
   supplied. Implementing or omitting trailing would each choose between incompatible
   card statements.

5. **The 3-tick slippage rule is not operationally defined.** The card requires a
   maximum of 3.0 ticks on market orders (`card:113`) but does not define whether a tick
   is `SYMBOL_TRADE_TICK_SIZE`, MT5 points, or allowed price deviation, nor how rejection
   is wired through the framework entry API. No declared card parameter resolves this.

## Deterministic preflight evidence

| Gate | Evidence | Result |
|---|---|---|
| Card identity | `g0_status: APPROVED`, `ea_id: QM5_36005`, matching slug and D1 symbols in the approved card | PASS |
| EA registry | `framework/registry/ea_id_registry.csv:4460` contains the active 36005 row | PASS |
| Magic registry | `framework/registry/magic_numbers.csv:17441-17443` contains active slots 0/1/2 for GBPJPY.DWX, EURJPY.DWX, AUDNZD.DWX | PASS |
| Active magic collisions | Read-only `Import-Csv ... | Group-Object magic | Where-Object Count -gt 1` returned `0`; the same check for `(ea_id,symbol_slot)` returned `0` | PASS |
| Resolver presence | Existing generated resolver contains each of `360050000`, `360050001`, and `360050002` exactly once | PASS |
| Exact card mechanics | Gaps 1–5 above | **FAIL** |

Because the failure occurs at the card-mechanics precondition, the governed directory →
CSV → resolver-regeneration → build → setfile path was not entered. Re-running
`update_magic_resolver.py`, `build_check.ps1`, `build_gate_hardening.py`, pytest, or a
compile would validate an invented proxy implementation rather than the approved card.
No tests or compile were therefore run for this refusal disposition.

## Required upstream amendment

Research/OWNER must issue a revised approved card that:

- gives the complete Trend Lord calculation, defaults, and GREEN/RED mapping;
- gives the complete WAE and ExplosionLine equations plus every fixed/default parameter;
- resolves Coral as either SMMA (dropping the coefficient) or a coefficient-bearing Coral
  recursive filter, and identifies the applied price;
- either removes trailing from the lifecycle or defines its trigger and stop algorithm; and
- defines the 3-tick slippage unit and the sanctioned framework wiring.

After re-approval, rebuild in place from the revised card and regenerate governed setfiles.

## Rollback

This commit adds only this evidence file. Roll back with:

```powershell
git revert <commit-sha>
```

No runtime or registry rollback is required.
