# QUA-415 Pipeline-Operator Unblock Instructions

## Required unblock proof
Post a workflow confirmation commit hash proving active dispatch consumes required `setfile_path` before tester launch.

## Commit message guidance
Include all of these concepts in one commit message line so monitor detection is unambiguous:
- dispatch or dispatcher behavior
- setfile_path consumption/enforcement/requirement
- pipeline role context (`pipeline-op` or `pipeline-operator`)

Example:
`pipeline-op: enforce dispatcher requires setfile_path and consumes setfile_path before dispatch`

## Then post on QUA-415
- commit hash
- short statement that workflow run validated refusal-on-missing-set and pass-on-present-set