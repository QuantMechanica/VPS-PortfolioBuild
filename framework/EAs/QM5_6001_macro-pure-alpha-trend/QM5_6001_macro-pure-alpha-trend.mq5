#property strict
#property version   "5.0"
#property description "QM5_6001 Macro Pure Alpha Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_6001: The Pure Alpha Trend (Ray Dalio Proxy)
// -----------------------------------------------------------------------------
// Logic:
// 1. Macro Trend: EMA(50) > EMA(200) for Long, EMA(50) < EMA(200) for Short.
// 2. Trend Strength: ADX(14) > 25.
// 3. Exit: ATR-based Trailing Stop (3.0 ATR).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 6001;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_ema_fast          = 50;
input int    strategy_ema_slow          = 200;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 25.0;
input int    strategy_atr_period        = 14;
input double strategy_trail_mult        = 3.0;
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

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow, 1);
   const double adx      = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);

   if(adx < strategy_adx_min) return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(ema_fast > ema_slow)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = bid - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_trail_mult);
      req.tp = 0.0; // Trailing exit
      req.reason = "PURE_ALPHA_TREND_LONG";
      return (req.sl > 0.0);
     }

   if(ema_fast < ema_slow)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = ask + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_trail_mult);
      req.tp = 0.0;
      req.reason = "PURE_ALPHA_TREND_SHORT";
      return (req.sl > 0.0);
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
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      const double trail_dist = atr * strategy_trail_mult;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trail_dist;
         if(new_sl > PositionGetDouble(POSITION_SL))
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "PURE_ALPHA_TRAIL");
        }
      else
        {
         const double new_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trail_dist;
         if(new_sl < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0.0)
            QM_TM_SendSLTPModify(ticket, new_sl, 0.0, "PURE_ALPHA_TRAIL");
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
