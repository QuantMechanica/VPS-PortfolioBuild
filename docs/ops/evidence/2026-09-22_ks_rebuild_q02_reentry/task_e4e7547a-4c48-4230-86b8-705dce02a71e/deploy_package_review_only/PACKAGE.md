# D2g6 governed kill-switch package — review only

This package is not deploy-authorized. It binds the six reviewed presets and
their current sleeve disposition for task
`e4e7547a-4c48-4230-86b8-705dce02a71e`. `authority.json`, `roster.json`, and
`sets/manifest.json` remain `install_authorized=false`.

| Sleeve | Status | Basis |
|---|---|---|
| QM5_13213 | EXACT | Existing verified `EQUIVALENT_EXACT` proof |
| QM5_10706 | BLOCKED | Selected ablation-02 Q02 was not enqueued: canonical `seed-fresh-q02` incorrectly treated the distinct base-control preset as the same terminal identity; own Q03-Q10 chain has not started |
| QM5_10700 | EXACT | Existing verified `EQUIVALENT_EXACT` proof |
| QM5_11422 | EXACT | Existing verified `EQUIVALENT_EXACT` proof |
| QM5_10403 | EXACT | New Q02 `5c12f7bb-a49f-4249-ba4e-3fa4d631d4fc`; verified proof SHA-256 `25d0ba875f0c3423033945fdbe06fbdaaabc947e93b833b1b223bfae36c5370a` |
| QM5_41219 | EXACT | Existing verified `EQUIVALENT_EXACT` proof |

The 10706 fix in this review changes the terminal-identity dedupe from EX5-only
to the already-governed EX5 + MQ5 + setfile tuple. It retains the exact-match
refusal and adds tests for both cases. It has not been run against the live
factory database because only integrated canonical controller code may mutate
that database.

Additional hard stops remain: the news-calendar correction task must close,
the canonical install dry-run previously reported AutoTrading enabled, and the
runtime marker plan has not run. Do not execute `demo_install.py --execute`,
start a terminal, toggle AutoTrading, or copy this package into an install
target.
