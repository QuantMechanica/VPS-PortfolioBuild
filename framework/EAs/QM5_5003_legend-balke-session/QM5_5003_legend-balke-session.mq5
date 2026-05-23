#property strict
#property version   "5.0"
#property description "QM5_5003 Legend Balke Session"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_5003: The Balke Session (René Balke)
// -----------------------------------------------------------------------------
// Logic:
// 1. Range: Identify High/Low of first 60m London session (08:00-09:00 UTC).
// 2. Breakout: Price crosses High/Low during main session.
// 3. Filter: Volume must be > 1.5 * MA(Volume, 20).
// 4. Exit: 16:30 UTC or 1.5 RR.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 5003;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Timing (UTC)"
input int    strategy_session_start     = 8;
input int    strategy_session_end       = 9;
input int    strategy_exit_hour         = 16;
input int    strategy_exit_min          = 30;

input group "Strategy Parameters"
input double strategy_vol_mult          = 1.5;
input double strategy_rr                = 1.5;
input int    strategy_atr_period        = 14;
input int    strategy_spread_cap_points  = 25;

double session_high = 0.0;
double session_low  = 999999.0;
bool   session_set  = false;

void UpdateSessionRange()
  {
   MqlDateTime dt;
   const datetime now = TimeCurrent();
   TimeToStruct(now, dt);

   if(dt.hour == 0 && dt.min == 0) { session_set = false; session_high = 0; session_low = 999999.0; }

   if(dt.hour == strategy_session_start && dt.min == 0) { session_set = false; session_high = 0; session_low = 999999.0; }

   if(dt.hour == strategy_session_start)
     {
      const double h = iHigh(_Symbol, _Period, 0);
      const double l = iLow(_Symbol, _Period, 0);
      if(h > session_high) session_high = h;
      if(l < session_low)  session_low  = l;
      if(dt.min >= 59) session_set = true;
     }
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
   UpdateSessionRange();

   if(!session_set) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_end || dt.hour >= strategy_exit_hour) return false;

   // Volume Filter
   const long vol_1 = iVolume(_Symbol, _Period, 1);
   double vol_sum = 0;
   for(int i = 1; i <= 20; ++i) vol_sum += (double)iVolume(_Symbol, _Period, i);
   const double vol_ma = vol_sum / 20.0;
   if((double)vol_1 < vol_ma * strategy_vol_mult) return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(bid > session_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = session_low;
      if(req.sl >= bid) req.sl = bid - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 1.5);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "BALKE_SESSION_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ask < session_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = session_high;
      if(req.sl <= ask) req.sl = ask + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 1.5);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "BALKE_SESSION_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour > strategy_exit_hour || (dt.hour == strategy_exit_hour && dt.min >= strategy_exit_min)) return true;
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
