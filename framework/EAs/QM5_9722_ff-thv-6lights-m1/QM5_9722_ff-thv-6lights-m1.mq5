#property strict
#property version   "5.0"
#property description "QM5_9722 ForexFactory THV Six Lights M1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9722;
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
input int    strategy_fast_trix_period       = 6;
input int    strategy_slow_trix_period       = 9;
input int    strategy_trix_signal_period     = 3;
input int    strategy_coral_period           = 34;
input double strategy_coral_factor           = 0.4;
input int    strategy_cloud_tenkan           = 9;
input int    strategy_cloud_kijun            = 26;
input int    strategy_cloud_senkou           = 52;
input int    strategy_atr_period             = 14;
input double strategy_abnormal_bar_atr_mult  = 2.2;
input double strategy_spread_atr_ratio       = 0.12;
input int    strategy_adr_days               = 14;
input double strategy_adr_max_fraction       = 0.90;
input int    strategy_swing_lookback         = 10;
input double strategy_tp_rr                  = 1.2;
input int    strategy_tp_fixed_pips          = 10;
input int    strategy_max_hold_m1_bars       = 18;
input int    strategy_session_start_hour     = 10;
input int    strategy_session_end_hour       = 20;

int g_thv_last_six_direction = 0;
int g_thv_same_direction_six_count = 0;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool InTradeSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;
   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (hour >= strategy_session_start_hour && hour < strategy_session_end_hour);
   return (hour >= strategy_session_start_hour || hour < strategy_session_end_hour);
  }

bool SpreadAllowed(const double atr_value)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr_value <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > atr_value * strategy_spread_atr_ratio)
      return false;
   return true;
  }

bool ReadRates(const string sym, const ENUM_TIMEFRAMES tf, const int start_pos,
               const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(sym, tf, start_pos, count, rates); // perf-allowed: bounded closed-bar structural read; called from framework-gated strategy hooks.
   return (copied == count);
  }

bool ReadCloses(const string sym, const ENUM_TIMEFRAMES tf, const int shift,
                const int count, double &closes[])
  {
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(sym, tf, shift, count, closes); // perf-allowed: bounded closed-bar TRIX/Coral math; no framework TRIX/Coral reader exists.
   return (copied == count);
  }

double EmaNext(const double value, const double previous, const int period)
  {
   const double alpha = 2.0 / ((double)period + 1.0);
   return previous + alpha * (value - previous);
  }

bool TrixHistogram(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const int signal_period, const int shift, double &out_hist)
  {
   out_hist = 0.0;
   if(period < 2 || signal_period < 1 || shift < 1)
      return false;

   const int bars = period * 8 + signal_period + shift + 20;
   double closes[];
   if(!ReadCloses(sym, tf, shift, bars, closes))
      return false;

   double ema1 = closes[bars - 1];
   double ema2 = ema1;
   double ema3 = ema1;
   double prev_triple = 0.0;
   double hist_source[];
   ArrayResize(hist_source, bars);
   int trix_count = 0;

   for(int i = bars - 1; i >= 0; --i)
     {
      ema1 = EmaNext(closes[i], ema1, period);
      ema2 = EmaNext(ema1, ema2, period);
      ema3 = EmaNext(ema2, ema3, period);

      if(prev_triple > 0.0)
        {
         hist_source[trix_count] = 100.0 * (ema3 - prev_triple) / prev_triple;
         trix_count++;
        }
      prev_triple = ema3;
     }

   if(trix_count <= signal_period)
      return false;

   const double current_trix = hist_source[trix_count - 1];
   double signal = hist_source[0];
   for(int j = 1; j < trix_count; ++j)
      signal = EmaNext(hist_source[j], signal, signal_period);

   out_hist = current_trix - signal;
   return true;
  }

int TrixLight(const ENUM_TIMEFRAMES tf, const int period)
  {
   double hist = 0.0;
   if(!TrixHistogram(_Symbol, tf, period, strategy_trix_signal_period, 1, hist))
      return 0;
   if(hist > 0.0)
      return 1;
   if(hist < 0.0)
      return -1;
   return 0;
  }

