// Framework P1 evidence-bundle compile contract (2026-07-20).
// This is intentionally separate from the protected P0 compile fixture.
#property strict
#property version "1.0"

#include <QM/QM_Common.mqh>

int OnInit()
  {
   string currency_a = "";
   string currency_b = "";
   if(QM_NewsStrictSymbolCurrencies("EURUSD.DWX", currency_a, currency_b) != 2)
      return INIT_FAILED;
   if(currency_a != "EUR" || currency_b != "USD")
      return INIT_FAILED;

   if(QM_NewsStrictSymbolCurrencies("NDX.DWX", currency_a, currency_b) != 1 ||
      currency_a != "USD")
      return INIT_FAILED;
   if(QM_NewsStrictSymbolCurrencies("JPN225.DWX", currency_a, currency_b) != 1 ||
      currency_a != "JPY")
      return INIT_FAILED;
   if(QM_NewsStrictSymbolCurrencies("AUS200.DWX", currency_a, currency_b) != 1 ||
      currency_a != "AUD")
      return INIT_FAILED;
   if(QM_NewsStrictSymbolCurrencies("UNKNOWN.DWX", currency_a, currency_b) != 0)
      return INIT_FAILED;

   Print("QM_FRAMEWORK_P1_EVIDENCE_COMPILE_TEST_OK");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;
  }
