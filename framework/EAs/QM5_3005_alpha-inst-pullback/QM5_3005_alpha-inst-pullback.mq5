#property strict
#property version   "5.0"
#property description "QM5_3005 Alpha Institutional Pullback (EMA Momentum)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_3005: The Institutional Pullback
// -----------------------------------------------------------------------------
// Paradigm: Momentum Pullback
// Baseline: Macro Trend (50 EMA > 200 EMA). Price pulls back to touch 20 EMA.
// Confirmation: Stochastic Oscillator (5,3,3) crosses in trend direction.
// Exit: Fixed RR or opposite candle structure.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 3005;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_ema_fast          = 20;
input int    strategy_ema_mid           = 50;
input int    strategy_ema_slow          = 200;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slow        = 3;
input double strategy_rr                = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
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

   const double ema_20_1  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast, 1);
   const double ema_50_1  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_mid, 1);
   const double ema_200_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow, 1);
   const double low_1     = iLow(_Symbol, _Period, 1);
   const double high_1    = iHigh(_Symbol, _Period, 1);

   const double stoch_k_1 = QM_Stoch_K(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_d_1 = QM_Stoch_D(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_k_2 = QM_Stoch_K(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double stoch_d_2 = QM_Stoch_D(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

   // Long: Macro Bullish (50 > 200) + Pullback to 20 EMA + Stoch Cross Up
   if(ema_50_1 > ema_200_1 && low_1 <= ema_20_1 && stoch_k_1 > stoch_d_1 && stoch_k_2 <= stoch_d_2)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "ALPHA_INST_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short: Macro Bearish (50 < 200) + Pullback to 20 EMA + Stoch Cross Down
   if(ema_50_1 < ema_200_1 && high_1 >= ema_20_1 && stoch_k_1 < stoch_d_1 && stoch_k_2 >= stoch_d_2)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "ALPHA_INST_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal() { return false; } // Handled by SL/TP

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
