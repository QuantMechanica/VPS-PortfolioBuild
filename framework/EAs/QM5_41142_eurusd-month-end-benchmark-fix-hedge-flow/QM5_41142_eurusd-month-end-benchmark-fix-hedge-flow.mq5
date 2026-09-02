#property strict
#property version   "5.0"
#property description "QM5_41142 EURUSD month-end benchmark-fix hedge flow"

#include <QM/QM_Common.mqh>
#include <QM/QM_LondonCalendars.mqh>
#include <QM/QM_XetraCashCalendar.mqh>

// Mechanical scope from the APPROVED card: on the last London business day,
// use the sign of completed GDAXI.DWX month-to-date return at 14:00 London to
// hold EURUSD.DWX into (but never beyond) the 16:00 London fix.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41142;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_lead_minutes  = 120;
input int    strategy_atr_period_h1       = 14;
input double strategy_hard_stop_atr       = 2.0;

const string STRATEGY_SIGNAL_SYMBOL = "GDAXI.DWX";
const int STRATEGY_FIX_MINUTE_LONDON = 16 * 60;
const int STRATEGY_BAR_SECONDS = 15 * 60;
const int STRATEGY_WARMUP_BARS = 6000;
const int STRATEGY_DEVIATION_POINTS = 20;
string g_strategy_symbols[2] = {"EURUSD.DWX", "GDAXI.DWX"};
int g_consumed_london_date_key = 0;
string g_consumed_state_key = "";
bool g_closed_this_tick = false;

int Strategy_DateKey(const datetime local_time)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(local_time <= 0 || !TimeToStruct(local_time, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_MinuteOfDay(const datetime local_time)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(local_time <= 0 || !TimeToStruct(local_time, parts))
      return -1;
   return parts.hour * 60 + parts.min;
  }

datetime Strategy_BrokerToLondon(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   if(utc <= 0)
      return 0;
   return QM_LondonCalendarUTCToLondonLocal(utc);
  }

int Strategy_DateKeyAddDays(const int date_key, const int day_delta)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return 0;
   const datetime value = StructToTime(parts);
   MqlDateTime shifted;
   ZeroMemory(shifted);
   if(value <= 0 ||
      !TimeToStruct(value + (long)day_delta * 86400, shifted))
      return 0;
   return shifted.year * 10000 + shifted.mon * 100 + shifted.day;
  }

int Strategy_MonthStartDateKey(const int date_key)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + 1;
  }

int Strategy_PreviousMonthStartDateKey(const int date_key)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return 0;
   int year = parts.year;
   int month = parts.mon - 1;
   if(month < 1)
     {
      month = 12;
      --year;
     }
   return year * 10000 + month * 100 + 1;
  }

bool Strategy_ResolveLondonWindow(const int date_key,
                                  datetime &entry_utc,
                                  datetime &fix_utc,
                                  datetime &entry_broker,
                                  datetime &fix_broker)
  {
   entry_utc = 0;
   fix_utc = 0;
   entry_broker = 0;
   fix_broker = 0;
   if(!QM_LondonCalendarLondonLocalToUTC(date_key, 16, 0, fix_utc))
      return false;
   entry_utc = fix_utc - strategy_entry_lead_minutes * 60;
   entry_broker = QM_UTCToBroker(entry_utc);
   fix_broker = QM_UTCToBroker(fix_utc);
   return (entry_utc > 0 && fix_utc > entry_utc &&
           fix_utc - entry_utc == strategy_entry_lead_minutes * 60 &&
           entry_broker > 0 && fix_broker > entry_broker &&
           QM_BrokerToUTC(entry_broker) == entry_utc &&
           QM_BrokerToUTC(fix_broker) == fix_utc);
  }

