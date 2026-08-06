# Crash-recovery wave 2 - Codex execution evidence

Date: 2026-08-06

Router task: `9887ebeb-af11-42f3-a306-97a441c134e3`

Verdict: `REVIEW_REQUIRED`. This task created pending evidence work only; it
does not assert a Q09, Q02, or pipeline result.

## Durable outcomes

- Q09 successor `2b792348-db4a-500f-a221-c26595ca3c83` reruns
  QM5_10440/NDX from predecessor `8f2a0a29...` and excludes T3.
- Q09 successor `2b74dd61-a521-53e9-8d31-1a4deb209338` reruns
  QM5_10939/GBPUSD from predecessor `debf9533...` and excludes T4.
- Q02 successors `681cb88b...`, `ed115d61...`, and `227c76b0...` requeue
  exactly QM5_20233, QM5_20234, and QM5_20235 from their recorded terminal
  INFRA_FAIL sources.

Both Q09 successors passed an independent 40/40 ordered identity comparison,
carry their original sealed anchors, are diagnostic non-admission rows, bind
fixed risk (`RISK_FIXED=1000`, `RISK_PERCENT=0`), and had zero rows in
`q09_news_tests` at the post-enqueue audit. Both were pending, unclaimed, and
`RUNNABLE_BOUND` at that audit.

QM5_10939 exposed mutable-source drift before enqueue: the sealed predecessor
requires EX5 SHA-256
`486b1690c74ce2ef07b9983b4e19eb4c3caf165b9369fcef7e31b9f00e07720b`,
while the current canonical build hashes
`812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`.
The successor uses an immutable copy recovered from the predecessor-recorded T3
staging path only after exact hash verification. No canonical EX5 was replaced.

The targeted sweep apply receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`27355d25002cc9fd7b590a4fb26ff0525b26dda402d6ad298f471d1c9f0da0eb`.
It records `apply=true`, three Q02 enqueues, zero skips, and the exact predecessor
row for every successor. Each successor carries the validated logical-basket
manifest with physical host `XAUUSD.DWX`; each setfile binds
`RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Verification

- Python compilation passed for the three changed tools.
- `test_q09_live_news_diagnostic.py`: 13 passed.
- `test_q09_news_runner_v2.py`: 24 passed.
- `test_sweep_enqueue_built_eas.py`: 4 passed.
- No T_Live or live-terminal state was changed and no active test was
  interrupted.
