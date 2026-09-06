"""Execute the three YES receipts of 2026-09-06 06:16-06:17Z: M06 attestation record, M11 refutation addendum, M13 Codex tickets."""
import datetime
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path('C:/QM/repo')
NOW = datetime.datetime.now(datetime.timezone.utc).strftime('%H:%MZ')
CR, LF = chr(13), chr(10)
TR = '\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM\n'
SCRATCH = Path('C:/Users/ADMINI~1/AppData/Local/Temp/3/claude/C--QM-repo/bf445003-6640-4617-ac2f-e2e705bd7988/scratchpad')


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, cwd=REPO)


def commit(files, text):
    git('add', *files)
    msg = REPO / 'artifacts/_commit_msg_tmp.txt'
    msg.write_text(text + TR, encoding='utf-8')
    r = None
    for _ in range(5):
        r = git('commit', '-q', '-F', str(msg), *files)
        if r.returncode == 0:
            break
        time.sleep(5)
    msg.unlink(missing_ok=True)
    return git('rev-parse', '--short=10', 'HEAD').stdout.strip(), r.returncode


def run(args):
    rr = subprocess.run([sys.executable, 'tools/strategy_farm/agent_router.py', *args], capture_output=True, text=True, cwd=REPO)
    return (rr.stdout + rr.stderr)[-90:]


fd = json.load(open('D:/QM/reports/state/owner_decisions.json', encoding='utf-8-sig'))
items = {i['id']: i for i in fd['items']}

# --- M06 attestation record ------------------------------------------------
D = REPO / 'docs/ops/evidence/2026-09-05_m06_attest_current'
prop = (D / 'proposal/proposal.json').read_bytes()
obs = (D / 'observation.json').read_bytes()
it = items['OWNER-DEC-LIVE-IDENTITY-SIGN-20260905']
att = {
    "schema": "qm.live-identity-attestation/v1",
    "decision_id": "OWNER-DEC-LIVE-IDENTITY-SIGN-20260905",
    "decision": it.get('last_decision'),
    "decided_at_utc": it.get('last_decision_at_utc'),
    "receipt_id": it.get('last_receipt_id'),
    "receipt_sha256": it.get('last_receipt_sha256'),
    "proposal_path": "docs/ops/evidence/2026-09-05_m06_attest_current/proposal/proposal.json",
    "proposal_sha256": hashlib.sha256(prop).hexdigest(),
    "observation_sha256": hashlib.sha256(obs).hexdigest(),
    "attests": "The OWNER attests the unsigned attest-current proposal as the identity of the UNCHANGED running live book (24 sleeves, 21 binaries, total risk 9.7499 %, fingerprints identical to the frozen baseline).",
    "effects": "Documentation only: no code activation, no pointer write, risk freeze stays ACTIVE; the consumer exception stays flag-gated off until its own activation receipt.",
    "recorded_by": "Claude Orchestrator",
    "recorded_at_utc": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
}
(D / 'attestation.json').write_text(json.dumps(att, indent=2) + '\n', encoding='utf-8')
assert att['proposal_sha256'].startswith('20de8acd'), att['proposal_sha256']
sha1, rc1 = commit(['docs/ops/evidence/2026-09-05_m06_attest_current/attestation.json'], 'ops(m06): OWNER attestation receipt bound to the attest-current proposal (OWNER-DEC-LIVE-IDENTITY-SIGN-20260905 = YES; documentation only, freeze stays ACTIVE)')
print('m06 commit', sha1, rc1)
print(run(['update-task', '244ec170-0f42-5c73-8189-0727199155eb', '--state', 'REVIEW', '--artifact-path', 'docs/ops/evidence/2026-09-05_m06_attest_current/attestation.json', '--verdict', 'Decision executed (DOCUMENT_AND_VERIFY): attestation.json binds receipt ' + str(it.get('last_receipt_id')) + ' to proposal sha ' + att['proposal_sha256'][:16] + '... (observation ' + att['observation_sha256'][:12] + '...); no runtime file changed, freeze ACTIVE, consumer exception still off. Commit ' + sha1]))

# --- M11 refutation-rule addendum -------------------------------------------
it11 = items['OWNER-DEC-M11-CENSUS-BRANCH-20260906']
P = REPO / 'docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md'
raw = P.read_bytes()
crlf = (CR + LF).encode() in raw
s = raw.decode('utf-8').replace(CR + LF, LF).rstrip('\n')
add = (
    '\n\n## Addendum 2026-09-06 - pre-registered refutation rule for the mandatory optimisation branch (OWNER receipt '
    + str(it11.get('last_receipt_id')) + ', YES, ' + str(it11.get('last_decision_at_utc'))[:19] + 'Z)\n\n'
    'Decision OWNER-DEC-M11-CENSUS-BRANCH-20260906 (Option A): the DL-089 census continues unchanged in the Amendment C queue order; '
    'it is the counter path under OWNER-DEC-A1 (a KEEP_INCUMBENT closure counts like a promotion). The audit finding '
    '(12 Q14 closures, all KEEP_INCUMBENT, 0 CHALLENGER_PROMOTED as of 2026-09-06) is registered as a refutation rule, not a stop:\n\n'
    '- **Rule:** if the next **5** Q14 closures after 2026-09-06 06:17Z again promote no challenger (0 of 16 overall; '
    'rule-of-three upper bound on the promotion rate about 19 %), the *mandatory* optimisation branch is refuted for pairs beyond the 25-pair book.\n'
    '- **Consequence when refuted:** the branch becomes an on-demand cohort (Option B contract in '
    'docs/ops/OWNER_VORLAGE_2026-09-06_m11_optimisation_branch_utility.md, section 3) for pairs beyond 25, and the Q14-terminal '
    'requirement in the counting rule is put to the OWNER again as its own card. Nothing changes for the pairs inside the current census.\n'
    '- **Evaluation:** the Orchestrator counts Q14 closures (work_items phase Q14, status done) and reports the tally in OPEN_ITEMS at each closure; the rule fires on the fifth closure.\n'
    '- **Not changed by this addendum:** the selection rule (DL-089 #1/#2), K/L/G thresholds, declared_trial_count, the candidate pool, any verdict.\n'
)
P.write_bytes(((s + add).replace(LF, CR + LF) if crlf else (s + add)).encode('utf-8'))
sha2, rc2 = commit(['docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md'], 'docs(dl089): addendum - pre-registered refutation rule for the mandatory optimisation branch (OWNER-DEC-M11-CENSUS-BRANCH-20260906 = YES, Option A)')
print('m11 commit', sha2, rc2)


