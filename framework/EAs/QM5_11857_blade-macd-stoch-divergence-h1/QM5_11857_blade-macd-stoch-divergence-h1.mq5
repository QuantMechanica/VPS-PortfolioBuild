#property strict
#property version   "5.0"
#property description "QM5_11857 Blade MACD Divergence + Stochastic Counter-Trend H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — strategy-specific inputs and five Strategy_* hooks only.
// Card: QM5_11857_blade-macd-stoch-divergence-h1
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11857;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_stoch_k           = 9;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slow        = 3;
input double strategy_stoch_overbought  = 80.0;
input double strategy_stoch_oversold    = 20.0;
input int    strategy_swing_lookback    = 50;
input int    strategy_sl_bars           = 5;
input int    strategy_sl_min_pips       = 20;
input int    strategy_sl_max_pips       = 35;
input int    strategy_div_window        = 10;
input double strategy_take_profit_rr    = 2.0;

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_swing_lookback < 6 || strategy_sl_bars < 1 ||
      strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 || strategy_take_profit_rr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double pip = point * 10.0;
   const double min_stop = strategy_sl_min_pips * pip;
   const double max_stop = strategy_sl_max_pips * pip;
   if(min_stop <= 0.0 || max_stop <= min_stop)
      return false;

   // perf-allowed: bespoke swing-high/low structure scan, bounded and called
   // only after the framework QM_IsNewBar() closed-bar gate.
   const int bars_needed = MathMax(strategy_swing_lookback + 2, strategy_sl_bars + 2);
   double highs[];
   double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, bars_needed, highs) < bars_needed)
      return false;
   if(CopyLow(_Symbol, PERIOD_H1, 0, bars_needed, lows) < bars_needed)
      return false;

   int swing_high_new = -1;
   int swing_high_old = -1;
   int swing_low_new = -1;
   int swing_low_old = -1;

   const int max_scan = MathMax(3, strategy_swing_lookback - 1);
   for(int shift = 2; shift <= max_scan; ++shift)
     {
      const double h_prev = highs[shift - 1];
      const double h_curr = highs[shift];
      const double h_next = highs[shift + 1];
      if(h_curr > h_prev && h_curr > h_next)
        {
         if(swing_high_new < 0)
            swing_high_new = shift;
         else if(swing_high_old < 0)
            swing_high_old = shift;
        }
      const double l_prev = lows[shift - 1];
      const double l_curr = lows[shift];
      const double l_next = lows[shift + 1];
      if(l_curr < l_prev && l_curr < l_next)
        {
         if(swing_low_new < 0)
            swing_low_new = shift;
         else if(swing_low_old < 0)
            swing_low_old = shift;
        }

      if(swing_high_old > 0 && swing_low_old > 0)
         break;
     }

   bool bearish_divergence = false;
   if(swing_high_new > 0 && swing_high_old > 0 && swing_high_new <= strategy_div_window)
     {
      const double price_new = highs[swing_high_new];
      const double price_old = highs[swing_high_old];
      const double macd_new = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_new);
      const double macd_old = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_old);
      const bool new_hill = (macd_new > QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_new - 1) &&
                             macd_new > QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_new + 1));
      const bool old_hill = (macd_old > QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_old - 1) &&
                             macd_old > QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_high_old + 1));
      bool valley_between = false;
      const double lower_peak = MathMin(macd_new, macd_old);
      for(int j = swing_high_new + 1; j < swing_high_old; ++j)
        {
         if(QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, j) < lower_peak)
           {
            valley_between = true;
            break;
           }
        }
      bearish_divergence = (price_new > price_old && macd_new < macd_old && new_hill && old_hill && valley_between);
     }

   bool bullish_divergence = false;
   if(swing_low_new > 0 && swing_low_old > 0 && swing_low_new <= strategy_div_window)
     {
      const double price_new = lows[swing_low_new];
      const double price_old = lows[swing_low_old];
      const double macd_new = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_new);
      const double macd_old = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_old);
      const bool new_trough = (macd_new < QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_new - 1) &&
                               macd_new < QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_new + 1));
      const bool old_trough = (macd_old < QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_old - 1) &&
                               macd_old < QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, swing_low_old + 1));
      bool hill_between = false;
      const double higher_trough = MathMax(macd_new, macd_old);
      for(int j = swing_low_new + 1; j < swing_low_old; ++j)
        {
         if(QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, j) > higher_trough)
           {
            hill_between = true;
            break;
           }
        }
      bullish_divergence = (price_new < price_old && macd_new > macd_old && new_trough && old_trough && hill_between);
     }

   const double stoch_1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stoch_2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

   if(bearish_divergence && stoch_2 >= strategy_stoch_overbought && stoch_1 < strategy_stoch_overbought)
     {
      double highest_high = -DBL_MAX;
      for(int j = 1; j <= strategy_sl_bars; ++j)
         highest_high = MathMax(highest_high, highs[j]);

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = highest_high + 10.0 * point;
      double risk = sl - entry;
      if(risk > max_stop)
         return false;
      if(risk < min_stop)
        {
         risk = min_stop;
         sl = entry + risk;
        }

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - strategy_take_profit_rr * risk, _Digits);
      req.reason = "BLADE_BEAR_MACD_STOCH_DIV";
      return (req.sl > entry && req.tp < entry);
     }

   if(bullish_divergence && stoch_2 <= strategy_stoch_oversold && stoch_1 > strategy_stoch_oversold)
     {
      double lowest_low = DBL_MAX;
      for(int j = 1; j <= strategy_sl_bars; ++j)
         lowest_low = MathMin(lowest_low, lows[j]);

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = lowest_low - 10.0 * point;
      double risk = entry - sl;
      if(risk > max_stop)
         return false;
      if(risk < min_stop)
        {
         risk = min_stop;
         sl = entry - risk;
        }

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + strategy_take_profit_rr * risk, _Digits);
      req.reason = "BLADE_BULL_MACD_STOCH_DIV";
      return (req.sl < entry && req.tp > entry);
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const double stoch = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(type == POSITION_TYPE_SELL)
        {
         if(current_sl <= open_price)
            continue;
         const double risk = current_sl - open_price;
         const double profit = open_price - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(profit >= risk && stoch < 50.0)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price - 10.0 * point, _Digits), "BLADE_BE_SHORT_STOCH_MIDLINE");
        }
      else if(type == POSITION_TYPE_BUY)
        {
         if(current_sl >= open_price)
            continue;
         const double risk = open_price - current_sl;
         const double profit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - open_price;
         if(profit >= risk && stoch > 50.0)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price + 10.0 * point, _Digits), "BLADE_BE_LONG_STOCH_MIDLINE");
        }
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for P8 News Impact phase)
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless the framework changes.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11857\",\"strategy\":\"blade-macd-stoch-divergence-h1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
