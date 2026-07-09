#property strict
#property version   "5.0"
#property description "QM5_13078 XTI post-driving-holiday gasoline pull-forward fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13078 - XTI Post-Holiday Gasoline Pull-Forward Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - Memorial Day, observed Independence Day, and Labor Day only
//   - short-only on the first scheduled trading day after the holiday
//   - requires a pre-holiday rally into the driving-demand window
//   - ATR stop/target, mean-reclaim exit, and time stop
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13078;
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
input int    strategy_rally_lookback_days = 5;
input int    strategy_trend_period        = 20;
input int    strategy_atr_period          = 20;
input double strategy_min_rally_atr       = 0.70;
input double strategy_max_post_drop_atr   = 1.25;
input double strategy_mean_reclaim_atr    = 0.20;
input double strategy_atr_sl_mult         = 2.60;
input double strategy_atr_tp_mult         = 2.20;
input int    strategy_max_hold_days       = 7;
input int    strategy_max_spread_points   = 1000;

int      g_last_entry_holiday_key = 0;
datetime g_last_manage_d1_bar = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

datetime Strategy_DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int Strategy_YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

int Strategy_HolidayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_DateFloor(value), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_NthWeekdayOfMonth(const int year,
                                    const int month,
                                    const int weekday,
                                    const int ordinal)
  {
   const datetime month_start = Strategy_MakeDate(year, month, 1);
   int seen = 0;
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
        {
         seen++;
         if(seen == ordinal)
            return Strategy_DateFloor(candidate);
        }
     }
   return 0;
  }

datetime Strategy_LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   datetime found = 0;
   const datetime month_start = Strategy_MakeDate(year, month, 1);
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
         found = Strategy_DateFloor(candidate);
     }
   return found;
  }

datetime Strategy_ObservedFixedHoliday(const int year, const int month, const int day)
  {
   const datetime actual = Strategy_MakeDate(year, month, day);
   const int dow = Strategy_DayOfWeek(actual);
   if(dow == 0)
      return actual + 86400;
   if(dow == 6)
      return actual - 86400;
   return actual;
  }

bool Strategy_IsWeekday(const datetime value)
  {
   const int dow = Strategy_DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

bool Strategy_HasScheduledTradeSession(const datetime value)
  {
   if(!Strategy_IsWeekday(value))
      return false;

   MqlDateTime dt;
   TimeToStruct(value, dt);

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, session_from, session_to))
         return true;
     }

   return true;
  }

datetime Strategy_NextScheduledTradingDayAfter(const datetime value)
  {
   datetime candidate = Strategy_DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(Strategy_HasScheduledTradeSession(candidate))
         return Strategy_DateFloor(candidate);
      candidate += 86400;
     }
   return 0;
  }

datetime Strategy_DrivingHolidayForEntryDay(const datetime entry_day)
  {
   const datetime d = Strategy_DateFloor(entry_day);
   const int year = Strategy_YearOf(d);

   datetime holidays[6];
   int count = 0;
   holidays[count++] = Strategy_LastWeekdayOfMonth(year, 5, 1);
   holidays[count++] = Strategy_ObservedFixedHoliday(year, 7, 4);
   holidays[count++] = Strategy_NthWeekdayOfMonth(year, 9, 1, 1);
   holidays[count++] = Strategy_LastWeekdayOfMonth(year - 1, 5, 1);
   holidays[count++] = Strategy_ObservedFixedHoliday(year - 1, 7, 4);
   holidays[count++] = Strategy_NthWeekdayOfMonth(year - 1, 9, 1, 1);

   for(int i = 0; i < count; ++i)
     {
      if(holidays[i] <= 0)
         continue;
      const datetime post_holiday = Strategy_NextScheduledTradingDayAfter(holidays[i]);
      if(post_holiday > 0 && Strategy_DateFloor(post_holiday) == d)
         return Strategy_DateFloor(holidays[i]);
     }

   return 0;
  }

bool Strategy_HasOpenPosition()
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

int Strategy_BarShiftOnOrBefore(const datetime day)
  {
   const datetime target = Strategy_DateFloor(day);
   for(int shift = 1; shift <= 15; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded holiday-window scan behind single new-bar gate.
      if(bar_time <= 0)
         break;
      if(Strategy_DateFloor(bar_time) <= target)
         return shift;
     }
   return -1;
  }

bool Strategy_LoadSignalState(datetime &holiday,
                              double &atr_last,
                              double &sma_last,
                              double &holiday_close)
  {
   holiday = 0;
   atr_last = 0.0;
   sma_last = 0.0;
   holiday_close = 0.0;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: entry-day calendar state behind single new-bar gate.
   if(current_d1 <= 0)
      return false;

   holiday = Strategy_DrivingHolidayForEntryDay(current_d1);
   if(holiday <= 0)
      return false;

   const int holiday_key = Strategy_HolidayKey(holiday);
   if(holiday_key == g_last_entry_holiday_key)
      return false;

   const int signal_shift = Strategy_BarShiftOnOrBefore(holiday);
   if(signal_shift < 1)
      return false;

   const int lookback = MathMax(1, strategy_rally_lookback_days);
   const int lookback_shift = signal_shift + lookback;
   if(Bars(_Symbol, PERIOD_D1) <= lookback_shift + 2) // perf-allowed: cheap D1 history guard behind single new-bar gate.
      return false;
   if(iTime(_Symbol, PERIOD_D1, lookback_shift) <= 0) // perf-allowed: bounded lookback validation behind single new-bar gate.
      return false;

   holiday_close = iClose(_Symbol, PERIOD_D1, signal_shift);       // perf-allowed: completed pre/post-holiday signal close.
   const double lookback_close = iClose(_Symbol, PERIOD_D1, lookback_shift); // perf-allowed: bounded rally-reference close.
   if(holiday_close <= 0.0 || lookback_close <= 0.0)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, signal_shift);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, signal_shift, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   if(holiday_close <= sma_last)
      return false;

   const double rally_distance = holiday_close - lookback_close;
   if(rally_distance < strategy_min_rally_atr * atr_last)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;
   if(holiday_close - bid > strategy_max_post_drop_atr * atr_last)
      return false;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_rally_lookback_days <= 0)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_rally_atr <= 0.0 || strategy_max_post_drop_atr < 0.0)
      return true;
   if(strategy_mean_reclaim_atr < 0.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13078_XTI_HOLIDAY_GAS_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   datetime holiday = 0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double holiday_close = 0.0;
   if(!Strategy_LoadSignalState(holiday, atr_last, sma_last, holiday_close))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl <= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price - strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0 || req.tp >= entry_price)
      return false;

   g_last_entry_holiday_key = Strategy_HolidayKey(holiday);
   req.reason = "XTI_POST_DRIVING_HOLIDAY_GAS_FADE_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 management gate.
   if(current_d1 <= 0 || current_d1 == g_last_manage_d1_bar)
      return;
   g_last_manage_d1_bar = current_d1;

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 mean-reclaim state.
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(close_last > 0.0 && atr_last > 0.0 && sma_last > 0.0)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_SELL && close_last <= sma_last - strategy_mean_reclaim_atr * atr_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13078\",\"ea\":\"xti-holiday-gas-fade\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
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
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
