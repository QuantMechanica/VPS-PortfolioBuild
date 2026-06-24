#property strict
#property version   "5.0"
#property description "QM5_9253 MQL5 3-swing slanted trendline breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9253;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_strength          = 5;
input int    strategy_lookback_bars           = 180;
input int    strategy_max_swings              = 32;
input int    strategy_breakout_buffer_pips    = 2;
input int    strategy_line_deviation_pips     = 4;
input double strategy_line_deviation_atr_mult = 0.15;
input int    strategy_min_contacts            = 3;
input int    strategy_atr_period              = 14;
input double strategy_stop_atr_mult           = 0.5;
input double strategy_take_profit_rr          = 2.0;
input int    strategy_time_exit_bars          = 72;

struct Strategy_Line
{
   bool   valid;
   bool   resistance;
   int    older_idx;
   int    newer_idx;
   double older_price;
   double newer_price;
   int    touches;
   double avg_deviation;
   double score;
};

bool   g_active_line_valid      = false;
bool   g_active_line_resistance = false;
int    g_active_side            = 0;
int    g_active_older_idx       = 0;
int    g_active_newer_idx       = 0;
double g_active_older_price     = 0.0;
double g_active_newer_price     = 0.0;
bool   g_pending_strategy_exit  = false;

void Strategy_ResetLine(Strategy_Line &line)
  {
   line.valid = false;
   line.resistance = false;
   line.older_idx = 0;
   line.newer_idx = 0;
   line.older_price = 0.0;
   line.newer_price = 0.0;
   line.touches = 0;
   line.avg_deviation = 0.0;
   line.score = 0.0;
  }

double Strategy_LinePrice(const int idx,
                          const int older_idx,
                          const int newer_idx,
                          const double older_price,
                          const double newer_price)
  {
   if(older_idx == newer_idx)
      return 0.0;

   const double slope = (newer_price - older_price) / (double)(newer_idx - older_idx);
   return older_price + slope * (double)(idx - older_idx);
  }

double Strategy_PipsToPrice(const int pips)
  {
   if(pips <= 0)
      return 0.0;
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool Strategy_ReadRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, count, rates); // perf-allowed: bounded structural OHLC scan; EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied == count);
  }

