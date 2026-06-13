#property strict
#property version   "5.0"
#property description "QM5_10644 Quant Arb volume z-score event momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10644;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_volume_lookback        = 60;
input double strategy_volume_z_threshold     = 4.0;
input int    strategy_atr_period             = 14;
input double strategy_return_atr_mult        = 0.75;
input int    strategy_breakout_lookback      = 5;
input double strategy_stop_atr_mult          = 1.25;
input int    strategy_time_exit_bars         = 10;
input int    strategy_daily_entry_cap        = 1;
input int    strategy_nonzero_volume_lookback = 30;
input int    strategy_min_nonzero_volume_bars = 20;
input int    strategy_spread_sessions        = 20;
input double strategy_spread_cap_mult        = 3.0;
input bool   strategy_session_edge_filter    = true;
input int    strategy_session_start_hhmm     = 1530;
input int    strategy_session_end_hhmm       = 2200;
input int    strategy_session_edge_minutes   = 10;

#define QA_SPREAD_BUCKETS 1440
#define QA_SPREAD_MAX_SAMPLES 20

double   g_spread_samples[QA_SPREAD_BUCKETS][QA_SPREAD_MAX_SAMPLES];
int      g_spread_counts[QA_SPREAD_BUCKETS];
int      g_spread_next[QA_SPREAD_BUCKETS];
int      g_entry_day_key = -1;
int      g_entries_today = 0;
int      g_cached_signal_direction = 0;
double   g_cached_signal_bar_open = 0.0;
double   g_cached_closed_close = 0.0;
datetime g_cached_signal_time = 0;

int ClampInt(const int value, const int lo, const int hi)
  {
   return MathMax(lo, MathMin(hi, value));
  }

int HhmmToMinute(const int hhmm)
  {
   const int h = ClampInt(hhmm / 100, 0, 23);
   const int m = ClampInt(hhmm % 100, 0, 59);
   return h * 60 + m;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

void RefreshEntryDay(const datetime t)
  {
   const int key = DayKey(t);
   if(key == g_entry_day_key)
      return;
   g_entry_day_key = key;
   g_entries_today = 0;
  }

bool IsSessionEdgeMinute(const datetime t)
  {
   if(!strategy_session_edge_filter || strategy_session_edge_minutes <= 0)
      return false;

   const int now_min = MinuteOfDay(t);
   const int start_min = HhmmToMinute(strategy_session_start_hhmm);
   const int end_min = HhmmToMinute(strategy_session_end_hhmm);
   const int edge = ClampInt(strategy_session_edge_minutes, 1, 180);

   if(start_min == end_min)
      return false;

   if(start_min < end_min)
     {
      if(now_min < start_min || now_min >= end_min)
         return false;
      return ((now_min - start_min) < edge || (end_min - now_min) <= edge);
     }

   if(now_min >= start_min)
      return ((now_min - start_min) < edge);
   if(now_min < end_min)
      return ((end_min - now_min) <= edge);
   return false;
  }

double CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return (ask - bid) / point;
  }

double BarSpreadPoints(const MqlRates &bar)
  {
   if(bar.spread > 0)
      return (double)bar.spread;
   return CurrentSpreadPoints();
  }

void AddSpreadSample(const int minute_idx, const double spread_points)
  {
   if(minute_idx < 0 || minute_idx >= QA_SPREAD_BUCKETS || spread_points <= 0.0)
      return;

   const int pos = g_spread_next[minute_idx];
   g_spread_samples[minute_idx][pos] = spread_points;
   g_spread_next[minute_idx] = (pos + 1) % QA_SPREAD_MAX_SAMPLES;
   if(g_spread_counts[minute_idx] < QA_SPREAD_MAX_SAMPLES)
      g_spread_counts[minute_idx]++;
  }

double MedianSpreadForMinute(const int minute_idx)
  {
   if(minute_idx < 0 || minute_idx >= QA_SPREAD_BUCKETS)
      return 0.0;

   const int required = ClampInt(strategy_spread_sessions, 1, QA_SPREAD_MAX_SAMPLES);
   const int count = g_spread_counts[minute_idx];
   if(count < required)
      return 0.0;

   double tmp[QA_SPREAD_MAX_SAMPLES];
   for(int i = 0; i < count; ++i)
      tmp[i] = g_spread_samples[minute_idx][i];

   for(int i = 0; i < count - 1; ++i)
     {
      for(int j = i + 1; j < count; ++j)
        {
         if(tmp[j] < tmp[i])
           {
            const double swap = tmp[i];
            tmp[i] = tmp[j];
            tmp[j] = swap;
           }
        }
     }

   if((count % 2) == 1)
      return tmp[count / 2];
   return 0.5 * (tmp[count / 2 - 1] + tmp[count / 2]);
  }

bool HasOurPosition()
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
      return true;
     }
   return false;
  }

double CommentSignalOpen()
  {
   const string comment = PositionGetString(POSITION_COMMENT);
   const int p = StringFind(comment, "SO=");
   if(p < 0)
      return 0.0;
   return StringToDouble(StringSubstr(comment, p + 3));
  }

