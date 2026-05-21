#property strict
#property version   "5.0"
#property description "QM5_3004 Alpha Morning Rush (London Breakout)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_3004: The Morning Rush
// -----------------------------------------------------------------------------
// Paradigm: Session Breakout
// Baseline: Asian Session Range (High/Low between 00:00 and 08:00 UTC)
// Confirmation: Price breaks the Asian range during the London Open (08:00-10:00)
// Exit: Time-based (16:00 UTC) or fixed RR
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 3004;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Timing (Broker Time)"
input int    strategy_asia_start_hour   = 0;
input int    strategy_asia_end_hour     = 8;
input int    strategy_london_start_hour = 8;
input int    strategy_london_end_hour   = 10;
input int    strategy_exit_hour         = 16;

input group "Strategy Parameters"
input double strategy_rr                = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input int    strategy_spread_cap_points  = 25;

double asia_high = 0.0;
double asia_low  = 0.0;
bool   range_calculated = false;

void CalculateAsianRange()
  {
   asia_high = 0.0;
   asia_low  = 999999.0;

   MqlDateTime dt;
   const datetime now = TimeCurrent();

   // Find the start of the current day
   TimeToStruct(now, dt);
   dt.hour = strategy_asia_start_hour;
   dt.min = 0;
   dt.sec = 0;
   const datetime start_time = StructToTime(dt);

   dt.hour = strategy_asia_end_hour;
   const datetime end_time = StructToTime(dt);

   const int start_bar = iBarShift(_Symbol, _Period, start_time);
   const int end_bar = iBarShift(_Symbol, _Period, end_time);

   if(start_bar < 0 || end_bar < 0) return;

   for(int i = end_bar; i <= start_bar; ++i)
     {
      const double h = iHigh(_Symbol, _Period, i);
      const double l = iLow(_Symbol, _Period, i);
      if(h > asia_high) asia_high = h;
      if(l < asia_low)  asia_low  = l;
     }
   range_calculated = true;
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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Reset range daily
   if(dt.hour == 0 && dt.min == 0) range_calculated = false;

   // Only calculate range once per day after Asia ends
   if(!range_calculated && dt.hour >= strategy_asia_end_hour)
      CalculateAsianRange();

   if(!range_calculated) return false;

   // Only enter during London Open window
   if(dt.hour < strategy_london_start_hour || dt.hour >= strategy_london_end_hour)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Long Breakout
   if(bid > asia_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = asia_low; // SL at Asian Low
      if(req.sl >= bid) req.sl = bid - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 0) * strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "ALPHA_RUSH_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short Breakout
   if(ask < asia_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = asia_high; // SL at Asian High
      if(req.sl <= ask) req.sl = ask + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 0) * strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "ALPHA_RUSH_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_exit_hour) return true;
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
