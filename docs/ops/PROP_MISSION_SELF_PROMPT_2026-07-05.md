# Prop Mission — Claude self-prompt (OWNER directive 2026-07-05)

**OWNER (chat, 2026-07-05): "You know my goal! Winning prop firm challenges and make
money! Prompt yourself to get there!"**

This document is the standing operating prompt Claude executes against until OWNER
amends it. Reports in English; OWNER chat in German. Evidence over claims — every
gate closes on a file path, never on narrative.

## The two money engines

1. **Prop track (FTMO first):** pass challenges → funded account → payouts.
   Vehicle: Round25 12-leg book, Two-Speed (P1 @9.0, P2 @6.0–7.0), realistic
   ~85–90% pass time-unbound, ~25–30% chance of a ≤30d Phase 1
   (ROUND25_FTMO_RECOMPOSITION_PACKAGE_2026-07-04 + horizon update f9dfec572).
2. **DXZ track:** 15-sleeve S3 book live (Sharpe 2.03 / MaxDD 4.8% composite basis);
   VaR-filled → grows ONLY via orthogonal sleeves (BOOK_GAP_SCAN_2026-07-05).

## Gates (measurable; Claude drives, OWNER holds the money decisions)

### G1 — Trial plumbing verification (target: ≤ 2026-07-12)
Trial (acct 1513845506, USD 100k, live since 2026-07-05) is a dress rehearsal, NOT a
pass attempt. Trial-pass (5% in 14d) is a free-roll bonus. G1 closes when ALL hold:
- [x] Server-time offset empirically verified at first tick — UTC+3 exactly
      (2026-07-06 00:05 broker = 21:05Z; decision record has the log evidence)
- [ ] ≥5 trading days with `ftmo_trial_pulse` verdict OK (no EA errors, 12/12 magics,
      terminal uptime through the daily FTMO server maintenance window)
- [~] ≥1 fill per: index (.cash), metal, FX leg class — sizing sane vs RISK_FIXED
      table. **First fills 2026-07-06 01:05 broker: 10286 USOIL.cash SELL 1.15
      lots (risk 4.501×100×1.15 = $517.6 ≈ RISK_FIXED 518 ✓ EXACT) + 12475
      US100.cash BUY 3.20 lots (101.55×3.2 = $325.0 = RISK_FIXED 325 ✓ EXACT);
      retcode 10009 clean, symbol_slot set. Commodity + index classes verified;
      FX/metal fill pending.**
- [ ] `RISK_CAP_OVERRIDE` present in exactly the 4 cap-2.0 legs (verified 07-05)
- [ ] No framework-level surprises (silent clamps, symbol mismatches, news-filter
      misfires) — the QM_Common risk-cap class of bug
→ Deliverable: **GO/NO-GO recommendation for the paid challenge** in the decision
  record; OWNER buys the challenge (money gate = OWNER only).

### G2 — Challenge Phase 1 @ scale 9.0
- Presets: r25p1 set already staged; redeploy 1:1 onto the challenge account.
- Verification chain identical to trial (SHA, INIT_OK, magics, cap events).
- Monitoring: `QM_FTMO_TrialPulse` (rename scope covers challenge), daily-loss
  early-warn at 3% (limit 5%), total at 6% (limit 10%).
- Discipline: NO mid-run composition changes. Challenger swaps only between phases
  and only with full evidence chain (Q09 rule applies in spirit).
- Median expectation ~5–6 weeks; timeout is not a fail (time-unbound).
- **Scale policy (MC study 2026-07-05, Codex spot-check 44203b14 PASS_CONDITIONAL 07-07):**
  drawdown-triggered step-down **dd −3% → scale 5.0** (variant: −4% → 5.0) adds
  **+2.06pp (full fold) / +2.44pp (2025 fold) phase-pass** for only +4–5 median
  days — near static-6.0 safety at static-9.0 speed, because the trigger fires
  on only ~28–30% of paths.
  Progress-triggered step-downs are rejected (+0.06–0.42pp; breach risk is
  front-loaded, de-risking after profit protects nothing). Implementation = preset
  redeploy on trigger day (pulse alarms at −3% total); no EA code change.
  Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\round25_dynamic_scale_20260705\`
  (extension validated bit-exact vs `prop_challenge_optimizer --screen-candidate`
  machinery: static anchors reproduced, policy engine max diff 1.4e-14 pp).
  Known limits inherited from the study: closed-daily P&L basis (intraday floating
  DD invisible), linear scale multiplier. OWNER decides the policy at challenge
  start; the live kill-switch (−3% daily flatten, QM_KillSwitch.mqh) sits on top
  and was never modeled — real odds are strictly better than these numbers.

### G3 — Phase 2 @ scale 6.0–7.0
- Setfile redeploy between phases (Two-Speed, OWNER-ratified 07-05); scale choice
  6.0 vs 7.0 decided on Phase-1 DD realization (≤3% realized → 7.0, else 6.0).

### G4 — Funded
- **Blocker to clear DURING Phase 2:** FTMO news-trading restriction applies funded.
  Build + validate the news-compliance preset variant (evidence params + FTMO
  compliance profile) BEFORE funded go-live. Owner of this task: Claude.
- Payout cadence and withdrawal ops: define at G3 close.

### Parallel: keep the survivor engine feeding both books
- Round26 recomposition trigger: ≥3 new validated FTMO-portable reports
  (report.htm chain only — the 4.5× lesson).
- DXZ admissions: cointegration baskets 12772/12778 (Q08 re-run live), exit-surgery
  v2 swaps, calendar Wave 2, 29 gap-family builds primed 07-05, XAG/pairs/defensive
  research tickets (ba0dbed9/d2bc5e78/d5199d43).

## Standing cadence (Claude)
- Morning + evening: `ftmo_trial_pulse.json` + T_Live `live_book_pulse` verdicts in
  any OWNER "Update?".
- Daily during trial: fill-quality spot-check once trades exist (slippage vs .DWX
  assumption; log findings in the decision record).
- G1 evidence accumulates in `decisions/2026-07-05_ftmo_round25_phase1_deploy.md`.

## Infrastructure state backing this (2026-07-05)
- FTMO terminal: kill-safe (path-anchored OFF/ON, da5a42979), reboot-safe
  (QM_FTMO_AtLogon + FTMO_ON.ps1, 940a6a8d3), monitored (QM_FTMO_TrialPulse, 30min).
- Factory recovered same-day (double-spawn DB-lock stall); 7/7 workers, verdicts
  flowing.
