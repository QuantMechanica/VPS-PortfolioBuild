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
input double RISK_PERCENT               = 0.0;
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

bool   g_closed_bar_state_ready = false;
bool   g_bullish_pattern        = false;
bool   g_bearish_pattern        = false;
double g_closed_rsi             = 0.0;
double g_closed_stoch_k         = 0.0;
double g_closed_atr             = 0.0;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

int GetTrend(int shift)
{
   // perf-allowed: fixed closed-bar reads for the card's bespoke candle and
   // prior-trend definition. The callers run only from the latched H1 new-bar
   // path in Strategy_RefreshClosedBarState().
   double close_curr = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed
   double close_past = iClose(_Symbol, PERIOD_H1, shift + strategy_trend_lookback); // perf-allowed
   if(close_curr <= 0.0 || close_past <= 0.0) return 0; // FLAT

   const int trend_pips = (int)MathRound(MathAbs(strategy_trend_min_pips));
   const double min_change = QM_StopRulesPipsToPriceDistance(_Symbol, trend_pips);
   if(min_change <= 0.0) return 0;
   
   if(close_curr > close_past + min_change) return 1;  // UP
   if(close_curr < close_past - min_change) return -1; // DOWN
   return 0; // FLAT
}

bool IsHammer(int shift)
{
   if(GetTrend(shift) != -1) return false;
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed
   double close = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed
   double low   = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed
   
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
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed
   double close = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed
   double high  = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed
   
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
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed
   double close = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed
   double low   = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed
   
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
   
   double open  = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed
   double close = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed
   double high  = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed
   
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

bool Strategy_RefreshClosedBarState()
{
   g_closed_bar_state_ready = false;
   g_bullish_pattern = false;
   g_bearish_pattern = false;
   g_closed_rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   g_closed_stoch_k = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k_period,
                                  strategy_stoch_d_period, strategy_stoch_slowing, 1);
   g_closed_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(g_closed_rsi <= 0.0 || g_closed_stoch_k <= 0.0 || g_closed_atr <= 0.0)
      return false;

   g_bullish_pattern = (IsHammer(1) || IsInvertedHammer(1));
   g_bearish_pattern = (IsHangingMan(1) || IsShootingStar(1));
   g_closed_bar_state_ready = true;
   return true;
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
   if(!g_closed_bar_state_ready) return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

   bool signal_long  = false;
   bool signal_short = false;

   // Bullish Setup
   if(g_closed_rsi < strategy_rsi_oversold && g_closed_stoch_k < strategy_stoch_oversold)
   {
      if(g_bullish_pattern)
         signal_long = true;
   }
   
   // Bearish Setup
   if(g_closed_rsi > strategy_rsi_overbought && g_closed_stoch_k > strategy_stoch_overbought)
   {
      if(g_bearish_pattern)
         signal_short = true;
   }

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, g_closed_atr, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "WATTHANA_REVERSAL_LONG" : "WATTHANA_REVERSAL_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

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
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Auto-reverse conditions
      if(g_closed_bar_state_ready && ptype == POSITION_TYPE_BUY)
      {
         if(g_closed_rsi > strategy_rsi_overbought ||
            g_closed_stoch_k > strategy_stoch_overbought || g_bearish_pattern)
            return true;
      }
      else if(g_closed_bar_state_ready && ptype == POSITION_TYPE_SELL)
      {
         if(g_closed_rsi < strategy_rsi_oversold ||
            g_closed_stoch_k < strategy_stoch_oversold || g_bullish_pattern)
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
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   // Latch the single-consume framework event once. Refreshing the closed-bar
   // cache here keeps position exits current even when the later news gate
   // suppresses entries.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
   {
      QM_EquityStreamOnNewBar();
      Strategy_RefreshClosedBarState();
   }

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

   // News blackout gates new entries only. Position management, hard stops,
   // and oscillator/candle exits above remain live through news windows.
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!new_bar) return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
