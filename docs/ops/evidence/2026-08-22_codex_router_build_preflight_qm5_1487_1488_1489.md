# Codex router build preflight — QM5_1487, QM5_1488, QM5_1489

Date: 2026-08-22  
Role: Development / Codex  
Scope: scheduled single-pass router cycle; three `build_ea` tasks at numeric priority 50  
Verdict: `PREBUILD_BLOCK_IDENTITY_OR_CARD_CONTRACT`

## Outcome

None of the three routed tasks can enter mechanical implementation:

- QM5_1487 has an EA-ID identity collision: active registry ID 1487 belongs to `as-kda-defensive`, not routed/card slug `raschke-3-10-oscillator-cross-h4`, and no magic rows exist.
- QM5_1488 has matching ID/magic allocations, but its card declares `card_body_incomplete: true`, says exact four-pod constituents are not exposed, requires Development to freeze them from an approved implementation before P1, and records R2/R3 as `UNKNOWN` in the body. Selecting pod pairs would be unauthorized strategy authorship.
- QM5_1489 has matching ID/magic allocations, but its fixed permanent-portfolio mechanics require TLT and BIL sleeves. Neither an approved TLT/Treasury symbol nor BIL/cash-proxy series is present in the registered universe or canonical symbol matrix. Omitting or replacing the 25% Treasury sleeve would change the approved portfolio.

## Routed cohort and focused verification

| Router task | EA | Card SHA-256 | Identity / magic | Card implementation gate | Existing artifact state | Result |
|---|---|---|---|---|---|---|
| `e534be5a-0fe5-4935-9e6f-bd8b44d8f499` | `QM5_1487_raschke-3-10-oscillator-cross-h4` | `5928da91af33872d6d1c77e06a842da6ffa91b850f589dd8ed8b23b07780ffe2` | ID 1487 belongs to `as-kda-defensive`; 0 magic rows | exact approved card is price-testable, but identity is unavailable | tracked TODO skeleton SHA-256 `27c5c724ebd5d3879d1a4c70147d62e6561f661deccb842fa0b122728b3f17f3`; 0 EX5 / 0 SPEC / 0 sets | identity conflict |
| `6c86e8b0-9336-463a-820c-8bb2cc0fa524` | `QM5_1488_as-ddm-pods` | `723864c5d41f1f79800ddd8855be500e210b35ae24eed6b72049a2ad909c8a43` | exact active ID; 13 active generic DWX rows | card incomplete; exact four pod pairs absent; body R2/R3 `UNKNOWN`; bond/international sleeves unresolved | tracked TODO skeleton SHA-256 `34691127445bc890e7f1dbd7bdde38a2bd4c7b58af9ac3e9609c65ea59286a94`; 0 EX5 / 0 SPEC / 13 pre-existing sets | card-contract block |
| `eb71678d-c6d3-4550-998a-29eb5cbba9c1` | `QM5_1489_as-permanent-tactical` | `43a4741ecc846b5dbf951fe94199fceb7f1fa82f5b6dff809add3c3147c747b7` | exact active ID; 13 active generic DWX rows | fixed TLT and BIL sleeves lack approved data/proxies; body R3 `UNKNOWN` | tracked TODO skeleton SHA-256 `fd3705d27e5cb4eee92c4e5053dca71ead56b88c30f2e725dad63a178224e65b`; 0 EX5 / 0 SPEC / 13 pre-existing sets | data-contract block |

For QM5_1488 and QM5_1489, the 13 magic rows cover indices, FX, and gold. Registration is not evidence that the missing pod definitions or bond/cash sleeves have been authorized. The generic pre-existing setfiles were not treated as Strategy Card completion evidence.

## Deterministic boundary

The build skill requires exact card/registry/directory identity and permits only card-authorized mechanical logic. It does not authorize registry rekeying, selecting undisclosed asset pairs, or inventing proxy substitutions. Therefore no source edit, build check, compile, setfile generation, smoke, or pipeline phase was run. These are precondition failures, not compile or pipeline verdicts.

No registry, resolver, news seed, terminal, `T_Live`, or AutoTrading state was changed.

## Required upstream remediation

1. OWNER-adjudicate/rekey the QM5_1487 collision and allocate matching magic rows before fresh routing.
2. Research/OWNER must freeze and approve every QM5_1488 pod constituent and explicit DWX/custom-symbol mapping, normalize the incomplete/R2/R3 fields, then reroute.
3. Research/OWNER must approve and validate TLT/Treasury and BIL/cash representations for QM5_1489, or approve a mechanically revised card, then reroute.

Pre-existing generic allocations alone do not close any of these gates.
