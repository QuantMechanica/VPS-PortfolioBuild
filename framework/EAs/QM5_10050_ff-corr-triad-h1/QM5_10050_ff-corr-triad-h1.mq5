#property strict
#property version   "5.0"
#property description "QM5_10050 ForexFactory correlation triad H1 MA cross"
// rework v2 2026-06-16: same-bar triple MA-cross was near-impossible (<<1 trade/yr);
// EURUSD fresh cross now TRIGGERS, correlated legs (EURCHF same-dir, USDCHF inverse) CONFIRM via MA state.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 10050;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_fast_sma_period      = 15;
input int    strategy_slow_sma_period      = 30;
input int    strategy_atr_period           = 10;
input double strategy_sl_atr_mult          = 3.0;
input double strategy_tp_atr_mult          = 1.0;
input int    strategy_max_spread_points    = 0;

string g_triad_symbols[3] = {"EURUSD.DWX", "EURCHF.DWX", "USDCHF.DWX"};

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "EURUSD.DWX")
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
   return false;
  }

bool TriadBarsSynchronized(datetime &decision_time)
  {
   decision_time = iTime("EURUSD.DWX", PERIOD_H1, 1);
   if(decision_time <= 0)
      return false;

   for(int i = 0; i < ArraySize(g_triad_symbols); ++i)
     {
      if(!QM_SymbolAssertOrLog(g_triad_symbols[i]))
         return false;
      if(iTime(g_triad_symbols[i], PERIOD_H1, 1) != decision_time)
         return false;
     }

   return true;
  }

int TriadSignal()
  {
   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return 0;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return 0;

   datetime decision_time = 0;
   if(!TriadBarsSynchronized(decision_time))
      return 0;

   const double eu_fast_1 = QM_SMA("EURUSD.DWX", PERIOD_H1, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double eu_slow_1 = QM_SMA("EURUSD.DWX", PERIOD_H1, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double eu_fast_2 = QM_SMA("EURUSD.DWX", PERIOD_H1, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double eu_slow_2 = QM_SMA("EURUSD.DWX", PERIOD_H1, strategy_slow_sma_period, 2, PRICE_CLOSE);
   const double ec_fast_1 = QM_SMA("EURCHF.DWX", PERIOD_H1, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double ec_slow_1 = QM_SMA("EURCHF.DWX", PERIOD_H1, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double ec_fast_2 = QM_SMA("EURCHF.DWX", PERIOD_H1, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double ec_slow_2 = QM_SMA("EURCHF.DWX", PERIOD_H1, strategy_slow_sma_period, 2, PRICE_CLOSE);
   const double uc_fast_1 = QM_SMA("USDCHF.DWX", PERIOD_H1, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double uc_slow_1 = QM_SMA("USDCHF.DWX", PERIOD_H1, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double uc_fast_2 = QM_SMA("USDCHF.DWX", PERIOD_H1, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double uc_slow_2 = QM_SMA("USDCHF.DWX", PERIOD_H1, strategy_slow_sma_period, 2, PRICE_CLOSE);

   if(eu_fast_1 <= 0.0 || eu_slow_1 <= 0.0 || eu_fast_2 <= 0.0 || eu_slow_2 <= 0.0 ||
      ec_fast_1 <= 0.0 || ec_slow_1 <= 0.0 || ec_fast_2 <= 0.0 || ec_slow_2 <= 0.0 ||
      uc_fast_1 <= 0.0 || uc_slow_1 <= 0.0 || uc_fast_2 <= 0.0 || uc_slow_2 <= 0.0)
      return 0;

   // EURUSD fresh MA cross is the TRIGGER; correlated legs CONFIRM via current MA state
   // (EURCHF positively correlated => same-direction bias; USDCHF inversely correlated => opposite bias).
   const bool eu_cross_up   = (eu_fast_2 <= eu_slow_2 && eu_fast_1 > eu_slow_1);
   const bool eu_cross_down = (eu_fast_2 >= eu_slow_2 && eu_fast_1 < eu_slow_1);
   const bool ec_state_up   = (ec_fast_1 > ec_slow_1);
   const bool ec_state_down = (ec_fast_1 < ec_slow_1);
   const bool uc_state_up   = (uc_fast_1 > uc_slow_1);
   const bool uc_state_down = (uc_fast_1 < uc_slow_1);

   if(eu_cross_up && ec_state_up && uc_state_down)
      return 1;
   if(eu_cross_down && ec_state_down && uc_state_up)
      return -1;

   return 0;
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

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int signal = TriadSignal();
   if(signal == 0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(req.price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr, strategy_tp_atr_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (signal > 0) ? "FF_CORR_TRIAD_LONG" : "FF_CORR_TRIAD_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         have_long = true;
      if(pos_type == POSITION_TYPE_SELL)
         have_short = true;
     }
   if(!have_long && !have_short)
      return false;

   const int signal = TriadSignal();
   if(have_long && signal < 0)
      return true;
   if(have_short && signal > 0)
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

   QM_SymbolGuardInit(g_triad_symbols);
   QM_BasketWarmupHistory(g_triad_symbols, PERIOD_H1, 300);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10050\",\"ea\":\"ff-corr-triad-h1\"}");
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
