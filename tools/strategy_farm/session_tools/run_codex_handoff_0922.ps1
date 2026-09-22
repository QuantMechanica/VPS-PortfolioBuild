# OWNER-DEC-CODEX-ORCHESTRATION-20260922: use the existing governed lane with
# its supported worktree-root setting. C: hit 0.9 GiB free during slot creation.
# No provider, ownership, quota, task, or review gate is bypassed here.
$ErrorActionPreference = 'Stop'
$env:QM_AGENT_WORKTREE_ROOT = 'D:\QM\agent_worktrees'
Set-Location -LiteralPath 'C:\QM\repo'
$handoffRunLog = 'D:\QM\strategy_farm\logs\codex_handoff_dispatch_' + (Get-Date -Format 'yyyyMMddTHHmmss') + '.log'
$handoffProcess = Start-Process -FilePath 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe' -ArgumentList '"C:\QM\repo\tools\strategy_farm\run_agent_orchestration_task.py" --agent codex --max-sessions 3' -WorkingDirectory 'C:\QM\repo' -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $handoffRunLog -RedirectStandardError ($handoffRunLog + '.err')
exit $handoffProcess.ExitCode