bool Strategy_IsLastLondonBusinessDay(const int date_key)
  {
   if(!QM_LondonPublicHolidayCalendarReady())
      return false;
   MqlDateTime today;
   ZeroMemory(today);
   if(!QM_LondonCalendarDateKeyParts(date_key, today) ||
      QM_LondonPublicHolidayClassify(date_key) !=
      QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY)
      return false;
   for(int day = today.day + 1; day <= 31; ++day)
     {
      MqlDateTime probe;
      ZeroMemory(probe);
      probe.year = today.year;
      probe.mon = today.mon;
      probe.day = day;
      const datetime stamp = StructToTime(probe);
      MqlDateTime checked;
      ZeroMemory(checked);
      if(stamp <= 0 || !TimeToStruct(stamp, checked) ||
         checked.year != today.year || checked.mon != today.mon ||
         checked.day != day)
         break;
      const int probe_key = checked.year * 10000 + checked.mon * 100 + checked.day;
      const QM_LondonPublicDayType day_type =
         QM_LondonPublicHolidayClassify(probe_key);
      if(day_type == QM_LONDON_PUBLIC_DAY_INVALID ||
         day_type == QM_LONDON_PUBLIC_DAY_OUT_OF_COVERAGE)
         return false;
      if(day_type == QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY)
         return false;
     }
   return true;
  }

string Strategy_ConsumedGlobalName()
  {
   return StringFormat("QM5_41142_MONTHEND_FIX_%d", QM_FrameworkMagic());
  }

void Strategy_LoadConsumedState()
  {
   g_consumed_state_key = Strategy_ConsumedGlobalName();
   g_consumed_london_date_key = 0;
   if(g_consumed_state_key == "" ||
      !GlobalVariableCheck(g_consumed_state_key))
      return;
   const double stored = GlobalVariableGet(g_consumed_state_key);
   if(MathIsValidNumber(stored) && stored > 0.0)
      g_consumed_london_date_key = (int)stored;
  }

bool Strategy_IsConsumed(const int date_key)
  {
   if(date_key <= 0 || g_consumed_state_key == "")
      return true;
   // A later tester run leaves one future marker. Delete only that impossible
   // marker so a full-history rerun starts clean while same-date restarts stay
   // consumed.
   if(g_consumed_london_date_key > date_key)
     {
      if(GlobalVariableCheck(g_consumed_state_key))
         GlobalVariableDel(g_consumed_state_key);
      g_consumed_london_date_key = 0;
     }
   return (g_consumed_london_date_key == date_key);
  }

bool Strategy_ConsumeBeforeSubmission(const int date_key)
  {
   if(date_key <= 0)
      return false;
   if(Strategy_IsConsumed(date_key))
      return false;
   if(GlobalVariableSet(g_consumed_state_key, (double)date_key) == 0)
      return false;
   GlobalVariablesFlush();
   g_consumed_london_date_key = date_key;
   return true;
  }

bool Strategy_GetOwnedPosition(datetime &opened_at,
                               ulong &ticket_out,
                               bool &integrity_ok)
  {
   opened_at = 0;
   ticket_out = 0;
   integrity_ok = false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int count = 0;
   bool valid = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++count;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop = PositionGetDouble(POSITION_SL);
      const double take = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const bool side_valid =
         (position_type == POSITION_TYPE_BUY ||
          position_type == POSITION_TYPE_SELL);
      const bool stop_valid =
         (side_valid && stop > 0.0 &&
          ((position_type == POSITION_TYPE_BUY && stop < open_price) ||
           (position_type == POSITION_TYPE_SELL && stop > open_price)));
      if(symbol != _Symbol || opened <= 0 ||
         !MathIsValidNumber(open_price) || open_price <= 0.0 ||
         !MathIsValidNumber(stop) || !stop_valid ||
         !MathIsValidNumber(take) || take != 0.0 ||
         !MathIsValidNumber(volume) || volume <= 0.0)
         valid = false;

      if(ticket_out == 0 || opened < opened_at)
        {
         opened_at = opened;
         ticket_out = ticket;
        }
     }
   integrity_ok = (count == 1 && valid);
   return (count > 0);
  }

bool Strategy_HasOwnedPosition()
  {
   datetime opened_at = 0;
   ulong ticket = 0;
   bool integrity_ok = false;
   return Strategy_GetOwnedPosition(opened_at, ticket, integrity_ok);
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         g_closed_this_tick = true;
     }
  }

