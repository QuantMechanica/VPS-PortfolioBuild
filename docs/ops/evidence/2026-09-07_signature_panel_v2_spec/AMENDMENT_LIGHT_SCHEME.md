# Signature Panel v2 light-scheme amendment

- Router task: `c4ae19ed-aa92-440e-b4f3-4ac0249d5879`
- Parent implementation task: `b020c337-ee9f-47f2-9c33-f6cf0ab4afea`
- OWNER instruction: `2026-09-07T05:52:00Z` (light / "hell")
- Disposition: duplicate folded into the still-open parent task

The parent Signature Panel v2 implementation task is still `IN_PROGRESS`. This amendment is therefore not a separate implementation stream. The following requirements are incorporated into that parent task and are authoritative over the earlier dark-v2 colour suggestion:

- MT5 chart base: Color on White / white background.
- Foreground and axis text: dark slate, `#0F172A`.
- Grid: disabled by default; if enabled by a future explicit option, it must be subtle and light.
- Bull candles: emerald on white with sufficient contrast.
- Bear candles: red on white with sufficient contrast.
- Bid/ask lines: QuantMechanica steel blue, `#2954D4`.
- Panel card: light surface such as `#F8FAFC`, dark slate text, steel-blue identity rail, and emerald/amber/red state accents with readable contrast.
- The existing opt-out, previous-scheme restoration, timer-driven rendering, tester-inert behavior, legacy-overlay suppression, artifact-only QM5_11421 canary build, demo-only install, receipt, and no-trading-logic-change constraints remain unchanged.

No code, terminal, preset, or live state was changed under this duplicate amendment. Its acceptance criterion is that the parent task's implementation and evidence use this light scheme.
