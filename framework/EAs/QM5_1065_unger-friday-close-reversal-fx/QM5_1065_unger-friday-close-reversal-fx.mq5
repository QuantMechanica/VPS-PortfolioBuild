#property strict
#property version   "5.0"
#property description "QM5_1065 Unger Friday Close Reversal FX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1065;
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
input int    strategy_range_lookback_days  = 5;
input double strategy_decile_threshold     = 0.10;
input int    strategy_atr_period           = 20;
input double strategy_sl_atr_mult          = 2.0;
input int    strategy_sunday_reopen_hour   = 21;
input int    strategy_monday_entry_end_h   = 6;
input double strategy_spread_mult          = 3.0;
input int    strategy_spread_lookback_days = 20;
input bool   strategy_skip_holiday_week    = true;
input bool   strategy_news_filter_enabled  = true;
input int    strategy_news_blackout_min    = 240;

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

   if(strategy_range_lookback_days < 3 || strategy_range_lookback_days > 20)
      return false;
   if(strategy_decile_threshold <= 0.0 || strategy_decile_threshold >= 0.50)
      return false;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return false;
   if(strategy_spread_lookback_days < 1 || strategy_spread_lookback_days > 60)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime now_dt;
   TimeToStruct(broker_now, now_dt);

   const bool sunday_reopen = (now_dt.day_of_week == 0 && now_dt.hour >= strategy_sunday_reopen_hour);
   const bool monday_open = (now_dt.day_of_week == 1 && now_dt.hour <= strategy_monday_entry_end_h);
   if(!sunday_reopen && !monday_open)
      return false;

   if(strategy_skip_holiday_week)
     {
      if((now_dt.mon == 12 && now_dt.day >= 24) || (now_dt.mon == 1 && now_dt.day <= 2))
         return false;
     }

   MqlDateTime week_dt = now_dt;
   week_dt.hour = 0;
   week_dt.min = 0;
   week_dt.sec = 0;
   const datetime today_start = StructToTime(week_dt);
   int days_since_monday = now_dt.day_of_week - 1;
   if(days_since_monday < 0)
      days_since_monday = 6;
   const datetime week_key = today_start - (days_since_monday * 86400);
   static datetime last_entry_week = 0;
   if(week_key > 0 && week_key == last_entry_week)
      return false;

   const int bars_needed = MathMax(strategy_spread_lookback_days + 10, strategy_range_lookback_days + 10);
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, bars); // perf-allowed: bounded closed D1 Friday/range/spread read inside framework QM_IsNewBar gate.
   if(copied < strategy_range_lookback_days + 1)
      return false;
   ArraySetAsSeries(bars, true);

   int friday_idx = -1;
   for(int i = 0; i < MathMin(copied, 10); ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(bars[i].time, bar_dt);
      if(bar_dt.day_of_week == 5)
        {
         friday_idx = i;
         if(strategy_skip_holiday_week)
           {
            if((bar_dt.mon == 12 && bar_dt.day >= 24) || (bar_dt.mon == 1 && bar_dt.day <= 2))
               return false;
           }
         break;
        }
     }
   if(friday_idx < 0 || friday_idx + strategy_range_lookback_days > copied)
      return false;

   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   for(int i = 0; i < strategy_range_lookback_days; ++i)
     {
      const int idx = friday_idx + i;
      if(bars[idx].high <= 0.0 || bars[idx].low <= 0.0 || bars[idx].high <= bars[idx].low)
         return false;
      range_high = MathMax(range_high, bars[idx].high);
      range_low = MathMin(range_low, bars[idx].low);
     }

   const double range = range_high - range_low;
   const double friday_close = bars[friday_idx].close;
   if(range <= 0.0 || friday_close <= 0.0)
      return false;

   double spread_samples[];
   ArrayResize(spread_samples, 0);
   for(int i = 0; i < MathMin(strategy_spread_lookback_days, copied); ++i)
     {
      if(bars[i].spread <= 0)
         continue;
      const int n = ArraySize(spread_samples);
      ArrayResize(spread_samples, n + 1);
      spread_samples[n] = (double)bars[i].spread;
     }
   const int spread_n = ArraySize(spread_samples);
   if(spread_n <= 0)
      return false;
   for(int i = 1; i < spread_n; ++i)
     {
      const double v = spread_samples[i];
      int j = i - 1;
      while(j >= 0 && spread_samples[j] > v)
        {
         spread_samples[j + 1] = spread_samples[j];
         --j;
        }
      spread_samples[j + 1] = v;
     }
   const double median_spread = ((spread_n % 2) == 1)
                                ? spread_samples[spread_n / 2]
                                : 0.5 * (spread_samples[spread_n / 2 - 1] + spread_samples[spread_n / 2]);
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || median_spread <= 0.0)
      return false;
   if((double)current_spread > strategy_spread_mult * median_spread)
      return false;

   const double decile_high = range_high - strategy_decile_threshold * range;
   const double decile_low = range_low + strategy_decile_threshold * range;
   int side = 0;
   if(friday_close > decile_high)
      side = -1;
   else if(friday_close < decile_low)
      side = 1;
   if(side == 0)
      return false;

   const QM_OrderType order_type = (side > 0) ? QM_BUY : QM_SELL;
   const double entry = (order_type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double mid = NormalizeDouble((range_high + range_low) * 0.5, _Digits);
   const double sl_dist = atr * strategy_sl_atr_mult;
   const double sl = NormalizeDouble((order_type == QM_BUY) ? entry - sl_dist : entry + sl_dist, _Digits);
   if(sl <= 0.0 || mid <= 0.0)
      return false;
   if(order_type == QM_BUY && mid <= entry)
      return false;
   if(order_type == QM_SELL && mid >= entry)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = mid;
   req.reason = (order_type == QM_BUY) ? "friday_bottom_decile_monday_long"
                                       : "friday_top_decile_monday_short";

   last_entry_week = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!strategy_news_filter_enabled || !QM_NewsIsAvailable())
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const bool sunday_reopen = (dt.day_of_week == 0 && dt.hour >= strategy_sunday_reopen_hour);
   const bool monday_open = (dt.day_of_week == 1 && dt.hour <= strategy_monday_entry_end_h);
   if(!sunday_reopen && !monday_open)
      return false;

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   return QM_NewsInWindow(utc_time, _Symbol, strategy_news_blackout_min, strategy_news_blackout_min, "HIGH");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
