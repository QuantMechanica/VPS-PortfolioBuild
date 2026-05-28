#property strict
#property version   "5.0"
#property description "QM5_1167 Quantpedia Inflation Gold Bond Timing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1167;
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
input string strategy_macro_csv_path       = "QM5_1167_inflation_gold_bond.csv";
input int    strategy_cpi_release_lag_days = 15;
input int    strategy_rebalance_day        = 16;
input int    strategy_momentum_12m_bars    = 252;
input int    strategy_min_d1_bars          = 270;
input int    strategy_macro_stale_days     = 62;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 5.0;
input int    strategy_max_spread_points    = 0;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;
datetime g_last_bond_log_day = 0;

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

bool Strategy_TextMeansAccelerating(const string raw, bool &is_accelerating)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);

   if(s == "ACCELERATING" || s == "ACCEL" || s == "UP" || s == "RISING" || s == "1" || s == "TRUE")
     {
      is_accelerating = true;
      return true;
     }
   if(s == "DECELERATING" || s == "DECEL" || s == "DOWN" || s == "FALLING" || s == "-1" || s == "0" || s == "FALSE")
     {
      is_accelerating = false;
      return true;
     }

   return false;
  }

bool Strategy_ReadLatestMacroRegime(const datetime signal_day,
                                    bool &is_accelerating,
                                    double &treasury_momentum,
                                    datetime &obs_date)
  {
   is_accelerating = false;
   treasury_momentum = 0.0;
   obs_date = 0;

   if(strategy_macro_csv_path == "")
      return false;

   const datetime max_obs_date = signal_day - MathMax(0, strategy_cpi_release_lag_days) * 86400;
   int handle = FileOpen(strategy_macro_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_macro_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string regime_field = FileReadString(handle);
      const string treasury_field = FileReadString(handle);
      if(date_field == "" && regime_field == "" && treasury_field == "")
         continue;

      const datetime row_date = Strategy_ParseDate(date_field);
      if(row_date <= 0 || row_date > max_obs_date)
         continue;

      bool row_accelerating = false;
      if(!Strategy_TextMeansAccelerating(regime_field, row_accelerating))
         continue;

      if(row_date >= obs_date)
        {
         obs_date = row_date;
         is_accelerating = row_accelerating;
         treasury_momentum = StringToDouble(treasury_field);
        }
     }

   FileClose(handle);
   if(obs_date <= 0)
      return false;
   if(strategy_macro_stale_days > 0 && (signal_day - obs_date) > strategy_macro_stale_days * 86400)
      return false;

   return true;
  }

bool Strategy_ReturnOverBars(const string symbol, const int lookback_bars, double &out_return)
  {
   out_return = 0.0;
   if(lookback_bars <= 0)
      return false;
   if(Bars(symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, lookback_bars + 5))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double past_close = iClose(symbol, PERIOD_D1, 1 + lookback_bars);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   out_return = (recent_close / past_close) - 1.0;
   return true;
  }

bool Strategy_IsMonthlyRebalanceDay(const datetime closed_day)
  {
   if(closed_day <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(closed_day, dt);
   const int rebalance_day = MathMax(1, MathMin(28, strategy_rebalance_day));
   if(dt.day < rebalance_day)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime current_dt;
   TimeToStruct(current_day, current_dt);
   if(current_dt.year == dt.year && current_dt.mon == dt.mon && current_dt.day > rebalance_day)
      return (dt.day == rebalance_day);

   return (current_dt.year != dt.year || current_dt.mon != dt.mon || dt.day == rebalance_day);
  }

bool Strategy_GoldSignalOn(const datetime signal_day, double &gold_momentum, double &treasury_momentum)
  {
   gold_momentum = 0.0;
   treasury_momentum = 0.0;

   bool accelerating = false;
   datetime obs_date = 0;
   if(!Strategy_ReadLatestMacroRegime(signal_day, accelerating, treasury_momentum, obs_date))
      return false;
   if(!Strategy_ReturnOverBars(STRATEGY_SYMBOL, strategy_momentum_12m_bars, gold_momentum))
      return false;

   if(!accelerating && treasury_momentum > 0.0 && g_last_bond_log_day != signal_day)
     {
      QM_LogEvent(QM_INFO, "BOND_SIGNAL_ON", StringFormat("{\"date\":%I64d,\"treasury_momentum\":%.6f}", (long)signal_day, treasury_momentum));
      g_last_bond_log_day = signal_day;
     }

   return (accelerating && gold_momentum > 0.0);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
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
   if(strategy_momentum_12m_bars <= 0 || strategy_min_d1_bars < strategy_momentum_12m_bars + 5)
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

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(!Strategy_IsMonthlyRebalanceDay(signal_day) || g_last_entry_rebalance_day == signal_day)
      return false;
   g_last_entry_rebalance_day = signal_day;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   double gold_momentum = 0.0;
   double treasury_momentum = 0.0;
   if(!Strategy_GoldSignalOn(signal_day, gold_momentum, treasury_momentum))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = "QM5_1167_INFLATION_GOLD_LONG";

   return Strategy_StopDistanceAllowed(entry, req.sl);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a hard ATR stop and monthly signal exit only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(!Strategy_IsMonthlyRebalanceDay(signal_day) || g_last_exit_rebalance_day == signal_day)
      return false;
   if(opened_at >= signal_day)
      return false;

   g_last_exit_rebalance_day = signal_day;

   double gold_momentum = 0.0;
   double treasury_momentum = 0.0;
   return !Strategy_GoldSignalOn(signal_day, gold_momentum, treasury_momentum);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1167\",\"ea\":\"qp-inflation-gold-bond\"}");
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
