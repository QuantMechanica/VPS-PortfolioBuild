#property strict
#property version   "5.0"
#property description "QM5_1166 Quantpedia Gold Treasury Joint Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1166;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_treasury_csv_path   = "IEF_total_return.csv";
input int    strategy_return_lookback_bars = 252;
input int    strategy_min_d1_bars         = 270;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 5.0;
input int    strategy_rebalance_hour      = 1;
input int    strategy_proxy_stale_days    = 45;
input int    strategy_max_spread_points   = 300;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsMonthlyRebalanceOpen(const datetime closed_day)
  {
   if(closed_day <= 0)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_day, closed_dt);
   TimeToStruct(current_day, current_dt);
   if(current_dt.hour < strategy_rebalance_hour)
      return false;

   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
  }

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

bool Strategy_IsHeaderDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToLower(s);
   return (s == "date" || s == "time" || s == "timestamp");
  }

bool Strategy_ReadTreasuryProxy(const datetime as_of,
                                datetime &latest_date,
                                double &latest_value,
                                datetime &past_date,
                                double &past_value)
  {
   latest_date = 0;
   latest_value = 0.0;
   past_date = 0;
   past_value = 0.0;

   if(strategy_treasury_csv_path == "")
      return false;

   int handle = FileOpen(strategy_treasury_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_treasury_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   const datetime target_past = as_of - (datetime)(MathMax(1, strategy_return_lookback_bars) * 86400);

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string value_field = FileReadString(handle);
      if(date_field == "" && value_field == "")
         continue;
      if(Strategy_IsHeaderDate(date_field))
         continue;

      const datetime obs_date = Strategy_ParseDate(date_field);
      const double obs_value = StringToDouble(value_field);
      if(obs_date <= 0 || obs_value <= 0.0 || obs_date > as_of)
         continue;

      if(obs_date >= latest_date)
        {
         latest_date = obs_date;
         latest_value = obs_value;
        }
      if(obs_date <= target_past && obs_date >= past_date)
        {
         past_date = obs_date;
         past_value = obs_value;
        }
     }

   FileClose(handle);

   if(latest_date <= 0 || past_date <= 0 || latest_value <= 0.0 || past_value <= 0.0)
      return false;
   if(strategy_proxy_stale_days > 0 && (as_of - latest_date) > strategy_proxy_stale_days * 86400)
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

bool Strategy_JointMomentumPositive()
  {
   double gold_return = 0.0;
   if(!Strategy_ReturnOverBars(STRATEGY_SYMBOL, strategy_return_lookback_bars, gold_return))
      return false;

   datetime latest_date = 0;
   datetime past_date = 0;
   double latest_value = 0.0;
   double past_value = 0.0;
   if(!Strategy_ReadTreasuryProxy(Strategy_LastClosedD1Time(), latest_date, latest_value, past_date, past_value))
      return false;

   const double treasury_return = (latest_value / past_value) - 1.0;
   return (gold_return > 0.0 && treasury_return > 0.0);
  }

bool Strategy_HasOpenPosition(ulong &ticket)
  {
   ticket = 0;
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
      ticket = pos_ticket;
      return true;
     }

   return false;
  }

bool Strategy_TradingStatusValid()
  {
   if(!SymbolSelect(STRATEGY_SYMBOL, true))
      return false;
   return (SymbolInfoInteger(STRATEGY_SYMBOL, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
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
   if(strategy_return_lookback_bars <= 0 || strategy_min_d1_bars < strategy_return_lookback_bars)
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

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthlyRebalanceOpen(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   if(Strategy_HasOpenPosition(ticket))
      return false;
   if(!Strategy_JointMomentumPositive())
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = "QP_GOLD_TREASURY_MOM_LONG";
   req.symbol_slot = qm_magic_slot_offset;

   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies hard ATR stop and monthly signal exit only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_HasOpenPosition(ticket))
      return false;
   if(!Strategy_TradingStatusValid())
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthlyRebalanceOpen(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;

   if(!Strategy_JointMomentumPositive())
     {
      g_last_exit_rebalance_day = rebalance_day;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1166_qp-gold-treasury-mom\"}");
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
