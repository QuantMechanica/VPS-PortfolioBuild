#property strict
#property version   "5.0"
#property description "QM5_20031 Asian-session FX range fade"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20031_asia-fx-fade, G0 APPROVED 2026-07-22.
// Session eligibility comes from valid broker-clock bars on UTC weekdays.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20031;
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
input ENUM_TIMEFRAMES strategy_signal_tf  = PERIOD_M15;
input double strategy_range_fraction      = 0.75;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points   = 0;

int      g_session_key = 0;
double   g_session_open = 0.0;
double   g_session_high = 0.0;
double   g_session_low = 0.0;
int      g_session_bar_count = 0;
int      g_session_last_minute = -1;
bool     g_session_valid = false;
double   g_prior_range_sum = 0.0;
int      g_prior_range_count = 0;
int      g_last_attempt_key = 0;
datetime g_active_exit_broker = 0;

int DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime UtcDateTime(const int year,
                     const int month,
                     const int day,
                     const int hour,
                     const int minute)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = day;
   parts.hour = hour;
   parts.min = minute;
   return StructToTime(parts);
  }

datetime BrokerDateTime(const int date_key, const int hour, const int minute)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = hour;
   parts.min = minute;
   return StructToTime(parts);
  }

bool IsUtcWeekdayForSession(const int date_key)
  {
   const datetime session_end_broker = BrokerDateTime(date_key, 7, 0);
   const datetime session_end_utc = QM_BrokerToUTC(session_end_broker);
   MqlDateTime parts;
   if(session_end_utc <= 0 || !TimeToStruct(session_end_utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

datetime LastSundayUtc(const int year, const int month, const int hour)
  {
   const int next_year = (month == 12) ? year + 1 : year;
   const int next_month = (month == 12) ? 1 : month + 1;
   const datetime last_day = UtcDateTime(next_year, next_month, 1, 0, 0) - 24 * 60 * 60;
   MqlDateTime parts;
   if(!TimeToStruct(last_day, parts))
      return 0;
   return last_day - parts.day_of_week * 24 * 60 * 60 + hour * 60 * 60;
  }

bool IsUKDSTUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime starts = LastSundayUtc(parts.year, 3, 1);
   const datetime ends = LastSundayUtc(parts.year, 10, 1);
   return (utc >= starts && utc < ends);
  }

datetime FallbackLondonExitBroker(const int date_key)
  {
   const int year = date_key / 10000;
   const int month = (date_key / 100) % 100;
   const int day = date_key % 100;
   datetime exit_utc = UtcDateTime(year, month, day, 8, 0);
   if(IsUKDSTUtc(exit_utc))
      exit_utc -= 60 * 60;
   return QM_UTCToBroker(exit_utc);
  }

bool IsRoutedSymbol(const string symbol)
  {
   return (symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX");
  }

bool FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int MinuteOfDay(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.hour * 60 + parts.min;
  }

void FinalizePriorSession()
  {
   if(!g_session_valid || g_session_bar_count != 28 ||
      g_session_last_minute != 6 * 60 + 45)
      return;
   const double completed_range = g_session_high - g_session_low;
   if(completed_range <= 0.0 || !MathIsValidNumber(completed_range))
      return;
   g_prior_range_sum += completed_range;
   ++g_prior_range_count;
  }

void ResetSession(const int date_key)
  {
   g_session_key = date_key;
   g_session_open = 0.0;
   g_session_high = 0.0;
   g_session_low = 0.0;
   g_session_bar_count = 0;
   g_session_last_minute = -1;
   g_session_valid = IsUtcWeekdayForSession(date_key);
  }

bool AdvanceSessionState()
  {
   const datetime closed_bar = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: one bespoke session-state step behind the framework new-bar gate.
   if(closed_bar <= 0)
      return false;
   const int date_key = DateKey(closed_bar);
   if(date_key <= 0)
      return false;
   if(date_key != g_session_key)
     {
      if(g_session_key > 0)
         FinalizePriorSession();
      ResetSession(date_key);
     }

   const int minute = MinuteOfDay(closed_bar);
   if(minute < 0 || minute >= 7 * 60)
      return true;
   if(!g_session_valid)
      return false;

   const int expected_minute = g_session_bar_count * 15;
   if(minute != expected_minute)
     {
      g_session_valid = false;
      return false;
     }

   const double bar_open = iOpen(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized completed M15 session bar.
   const double bar_high = iHigh(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized completed M15 session bar.
   const double bar_low = iLow(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized completed M15 session bar.
   const double bar_close = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: validates the completed M15 session bar.
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0 ||
      bar_high < bar_low)
     {
      g_session_valid = false;
      return false;
     }

   if(g_session_bar_count == 0)
     {
      g_session_open = bar_open;
      g_session_high = bar_high;
      g_session_low = bar_low;
     }
   else
     {
      g_session_high = MathMax(g_session_high, bar_high);
      g_session_low = MathMin(g_session_low, bar_low);
     }
   ++g_session_bar_count;
   g_session_last_minute = minute;
   return true;
  }

bool TradeGeometryAndVolumeAllow(const double entry_price,
                                 const double stop_price,
                                 const double target_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 || target_distance <= 0.0)
      return false;

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return true;
   return Strategy_WideSpread();
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

   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_range_fraction != 0.75)
      return false;
   if(!AdvanceSessionState() || !g_session_valid || g_prior_range_count <= 0)
      return false;

   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact next-M15-open eligibility behind QM_IsNewBar.
   if(current_bar <= 0 || DateKey(current_bar) != g_session_key)
      return false;
   const int current_minute = MinuteOfDay(current_bar);
   if(current_minute <= 0 || current_minute > 7 * 60 || g_last_attempt_key == g_session_key)
      return false;

   const double signal_close = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized completed signal-bar close.
   const double mean_range = g_prior_range_sum / (double)g_prior_range_count;
   if(signal_close <= 0.0 || mean_range <= 0.0 || !MathIsValidNumber(mean_range))
      return false;
   const double move = signal_close - g_session_open;
   if(MathAbs(move) < strategy_range_fraction * mean_range || move == 0.0)
      return false;

   g_last_attempt_key = g_session_key;
   const bool buy = (move < 0.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = buy ? ask : bid;
   const double target_price = QM_StopRulesNormalizePrice(_Symbol,
                                                           0.5 * (g_session_high + g_session_low));
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         buy ? g_session_open - mean_range
                                                             : g_session_open + mean_range);
   if(stop_price <= 0.0 || target_price <= 0.0 ||
      (buy && !(stop_price < entry_price && entry_price < target_price)) ||
      (!buy && !(target_price < entry_price && entry_price < stop_price)) ||
      !TradeGeometryAndVolumeAllow(entry_price, stop_price, target_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = target_price;
   req.reason = buy ? "ASIA_RANGE_FADE_LONG" : "ASIA_RANGE_FADE_SHORT";
   g_active_exit_broker = FallbackLondonExitBroker(g_session_key);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const int open_key = DateKey(open_time);
      g_active_exit_broker = FallbackLondonExitBroker(open_key);
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline explicitly applies no generic news blackout.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — retained from framework/templates/EA_Skeleton.mq5.
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

   string allowed_symbols[2] = {"EURUSD.DWX", "GBPUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 64);

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
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
