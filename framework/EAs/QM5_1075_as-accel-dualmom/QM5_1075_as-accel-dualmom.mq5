#property strict
#property version   "5.0"
#property description "QM5_1075 Allocate Smartly Accelerating Dual Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1075;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_us_proxy_1        = "SP500.DWX";
input string strategy_us_proxy_2        = "NDX.DWX";
input string strategy_us_proxy_3        = "WS30.DWX";
input string strategy_international_proxy = "GER40.DWX";
input int    strategy_m1_bars           = 22;
input int    strategy_m3_bars           = 63;
input int    strategy_m6_bars           = 126;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;

const int STRATEGY_US_PROXY_COUNT = 3;
string g_strategy_us_symbols[3];

void Strategy_LoadUniverse()
  {
   g_strategy_us_symbols[0] = strategy_us_proxy_1;
   g_strategy_us_symbols[1] = strategy_us_proxy_2;
   g_strategy_us_symbols[2] = strategy_us_proxy_3;
  }

int Strategy_MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;
   return (Strategy_MonthOf(current_d1) != Strategy_MonthOf(prior_d1));
  }

bool Strategy_IsUsProxy(const string symbol)
  {
   for(int i = 0; i < STRATEGY_US_PROXY_COUNT; ++i)
     {
      if(g_strategy_us_symbols[i] != "" && symbol == g_strategy_us_symbols[i])
         return true;
     }
   return false;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   if(symbol == strategy_us_proxy_1)
      return 0;
   if(symbol == strategy_us_proxy_2)
      return 1;
   if(symbol == strategy_us_proxy_3)
      return 2;
   if(symbol == strategy_international_proxy)
      return 3;
   return -1;
  }

double Strategy_Return(const string symbol, const int bars_back)
  {
   if(symbol == "" || bars_back < 1)
      return -DBL_MAX;
   if(!SymbolSelect(symbol, true))
      return -DBL_MAX;
   if(Bars(symbol, PERIOD_D1) < bars_back + 2)
      return -DBL_MAX;

   const double recent_close = QM_SMA(symbol, PERIOD_D1, 1, 1);
   const double lookback_close = QM_SMA(symbol, PERIOD_D1, 1, 1 + bars_back);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return -DBL_MAX;

   return (recent_close / lookback_close) - 1.0;
  }

double Strategy_AccelScore(const string symbol)
  {
   const double ret_1m = Strategy_Return(symbol, strategy_m1_bars);
   const double ret_3m = Strategy_Return(symbol, strategy_m3_bars);
   const double ret_6m = Strategy_Return(symbol, strategy_m6_bars);
   if(ret_1m == -DBL_MAX || ret_3m == -DBL_MAX || ret_6m == -DBL_MAX)
      return -DBL_MAX;
   return ret_1m + ret_3m + ret_6m;
  }

string Strategy_SelectedSymbol()
  {
   string best_us_symbol = "";
   double best_us_score = -DBL_MAX;

   for(int i = 0; i < STRATEGY_US_PROXY_COUNT; ++i)
     {
      const string symbol = g_strategy_us_symbols[i];
      const double score = Strategy_AccelScore(symbol);
      if(score > best_us_score)
        {
         best_us_score = score;
         best_us_symbol = symbol;
        }
     }

   const double international_score = Strategy_AccelScore(strategy_international_proxy);
   if(best_us_score == -DBL_MAX || international_score == -DBL_MAX)
      return "";

   if(best_us_score < 0.0 && international_score < 0.0)
      return "";

   if(best_us_score >= international_score)
      return best_us_symbol;
   return strategy_international_proxy;
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

bool Strategy_NoTradeFilter()
  {
   const int expected_slot = Strategy_SymbolSlot(_Symbol);
   if(expected_slot < 0)
      return true;
   return (expected_slot != qm_magic_slot_offset);
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

   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const string selected_symbol = Strategy_SelectedSymbol();
   if(selected_symbol == "" || selected_symbol != _Symbol)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.sl = sl;
   req.reason = "AS_ACCEL_DUALMOM_MONTHLY_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline holds until monthly rotation; only framework SL/Friday/KS exits apply intramonth.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const string selected_symbol = Strategy_SelectedSymbol();
   return (selected_symbol != _Symbol);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_LoadUniverse();

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
