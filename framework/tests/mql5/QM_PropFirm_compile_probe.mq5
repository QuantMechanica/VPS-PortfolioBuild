//+------------------------------------------------------------------+
//| Compile probe for QM_PropFirm.mqh - not a tradable EA.            |
//| Exercises every exported symbol so unused-code elision cannot     |
//| hide a syntax or signature error.                                 |
//+------------------------------------------------------------------+
#property strict
#include <QM/QM_Logger.mqh>
#include <QM/QM_PropFirm.mqh>

int OnInit()
  {
   if(!QM_PropInit(9999))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!QM_PropEntryAllowed(99990000))
      return;
   const double basis = QM_PropRiskBasis(AccountInfoDouble(ACCOUNT_BALANCE));
   const double scale = QM_PropRiskScale();
   if(basis > 0.0 && scale > 0.0)
      Comment(StringFormat("basis=%.2f scale=%.2f day_key=%d", basis, scale,
                           QM_PropDayKey(TimeCurrent())));
  }

void OnDeinit(const int reason)
  {
   QM_PropSaveState();
  }
