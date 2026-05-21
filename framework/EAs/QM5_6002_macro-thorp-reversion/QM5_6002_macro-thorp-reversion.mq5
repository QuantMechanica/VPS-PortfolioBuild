#property strict
#property version   "5.0"
#property description "QM5_6002 Macro Thorp Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_6002: The Thorp Reversion (Ed Thorp Proxy)
// -----------------------------------------------------------------------------
// Logic:
// 1. Deviation: Price < SMA(20) - (2.0 * StdDev) for Long, vice versa for Short.
// 2. Mean Reversion: Target return to the SMA (the mean).
// 3. Exit: Touch of the SMA.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 6002;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_sma_period        = 20;
input double strategy_stdev_mult        = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
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

   const double close = iClose(_Symbol, _Period, 1);
   const double sma   = iMA(_Symbol, _Period, strategy_sma_period, 0, MODE_SMA, PRICE_CLOSE, 1);
   const double stdev = iStdDev(_Symbol, _Period, strategy_sma_period, 0, MODE_SMA, PRICE_CLOSE, 1);

   if(stdev <= 0.0) return false;

   // Long Reversion
   if(close < sma - (strategy_stdev_mult * stdev))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = close - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_atr_sl_mult);
      req.tp = 0.0; // Exit at mean
      req.reason = "THORP_MEAN_REV_LONG";
      return (req.sl > 0.0);
     }

   // Short Reversion
   if(close > sma + (strategy_stdev_mult * stdev))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = close + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "THORP_MEAN_REV_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close = iClose(_Symbol, _Period, 0);
      const double sma   = iMA(_Symbol, _Period, strategy_sma_period, 0, MODE_SMA, PRICE_CLOSE, 0);

      if(ptype == POSITION_TYPE_BUY && close >= sma) return true;
      if(ptype == POSITION_TYPE_SELL && close <= sma) return true;
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
