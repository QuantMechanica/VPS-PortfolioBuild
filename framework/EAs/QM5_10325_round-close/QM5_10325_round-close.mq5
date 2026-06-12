#property strict
#property version   "5.0"
#property description "QM5_10325 Round Number Close Continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10325;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input double strategy_round_grid_points   = 100.0;
input double strategy_band_atr_mult       = 0.10;
input double strategy_min_band_points     = 10.0;
input double strategy_stop_atr_mult       = 0.75;
input int    strategy_max_hold_d1_bars    = 1;

double g_active_round_level = 0.0;
int    g_active_side        = 0;

double NearestRoundLevel(const double price)
  {
   if(price <= 0.0 || strategy_round_grid_points <= 0.0)
      return 0.0;
   return MathRound(price / strategy_round_grid_points) * strategy_round_grid_points;
  }

double StrategyBandPoints(const double atr)
  {
   if(atr <= 0.0)
      return 0.0;
   return MathMax(strategy_band_atr_mult * atr, strategy_min_band_points);
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
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

   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(GetOurPosition(ptype, opened_at))
      return false;

   if(strategy_atr_period <= 0 || strategy_round_grid_points <= 0.0 ||
      strategy_band_atr_mult <= 0.0 || strategy_min_band_points <= 0.0 ||
      strategy_stop_atr_mult <= 0.0)
      return false;

   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 close for round-number distance; no QM close reader exists.
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_d1 <= 0.0 || atr <= 0.0)
      return false;

   const double round_level = NearestRoundLevel(close_d1);
   const double band = StrategyBandPoints(atr);
   const double dist = close_d1 - round_level;
   if(round_level <= 0.0 || band <= 0.0)
      return false;

   double entry = 0.0;
   if(dist > 0.0 && dist <= band)
     {
      req.type = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "ROUND_CLOSE_LONG";
      g_active_side = 1;
     }
   else if(dist < 0.0 && dist >= -band)
     {
      req.type = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "ROUND_CLOSE_SHORT";
      g_active_side = -1;
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   g_active_round_level = round_level;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing stop, break-even shift, or partial close.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!GetOurPosition(ptype, opened_at))
     {
      g_active_round_level = 0.0;
      g_active_side = 0;
      return false;
     }

   if(strategy_max_hold_d1_bars > 0 && opened_at > 0)
     {
      const int seconds_per_bar = PeriodSeconds(PERIOD_D1);
      if(seconds_per_bar > 0 && (TimeCurrent() - opened_at) >= (strategy_max_hold_d1_bars * seconds_per_bar))
         return true;
     }

   if(g_active_round_level > 0.0)
     {
      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid <= g_active_round_level)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask >= g_active_round_level)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10325_round-close\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_active_round_level = 0.0;
      g_active_side = 0;
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
