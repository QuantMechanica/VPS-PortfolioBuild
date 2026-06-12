#property strict
#property version   "5.0"
#property description "QM5_10763 FX month-end hedge rebalancing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10763;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_signal_symbol                 = "SP500.DWX";
input double strategy_mtd_threshold_pct             = 2.0;
input int    strategy_atr_period                    = 14;
input double strategy_atr_sl_mult                   = 1.5;
input int    strategy_entry_broker_hour_non_us_dst  = 16;
input int    strategy_entry_broker_hour_us_dst      = 15;
input int    strategy_exit_broker_hour_non_us_dst   = 18;
input int    strategy_exit_broker_hour_us_dst       = 17;
input int    strategy_news_blackout_minutes         = 120;
input double strategy_max_spread_points             = 0.0;

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_DayOfWeek(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   datetime t = StructToTime(dt);
   MqlDateTime checked;
   TimeToStruct(t, checked);
   return checked.day_of_week;
  }

int Strategy_NthSunday(const int year, const int month, const int nth)
  {
   int seen = 0;
   const int days = Strategy_DaysInMonth(year, month);
   for(int day = 1; day <= days; ++day)
     {
      if(Strategy_DayOfWeek(year, month, day) != 0)
         continue;
      seen++;
      if(seen == nth)
         return day;
     }
   return 0;
  }

bool Strategy_IsUSDST(const MqlDateTime &dt)
  {
   const int start_day = Strategy_NthSunday(dt.year, 3, 2);
   const int end_day = Strategy_NthSunday(dt.year, 11, 1);
   if(dt.mon > 3 && dt.mon < 11)
      return true;
   if(dt.mon < 3 || dt.mon > 11)
      return false;
   if(dt.mon == 3)
      return (dt.day >= start_day);
   return (dt.day < end_day);
  }

int Strategy_EntryHour(const MqlDateTime &dt)
  {
   return Strategy_IsUSDST(dt) ? strategy_entry_broker_hour_us_dst : strategy_entry_broker_hour_non_us_dst;
  }

int Strategy_ExitHour(const MqlDateTime &dt)
  {
   return Strategy_IsUSDST(dt) ? strategy_exit_broker_hour_us_dst : strategy_exit_broker_hour_non_us_dst;
  }

bool Strategy_IsLastBusinessDay(const MqlDateTime &dt)
  {
   int day = Strategy_DaysInMonth(dt.year, dt.mon);
   while(day > 0)
     {
      const int dow = Strategy_DayOfWeek(dt.year, dt.mon, day);
      if(dow != 0 && dow != 6)
         break;
      day--;
     }
   return (dt.day == day);
  }

bool Strategy_IsEntryGateTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (Strategy_IsLastBusinessDay(dt) && dt.hour == Strategy_EntryHour(dt));
  }

bool Strategy_IsExitGateTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (Strategy_IsLastBusinessDay(dt) && dt.hour >= Strategy_ExitHour(dt));
  }

bool Strategy_IsTargetSymbol(const string symbol)
  {
   return (symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX" || symbol == "AUDUSD.DWX" ||
           symbol == "USDJPY.DWX" || symbol == "USDCHF.DWX" || symbol == "USDCAD.DWX");
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

int Strategy_DirectionForSymbol(const string symbol, const double signal_return_pct)
  {
   if(MathAbs(signal_return_pct) <= strategy_mtd_threshold_pct)
      return 0;

   const bool short_usd = (signal_return_pct > strategy_mtd_threshold_pct);
   if(symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX" || symbol == "AUDUSD.DWX")
      return short_usd ? 1 : -1;
   if(symbol == "USDJPY.DWX" || symbol == "USDCHF.DWX" || symbol == "USDCAD.DWX")
      return short_usd ? -1 : 1;
   return 0;
  }

double Strategy_MTDReturnPct(const datetime broker_time)
  {
   if(!SymbolSelect(strategy_signal_symbol, true))
      return 0.0;

   MqlDateTime now_dt;
   TimeToStruct(broker_time, now_dt);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(strategy_signal_symbol, PERIOD_D1, 1, 45, rates); // perf-allowed: bounded D1 signal feed read, called only after the framework QM_IsNewBar-gated entry path and the month-end time filter.
   if(copied < 2)
      return 0.0;

   const double recent_close = rates[0].close;
   if(recent_close <= 0.0)
      return 0.0;

   double base_close = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      if(bar_dt.year == now_dt.year && bar_dt.mon == now_dt.mon)
         continue;
      base_close = rates[i].close;
      break;
     }

   if(base_close <= 0.0)
      return 0.0;
   return 100.0 * (recent_close / base_close - 1.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_IsTargetSymbol(_Symbol))
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)spread_points > strategy_max_spread_points)
         return true;
     }

   return !Strategy_IsEntryGateTime(TimeCurrent());
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

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsEntryGateTime(TimeCurrent()))
      return false;

   const double signal_return_pct = Strategy_MTDReturnPct(TimeCurrent());
   const int direction = Strategy_DirectionForSymbol(_Symbol, signal_return_pct);
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = StringFormat("FX_MONTH_END_REBAL_MTD_%.2f", signal_return_pct);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, or partial close.
  }

bool Strategy_ExitSignal()
  {
   return Strategy_IsExitGateTime(TimeCurrent());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_news_blackout_minutes <= 0)
      return false;

   if(!QM_NewsIsLoaded())
     {
      if(!QM_NewsInit("D:\\QM\\data\\news_calendar",
                      qm_news_stale_max_hours,
                      strategy_news_blackout_minutes,
                      strategy_news_blackout_minutes,
                      qm_news_min_impact))
         return true;
     }

   if(!QM_NewsIsAvailable())
      return true;

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();

   return QM_NewsInWindow(utc_time,
                          _Symbol,
                          strategy_news_blackout_minutes,
                          strategy_news_blackout_minutes,
                          "HIGH");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10763_fx-month-end-rebal\",\"ea\":\"QM5_10763\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
