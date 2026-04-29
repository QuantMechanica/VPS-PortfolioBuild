# QUA-524 Owner Cap Request Stub (2026-04-29)

Purpose: unblock token-cost alarms by replacing placeholder caps with OWNER-approved provider limits.

Proposed child issue to OWNER:

- Title: `QUA-524 Child E - OWNER: decide provider token cap (monthly + daily guardrail)`
- Parent: `QUA-524`
- Priority: `high`
- Assignee: `OWNER`
- Requested decision:
  - Monthly provider cap (tokens) used for 70/80/95% alarm thresholds.
  - Optional daily guardrail override (tokens).
- Current placeholders in automation:
  - `MonthlyTokenCap=75000000`
  - `DailyTokenBudget=2500000`
- Required output from OWNER:
  - final numeric cap values
  - effective date for enforcement

Execution note: until OWNER sets values, alarms remain active with placeholder caps and payload field `cap_is_placeholder=true`.