int CountLights(const int direction, bool &fast_group_ok)
  {
   fast_group_ok = false;
   const int m1_fast = TrixLight(PERIOD_M1, strategy_fast_trix_period);
   const int m1_slow = TrixLight(PERIOD_M1, strategy_slow_trix_period);
   const int m5_fast = TrixLight(PERIOD_M5, strategy_fast_trix_period);
   const int m5_slow = TrixLight(PERIOD_M5, strategy_slow_trix_period);
   const int m15_fast = TrixLight(PERIOD_M15, strategy_fast_trix_period);
   const int m15_slow = TrixLight(PERIOD_M15, strategy_slow_trix_period);

   int count = 0;
   if(m1_fast == direction)
      count++;
   if(m1_slow == direction)
      count++;
   if(m5_fast == direction)
      count++;
   if(m5_slow == direction)
      count++;
   if(m15_fast == direction)
      count++;
   if(m15_slow == direction)
      count++;

   fast_group_ok = (m1_fast == direction && m1_slow == direction);
   return count;
  }

bool M5FastSlopeAligned(const int direction)
  {
   double h1 = 0.0;
   double h2 = 0.0;
   if(!TrixHistogram(_Symbol, PERIOD_M5, strategy_fast_trix_period, strategy_trix_signal_period, 1, h1))
      return false;
   if(!TrixHistogram(_Symbol, PERIOD_M5, strategy_fast_trix_period, strategy_trix_signal_period, 2, h2))
      return false;
   if(direction > 0)
      return (h1 > h2);
   return (h1 < h2);
  }

bool CoralValue(const int shift, double &out_coral)
  {
   out_coral = 0.0;
   if(strategy_coral_period < 2)
      return false;

   const int bars = strategy_coral_period * 8 + shift + 20;
   double closes[];
   if(!ReadCloses(_Symbol, PERIOD_M1, shift, bars, closes))
      return false;

   double e1 = closes[bars - 1];
   double e2 = e1;
   double e3 = e1;
   double e4 = e1;
   double e5 = e1;
   double e6 = e1;
   for(int i = bars - 1; i >= 0; --i)
     {
      e1 = EmaNext(closes[i], e1, strategy_coral_period);
      e2 = EmaNext(e1, e2, strategy_coral_period);
      e3 = EmaNext(e2, e3, strategy_coral_period);
      e4 = EmaNext(e3, e4, strategy_coral_period);
      e5 = EmaNext(e4, e5, strategy_coral_period);
      e6 = EmaNext(e5, e6, strategy_coral_period);
     }

   const double b = strategy_coral_factor;
   const double b2 = b * b;
   const double b3 = b2 * b;
   const double c1 = -b3;
   const double c2 = 3.0 * b2 + 3.0 * b3;
   const double c3 = -6.0 * b2 - 3.0 * b - 3.0 * b3;
   const double c4 = 1.0 + 3.0 * b + 3.0 * b2 + b3;
   out_coral = c1 * e6 + c2 * e5 + c3 * e4 + c4 * e3;
   return (out_coral > 0.0);
  }

bool ClosedM1Bar(MqlRates &bar)
  {
   MqlRates rates[];
   if(!ReadRates(_Symbol, PERIOD_M1, 1, 1, rates))
      return false;
   bar = rates[0];
   return (bar.close > 0.0 && bar.high >= bar.low);
  }

bool PriceOnCloudSide(const int direction, const double close_price)
  {
   const int cloud_shift = strategy_cloud_kijun;
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol, PERIOD_M1,
                                                 strategy_cloud_tenkan,
                                                 strategy_cloud_kijun,
                                                 strategy_cloud_senkou,
                                                 cloud_shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol, PERIOD_M1,
                                                 strategy_cloud_tenkan,
                                                 strategy_cloud_kijun,
                                                 strategy_cloud_senkou,
                                                 cloud_shift);
   if(span_a <= 0.0 || span_b <= 0.0)
      return false;
   const double cloud_top = MathMax(span_a, span_b);
   const double cloud_bottom = MathMin(span_a, span_b);
   if(direction > 0)
      return (close_price > cloud_top);
   return (close_price < cloud_bottom);
  }

