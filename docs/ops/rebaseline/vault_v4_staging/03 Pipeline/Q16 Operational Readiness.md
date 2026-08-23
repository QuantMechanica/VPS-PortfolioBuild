# Q16 — Operational Readiness

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q16 |
| **Makrophase** | 3 · Strategie wird zum Buch bewertet |
| **v3-Herkunft** | Q12 — „Operational Readiness" |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q15 Final Portfolio Construction]] · → [[Q17 Live Burn-In DXZ]] |

**Herkunft:** v4 Q16 = v3 Q12 (Operational Readiness), 11-Punkte-Checkliste unverändert (ROT).

> **Lese-Hinweis:** Der Fließtext nennt das Folgegate „Q13" und die Risk-Allokation „Q11".
> v4-Entsprechung: Folgegate = **Q17 Live Burn-In DXZ**, Risk-Allokation aus **Q15**. Mapping:
> [[Gate Manifest v4 Diff]].

---

**Gate Owner:** OWNER
**Successor:** [[Q17 Live Burn-In DXZ]]
**Spec version:** 2026-05-23 (post-rewrite — was Q13 in previous spec)

---

## Purpose

Q12 is the technical pre-flight checklist before the EA is allowed anywhere near the T_Live terminal. Every check must PASS — no skipped checks, no exceptions.

If any check fails, Q13 deployment is blocked until the failure is fixed and the full checklist re-run.

---

## Hard Gate Checklist (all must PASS)

| # | Check | Owner | Evidence |
|---|---|---|---|
| 1 | EA `.ex5` compiles cleanly on T_Live (fresh compile, not a copy from factory) | Codex | Compile log |
| 2 | Deploy manifest created | Codex | `decisions/deploy/QM5_<NNNN>_<symbol>_<date>.yaml` |
| 3 | **Deploy manifest signed by OWNER** | **OWNER** | OWNER signature in manifest |
| 4 | Risk parameters set to RISK_PERCENT (per Q11 allocation), min-lot enforced for burn-in | Codex | Setfile screenshot |
| 5 | Q09 news mode correctly configured | Codex | Setfile screenshot |
| 6 | Commission / swap matches DXZ Live broker schedule in T_Live tester | Codex | Tester groups file (`MQL5/Profiles/Tester/Groups/<server>_<account>.txt`) |
| 7 | DST timezone correct on T_Live (GMT+2 outside US DST, GMT+3 during) | Codex | Terminal screenshot |
| 8 | Kill-switch threshold defined and tested | Codex | In manifest |
| 9 | Symbol routing: backtest symbol (.DWX suffix) maps to live broker symbol correctly | Codex | Routing check log |
| 10 | Magic number registered and unique for live (formula: `ea_id * 10000 + slot`) | Codex | Magic numbers registry |
| 11 | SHA256 of `.ex5` matches between factory and T_Live | Claude | Hash comparison |

**11 checks. All must be GREEN.** Q13 deployment is blocked until every box is ticked.

---

## Deploy Manifest Schema

```yaml
ea: QM5_<NNNN>_<slug>
git_commit: <hash>
sha256_ex5: <hash>
symbol: <SYMBOL.DWX>
live_symbol: <BROKER_SYMBOL>           # the symbol name on DXZ Live (may differ from .DWX suffix)
period: H1
magic_number: <int>
news_mode: <0-6>                        # Q09 chosen mode
risk_mode: RISK_PERCENT                 # live; backtest used RISK_FIXED
risk_percent: <X.XX>                    # from Q11 allocation
burn_in_lot: 0.01                       # min-lot for 14d burn-in
max_drawdown_alert_pct: <Y>
kill_switch_threshold_pct: <Z>
news_calendar_path: D:/QM/data/news_calendar/<seed-file>
news_calendar_max_age_hours: 336        # 14d staleness bound
deploy_date: YYYY-MM-DD
owner_signature: OWNER
claude_verification_signature: Claude
```

**Without OWNER signature AND Claude verification: no AutoTrading.** This is the Hard Rule.

---

## Verification by Claude (Hard Rule)

Per CLAUDE.md, Claude must verify before T_Live AutoTrading is enabled:
1. SHA256 of `.ex5` matches across factory → T_Live
2. Magic number formula consistent (`ea_id * 10000 + slot`)
3. Setfile ENV = `live` and `RISK_FIXED = 0`, `RISK_PERCENT` set
4. News calendar present and current (age < 14 days)

Claude records the verification under `decisions/YYYY-MM-DD_t_live_<ea>_<symbol>.md`.

---

## After Q12 PASS

- All checks green, manifest signed, ready for Q13 (v4: **Q17 Live Burn-In DXZ**).
- **OWNER alone** enables AutoTrading on T_Live for this EA (Hard Rule — no AI seat toggles AutoTrading).

## After Q12 FAIL

- Specific failed check is logged.
- Fix the underlying issue.
- Re-run the full checklist (no partial re-run — all 11 checks repeat).
