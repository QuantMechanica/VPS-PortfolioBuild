# QUA-914 Video Analysis — UIdH5Ac1Db8 (2026-05-08)

Source transcript:
- `docs/ops/youtube-transcripts/UIdH5Ac1Db8/transcript_UIdH5Ac1Db8.txt`

## Strategy Ideas (Paperclip Ops)

1. **Cadence-tiered agent architecture**
   - Classify agents into cadence buckets (`5m`, `hourly`, `daily`, `manual-only`) instead of uniform timers.
   - Default low-value or infrequent workflows to manual/daily.

2. **Model-tier routing by task class**
   - Reserve top-tier models for synthesis/decision roles.
   - Use cheaper/local models for repetitive collection/scanning jobs.

3. **Two-stage pipeline pattern**
   - Stage A: low-cost collector agent writes structured summaries/files.
   - Stage B: higher-cost chief/synthesizer reads staged data once per cycle.

4. **Instruction/skill minimization**
   - Keep each agent’s instruction + skill bundle narrowly scoped.
   - Avoid broad skill packs that inflate recurring token-in cost per run.

5. **Budget guardrails with fail-safe stop**
   - Enforce per-agent budget ceilings.
   - Stop execution automatically when threshold reached.

## Token-Efficiency Insights

1. **Run frequency is first-order cost driver**
   - Frequent heartbeat on many agents dominates spend quickly.

2. **Token-in overhead is persistent tax**
   - Every run re-sends instructions/skills/context; large prompts compound cost.

3. **Cache-token awareness**
   - Cached context still costs, but typically cheaper than fresh tokens.
   - Budgeting should track token classes, not only aggregate count.

4. **Subscription observability gap risk**
   - UI cost may under-report on subscription-backed runs.
   - Need independent cost inference path (token counts × model pricing).

5. **Cost control order of operations**
   - Reduce cadence -> reduce instruction size -> downgrade model where safe.
   - This sequence preserves quality while cutting spend.

## Immediate QuantMechanica Follow-ups

1. Add an explicit **agent cadence matrix** to ops docs (`manual/daily/hourly/fast-loop`) with owner-approved defaults.
2. Add **prompt-size budget checks** (max instruction/skill length by role class).
3. Extend token observability to always emit **inferred cost snapshots** even when provider billing is opaque.
4. Route low-complexity monitoring/collection jobs to lower-cost adapters where available.

## Boundary Note

- Analysis is operational/process-focused; no EA strategy-code changes performed.
