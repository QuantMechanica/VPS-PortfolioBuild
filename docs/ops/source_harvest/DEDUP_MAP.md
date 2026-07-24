# Dedup Map

_As of 2026-07-24. 5 clusters where a single underlying strategy/thread was captured more than once (or split across captures). The **primary** id is the kept, best-classified row; **secondaries** are folded into it. `overlaps_existing` shows whether the cluster's strategy is already built as a QM5 EA._

| cluster | primary | secondaries | overlaps_existing | core |
|---|---|---|---|---|
| CL-01 | STR-095 (APB Heiken-Ashi Color-Flip NY-Open Reversal Scalp (US30)) | STR-010 (APB Color-Flip Scalp (US30 NY-Open)) | none | APB (modified-Heiken-Ashi) color-flip NY-open reversal scalp on US30 — same thread 1184099 captured twice (STR-095 ELIGIBLE/PARTIAL kept; STR-010 REJECTED dup). |
| CL-02 | STR-027 (VR Gap (bar-to-bar gap fade)) | STR-096 (VR Gap fade (bar-open gap-fill mean-reversion)) | QM5_10044 | VR Gap bar-to-bar gap fade (fade impulse when \|prevClose-open\|>threshold, TP=gap) — FF thread 1394867 captured twice, both ELIGIBLE/FULL. |
| CL-03 | STR-061 (Momentum-Divergence Swing (F-break reversal)) | STR-098 (Momentum Divergence Reversal (28-period)) | QM5_10046 | Momentum(28) divergence reversal, enter on break of momentum swing extreme (point F), measured-move TPs — FF thread 423512 captured twice, both ELIGIBLE/PARTIAL. |
| CL-04 | STR-143 (SMA Crossover Pullback (100/200 SMA + Stochastic)) | STR-142 (SMA Crossover Pullback (Robopip) with breakeven trail); STR-094 (SMA Crossover Pullback (Big Pippin)); STR-093 (n/a - blocked capture) | none | Robopip/Big-Pippin SMA Crossover Pullback (100/200 SMA trend + Stochastic 14,3,3 pullback, 150/300-pip stop/target + BE trail) — babypips base post (20150605) + risk-adjust follow-up (20151009), each captured twice. |
| CL-05 | STR-118 (Mechanized Ichimoku cloud trend system (ATR cloud filter)) | STR-117 (Ichimoku triple-condition D1 trend system) | QM5_10513 | Ichimoku D1 trend system (Tenkan/Kijun + price beyond Kumo) — babypips thread 18242; STR-118 is unhommefou's fully-mechanical ATR-cloud-filtered variant (FULL), STR-117 the OP/ArmyDoc triple-condition variant (PARTIAL). |

## Cluster detail

### CL-01 — primary STR-095 (APB Heiken-Ashi Color-Flip NY-Open Reversal Scalp (US30))

- **Secondaries folded in:** STR-010
- **overlaps_existing:** none
- **Core:** APB (modified-Heiken-Ashi) color-flip NY-open reversal scalp on US30 — same thread 1184099 captured twice (STR-095 ELIGIBLE/PARTIAL kept; STR-010 REJECTED dup).

### CL-02 — primary STR-027 (VR Gap (bar-to-bar gap fade))

- **Secondaries folded in:** STR-096
- **overlaps_existing:** QM5_10044
- **Core:** VR Gap bar-to-bar gap fade (fade impulse when |prevClose-open|>threshold, TP=gap) — FF thread 1394867 captured twice, both ELIGIBLE/FULL.

### CL-03 — primary STR-061 (Momentum-Divergence Swing (F-break reversal))

- **Secondaries folded in:** STR-098
- **overlaps_existing:** QM5_10046
- **Core:** Momentum(28) divergence reversal, enter on break of momentum swing extreme (point F), measured-move TPs — FF thread 423512 captured twice, both ELIGIBLE/PARTIAL.

### CL-04 — primary STR-143 (SMA Crossover Pullback (100/200 SMA + Stochastic))

- **Secondaries folded in:** STR-142, STR-094, STR-093
- **overlaps_existing:** none
- **Core:** Robopip/Big-Pippin SMA Crossover Pullback (100/200 SMA trend + Stochastic 14,3,3 pullback, 150/300-pip stop/target + BE trail) — babypips base post (20150605) + risk-adjust follow-up (20151009), each captured twice.

### CL-05 — primary STR-118 (Mechanized Ichimoku cloud trend system (ATR cloud filter))

- **Secondaries folded in:** STR-117
- **overlaps_existing:** QM5_10513
- **Core:** Ichimoku D1 trend system (Tenkan/Kijun + price beyond Kumo) — babypips thread 18242; STR-118 is unhommefou's fully-mechanical ATR-cloud-filtered variant (FULL), STR-117 the OP/ArmyDoc triple-condition variant (PARTIAL).
