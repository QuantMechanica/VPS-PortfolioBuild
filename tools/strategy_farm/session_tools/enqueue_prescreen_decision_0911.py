"""OWNER-DEC-PRESCREEN-OHLC-20260911 (chat 2026-09-11 ~16:5xZ): "T12 ist auch nutzbar, 1min Tests gehen auf allen
Terminals, hauptsache Zeitgewinn, aber natuerlich erfolgreiche EAs dann mit Real Tick Data verifizieren!"
Three tickets: T12 seat, fleet OHLC-M1 pre-screen cell class + real-tick promotion, DL-089 census amendment draft."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
DEC = ("OWNER-DEC-PRESCREEN-OHLC-20260911 (OWNER chat 2026-09-11 ~16:5xZ, verbatim: 'T12 ist auch nutzbar, 1min Tests gehen "
       "auf allen Terminals, hauptsache Zeitgewinn, aber natuerlich erfolgreiche EAs dann mit Real Tick Data verifizieren!'). "
       "Evidence basis: docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.csv (OHLC-M1 rho 0.95-0.98 vs real ticks, ~3.3x faster) and "
       "docs/ops/evidence/2026-09-11_prescreen_decision/PRESCREEN_PROTOCOL_DECISION_CARD_2026-09-11.md. Binding invariant: real-tick "
       "(Model 4) evidence remains the ONLY evidence class for verdicts, the counter and any book; OHLC-M1 cells are PRESCREEN evidence "
       "that may only order or shrink a candidate pool before real-tick confirmation.")
COMMON = {
    "requested_by": "Orchestrator Claude 2026-09-11 (executing " + DEC[:38] + ")",
    "owner_decision": DEC,
    "required_capabilities": ["code", "ops"],
    "hard_limits": [
        "Real-tick Model 4 stays the only evidence class for verdicts/counter/book; a PRESCREEN cell can never become MEASURED evidence or feed a verdict",
        "Every pre-screen program is declared (pre-registered keep fraction, control-sample fraction 10 pct of drops, suspension rule FN > 10 pct) before cells run; append-only; no change to existing MEASURED rows",
        "Never T_Live / FTMO terminal; worker code changes ship Default-OFF and are activated only by the orchestrator staggered reload; commit with explicit pathspecs; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a path",
    ],
}
T12 = dict(COMMON, model_tier="codex_high", codex_model_tier="terra", codex_reasoning_effort="high", **{
    "title": "T12 research seat: bring D:/QM/mt5/T12 to the same governed state as T11 (symbols.custom.dat from the signed source, private Custom history verified, research_canary.py --terminal T12 with /skipupdate, guards, receipts), prove it with the 2021 s3_l3 real-tick identity smoke (must equal net 2941.71 / PF 1.03 / 208 trades), then allow T11+T12 to run pilots concurrently (one run per seat)",
    "acceptance": ["T12 identity smoke identical to the fleet cell", "controller accepts --terminal T12 with per-seat isolation receipts", "two concurrent pilots (T11+T12) documented with CPU/RAM impact"],
    "evidence": ["docs/ops/evidence/2026-09-10_t11_launch_path.md", "tools/strategy_farm/research_canary.py", "D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_104039_6540e43e/receipt.json"],
})
FLEET = dict(COMMON, model_tier="codex_high", codex_model_tier="terra", codex_reasoning_effort="high", **{
    "title": "BUILD fleet OHLC-M1 pre-screen cell class: per-year OPT_CENSUS cells with Model=2 (1-minute OHLC) declared as PRESCREEN (verdict taxonomy PRESCREEN_MEASURED, never MEASURED), a governed promote step that enqueues real-tick Model 4 cells for the survivors (keep fraction from the declaration) plus a 10 pct random control sample of the dropped arms, and a report that tracks the false-negative estimate and suspends promotion when it exceeds 10 pct; first application = config_sweep/window_sweep programs, then DL-089 pattern census under its amendment",
    "spec": [
        "S1 Cell class: declaration field prescreen_model=2; setfile/tester.ini rendering identical except Model; summary/evidence schema marked evidence_class=PRESCREEN; claim path identical (priority_track, queue owner) so the fleet interleaves; the report must refuse to use PRESCREEN cells for any selection that the plan defines on real ticks",
        "S2 Promote: `promote --keep <fraction> --control 0.10 --apply` enqueues real-tick cells for the top keep-fraction by the program's declared score plus a seeded random 10 pct sample of the dropped arms (control), appends an amendment to the ledger with the ranking snapshot sha; idempotent",
        "S3 FN tracking: after control cells are MEASURED, compare real-tick rank of controls vs the pre-screen cut; running FNR; suspend flag in the ledger when > 10 pct; report table",
        "S4 Tests + a dry run on the stage-2 matrix declaration (config_sweep) as the first program; do not enqueue on production without the orchestrator (worker reload + apply are orchestrator steps)",
    ],
    "acceptance": ["prescreen cells enqueue/claim/measure through the normal worker (first real claim proven after the orchestrator reload)", "promote + control + FN report with tests", "PRESCREEN never appears as MEASURED anywhere (grep-able invariant + test)"],
    "evidence": ["tools/strategy_farm/config_sweep.py", "tools/strategy_farm/window_sweep.py", "tools/strategy_farm/opt_census.py", "docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.md"],
})
AMEND = dict(COMMON, codex_model_tier="astra", scalpel=True, model_tier="astra", codex_reasoning_effort="high", required_capabilities=["research", "code", "ops"], **{
    "title": "DL-089 census amendment draft for OWNER signature: OHLC-M1 pre-screen stage before the sealed real-tick census (keep fraction, 10 pct control sample of dropped arms, FN suspension at 10 pct, no change to the sealed selection rule which keeps operating on real-tick cells only), with the expected backlog reduction on the ~6,400 pending cells and the exact ledger/plan text changes",
    "spec": [
        "S1 Text: a Nachtrag to docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md in the style of the existing sealed amendments: scope, pre-registration fields, invariants (real-tick only for selection/verdicts), keep fraction recommendation from the pilot (start 70 pct, pilot FN 0-20 pct), control sample and suspension rule, rollback",
        "S2 Numbers: pending cells per program, cheap cells needed, real-tick cells saved, hours saved at fleet rate and with T11+T12, effect on the counter path (which programs reach Q14 sooner)",
        "S3 German OWNER card (15 lines) for Mission Control / Vault OWNER.md: what changes, what does not, the sentence the OWNER signs",
    ],
    "acceptance": ["Nachtrag draft file + numbers table + German card", "no launches, no rows"],
    "evidence": ["docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md", "docs/ops/evidence/2026-09-11_prescreen_decision/PRESCREEN_PROTOCOL_DECISION_CARD_2026-09-11.md", "docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.csv"],
})

if __name__ == "__main__":
    for key, prio, payload in (("T12", 88, T12), ("FLEET_PRESCREEN", 95, FLEET), ("DL089_AMEND", 90, AMEND)):
        for _ in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                                "--assigned-agent", "codex", "--payload-json", json.dumps(payload, ensure_ascii=False)],
                               capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                print("enqueue ok", key, json.loads(r.stdout)["task_id"][:8])
                break
            print("retry", key, r.stderr.strip()[-200:])
            time.sleep(8)
