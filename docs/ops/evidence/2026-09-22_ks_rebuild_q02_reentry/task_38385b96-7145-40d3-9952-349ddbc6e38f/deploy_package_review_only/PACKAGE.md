# D2g6 governed kill-switch package — review only

This package is not deploy-authorized. It exists to bind the current six EX5 hashes and governed presets for review. authority.json, roster.json, and sets/manifest.json all mark it REVIEW_ONLY_BLOCKED_IDENTITY / install_authorized=false.

Hard stops:

- 10706's selected ablation-02 predecessor lacks a source EX5 binding; its separate base-preset control is also NOT_EQUIVALENT (one deal-time mismatch).
- 10403 has no authenticated append-only Q02 successor.
- The canonical target dry-run refuses while AutoTrading is enabled.
- Runtime markers have not been collected.

Do not execute demo_install.py --execute from this package. A later OWNER-authorized package must be regenerated only after the identity/provenance stops are resolved, the news correction task is closed, the dry-run precondition is safely satisfied, and the runtime-proof plan can be executed without violating terminal controls.
