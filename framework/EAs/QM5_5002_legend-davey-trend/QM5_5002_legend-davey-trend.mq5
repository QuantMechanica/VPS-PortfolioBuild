#property strict
#property version   "5.0"
#property description "QM5_5002 Legend Davey Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_5002: The Davey Trend (Kevin Davey)
// -----------------------------------------------------------------------------
// Logic:
// 1. Breakout: Price > Highest(40 bars) for Long, Price < Lowest(40 bars) for Short.
// 2. Trend Filter: Price > SMA(200) for Long, Price < SMA(200) for Short.
// 3. Exit: Low of last 10 bars (Trailing Stop).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 5002;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_breakout_period   = 40;
input int    strategy_trail_period      = 10;
input int    strategy_sma_filter        = 200;
input double strategy_rr                = 2.0;
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

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_filter, 1);

   const double channel_high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_breakout_period, 1));
   const double channel_low  = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_breakout_period, 1));

   // Long Trend Breakout
   if(bid > channel_high && bid > sma)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_trail_period, 1));
      if(req.sl >= bid) req.sl = bid - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 14, 1) * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "DAVEY_TREND_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short Trend Breakout
   if(ask < channel_low && ask < sma)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_trail_period, 1));
      if(req.sl <= ask) req.sl = ask + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 14, 1) * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "DAVEY_TREND_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_trail_period, 1));
         if(new_sl > PositionGetDouble(POSITION_SL))
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "DAVEY_TRAIL");
        }
      else
        {
         const double new_sl = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_trail_period, 1));
         if(new_sl < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0.0)
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "DAVEY_TRAIL");
        }
     }
  }

bool Strategy_ExitSignal() { return false; }

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
