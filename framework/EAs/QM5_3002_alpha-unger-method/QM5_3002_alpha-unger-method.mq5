#property strict
#property version   "5.0"
#property description "QM5_3002 Alpha Unger Method (Volatility Breakout)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_3002: The Unger Method
// -----------------------------------------------------------------------------
// Paradigm: Volatility Breakout
// Baseline: Keltner Channel (20 EMA, 2.0 ATR multiplier)
// Confirmation: ADX (14 period) > 30 (Strong Trend confirmed)
// Exit: End of London/NY overlap (16:00 UTC) or Trailing Stop
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 3002;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy"
input int    strategy_ma_period         = 20;
input double strategy_atr_mult          = 2.0;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 30.0;
input int    strategy_exit_hour_utc     = 16;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_trailing_atr      = 2.0;
input int    strategy_spread_cap_points  = 25;

// --- Keltner Channel Logic ---
double KeltnerMid(const int shift) { return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, shift, PRICE_CLOSE); }
double KeltnerUpper(const int shift) { return KeltnerMid(shift) + (strategy_atr_mult * QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift)); }
double KeltnerLower(const int shift) { return KeltnerMid(shift) - (strategy_atr_mult * QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift)); }

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

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double upper_1 = KeltnerUpper(1);
   const double lower_1 = KeltnerLower(1);
   const double adx_1 = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);

   if(adx_1 < strategy_adx_min) return false;

   // Long Breakout
   if(close_1 > upper_1)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0; // Using trailing stop and time exit
      req.reason = "ALPHA_UNGER_LONG";
      return (req.sl > 0.0);
     }

   // Short Breakout
   if(close_1 < lower_1)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "ALPHA_UNGER_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Implement ATR Trailing Stop
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 0);
      const double trail_dist = atr * strategy_trailing_atr;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trail_dist;
         if(new_sl > PositionGetDouble(POSITION_SL))
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "ALPHA_UNGER_TRAIL");
        }
      else
        {
         const double new_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trail_dist;
         if(new_sl < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0.0)
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "ALPHA_UNGER_TRAIL");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   // Exit by time (16:00 UTC)
   MqlDateTime dt_struct;
   TimeToStruct(TimeCurrent(), dt_struct);
   if(dt_struct.hour >= strategy_exit_hour_utc) return true;
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
