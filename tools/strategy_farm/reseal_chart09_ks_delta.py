"""Re-seal the DXZ V2 reference profile with the OWNER-signed KS-deploy delta.

WHY THIS EXISTS (2026-08-13)
----------------------------
The T_Live recovery chain has been broken since the 2026-08-12 23:44 Windows
Update reboot: T_Live_ON.ps1 aborts with `profile_contract_failed` on every
boot (live_launcher_events.jsonl, 3 consecutive boots), so T_Live only comes
back by hand while FTMO_ON succeeds.

Root cause, fully evidenced: the OWNER-signed kill-switch deploy of 2026-08-02
(decisions/2026-08-02_t_live_ks_recompile_deploy.md:37) added the input
`qm_risk_cap_pct=1.0` to QM5_10911 (chart09). MT5 flushed that input into the
operational profile's chart09.chr at the next shutdown -- which was the 08-12
WU reboot. The sealed reference profile was never re-sealed after the deploy,
so the verifier now sees `operational contract drift: chart09.chr/expert` and
fails closed. The LIVE profile is correct; the REFERENCE is stale.

Diff proven minimal before writing this script: exactly 1 of 24 charts drifts,
by exactly one line, matching the signed decision record word for word.

WHAT IT DOES (idempotent, single OWNER command)
-----------------------------------------------
1. backs up the sealed chart09.chr
2. inserts the one signed line into its <expert> block (byte-minimal patch)
3. updates $sealedSha256['chart09.chr'] in prepare_dxz_v2_liveops_profile.ps1
4. runs the verifier -VerifyOnly and reports its exit code -- success is 0

It touches nothing else: no other chart, no operational profile file, no
terminal process, no AutoTrading.

ROLLBACK
--------
Restore D:\QM\reports\state\task_backups\20260813_uptime\sealed_chart09_before.chr
over the sealed chart09.chr and revert the repo commit that updated the hash.
"""
from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from tools.strategy_farm import risk_freeze
except ModuleNotFoundError:  # direct script execution
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from tools.strategy_farm import risk_freeze

SEALED = Path(r'C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2\chart09.chr')
BK_DIR = Path(r'D:\QM\reports\state\task_backups\20260813_uptime')
BK = BK_DIR / 'sealed_chart09_before.chr'
VERIFIER = Path(r'C:\QM\repo\tools\strategy_farm\prepare_dxz_v2_liveops_profile.ps1')
PS51 = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

NEEDLE = 'PORTFOLIO_WEIGHT=1.0\r\n'
INSERT = 'qm_risk_cap_pct=1.0\r\n'


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def main() -> int:
    risk_freeze.assert_live_book_mutation_allowed(
        "re-seal a T_Live DXZ chart contract",
    )
    raw = SEALED.read_bytes()
    txt = raw.decode('utf-16-le')  # strict: abort loudly on any encoding surprise
    before = sha256(raw)
    print(f'sealed chart09 sha_before = {before}')

    if 'qm_risk_cap_pct' in txt:
        print('sealed file already carries the KS delta -- nothing to patch')
        after = before
    else:
        count = txt.count(NEEDLE)
        if count != 1:
            print(f'REFUSING: needle occurs {count}x, patch would be ambiguous')
            return 2
        BK_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SEALED, BK)
        print(f'backup written: {BK}')
        patched = (txt.replace(NEEDLE, NEEDLE + INSERT)).encode('utf-16-le')
        SEALED.write_bytes(patched)
        after = sha256(patched)
        print(f'sealed chart09 sha_after  = {after}')

    # Update the verifier's pinned hash for chart09.
    vtxt = VERIFIER.read_text(encoding='utf-8')
    pattern = r"('chart09\.chr'\s*=\s*')([0-9A-F]{64})(')"
    m = re.search(pattern, vtxt)
    if not m:
        print('REFUSING: chart09 hash entry not found in verifier')
        return 2
    if m.group(2) == after:
        print('verifier hash already current')
    else:
        vtxt = re.sub(pattern, lambda mm: mm.group(1) + after + mm.group(3), vtxt, count=1)
        VERIFIER.write_text(vtxt, encoding='utf-8')
        print(f'verifier table updated: chart09 {m.group(2)[:12]}... -> {after[:12]}...')

    # Prove the chain: the verifier must now pass in recovery mode.
    # Drop PSModulePath from the child env: when this script is invoked from a
    # Git-Bash `!` chain, an inherited PSModulePath can hide the PS5.1 module
    # dirs and Get-FileHash stops resolving (observed 2026-08-13). With the
    # variable absent, PowerShell 5.1 reconstructs its own default path.
    child_env = {k: v for k, v in __import__('os').environ.items()
                 if k.upper() != 'PSMODULEPATH'}
    proc = subprocess.run(
        [PS51, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
         '-File', str(VERIFIER), '-VerifyOnly'],
        capture_output=True, text=True, timeout=120, env=child_env)
    print(proc.stdout.strip())
    if proc.stderr.strip():
        print(proc.stderr.strip())
    print(f'verifier -VerifyOnly exit code = {proc.returncode}')
    return 0 if proc.returncode == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
