#property strict
#property version   "5.0"
#property description "QM5_4002 Elite JPY Carry-Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_4002: The JPY Carry-Fade
// -----------------------------------------------------------------------------
// Seasonal/Timing Logic:
// 1. Day of Week: Monday or Tuesday (Accumulation days).
// 2. Macro Trend: 200 EMA Slope must be positive (Long Carry bias).
// 3. VSA Exhaustion: Bottom Wick > 2.0 * Body (Bullish rejection).
// 4. Exit: Friday Close (avoid weekend risk).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 4002;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_ema_slow          = 200;
input double strategy_wick_ratio        = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input double strategy_rr                = 2.0;
input int    strategy_spread_cap_points  = 25;

bool IsCarryDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 1 || dt.day_of_week == 2);
  }

bool IsFriday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
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
   if(!IsCarryDay()) return false;

   // Factor 1: Macro Trend
   const double ema_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow, 1);
   const double ema_old = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow, 5);
   if(ema_now <= ema_old) return false;

   // Factor 2: VSA Rejection (Hammer-like candle)
   const double open = iOpen(_Symbol, _Period, 1);
   const double close = iClose(_Symbol, _Period, 1);
   const double low = iLow(_Symbol, _Period, 1);
   const double high = iHigh(_Symbol, _Period, 1);
   const double body = MathAbs(close - open);
   const double bottom_wick = MathMin(open, close) - low;

   if(bottom_wick < body * strategy_wick_ratio) return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = low - (5 * _Point); // SL just below the rejection low
   if(req.sl >= SymbolInfoDouble(_Symbol, SYMBOL_ASK))
      req.sl = QM_StopATR(_Symbol, req.type, SymbolInfoDouble(_Symbol, SYMBOL_ASK), strategy_atr_period, strategy_atr_sl_mult);

   req.tp = QM_TakeRR(_Symbol, req.type, SymbolInfoDouble(_Symbol, SYMBOL_ASK), req.sl, strategy_rr);
   req.reason = "CARRY_VSA_ACCUM";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   if(IsFriday())
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= 20) return true; // Close before market end
     }
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
