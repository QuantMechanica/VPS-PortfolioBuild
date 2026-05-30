#property strict
#property version   "5.0"
#property description "QM5_1202 Quantpedia SP500 RV vs VIX SMA short hedge"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1202;
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
input string strategy_vix_csv_path         = "QM5_1202_vix_daily.csv";
input int    strategy_rv_lookback_d1       = 10;
input int    strategy_vix_sma_period       = 60;
input int    strategy_min_vix_observations = 80;
input int    strategy_min_sp500_d1_bars    = 40;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_vix_stale_days       = 10;
input int    strategy_max_spread_points    = 0;

const string STRATEGY_SYMBOL = "SP500.DWX";

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;

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

int Strategy_DaysBetween(const datetime from_date, const datetime to_date)
  {
   if(from_date <= 0 || to_date <= 0)
      return 0;
   return (int)MathFloor((double)(Strategy_DateFloor(to_date) - Strategy_DateFloor(from_date)) / 86400.0);
  }

bool Strategy_HasOpenShort(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
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
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_TradingStatusValid()
  {
   if(!SymbolSelect(_Symbol, true))
      return false;
   return (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= strategy_max_spread_points);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(sl - entry) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_RealizedVol10(const int lookback, double &rv_annualized_pct)
  {
   rv_annualized_pct = 0.0;
   if(lookback < 2 || Bars(_Symbol, PERIOD_D1) < lookback + 2)
      return false;

   double sum = 0.0;
   double values[];
   ArrayResize(values, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      const double close_now = iClose(_Symbol, PERIOD_D1, i + 1);
      const double close_prev = iClose(_Symbol, PERIOD_D1, i + 2);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;
      const double ret = close_now / close_prev - 1.0;
      values[i] = ret;
      sum += ret;
     }

   const double mean = sum / (double)lookback;
   double variance = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double diff = values[i] - mean;
      variance += diff * diff;
     }

   variance /= (double)lookback;
   rv_annualized_pct = MathSqrt(variance) * MathSqrt(252.0) * 100.0;
   return (rv_annualized_pct > 0.0);
  }

bool Strategy_ReadVixSma(const datetime signal_day, double &vix_sma, datetime &latest_obs)
  {
   vix_sma = 0.0;
   latest_obs = 0;
   if(strategy_vix_csv_path == "" || strategy_vix_sma_period <= 0 || strategy_min_vix_observations < strategy_vix_sma_period)
      return false;

   int handle = FileOpen(strategy_vix_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_vix_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   double closes[];
   datetime dates[];
   ArrayResize(closes, 0);
   ArrayResize(dates, 0);

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string close_field = FileReadString(handle);
      if(date_field == "" && close_field == "")
         continue;

      const datetime row_date = Strategy_ParseDate(date_field);
      const double row_close = StringToDouble(close_field);
      if(row_date <= 0 || row_date > signal_day || row_close <= 0.0)
         continue;

      const int n = ArraySize(closes);
      ArrayResize(closes, n + 1);
      ArrayResize(dates, n + 1);
      closes[n] = row_close;
      dates[n] = row_date;
     }

   FileClose(handle);

   const int count = ArraySize(closes);
   if(count < strategy_min_vix_observations || count < strategy_vix_sma_period)
      return false;

   latest_obs = dates[count - 1];
   if(strategy_vix_stale_days > 0 && Strategy_DaysBetween(latest_obs, signal_day) > strategy_vix_stale_days)
      return false;

   double sum = 0.0;
   for(int i = count - strategy_vix_sma_period; i < count; ++i)
      sum += closes[i];

   vix_sma = sum / (double)strategy_vix_sma_period;
   return (vix_sma > 0.0);
  }

bool Strategy_ShortSignal(const datetime signal_day, double &rv_pct, double &vix_sma)
  {
   rv_pct = 0.0;
   vix_sma = 0.0;

   datetime latest_vix = 0;
   if(!Strategy_RealizedVol10(strategy_rv_lookback_d1, rv_pct))
      return false;
   if(!Strategy_ReadVixSma(signal_day, vix_sma, latest_vix))
      return false;

   return (vix_sma < rv_pct);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(!Strategy_TradingStatusValid())
      return true;
   if(strategy_rv_lookback_d1 < 2 || strategy_vix_sma_period <= 0 || strategy_min_vix_observations < strategy_vix_sma_period)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_sp500_d1_bars, strategy_rv_lookback_d1 + strategy_atr_period_d1 + 5))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenShort(ticket, opened_at))
      return false;

   if(!Strategy_SpreadAllowed())
      return false;

   double rv_pct = 0.0;
   double vix_sma = 0.0;
   if(!Strategy_ShortSignal(signal_bar, rv_pct, vix_sma))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1202_SP500_RV_GT_VIX_SHORT";

   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed initial ATR stop; signal exits are handled at D1 rebalance.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenShort(ticket, opened_at))
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || g_last_exit_bar == signal_bar)
      return false;

   double rv_pct = 0.0;
   double vix_sma = 0.0;
   if(!Strategy_ShortSignal(signal_bar, rv_pct, vix_sma))
     {
      g_last_exit_bar = signal_bar;
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

   string symbols[1] = {STRATEGY_SYMBOL};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, MathMax(strategy_min_sp500_d1_bars, strategy_rv_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1202_qp-sp500-rv-vix-short\"}");
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
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
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
