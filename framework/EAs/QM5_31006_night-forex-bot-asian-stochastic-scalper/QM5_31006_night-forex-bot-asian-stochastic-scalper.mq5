#property strict
#property version   "5.0"
#property description "Asian Night Stochastic Scalper"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 31006;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpStochK      = 14;
input int    InpStochD      = 3;
input double InpBBDeviation = 1.50;

double g_strategy_initial_equity = 0.0;

bool Strategy_RolloverBlackout()
  {
   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return true;
   const int minute_of_day = utc.hour * 60 + utc.min;
   return minute_of_day >= 1435 || minute_of_day <= 5;
  }

bool Strategy_EntryCircuitBreaker()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity * 0.98)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_EquityExitRequired()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity * 0.975)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_WideSpread(const ENUM_TIMEFRAMES tf)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, tf, 14, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   return ask > bid && (ask - bid) > 1.8 * atr;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(Strategy_RolloverBlackout())
      return true;
   return Strategy_EntryCircuitBreaker();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1 ||
      Strategy_WideSpread(PERIOD_M15) ||
      InpStochK < 8 || InpStochK > 21 ||
      InpStochD < 2 || InpStochD > 5 ||
      InpBBDeviation < 1.0 || InpBBDeviation > 2.0)
      return false;

   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return false;
   const int minute_of_day = utc.hour * 60 + utc.min;
   if(minute_of_day < 21 * 60 + 30 || minute_of_day > 23 * 60 + 30)
      return false;

   const double k_1 = QM_Stoch_K(_Symbol, PERIOD_M15,
                                  InpStochK, InpStochD, 3, 1);
   const double d_1 = QM_Stoch_D(_Symbol, PERIOD_M15,
                                  InpStochK, InpStochD, 3, 1);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_M15,
                                    20, InpBBDeviation, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_M15,
                                    20, InpBBDeviation, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, 14, 1);
   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: one closed-bar band comparison.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(k_1 < 0.0 || k_1 > 100.0 || d_1 < 0.0 || d_1 > 100.0 ||
      lower <= 0.0 || upper <= lower || atr <= 0.0 ||
      close_1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(k_1 <= 20.0 && k_1 > d_1 && close_1 <= lower)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - atr, digits);
      req.tp = NormalizeDouble(ask + atr, digits);
      req.reason = "night_stoch_oversold_lower_band";
      return req.sl > 0.0;
     }

   if(k_1 >= 80.0 && k_1 < d_1 && close_1 >= upper)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + atr, digits);
      req.tp = NormalizeDouble(bid - atr, digits);
      req.reason = "night_stoch_overbought_upper_band";
      return req.tp > 0.0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return Strategy_EquityExitRequired();
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar())
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
