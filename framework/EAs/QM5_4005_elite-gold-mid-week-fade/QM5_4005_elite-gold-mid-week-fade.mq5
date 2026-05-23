#property strict
#property version   "5.0"
#property description "QM5_4005 Elite Gold Mid-Week Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_4005: The Gold Mid-Week Fade
// -----------------------------------------------------------------------------
// Logic:
// 1. Timing: Friday afternoon (after 16:00 UTC).
// 2. Over-extension: Price above Daily Upper BB (20, 2.0).
// 3. Rejection: Bearish wick on H1.
// 4. Exit: Friday close.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 4005;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_exit_hour_broker  = 22;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_spread_cap_points  = 50;

bool IsFridayAfternoon()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5 && dt.hour >= 16);
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;
   if(!IsFridayAfternoon()) return false;

   // Extension Check: Use Daily Bollinger Bands
   const double bb_upper_d1 = QM_BB_Upper(_Symbol, PERIOD_D1, 20, 2.0, 1);
   const double close_now = iClose(_Symbol, _Period, 0);

   if(close_now < bb_upper_d1) return false;

   // Rejection Check: Bearish Wick on H1
   const double h1_open  = iOpen(_Symbol, PERIOD_H1, 1);
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);
   const double h1_high  = iHigh(_Symbol, PERIOD_H1, 1);
   const double h1_low   = iLow(_Symbol, PERIOD_H1, 1);
   const double body = MathAbs(h1_close - h1_open);
   const double upper_wick = h1_high - MathMax(h1_open, h1_close);

   if(upper_wick > body * 1.5)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = h1_high + (10 * _Point);
      req.tp = 0.0; // Time exit
      req.reason = "GOLD_FRI_FADE";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= strategy_exit_hour_broker) return true;
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, QM_NEWS_OFF))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar()) return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