bool Strategy_SymbolGeometryReady(const QM_OrderType direction,
                                  const MqlTick &tick)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   long trade_mode = 0;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode) ||
      trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      (direction == QM_BUY && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction == QM_SELL && trade_mode == SYMBOL_TRADE_MODE_LONGONLY))
      return false;
   return (MathIsValidNumber(point) && point > 0.0 &&
           MathIsValidNumber(tick_size) && tick_size > 0.0 &&
           MathIsValidNumber(tick_value) && tick_value > 0.0 &&
           MathIsValidNumber(contract_size) && contract_size > 0.0 &&
           MathIsValidNumber(volume_min) && volume_min > 0.0 &&
           MathIsValidNumber(volume_max) && volume_max >= volume_min &&
           MathIsValidNumber(volume_step) && volume_step > 0.0 &&
           MathIsValidNumber(tick.ask) && tick.ask > 0.0 &&
           MathIsValidNumber(tick.bid) && tick.bid > 0.0 &&
           tick.ask >= tick.bid);
  }

bool Strategy_LastXetraSessionBefore(const int current_month_start_key,
                                     int &session_date_key)
  {
   session_date_key = 0;
   int candidate = Strategy_DateKeyAddDays(current_month_start_key, -1);
   for(int step = 0; step < 16; ++step)
     {
      if(candidate <= 0)
         return false;
      const QM_XetraCashSessionType session_type =
         QM_XetraCashCalendarClassify(candidate);
      if(session_type == QM_XETRA_CASH_NORMAL ||
         session_type == QM_XETRA_CASH_EARLY_CLOSE)
        {
         session_date_key = candidate;
         return true;
        }
      if(session_type == QM_XETRA_CASH_INVALID ||
         session_type == QM_XETRA_CASH_OUT_OF_COVERAGE)
         return false;
      candidate = Strategy_DateKeyAddDays(candidate, -1);
     }
   return false;
  }

bool Strategy_GdaxiMonthToDateReturn(const int london_date_key,
                                     const datetime entry_utc,
                                     double &return_value)
  {
   return_value = 0.0;
   if(!QM_SymbolAssertOrLog(STRATEGY_SIGNAL_SYMBOL))
      return false;

   const int current_month_start_key =
      Strategy_MonthStartDateKey(london_date_key);
   const int previous_month_start_key =
      Strategy_PreviousMonthStartDateKey(london_date_key);
   int expected_prior_session_key = 0;
   if(current_month_start_key <= 0 || previous_month_start_key <= 0 ||
      !Strategy_LastXetraSessionBefore(current_month_start_key,
                                       expected_prior_session_key))
      return false;

   datetime previous_month_start_utc = 0;
   datetime current_month_start_utc = 0;
   if(!QM_XetraCashBerlinLocalToUTC(previous_month_start_key, 0, 0,
                                    previous_month_start_utc) ||
      !QM_XetraCashBerlinLocalToUTC(current_month_start_key, 0, 0,
                                    current_month_start_utc))
      return false;
   const datetime signal_bar_open_utc = entry_utc - STRATEGY_BAR_SECONDS;
   const datetime from_broker = QM_UTCToBroker(previous_month_start_utc);
   const datetime current_month_start_broker =
      QM_UTCToBroker(current_month_start_utc);
   const datetime signal_bar_open_broker =
      QM_UTCToBroker(signal_bar_open_utc);
   if(from_broker <= 0 || current_month_start_broker <= from_broker ||
      signal_bar_open_broker <= current_month_start_broker ||
      QM_BrokerToUTC(signal_bar_open_broker) != signal_bar_open_utc)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(STRATEGY_SIGNAL_SYMBOL, PERIOD_M15,
                                from_broker, signal_bar_open_broker,
                                rates); // perf-allowed: one bounded structural month read behind the sole M15 new-bar gate.
   const int size = ArraySize(rates);
   if(copied != size || size < 2)
      return false;

   int prior_close_index = -1;
   datetime previous_time = 0;
   for(int i = 0; i < size; ++i)
     {
      if(i < 0 || i >= ArraySize(rates))
         return false;
      if(rates[i].time <= previous_time ||
         rates[i].time > signal_bar_open_broker ||
         !MathIsValidNumber(rates[i].close) || rates[i].close <= 0.0)
         return false;
      if(rates[i].time < current_month_start_broker)
         prior_close_index = i;
      previous_time = rates[i].time;
     }

   const int latest_index = size - 1;
   if(latest_index < 0 || latest_index >= ArraySize(rates) ||
      prior_close_index < 0 || prior_close_index >= ArraySize(rates) ||
      prior_close_index >= latest_index ||
      rates[latest_index].time != signal_bar_open_broker)
      return false;

   const int actual_prior_session_key =
      QM_XetraCashBerlinDateKeyFromUTC(
         QM_BrokerToUTC(rates[prior_close_index].time));
   const int actual_signal_date_key =
      QM_XetraCashBerlinDateKeyFromUTC(
         QM_BrokerToUTC(rates[latest_index].time));
   if(actual_prior_session_key != expected_prior_session_key ||
      actual_signal_date_key != london_date_key)
      return false;

   return_value = rates[latest_index].close /
                  rates[prior_close_index].close - 1.0;
   return MathIsValidNumber(return_value);
  }

