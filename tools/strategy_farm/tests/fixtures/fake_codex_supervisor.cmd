@echo off
if "%~1"=="exec" (
  >"%QM_CODEX_FAKE_ARGS%" echo %*
  exit /b 0
)
if not exist "%QM_CODEX_FAKE_STATE%" (
  >"%QM_CODEX_FAKE_STATE%" echo first_failed
  exit /b 23
)
>"%QM_CODEX_FAKE_ARGS%" echo %*
exit /b 130
