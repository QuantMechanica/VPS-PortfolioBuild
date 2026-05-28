#property strict
#property version   "5.0"
#property description "QM5_11906 Watthana Candlestick RSI Stoch EA (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11906
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11906;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_stoch_k_period    = 14;
input int    strategy_stoch_d_period    = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_oversold    = 20.0;
input double strategy_stoch_overbought  = 80.0;
input double strategy_body_shadow_ratio = 2.0;
input int    strategy_trend_lookback    = 5;
input double strategy_trend_min_pips    = 10.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_time_stop_bars    = 120;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

int GetTrend(int shift)
{
   double close_curr = iClose(_Symbol, PERIOD_H1, shift);
   double close_past = iClose(_Symbol, PERIOD_H1, shift + strategy_trend_lookback);
   if(close_curr <= 0.0 || close_past <= 0.0) return 0; // FLAT
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_change = strategy_trend_min_pips * 10 * point;
   
   if(close_curr > close_past + min_change) return 1;  // UP
   if(close_curr < close_past - min_change) return -1; // DOWN
   return 0; // FLAT
}

bool IsHammer(int shift)
{
   if(GetTrend(shift) != -1) return false;
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift);
   double close = iClose(_Symbol, PERIOD_H1, shift);
   double low   = iLow(_Symbol, PERIOD_H1, shift);
   double high  = iHigh(_Symbol, PERIOD_H1, shift);
   
   if(open - close > 0) // bearish candle body
   {
      double body = open - close;
      if((close - low) > strategy_body_shadow_ratio * body) // lower shadow
      {
         // Usually a hammer has a small upper shadow, but card only specifies lower shadow relation
         return true;
      }
   }
   return false;
}

bool IsInvertedHammer(int shift)
{
   if(GetTrend(shift) != -1) return false;
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift);
   double close = iClose(_Symbol, PERIOD_H1, shift);
   double low   = iLow(_Symbol, PERIOD_H1, shift);
   double high  = iHigh(_Symbol, PERIOD_H1, shift);
   
   double body = MathAbs(open - close);
   if(open - close >= 0) // bearish or doji
   {
      if((high - open) > strategy_body_shadow_ratio * body) return true;
   }
   else // bullish
   {
      if((high - close) > strategy_body_shadow_ratio * body) return true;
   }
   return false;
}

bool IsHangingMan(int shift)
{
   if(GetTrend(shift) != 1) return false;
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift);
   double close = iClose(_Symbol, PERIOD_H1, shift);
   double low   = iLow(_Symbol, PERIOD_H1, shift);
   double high  = iHigh(_Symbol, PERIOD_H1, shift);
   
   if(open - close < 0) // bullish candle body
   {
      double body = close - open;
      if((open - low) > strategy_body_shadow_ratio * body) 
      {
         return true;
      }
   }
   return false;
}

bool IsShootingStar(int shift)
{
   if(GetTrend(shift) != 1) return false;
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift);
   double close = iClose(_Symbol, PERIOD_H1, shift);
   double low   = iLow(_Symbol, PERIOD_H1, shift);
   double high  = iHigh(_Symbol, PERIOD_H1, shift);
   
   double body = MathAbs(open - close);
   if(open - close <= 0) // bullish or doji
   {
      if((high - close) > strategy_body_shadow_ratio * body) return true;
   }
   else // bearish
   {
      if((high - open) > strategy_body_shadow_ratio * body) return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);

   if(rsi <= 0.0 || stoch_k <= 0.0 || atr1 <= 0.0) return false;

   bool signal_long  = false;
   bool signal_short = false;

   // Bullish Setup
   if(rsi < strategy_rsi_oversold && stoch_k < strategy_stoch_oversold)
   {
      if(IsHammer(1) || IsInvertedHammer(1))
         signal_long = true;
   }
   
   // Bearish Setup
   if(rsi > strategy_rsi_overbought && stoch_k > strategy_stoch_overbought)
   {
      if(IsHangingMan(1) || IsShootingStar(1))
         signal_short = true;
   }

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "WATTHANA_REVERSAL_LONG" : "WATTHANA_REVERSAL_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
      const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Auto-reverse conditions
      if(ptype == POSITION_TYPE_BUY)
      {
         if(rsi > strategy_rsi_overbought || stoch_k > strategy_stoch_overbought || IsHangingMan(1) || IsShootingStar(1)) 
            return true;
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         if(rsi < strategy_rsi_oversold || stoch_k < strategy_stoch_oversold || IsHammer(1) || IsInvertedHammer(1)) 
            return true;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