bool Strategy_NewsWindowReady(const datetime entry_utc,
                              const datetime fix_utc,
                              bool &event_overlap)
  {
   event_overlap = false;
   if(!QM_NewsIsLoaded() || !QM_NewsIsAvailable())
      return false;
   if(entry_utc <= 0 || fix_utc - entry_utc != 120 * 60)
      return false;
   event_overlap = QM_NewsInWindow(entry_utc, _Symbol, 120, 0, "HIGH");
   if(event_overlap)
      return true;

   const datetime entry_broker = QM_UTCToBroker(entry_utc);
   const datetime midpoint_broker = QM_UTCToBroker(entry_utc + 60 * 60);
   if(entry_broker <= 0 || midpoint_broker <= 0)
      return false;
   // The uncached checks prove deterministic tester coverage for both halves
   // of the owned window and fail closed on native-calendar errors outside it.
   return (QM_NewsAllowsTrade2Fresh(_Symbol, entry_broker,
                                    QM_NEWS_TEMPORAL_PRE60,
                                    qm_news_compliance) &&
           QM_NewsAllowsTrade2Fresh(_Symbol, midpoint_broker,
                                    QM_NEWS_TEMPORAL_PRE60,
                                    qm_news_compliance));
  }

bool Strategy_NoTradeFilter()
  {
   return (_Symbol != "EURUSD.DWX" || _Period != PERIOD_M15);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   if(g_closed_this_tick || Strategy_HasOwnedPosition() ||
      !QM_LondonPublicHolidayCalendarReady() ||
      !QM_XetraCashCalendarReady())
      return false;

   const datetime current_bar_broker =
      iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: exact current M15 anchor, reached only after the sole framework new-bar gate.
   const datetime current_bar_utc = QM_BrokerToUTC(current_bar_broker);
   const int date_key = QM_LondonCalendarDateKeyFromUTC(current_bar_utc);
   if(current_bar_broker <= 0 || current_bar_utc <= 0 ||
      date_key <= 0 || !Strategy_IsLastLondonBusinessDay(date_key) ||
      Strategy_IsConsumed(date_key))
      return false;

   datetime entry_utc = 0;
   datetime fix_utc = 0;
   datetime entry_broker = 0;
   datetime fix_broker = 0;
   if(!Strategy_ResolveLondonWindow(date_key, entry_utc, fix_utc,
                                    entry_broker, fix_broker) ||
      current_bar_broker < entry_broker ||
      current_bar_broker >= fix_broker ||
      (current_bar_broker - entry_broker) % STRATEGY_BAR_SECONDS != 0)
      return false;

   bool event_overlap = false;
   if(!Strategy_NewsWindowReady(entry_utc, fix_utc, event_overlap))
      return false;
   if(event_overlap)
     {
      Strategy_ConsumeBeforeSubmission(date_key);
      return false;
     }

   double mtd_return = 0.0;
   if(!Strategy_GdaxiMonthToDateReturn(date_key, entry_utc, mtd_return))
      return false;
   if(mtd_return == 0.0)
     {
      Strategy_ConsumeBeforeSubmission(date_key);
      return false;
     }

   const QM_OrderType direction = (mtd_return > 0.0) ? QM_SELL : QM_BUY;
   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(_Symbol, tick) ||
      !Strategy_SymbolGeometryReady(direction, tick))
      return false;
   const double price = (direction == QM_BUY) ? tick.ask : tick.bid;
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
   const double spread_price = tick.ask - tick.bid;
   const double stop_distance = atr_h1 * strategy_hard_stop_atr;
   if(price <= 0.0 || !MathIsValidNumber(atr_h1) || atr_h1 <= 0.0 ||
      !MathIsValidNumber(spread_price) || spread_price < 0.0 ||
      !MathIsValidNumber(stop_distance) || stop_distance <= 0.0 ||
      (spread_price > 0.0 && spread_price >= stop_distance))
      return false;
   const double stop = QM_StopATRFromValue(_Symbol, direction, price,
                                            atr_h1, strategy_hard_stop_atr);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool stop_side_valid =
      (direction == QM_BUY ? (stop > 0.0 && stop < tick.bid)
                           : (stop > tick.ask));
   if(!MathIsValidNumber(stop) || !stop_side_valid ||
      !MathIsValidNumber(point) || point <= 0.0)
      return false;

   const double risk_points = MathAbs(price - stop) / point;
   const double market_distance_points =
      (direction == QM_BUY ? (tick.bid - stop) : (stop - tick.ask)) / point;
   const int broker_stops_level =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(!MathIsValidNumber(risk_points) || risk_points <= 0.0 ||
      !MathIsValidNumber(market_distance_points) ||
      market_distance_points <= 0.0 ||
      (broker_stops_level > 0 &&
       market_distance_points < broker_stops_level))
      return false;
   const ENUM_ORDER_TYPE broker_direction =
      (direction == QM_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   const double risk_lots =
      QM_LotsForRiskAtEntry(_Symbol, risk_points, broker_direction, price);
   if(!MathIsValidNumber(risk_lots) || risk_lots <= 0.0)
      return false;

   // Persist before the request leaves this hook. A broker rejection still
   // consumes the date and cannot produce a re-entry.
   if(!Strategy_ConsumeBeforeSubmission(date_key))
      return false;
   req.type = direction;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = StringFormat("MONTH_END_FIX_MTD_%+.6f", mtd_return);
   req.symbol_slot = 0;
   QM_LogEvent(QM_INFO, "STRATEGY_ENTRY_READY",
               StringFormat("{\"london_date\":%d,\"entry_utc\":%I64d,\"fix_utc\":%I64d,\"mtd_return\":%.12e,\"direction\":\"%s\",\"atr_h1\":%.8f,\"stop\":%.8f}",
                            date_key, (long)entry_utc, (long)fix_utc,
                            mtd_return, direction == QM_BUY ? "BUY" : "SELL",
                            atr_h1, stop));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed initial stop only: never trail, widen, scale, or partially close.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOwnedPosition())
      return false;
   return (Strategy_MinuteOfDay(Strategy_BrokerToLondon(TimeCurrent())) >=
           STRATEGY_FIX_MINUTE_LONDON);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(strategy_entry_lead_minutes != 120 || strategy_atr_period_h1 != 14 ||
      MathAbs(strategy_hard_stop_atr - 2.0) > 1e-9 ||
      _Symbol != "EURUSD.DWX" || _Period != PERIOD_M15)
      return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT,
                        RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   if(!QM_LondonPublicHolidayCalendarLoad() ||
      !SymbolSelect(STRATEGY_SIGNAL_SYMBOL, true))
     {
      QM_LogEvent(QM_ERROR, "SETUP_DATA_MISSING",
                  StringFormat("{\"london_calendar\":\"%s\",\"signal_symbol\":\"%s\"}",
                               QM_LondonPublicHolidayCalendarLastError(),
                               STRATEGY_SIGNAL_SYMBOL));
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41142_eurusd-month-end-benchmark-fix-hedge-flow\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar())
      return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
