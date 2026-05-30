#property strict
#property version   "5.0"
#property description "QM5_1183 Quantpedia Box-PPI SP500 Risk Switch"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1183;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_ppi_csv_path         = "QM5_1183_box_ppi_monthly.csv";
input int    strategy_ppi_sma_months       = 6;
input int    strategy_ppi_lag_months       = 1;
input int    strategy_ppi_stale_months     = 3;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_min_d1_bars          = 80;
input int    strategy_max_spread_points    = 0;

const string STRATEGY_SYMBOL = "SP500.DWX";

datetime g_last_entry_signal_day = 0;
datetime g_last_exit_signal_day = 0;

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(StringSubstr(s, 0, 10) + " 00:00");
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

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 12 + dt.mon;
  }

int Strategy_MonthsBetween(const datetime from_date, const datetime to_date)
  {
   if(from_date <= 0 || to_date <= 0)
      return 0;
   return Strategy_MonthKey(to_date) - Strategy_MonthKey(from_date);
  }

bool Strategy_IsMonthTurnSignalDay(const datetime signal_day)
  {
   if(signal_day <= 0)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime signal_dt;
   MqlDateTime current_dt;
   TimeToStruct(signal_day, signal_dt);
   TimeToStruct(current_day, current_dt);
   return (signal_dt.year != current_dt.year || signal_dt.mon != current_dt.mon);
  }

bool Strategy_ReadPpiSignal(const datetime signal_day, bool &long_allowed, double &latest_ppi, double &sma_value, datetime &obs_date)
  {
   long_allowed = false;
   latest_ppi = 0.0;
   sma_value = 0.0;
   obs_date = 0;

   const int sma_months = MathMax(2, strategy_ppi_sma_months);
   const int lag_months = MathMax(1, strategy_ppi_lag_months);
   const int max_obs_month_key = Strategy_MonthKey(signal_day) - lag_months;
   if(max_obs_month_key <= 0 || strategy_ppi_csv_path == "")
      return false;

   int handle = FileOpen(strategy_ppi_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_ppi_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   double values[];
   datetime dates[];

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string ppi_field = FileReadString(handle);
      if(date_field == "" && ppi_field == "")
         continue;

      const datetime row_date = Strategy_ParseDate(date_field);
      if(row_date <= 0 || Strategy_MonthKey(row_date) > max_obs_month_key)
         continue;

      const double row_ppi = StringToDouble(ppi_field);
      if(row_ppi <= 0.0)
         continue;

      const int n = ArraySize(values);
      ArrayResize(values, n + 1);
      ArrayResize(dates, n + 1);
      values[n] = row_ppi;
      dates[n] = row_date;
     }

   FileClose(handle);

   const int count = ArraySize(values);
   if(count < sma_months)
      return false;

   obs_date = dates[count - 1];
   latest_ppi = values[count - 1];
   if(obs_date <= 0 || latest_ppi <= 0.0)
      return false;

   if(Strategy_MonthsBetween(obs_date, signal_day) > MathMax(lag_months, strategy_ppi_stale_months))
      return false;

   double sum = 0.0;
   for(int i = count - sma_months; i < count; ++i)
      sum += values[i];

   sma_value = sum / (double)sma_months;
   if(sma_value <= 0.0)
      return false;

   long_allowed = (latest_ppi < sma_value);
   return true;
  }

bool Strategy_BoxPpiLongSignal(const datetime signal_day)
  {
   bool long_allowed = false;
   double latest_ppi = 0.0;
   double sma_value = 0.0;
   datetime obs_date = 0;
   if(!Strategy_ReadPpiSignal(signal_day, long_allowed, latest_ppi, sma_value, obs_date))
      return false;
   return long_allowed;
  }

bool Strategy_HasOpenPosition(ulong &ticket, double &open_price)
  {
   ticket = 0;
   open_price = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }

   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, strategy_atr_period_d1 + 10))
      return true;
   if(strategy_ppi_sma_months < 2 || strategy_ppi_lag_months < 1 || strategy_ppi_stale_months < 1)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
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

   const datetime signal_day = Strategy_DateFloor(iTime(_Symbol, PERIOD_D1, 1));
   if(!Strategy_IsMonthTurnSignalDay(signal_day) || g_last_entry_signal_day == signal_day)
      return false;
   g_last_entry_signal_day = signal_day;

   ulong ticket = 0;
   double open_price = 0.0;
   if(Strategy_HasOpenPosition(ticket, open_price))
      return false;

   if(!Strategy_BoxPpiLongSignal(signal_day))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = "QM5_1183_BOX_PPI_SP500_LONG";

   return Strategy_StopDistanceAllowed(entry, req.sl);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies only an initial ATR stop and monthly signal exits.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   double open_price = 0.0;
   if(!Strategy_HasOpenPosition(ticket, open_price))
      return false;

   const datetime signal_day = Strategy_DateFloor(iTime(_Symbol, PERIOD_D1, 1));
   if(!Strategy_IsMonthTurnSignalDay(signal_day) || g_last_exit_signal_day == signal_day)
      return false;

   bool long_allowed = false;
   double latest_ppi = 0.0;
   double sma_value = 0.0;
   datetime obs_date = 0;
   if(!Strategy_ReadPpiSignal(signal_day, long_allowed, latest_ppi, sma_value, obs_date))
      return false;

   g_last_exit_signal_day = signal_day;
   return !long_allowed;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1183\",\"ea\":\"qp-boxppi-sp500-risk\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
