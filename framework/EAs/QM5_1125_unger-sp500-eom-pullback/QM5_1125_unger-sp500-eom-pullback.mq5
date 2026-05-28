#property strict
#property version   "5.0"
#property description "QM5_1125 Unger SP500 End-of-Month Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1125;
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
input int    strategy_entry_trading_days_to_month_end = 4;
input int    strategy_atr_period          = 5;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_midpoint_fraction   = 0.5;
input double strategy_max_gap_stop_mult   = 1.5;
input bool   strategy_spread_filter_enabled = true;
input int    strategy_max_spread_points   = 0;

datetime g_last_signal_bar = 0;

int Strategy_SymbolSlot()
  {
   if(_Symbol == "SP500.DWX")
      return 0;
   if(_Symbol == "NDX.DWX")
      return 1;
   if(_Symbol == "WS30.DWX")
      return 2;
   return qm_magic_slot_offset;
  }

bool Strategy_IsAllowedSymbol()
  {
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsWeekday(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.day_of_week >= MONDAY && dt.day_of_week <= FRIDAY);
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

datetime Strategy_MonthStart(const int year, const int month)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   return StructToTime(dt);
  }

datetime Strategy_NextMonthStart(const int year, const int month)
  {
   if(month >= 12)
      return Strategy_MonthStart(year + 1, 1);
   return Strategy_MonthStart(year, month + 1);
  }

int Strategy_WeekdaysToMonthEndInclusive(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);

   const datetime next_month = Strategy_NextMonthStart(dt.year, dt.mon);
   const datetime last_day = next_month - 86400;

   int count = 0;
   datetime day = Strategy_DayStart(t);
   while(day <= last_day)
     {
      if(Strategy_IsWeekday(day))
         ++count;
      day += 86400;
     }
   return count;
  }

bool Strategy_PreviousMonthRange(const datetime t, double &month_high, double &month_low)
  {
   month_high = -DBL_MAX;
   month_low = DBL_MAX;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);

   int prev_year = dt.year;
   int prev_month = dt.mon - 1;
   if(prev_month <= 0)
     {
      prev_month = 12;
      --prev_year;
     }

   const datetime from_time = Strategy_MonthStart(prev_year, prev_month);
   const datetime to_time = Strategy_MonthStart(dt.year, dt.mon);
   bool found = false;

   for(int shift = 1; shift < 80; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift);
      if(bar_time <= 0)
         break;
      if(bar_time < from_time)
         break;
      if(bar_time >= to_time)
         continue;

      const double high = iHigh(_Symbol, PERIOD_D1, shift);
      const double low = iLow(_Symbol, PERIOD_D1, shift);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         continue;

      month_high = MathMax(month_high, high);
      month_low = MathMin(month_low, low);
      found = true;
     }

   return (found && month_high > month_low && month_low < DBL_MAX);
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsAllowedSymbol())
      return true;

   if(strategy_spread_filter_enabled && strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "UNGER_SP500_EOM_PULLBACK_LONG";
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime entry_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(signal_bar <= 0 || entry_bar <= 0)
      return false;
   if(signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   if(Strategy_MonthKey(signal_bar) != Strategy_MonthKey(entry_bar))
      return false;
   if(Strategy_WeekdaysToMonthEndInclusive(signal_bar) != strategy_entry_trading_days_to_month_end)
      return false;

   double prev_high = 0.0;
   double prev_low = 0.0;
   if(!Strategy_PreviousMonthRange(signal_bar, prev_high, prev_low))
      return false;

   const double midpoint = prev_low + strategy_midpoint_fraction * (prev_high - prev_low);
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1);
   if(signal_close <= 0.0 || signal_close >= midpoint)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   const double open_price = iOpen(_Symbol, PERIOD_D1, 0);
   const double stop_distance = strategy_atr_sl_mult * atr;
   if(open_price > 0.0 && strategy_max_gap_stop_mult > 0.0)
     {
      const double gap = MathAbs(open_price - signal_close);
      if(gap > strategy_max_gap_stop_mult * stop_distance)
         return false;
     }

   req.sl = NormalizeDouble(entry - stop_distance, _Digits);
   return (req.sl > 0.0 && req.sl < entry);
  }

void Strategy_ManageOpenPosition()
  {
   // Card default: no trailing, break-even, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKey(open_time) != Strategy_MonthKey(now))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1125\",\"card\":\"unger-sp500-eom-pullback\"}");
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
