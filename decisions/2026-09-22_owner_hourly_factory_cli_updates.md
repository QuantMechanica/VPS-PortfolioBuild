# OWNER: hourly Factory inspections and updates in this CLI chat

Date: 2026-09-22. Authority: explicit instructions in Codex thread
`01a0c58a-454a-76d3-998d-a26f15f34610`.

OWNER requested: "in einem stündlichen Job musst du das alles immer prüfen und mir
ein Update dazu geben!" Delivery clarified: "Automatische Nachrichten in diesem
CLI-Chat".

Implemented as `QM_Codex_FactoryChat_Hourly`: every hour queues a bounded Factory
inspection into this exact existing thread. The current Codex orchestrator checks
fresh evidence, performs already-authorized reversible follow-through and replies
in German here. No email channel was enabled. Existing Factory/AI pause flags,
review gates, quota limits and live-trading boundaries remain binding.

This standing hourly instruction does not extend the temporary 2026-09-22 burn
authorization or unpause Fable. The job does not spawn a second orchestrator.
Machine/login and thread availability are required for timely execution; pending
reminders are coalesced instead of accumulating an offline backlog.

Implementation, exact schedule, tests and live queue receipts:
`docs/ops/CODEX_FACTORY_CHAT_HOURLY_2026-09-22.md`.
