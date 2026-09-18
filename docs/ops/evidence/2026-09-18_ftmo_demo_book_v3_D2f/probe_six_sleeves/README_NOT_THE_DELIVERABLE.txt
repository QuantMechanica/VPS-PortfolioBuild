DIAGNOSTIC ONLY - NOT THE DEPLOYMENT PACKAGE.

roster_six.json is the D2f roster with QM5_21505 and QM5_13054 removed, used solely to prove
that the other six sleeves derive cleanly through the identical trial_setpath code path after
the 8-row run refused with sealed_source_hash_drift (GAPS G1).

sets_probe/ holds those six presets and a qm.ftmo-trial-setpath/v2 manifest for six sleeves.
It is NOT the package's sets/ directory and must never be copied into one: a six-sleeve
install would silently deploy a 1.71875 % book instead of the decided 2.34375 %.

The real sets/ can only be produced once GAPS G1 and G2 are closed - see RUNBOOK.md step 1.