# --- M13 Codex tickets -------------------------------------------------------
def enq(prio, skills, payload):
    for _ in range(4):
        t = subprocess.run([sys.executable, 'tools/strategy_farm/agent_router.py', 'enqueue', 'ops_issue', '--priority', str(prio), '--skills', skills, '--payload-json', json.dumps(payload)], capture_output=True, text=True, cwd=REPO)
        t = t.stdout + t.stderr
        try:
            return json.loads(t[t.index('{'):]).get('task_id', '?')[:8]
        except Exception:  # noqa: BLE001
            time.sleep(2)
    return '?'


t1 = enq(76, 'ops,code', {
    "owner_context": "OWNER-DEC-M13-ECONOMIC-TRIAL-20260906 = YES (Option B capture-only FREE demo trial, USD 0, no purchase; receipt c575c17a). docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md section B lists the missing live-mode set-path generator: the FTMO trial needs ENV=live set files (RISK_PERCENT set, RISK_FIXED=0, FTMO rulepack constraints, QM news blackout binding) generated from the sealed FTMO candidate sets on the covered lanes (XAUUSD, GER40, GBPUSD, EURUSD, USDCAD, NZDUSD, XTIUSD, XAGUSD) - currently no on-disk tool produces them.",
    "commit_rules": "Implement on isolated branch agents/codex-ftmo-live-setpath-20260906: a governed generator (extend framework/scripts/gen_setfile.ps1 or a Python wrapper under tools/strategy_farm/ftmo/) that derives live-mode trial sets from the sealed candidate sets without changing any strategy parameter (only ENV/risk-mode/rulepack fields), writes them to a trial directory (never into framework/EAs active sets, never T_Live), records a manifest with sha256 per set and the source set sha, and refuses if the source set is unsealed or parameters differ from the sealed values. Tests. Dry-run on the 8 candidates; evidence docs/ops/evidence/2026-09-06_ftmo_live_setpath.md; REVIEW. INERT: nothing is installed into any terminal.",
    "codex_model_tier": "sol", "codex_reasoning_effort": "medium",
    "title": "FTMO M13 (Option B): live-mode trial set-path generator from sealed candidate sets (ENV=live, RISK_PERCENT, rulepack + news blackout), manifest + refusals, dry-run on the 8 candidates",
    "summary": "Generator + manifest + tests + dry-run evidence; nothing installed; REVIEW.",
    "acceptance": "8 trial sets generated in dry-run with parameter-identity proof vs sealed sets; refusals tested; REVIEW.",
})
t2 = enq(76, 'ops,code', {
    "owner_context": "OWNER-DEC-M13-ECONOMIC-TRIAL-20260906 = YES (Option B capture-only free demo trial). The telemetry collector pair QM_FTMO_TrialTelemetry.mq5 + tools/strategy_farm/ftmo_trial_telemetry.py was delivered (docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md sections B.2/B.7) but is not yet reviewed, accepted or installable. The trial needs a gap-free Europe/Prague-day-keyed M5 interval-minimum equity series with per-interval position/pending census (schema qm.ftmo-trial-telemetry.raw/v1), surviving terminal restarts and the Prague-midnight crossing.",
    "commit_rules": "Review and harden the collector on isolated branch agents/codex-ftmo-collector-acceptance-20260906: compile probe (governed compile lane, not active inventory), a tester-based acceptance run proving gap-free intervals across a simulated restart and a midnight crossing, the compaction script producing the daily jsonl + sha manifest, an installation plan for a dedicated NON-live terminal directory (never C:/QM/mt5/T_Live), and the OWNER-facing checklist. Tests. Evidence docs/ops/evidence/2026-09-06_ftmo_collector_acceptance.md; REVIEW. Nothing is installed yet.",
    "codex_model_tier": "sol", "codex_reasoning_effort": "medium",
    "title": "FTMO M13 (Option B): telemetry collector acceptance - compile probe, tester acceptance run (restart + Prague-midnight crossing), compaction + manifest, installation plan for a dedicated non-live terminal",
    "summary": "Acceptance evidence + hardening + install plan; nothing installed; REVIEW.",
    "acceptance": "Gap-free interval series proven in the tester across restart and midnight; compaction manifest verified; install plan names the non-live terminal directory; REVIEW.",
})
print('m13 tickets', t1, t2)
(SCRATCH / 'm13_tickets.json').write_text(json.dumps({"setpath": t1, "collector": t2}), encoding='utf-8')
