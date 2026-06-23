#property strict
#property version   "5.0"
#property description "QM5_1139 Quantpedia RSI 35 Rebound - SP500"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1139;
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
input int    strategy_rsi_period          = 14;
input double strategy_entry_rsi           = 35.0;
input double strategy_exit_rsi            = 55.0;
input int    strategy_min_d1_closes       = 60;
input int    strategy_time_stop_days      = 10;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_spread_median_mult  = 3.0;
input int    strategy_spread_lookback_days = 20;

int g_last_entry_date_key = 0;

datetime Strategy_MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
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

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsWeekday(const datetime value)
  {
   const int dow = Strategy_DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

int Strategy_TradingDaysSince(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   datetime cursor = Strategy_DateFloor(open_time);
   const datetime today = Strategy_DateFloor(TimeCurrent());
   int days = 0;
   int guard = 0;

   while(cursor < today && guard < 40)
     {
      cursor += 86400;
      if(Strategy_IsWeekday(cursor))
         ++days;
      ++guard;
     }

   return days;
  }

bool Strategy_GetOurPosition(ulong &ticket_out)
  {
   ticket_out = 0;
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

      ticket_out = ticket;
      return true;
     }

   return false;
  }

bool Strategy_HasWarmup()
  {
   if(strategy_rsi_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_min_d1_closes < 3 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const int warmup_shift = MathMax(strategy_min_d1_closes, strategy_rsi_period + strategy_atr_period);
   const double rsi_warmup = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, warmup_shift);
   const double rsi_recent = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double atr_recent = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   return (rsi_warmup > 0.0 && rsi_recent > 0.0 && atr_recent > 0.0);
  }

bool Strategy_RsiCrossedBelowEntry()
  {
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 2);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   return (rsi_2 > strategy_entry_rsi && rsi_1 < strategy_entry_rsi);
  }

bool Strategy_SpreadAllowsTrade()
  {
   if(strategy_spread_median_mult <= 0.0)
      return true;

   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   const int lookback_bars = MathMax(1, strategy_spread_lookback_days) * 48;
   double spreads[];
   ArrayResize(spreads, lookback_bars);

   int samples = 0;
   for(int shift = 1; shift <= lookback_bars; ++shift)
     {
      const int spread_points = iSpread(_Symbol, PERIOD_M30, shift);
      if(spread_points <= 0)
         continue;

      spreads[samples] = (double)spread_points;
      ++samples;
     }

   if(samples <= 0)
      return true;

   ArrayResize(spreads, samples);
   ArraySort(spreads);

   double median = 0.0;
   const int mid = samples / 2;
   if((samples % 2) == 1)
      median = spreads[mid];
   else
      median = (spreads[mid - 1] + spreads[mid]) * 0.5;

   if(median <= 0.0)
      return true;

   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "SP500.DWX")
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_IsWeekday(TimeCurrent()))
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QP_SP500_RSI35_REBOUND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_HasWarmup())
      return false;

   ulong existing_ticket = 0;
   if(Strategy_GetOurPosition(existing_ticket))
      return false;

   const int entry_date_key = Strategy_DateKey(TimeCurrent());
   if(entry_date_key <= 0 || entry_date_key == g_last_entry_date_key)
      return false;

   if(!Strategy_RsiCrossedBelowEntry())
      return false;
   if(!Strategy_SpreadAllowsTrade())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   g_last_entry_date_key = entry_date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(ticket))
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(rsi > strategy_exit_rsi)
      return true;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   if(Strategy_TradingDaysSince(opened) >= MathMax(1, strategy_time_stop_days))
      return true;

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

   SymbolSelect("SP500.DWX", true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1139\",\"ea\":\"qp-sp500-rsi35-rebound\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