bool ReadSignalWindow(MqlRates &rates[], const int count)
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M1, 1, count, rates); // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied >= count);
  }

bool ComputeVolumeZ(MqlRates &rates[], double &out_z)
  {
   out_z = 0.0;
   const int lookback = MathMax(2, strategy_volume_lookback);

   double sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
      sum += (double)rates[i].tick_volume;

   const double mean = sum / (double)lookback;
   double var_sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = (double)rates[i].tick_volume - mean;
      var_sum += d * d;
     }

   const double stdev = MathSqrt(var_sum / (double)lookback);
   if(stdev <= 0.0)
      return false;

   out_z = ((double)rates[0].tick_volume - mean) / stdev;
   return true;
  }

int DirectionalBreakoutSignal(MqlRates &rates[], const double atr_value)
  {
   if(atr_value <= 0.0 || rates[0].close <= 0.0 || rates[1].close <= 0.0)
      return 0;

   const int breakout = MathMax(1, strategy_breakout_lookback);
   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 1; i <= breakout; ++i)
     {
      prior_high = MathMax(prior_high, rates[i].high);
      prior_low = MathMin(prior_low, rates[i].low);
     }

   const double ret_1 = rates[0].close / rates[1].close - 1.0;
   const double atr_pct = atr_value / rates[0].close;
   const double ret_threshold = strategy_return_atr_mult * atr_pct;

   if(ret_1 >= ret_threshold && rates[0].close > prior_high)
      return 1;
   if(ret_1 <= -ret_threshold && rates[0].close < prior_low)
      return -1;
   return 0;
  }

bool NonzeroVolumeGate(MqlRates &rates[])
  {
   const int lookback = MathMax(1, strategy_nonzero_volume_lookback);
   int nonzero = 0;
   for(int i = 1; i <= lookback; ++i)
      if(rates[i].tick_volume > 0)
         nonzero++;
   return (nonzero >= strategy_min_nonzero_volume_bars);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M1)
      return true;

   if(IsSessionEdgeMinute(TimeCurrent()))
      return true;

   if(CurrentSpreadPoints() <= 0.0)
      return true;

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

   const int lookback_needed = MathMax(strategy_volume_lookback + 1,
                              MathMax(strategy_breakout_lookback + 1,
                                      strategy_nonzero_volume_lookback + 1));
   if(lookback_needed < 3)
      return false;

   MqlRates rates[];
   if(!ReadSignalWindow(rates, lookback_needed))
      return false;

   const int signal_minute = MinuteOfDay(rates[0].time);
   const double signal_spread = BarSpreadPoints(rates[0]);
   const double median_spread = MedianSpreadForMinute(signal_minute);
   g_cached_closed_close = rates[0].close;
   g_cached_signal_direction = 0;
   g_cached_signal_time = rates[0].time;

   RefreshEntryDay(rates[0].time);

   bool allow_entry = true;
   if(HasOurPosition())
      allow_entry = false;
   if(strategy_daily_entry_cap > 0 && g_entries_today >= strategy_daily_entry_cap)
      allow_entry = false;
   if(signal_spread <= 0.0 || median_spread <= 0.0 || signal_spread > strategy_spread_cap_mult * median_spread)
      allow_entry = false;
   if(!NonzeroVolumeGate(rates))
      allow_entry = false;

   double vol_z = 0.0;
   if(!ComputeVolumeZ(rates, vol_z))
      allow_entry = false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const int direction = (allow_entry && vol_z >= strategy_volume_z_threshold)
                         ? DirectionalBreakoutSignal(rates, atr_value)
                         : 0;

   g_cached_signal_direction = direction;
   g_cached_signal_bar_open = rates[0].open;
   AddSpreadSample(signal_minute, signal_spread);

   if(direction == 0)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = StringFormat("QAVOLZ_%s_SO=%.8f", (direction > 0 ? "L" : "S"), rates[0].open);
   g_entries_today++;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - sl);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(risk_distance <= 0.0 || moved < risk_distance)
         continue;

      const double target = NormalizeDouble(open_price, _Digits);
      const bool improves = is_buy ? (target > sl + point * 0.5) : (target < sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target, "event_momentum_be_after_1r");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_hold_seconds = MathMax(1, strategy_time_exit_bars) * PeriodSeconds(PERIOD_M1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= max_hold_seconds)
         return true;

      double signal_open = CommentSignalOpen();
      if(signal_open <= 0.0)
         signal_open = g_cached_signal_bar_open;
      if(signal_open > 0.0 && g_cached_closed_close > 0.0)
        {
         if(is_buy && g_cached_closed_close < signal_open)
            return true;
         if(!is_buy && g_cached_closed_close > signal_open)
            return true;
        }

      if(g_cached_signal_time > opened)
        {
         if(is_buy && g_cached_signal_direction < 0)
            return true;
         if(!is_buy && g_cached_signal_direction > 0)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10644_qa-volz-event\"}");
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
