#property strict
#property version   "5.0"
#property description "QM5_12918 Jegadeesh 1W reversal FX"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 7

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12918;
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
input int    strategy_bottom_count              = 2;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 2.0;
input int    strategy_hold_trading_days         = 5;
input int    strategy_min_eligible_symbols      = 5;
input int    strategy_monday_start_hour         = 0;
input int    strategy_monday_end_hour           = 4;
input int    strategy_friday_exit_hour          = 21;
input int    strategy_max_spread_points         = 0;
input bool   strategy_skip_rate_decision_weeks  = true;
input string strategy_rate_calendar_path        = "D:\\QM\\data\\news_calendar\\news_calendar_2015_2025.csv";

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX",
   "NZDUSD.DWX"
  };

int  g_last_entry_week_key = 0;
bool g_rate_weeks_loaded = false;
bool g_rate_weeks_available = false;
int  g_rate_decision_week_keys[];

string Strategy_Upper(const string value)
  {
   string out = value;
   StringToUpper(out);
   return out;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsTarget()
  {
   const int slot = Strategy_SymbolSlot(_Symbol);
   if(slot < 0)
      return false;
   if(qm_magic_slot_offset != slot)
      return false;
   return ((ENUM_TIMEFRAMES)_Period == PERIOD_H1);
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

bool Strategy_EntryWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week != 1)
      return false;
   return (dt.hour >= strategy_monday_start_hour && dt.hour <= strategy_monday_end_hour);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

int Strategy_FindClosedWeekdayShift(const string symbol,
                                    const int weekday,
                                    const int start_shift,
                                    const int max_shift)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return -1;
   for(int shift = start_shift; shift <= max_shift; ++shift)
     {
      const datetime t = iTime(symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Friday lookup from the H1 closed-bar entry path.
      if(t <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.day_of_week == weekday)
         return shift;
     }
   return -1;
  }

bool Strategy_WeeklyReturn(const string symbol, double &out_return)
  {
   out_return = 0.0;
   const int recent_friday = Strategy_FindClosedWeekdayShift(symbol, 5, 1, 10);
   if(recent_friday < 0)
      return false;
   const int prior_friday = Strategy_FindClosedWeekdayShift(symbol, 5, recent_friday + 1, recent_friday + 10);
   if(prior_friday < 0)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, recent_friday); // perf-allowed: bounded D1 close read for weekly cross-sectional rank.
   const double prior_close = iClose(symbol, PERIOD_D1, prior_friday);   // perf-allowed: bounded D1 close read for weekly cross-sectional rank.
   if(recent_close <= 0.0 || prior_close <= 0.0)
      return false;

   out_return = (recent_close / prior_close) - 1.0;
   return true;
  }

int Strategy_BuildWeeklyReturns(double &returns[], bool &eligible[])
  {
   ArrayResize(returns, STRATEGY_SYMBOL_COUNT);
   ArrayResize(eligible, STRATEGY_SYMBOL_COUNT);
   int eligible_count = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      returns[i] = 0.0;
      eligible[i] = false;
      if(!Strategy_WeeklyReturn(g_strategy_symbols[i], returns[i]))
         continue;
      eligible[i] = true;
      eligible_count++;
     }
   return eligible_count;
  }

int Strategy_AscendingRank(const int symbol_slot,
                           const double &returns[],
                           const bool &eligible[])
  {
   if(symbol_slot < 0 || symbol_slot >= STRATEGY_SYMBOL_COUNT)
      return 999;
   if(!eligible[symbol_slot])
      return 999;

   int rank = 1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == symbol_slot || !eligible[i])
         continue;
      if(returns[i] < returns[symbol_slot])
         rank++;
      else if(returns[i] == returns[symbol_slot] && i < symbol_slot)
         rank++;
     }
   return rank;
  }

bool Strategy_IsG10Currency(const string raw_currency)
  {
   const string currency = Strategy_Upper(QM_NewsStripQuotes(raw_currency));
   return (currency == "USD" || currency == "EUR" || currency == "GBP" ||
           currency == "JPY" || currency == "AUD" || currency == "CAD" ||
           currency == "CHF" || currency == "NZD");
  }

bool Strategy_IsRateDecisionEvent(const string raw_currency, const string raw_event)
  {
   if(!Strategy_IsG10Currency(raw_currency))
      return false;

   const string event_upper = Strategy_Upper(QM_NewsStripQuotes(raw_event));
   if(StringLen(event_upper) == 0)
      return false;
   if(StringFind(event_upper, "SPEAK") >= 0 || StringFind(event_upper, "MINUTES") >= 0)
      return false;

   if(StringFind(event_upper, "FOMC") >= 0 &&
      (StringFind(event_upper, "STATEMENT") >= 0 ||
       StringFind(event_upper, "PRESS CONFERENCE") >= 0 ||
       StringFind(event_upper, "ECONOMIC PROJECTIONS") >= 0))
      return true;

   if(StringFind(event_upper, "MONETARY POLICY") >= 0 &&
      (StringFind(event_upper, "STATEMENT") >= 0 || StringFind(event_upper, "DECISION") >= 0))
      return true;

   if(StringFind(event_upper, "RATE") < 0)
      return false;
   if(StringFind(event_upper, "UNEMPLOYMENT") >= 0 || StringFind(event_upper, "PARTICIPATION") >= 0)
      return false;

   return (StringFind(event_upper, "BANK") >= 0 ||
           StringFind(event_upper, "CASH") >= 0 ||
           StringFind(event_upper, "POLICY") >= 0 ||
           StringFind(event_upper, "REFINANCING") >= 0 ||
           StringFind(event_upper, "FEDERAL FUNDS") >= 0 ||
           StringFind(event_upper, "OVERNIGHT") >= 0 ||
           StringFind(event_upper, "INTEREST") >= 0);
  }