bool Strategy_IsSwingHigh(const MqlRates &rates[], const int idx, const int strength)
  {
   const double p = rates[idx].high;
   if(p <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      if(rates[idx - k].high >= p || rates[idx + k].high > p)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const MqlRates &rates[], const int idx, const int strength)
  {
   const double p = rates[idx].low;
   if(p <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      if(rates[idx - k].low <= p || rates[idx + k].low < p)
         return false;
     }
   return true;
  }

void Strategy_CollectSwings(const MqlRates &rates[],
                            const int count,
                            const int strength,
                            const int max_swings,
                            int &high_idx[],
                            double &high_price[],
                            int &high_count,
                            int &low_idx[],
                            double &low_price[],
                            int &low_count)
  {
   high_count = 0;
   low_count = 0;
   ArrayResize(high_idx, max_swings);
   ArrayResize(high_price, max_swings);
   ArrayResize(low_idx, max_swings);
   ArrayResize(low_price, max_swings);

   for(int idx = strength; idx < count - strength && (high_count < max_swings || low_count < max_swings); ++idx)
     {
      if(high_count < max_swings && Strategy_IsSwingHigh(rates, idx, strength))
        {
         high_idx[high_count] = idx;
         high_price[high_count] = rates[idx].high;
         ++high_count;
        }
      if(low_count < max_swings && Strategy_IsSwingLow(rates, idx, strength))
        {
         low_idx[low_count] = idx;
         low_price[low_count] = rates[idx].low;
         ++low_count;
        }
     }
  }

bool Strategy_FindBestLine(const int &swing_idx[],
                           const double &swing_price[],
                           const int swing_count,
                           const bool resistance,
                           const double max_deviation,
                           Strategy_Line &best)
  {
   Strategy_ResetLine(best);
   if(swing_count < 3 || max_deviation <= 0.0)
      return false;

   const int min_contacts = MathMax(3, strategy_min_contacts);
   for(int older = 0; older < swing_count; ++older)
     {
      for(int newer = 0; newer < swing_count; ++newer)
        {
         if(swing_idx[older] <= swing_idx[newer])
            continue;

         const double older_price = swing_price[older];
         const double newer_price = swing_price[newer];
         if(resistance && older_price <= newer_price)
            continue;
         if(!resistance && older_price >= newer_price)
            continue;

         int touches = 2;
         double deviation_sum = 0.0;
         bool third_confirmed = false;

         for(int k = 0; k < swing_count; ++k)
           {
            if(k == older || k == newer)
               continue;

            const int idx = swing_idx[k];
            const double line_price = Strategy_LinePrice(idx, swing_idx[older], swing_idx[newer], older_price, newer_price);
            if(line_price <= 0.0)
               continue;

            const double deviation = MathAbs(swing_price[k] - line_price);
            if(deviation <= max_deviation)
              {
               ++touches;
               deviation_sum += deviation;
               third_confirmed = true;
              }
           }

         if(!third_confirmed || touches < min_contacts)
            continue;

         const double avg_dev = deviation_sum / (double)MathMax(1, touches - 2);
         const double recency_score = 1000.0 / (double)(1 + swing_idx[newer]);
         const double span_score = MathMin(200.0, (double)MathAbs(swing_idx[older] - swing_idx[newer]));
         const double deviation_score = 1000.0 / (1.0 + avg_dev / max_deviation);
         const double score = (double)touches * 10000.0 + deviation_score + recency_score + span_score;

         if(!best.valid || score > best.score)
           {
            best.valid = true;
            best.resistance = resistance;
            best.older_idx = swing_idx[older];
            best.newer_idx = swing_idx[newer];
            best.older_price = older_price;
            best.newer_price = newer_price;
            best.touches = touches;
            best.avg_deviation = avg_dev;
            best.score = score;
           }
        }
     }

   return best.valid;
  }

int Strategy_CurrentSignal(const MqlRates &rates[],
                           const Strategy_Line &resistance,
                           const Strategy_Line &support,
                           const double breakout_buffer,
                           Strategy_Line &signal_line)
  {
   Strategy_ResetLine(signal_line);
   if(breakout_buffer <= 0.0)
      return 0;

   if(resistance.valid)
     {
      const double prior_line = Strategy_LinePrice(1, resistance.older_idx, resistance.newer_idx, resistance.older_price, resistance.newer_price);
      const double last_line = Strategy_LinePrice(0, resistance.older_idx, resistance.newer_idx, resistance.older_price, resistance.newer_price);
      if(prior_line > 0.0 && last_line > 0.0 &&
         rates[1].high <= prior_line + breakout_buffer &&
         (rates[0].close > last_line + breakout_buffer || rates[0].high > last_line + breakout_buffer))
        {
         signal_line = resistance;
         return 1;
        }
     }

   if(support.valid)
     {
      const double prior_line = Strategy_LinePrice(1, support.older_idx, support.newer_idx, support.older_price, support.newer_price);
      const double last_line = Strategy_LinePrice(0, support.older_idx, support.newer_idx, support.older_price, support.newer_price);
      if(prior_line > 0.0 && last_line > 0.0 &&
         rates[1].low >= prior_line - breakout_buffer &&
         (rates[0].close < last_line - breakout_buffer || rates[0].low < last_line - breakout_buffer))
        {
         signal_line = support;
         return -1;
        }
     }

   return 0;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &position_time)
  {
   ptype = POSITION_TYPE_BUY;
   position_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_MostRecentSwingLow(const int &low_idx[], const double &low_price[], const int low_count)
  {
   int best_idx = 1000000;
   double best_price = 0.0;
   for(int i = 0; i < low_count; ++i)
     {
      if(low_idx[i] >= 1 && low_idx[i] < best_idx)
        {
         best_idx = low_idx[i];
         best_price = low_price[i];
        }
     }
   return best_price;
  }

double Strategy_MostRecentSwingHigh(const int &high_idx[], const double &high_price[], const int high_count)
  {
   int best_idx = 1000000;
   double best_price = 0.0;
   for(int i = 0; i < high_count; ++i)
     {
      if(high_idx[i] >= 1 && high_idx[i] < best_idx)
        {
         best_idx = high_idx[i];
         best_price = high_price[i];
        }
     }
   return best_price;
  }

void Strategy_RecordActiveLine(const Strategy_Line &line, const int side)
  {
   g_active_line_valid = line.valid;
   g_active_line_resistance = line.resistance;
   g_active_side = side;
   g_active_older_idx = line.older_idx;
   g_active_newer_idx = line.newer_idx;
   g_active_older_price = line.older_price;
   g_active_newer_price = line.newer_price;
  }

void Strategy_AdvanceActiveLine()
  {
   if(!g_active_line_valid)
      return;
   ++g_active_older_idx;
   ++g_active_newer_idx;
  }

void Strategy_ResetActiveLine()
  {
   g_active_line_valid = false;
   g_active_line_resistance = false;
   g_active_side = 0;
   g_active_older_idx = 0;
   g_active_newer_idx = 0;
   g_active_older_price = 0.0;
   g_active_newer_price = 0.0;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_AdvanceActiveLine();

   const int strength = MathMax(1, strategy_swing_strength);
   const int max_swings = MathMax(3, MathMin(64, strategy_max_swings));
   const int lookback = MathMax(2 * strength + 10, strategy_lookback_bars);
   if(strategy_atr_period <= 0 || strategy_stop_atr_mult <= 0.0 || strategy_take_profit_rr <= 0.0)
      return false;

   MqlRates rates[];
   if(!Strategy_ReadRates(rates, lookback))
      return false;
   if(rates[0].close <= 0.0 || rates[1].close <= 0.0)
      return false;

   int high_idx[];
   double high_price[];
   int low_idx[];
   double low_price[];
   int high_count = 0;
   int low_count = 0;
   Strategy_CollectSwings(rates, lookback, strength, max_swings, high_idx, high_price, high_count, low_idx, low_price, low_count);

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double buffer = Strategy_PipsToPrice(strategy_breakout_buffer_pips);
   const double fixed_deviation = Strategy_PipsToPrice(strategy_line_deviation_pips);
   const double max_deviation = MathMax(fixed_deviation, atr * strategy_line_deviation_atr_mult);
   if(atr <= 0.0 || buffer <= 0.0 || max_deviation <= 0.0)
      return false;

   Strategy_Line resistance;
   Strategy_Line support;
   Strategy_Line signal_line;
   Strategy_FindBestLine(high_idx, high_price, high_count, true, max_deviation, resistance);
   Strategy_FindBestLine(low_idx, low_price, low_count, false, max_deviation, support);
   const int signal = Strategy_CurrentSignal(rates, resistance, support, buffer, signal_line);

   ENUM_POSITION_TYPE ptype;
   datetime position_time = 0;
   const bool has_position = Strategy_GetOurPosition(ptype, position_time);
   if(has_position)
     {
      const int position_side = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      if(signal != 0 && signal != position_side)
         g_pending_strategy_exit = true;

      if(g_active_line_valid && g_active_side == position_side && position_time > 0)
        {
         const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
         const int age_seconds = (int)(TimeCurrent() - position_time);
         const double active_line_now = Strategy_LinePrice(0, g_active_older_idx, g_active_newer_idx, g_active_older_price, g_active_newer_price);
         if(seconds_per_bar > 0 && age_seconds <= 2 * seconds_per_bar && active_line_now > 0.0)
           {
            if(position_side > 0 && rates[0].close <= active_line_now + buffer)
               g_pending_strategy_exit = true;
            if(position_side < 0 && rates[0].close >= active_line_now - buffer)
               g_pending_strategy_exit = true;
           }
        }
      return false;
     }

   g_pending_strategy_exit = false;
   Strategy_ResetActiveLine();
   if(signal == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(signal > 0)
     {
      const double swing_low = Strategy_MostRecentSwingLow(low_idx, low_price, low_count);
      if(swing_low <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_low - strategy_stop_atr_mult * atr);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_take_profit_rr);
      req.reason = "THREE_SWING_RESISTANCE_BREAK";
      Strategy_RecordActiveLine(signal_line, 1);
      return (req.tp > ask);
     }

   const double swing_high = Strategy_MostRecentSwingHigh(high_idx, high_price, high_count);
   if(swing_high <= 0.0)
      return false;
   const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_high + strategy_stop_atr_mult * atr);
   if(sl <= 0.0 || sl <= bid)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_take_profit_rr);
   req.reason = "THREE_SWING_SUPPORT_BREAK";
   Strategy_RecordActiveLine(signal_line, -1);
   return (req.tp > 0.0 && req.tp < bid);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime position_time = 0;
   if(!Strategy_GetOurPosition(ptype, position_time))
     {
      g_pending_strategy_exit = false;
      Strategy_ResetActiveLine();
      return false;
     }

   if(g_pending_strategy_exit)
      return true;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar > 0 && strategy_time_exit_bars > 0 && position_time > 0)
     {
      if((TimeCurrent() - position_time) >= strategy_time_exit_bars * seconds_per_bar)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9253_mql5-3swing-break\"}");
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
