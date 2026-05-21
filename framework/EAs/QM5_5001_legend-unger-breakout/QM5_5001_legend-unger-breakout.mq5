#property strict
#property version   "5.0"
#property description "QM5_5001 Legend Unger Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_5001: The Unger Breakout (Andrea Unger)
// -----------------------------------------------------------------------------
// Logic:
// 1. Breakout: Price crosses Previous Day's High/Low.
// 2. Volatility Filter: Current Daily ATR > 5-day SMA of ATR.
// 3. Exit: Time-based (22:00 Broker) or Trailing Stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 5001;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_atr_period        = 14;
input int    strategy_atr_ma_period     = 5;
input double strategy_rr                = 1.5;
input int    strategy_exit_hour_broker  = 22;
input int    strategy_spread_cap_points  = 25;

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

   // Volatility Filter: Use Daily Data
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   double atr_sum = 0;
   for(int i = 1; i <= strategy_atr_ma_period; ++i)
      atr_sum += QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, i);
   const double atr_ma = atr_sum / strategy_atr_ma_period;

   if(atr_d1 <= atr_ma) return false;

   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_low  = iLow(_Symbol, PERIOD_D1, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Long Breakout
   if(bid > prev_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = prev_low;
      if(req.sl >= bid) req.sl = bid - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "UNGER_LONG_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short Breakout
   if(ask < prev_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = prev_high;
      if(req.sl <= ask) req.sl = ask + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "UNGER_SHORT_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_exit_hour_broker) return true;
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