bool ADRAllowed()
  {
   if(strategy_adr_days <= 0)
      return true;

   MqlRates daily[];
   if(!ReadRates(_Symbol, PERIOD_D1, 0, strategy_adr_days + 1, daily))
      return false;

   double adr_sum = 0.0;
   int samples = 0;
   for(int i = 1; i <= strategy_adr_days; ++i)
     {
      const double range = daily[i].high - daily[i].low;
      if(range > 0.0)
        {
         adr_sum += range;
         samples++;
        }
     }
   if(samples <= 0 || adr_sum <= 0.0)
      return false;

   const double adr = adr_sum / (double)samples;
   const double current_range = daily[0].high - daily[0].low;
   if(adr <= 0.0 || current_range < 0.0)
      return false;
   return (current_range <= adr * strategy_adr_max_fraction);
  }

bool SwingExtremes(double &out_low, double &out_high)
  {
   out_low = 0.0;
   out_high = 0.0;
   if(strategy_swing_lookback <= 0)
      return false;

   MqlRates rates[];
   if(!ReadRates(_Symbol, PERIOD_M1, 1, strategy_swing_lookback, rates))
      return false;

   out_low = rates[0].low;
   out_high = rates[0].high;
   for(int i = 1; i < strategy_swing_lookback; ++i)
     {
      if(rates[i].low < out_low)
         out_low = rates[i].low;
      if(rates[i].high > out_high)
         out_high = rates[i].high;
     }
   return (out_low > 0.0 && out_high > 0.0);
  }

void RefreshSixLightSequence(const int current_direction)
  {
   if(current_direction == 0)
      return;
   if(current_direction != g_thv_last_six_direction)
     {
      g_thv_last_six_direction = current_direction;
      g_thv_same_direction_six_count = 1;
      return;
     }
   g_thv_same_direction_six_count++;
  }

bool BuildEntry(const int direction, QM_EntryRequest &req)
  {
   bool fast_group_ok = false;
   const int light_count = CountLights(direction, fast_group_ok);
   if(light_count < 6 || !fast_group_ok)
      return false;

   RefreshSixLightSequence(direction);
   if(g_thv_same_direction_six_count > 3)
      return false;

   MqlRates bar;
   if(!ClosedM1Bar(bar))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if((bar.high - bar.low) > atr * strategy_abnormal_bar_atr_mult)
      return false;
   if(!SpreadAllowed(atr))
      return false;
   if(!ADRAllowed())
      return false;

   double coral = 0.0;
   if(!CoralValue(1, coral))
      return false;
   if(direction > 0 && bar.close <= coral)
      return false;
   if(direction < 0 && bar.close >= coral)
      return false;
   if(!PriceOnCloudSide(direction, bar.close))
      return false;
   if(!M5FastSlopeAligned(direction))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (direction > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   double swing_low = 0.0;
   double swing_high = 0.0;
   if(!SwingExtremes(swing_low, swing_high))
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   double sl = 0.0;
   if(direction > 0)
      sl = MathMin(swing_low, entry - atr);
   else
      sl = MathMax(swing_high, entry + atr);

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   const double fixed_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_fixed_pips);
   const double fixed_tp = QM_StopRulesNormalizePrice(_Symbol, (direction > 0) ? (entry + fixed_dist) : (entry - fixed_dist));
   if(rr_tp <= 0.0 || fixed_tp <= 0.0)
      return false;

   double tp = 0.0;
   if(direction > 0)
      tp = MathMin(rr_tp, fixed_tp);
   else
      tp = MathMax(rr_tp, fixed_tp);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = (direction > 0) ? "THV_SIX_LIGHTS_LONG" : "THV_SIX_LIGHTS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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

   if(!InTradeSession())
      return false;

   if(BuildEntry(1, req))
      return true;
   return BuildEntry(-1, req);
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time = 0;
   if(!GetOurPosition(ptype, open_time))
      return false;

   if(strategy_max_hold_m1_bars > 0 && open_time > 0)
     {
      if((TimeCurrent() - open_time) >= strategy_max_hold_m1_bars * 60)
         return true;
     }

   const int direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   bool fast_group_ok = false;
   const int light_count = CountLights(direction, fast_group_ok);
   if(light_count > 0 && light_count < 4)
      return true;

   MqlRates bar;
   if(!ClosedM1Bar(bar))
      return false;

   double coral = 0.0;
   if(!CoralValue(1, coral))
      return false;

   if(direction > 0 && bar.close < coral)
      return true;
   if(direction < 0 && bar.close > coral)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9722_ff-thv-6lights-m1\"}");
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
