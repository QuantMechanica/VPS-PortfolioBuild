#property strict
#property version   "5.0"
#property description "QM5_10114_v2 TradingView Golden Cross 50/200 — V2 rebuild"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10114;
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
input int    strategy_fast_sma_period      = 50;
input int    strategy_slow_sma_period      = 200;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 4.0;
input double strategy_max_spread_stop_frac = 0.10;

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;

   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_spread_stop_frac < 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   const double fast_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_sma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0) return false;
   if(!(fast_2 <= slow_2 && fast_1 > slow_1)) return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0) return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry) return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0 || (entry - bid) > stop_distance * strategy_max_spread_stop_frac) return false;

   req.type = QM_BUY; req.price = 0.0; req.sl = sl; req.tp = 0.0;
   req.reason = "TV_GOLDEN_CROSS_50_200_LONG";
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   const double fast_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_sma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0) return false;
   if(!(fast_2 >= slow_2 && fast_1 < slow_1)) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
