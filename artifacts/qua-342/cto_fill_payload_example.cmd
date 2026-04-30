@echo off
REM QUA-342: Example helper for CTO mapping payload generation
REM Replace placeholder values before running.

set EA_ID=<CONCRETE_EA_ID>
set EA_NAME=<CONCRETE_EA_NAME>
set SETFILE_PATH=<ABSOLUTE_OR_REPO_PATH_TO_SETFILE>

powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\artifacts\qua-342\generate_cto_payload_from_env.ps1
if errorlevel 1 (
  echo Payload generation/validation failed.
  exit /b 1
)

echo Payload generated and validated successfully.