int Strategy_WeekKeyFromUTC(const datetime event_utc)
  {
   datetime broker_time = QM_UTCToBroker(event_utc);
   if(broker_time <= 0)
      broker_time = event_utc;
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 1000 + (dt.day_of_year / 7);
  }

bool Strategy_RateWeekKeyExists(const int key)
  {
   const int n = ArraySize(g_rate_decision_week_keys);
   for(int i = 0; i < n; ++i)
      if(g_rate_decision_week_keys[i] == key)
         return true;
   return false;
  }

void Strategy_AddRateWeekKey(const int key)
  {
   if(key <= 0 || Strategy_RateWeekKeyExists(key))
      return;
   const int n = ArraySize(g_rate_decision_week_keys);
   ArrayResize(g_rate_decision_week_keys, n + 1);
   g_rate_decision_week_keys[n] = key;
  }

bool Strategy_LoadRateDecisionWeeks()
  {
   g_rate_weeks_loaded = true;
   g_rate_weeks_available = false;
   ArrayResize(g_rate_decision_week_keys, 0);

   int handle = FileOpen(strategy_rate_calendar_path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(QM_NewsBasename(strategy_rate_calendar_path), FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0)
         continue;

      string fields[];
      const int n = StringSplit(line, ',', fields);
      if(n < 4)
         continue;
      if(rows == 0 && Strategy_Upper(QM_NewsStripQuotes(fields[0])) == "DATETIME")
        {
         rows++;
         continue;
        }
      rows++;

      datetime event_utc = 0;
      if(!QM_NewsParseDateTimeUTC(fields[0], event_utc))
         continue;
      if(!Strategy_IsRateDecisionEvent(fields[1], fields[2]))
         continue;
      Strategy_AddRateWeekKey(Strategy_WeekKeyFromUTC(event_utc));
     }

   FileClose(handle);
   g_rate_weeks_available = (ArraySize(g_rate_decision_week_keys) > 0);
   return g_rate_weeks_available;
  }

bool Strategy_RateDecisionWeekBlocked()
  {
   if(!strategy_skip_rate_decision_weeks)
      return false;
   if(!g_rate_weeks_loaded && !Strategy_LoadRateDecisionWeeks())
      return true;
   if(!g_rate_weeks_available)
      return true;

   const int week_key = QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   return Strategy_RateWeekKeyExists(week_key);
  }

int Strategy_OpenPositionD1Age()
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
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: O(1) time-stop age lookup for the single open position.
      if(shift >= 0)
         return shift;
     }
   return -1;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_bottom_count <= 0 || strategy_bottom_count > STRATEGY_SYMBOL_COUNT)
      return true;
   if(strategy_min_eligible_symbols < strategy_bottom_count || strategy_min_eligible_symbols > STRATEGY_SYMBOL_COUNT)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_hold_trading_days <= 0)
      return true;
   if(strategy_monday_start_hour < 0 || strategy_monday_start_hour > 23)
      return true;
   if(strategy_monday_end_hour < strategy_monday_start_hour || strategy_monday_end_hour > 23)
      return true;
   if(strategy_friday_exit_hour < 0 || strategy_friday_exit_hour > 23)
      return true;
   if(Strategy_WideSpread())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "JEGADEESH_1W_FX_REVERSAL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_EntryWindow(TimeCurrent()))
      return false;
   if(Strategy_RateDecisionWeekBlocked())
      return false;

   const int week_key = QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   double returns[];
   bool eligible[];
   const int eligible_count = Strategy_BuildWeeklyReturns(returns, eligible);
   if(eligible_count < strategy_min_eligible_symbols)
      return false;

   const int symbol_slot = Strategy_SymbolSlot(_Symbol);
   const int rank = Strategy_AscendingRank(symbol_slot, returns, eligible);
   if(rank > strategy_bottom_count)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_exit_hour)
      return true;

   const int d1_age = Strategy_OpenPositionD1Age();
   return (d1_age >= strategy_hold_trading_days);
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, 80);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_H1, 240);

   if(strategy_skip_rate_decision_weeks && !Strategy_LoadRateDecisionWeeks())
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING, "{\"component\":\"rate_decision_calendar\"}");
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12918\",\"ea\":\"jegadeesh-1w-reversal-fx\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
