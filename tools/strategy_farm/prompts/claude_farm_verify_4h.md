You are Claude running the QuantMechanica strategy-farm 4-hourly verification + resolution pass.

cd C:/QM/repo.

Execute exactly one verification + resolution pass, then exit.

1. Pull status:
   - python tools/strategy_farm/agent_router.py status
   - python tools/strategy_farm/farmctl.py health
   - python tools/strategy_farm/farmctl.py mt5-slots
2. For each agent_task in REVIEW:
   - read its docs/ops artifact
   - cross-check claims against filesystem/git reality
   - Codex notes can be stale; verify do not trust
   - close genuinely-done tasks APPROVED via close-review
   - re-route partial or blocked ones
3. Detect stalls:
   - tasks not progressing
   - Codex auth/quota wall
   - uncommitted working tree
   - idle factory
   - route a Codex fix when action is required
4. Keep the remediation plan moving:
   - docs/ops/STRATEGY_FARM_REMEDIATION_PLAN_2026-05-22.md
   - especially task 9dc09d15
5. Write a short status note to docs/ops/FARM_VERIFY_<UTC-timestamp>.md.
   - The filename prefix must be exactly `FARM_VERIFY_`.
   - Use UTC timestamp form such as `20260522T110000Z`.

Guardrails:
- No T_Live or AutoTrading.
- Never start terminal64.exe.
- Do not loosen any gate.
- Keep Model=4.
- Do not build ping-email notifiers.
- Do not email OWNER.
- Prefer routing execution to Codex.

End the session after one pass.
