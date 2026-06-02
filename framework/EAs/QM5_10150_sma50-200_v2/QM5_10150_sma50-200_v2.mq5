#property strict
#property version   "5.0"
#property description "QM5_10150_v2 SMA 50/200 Golden-Cross Trend Filter — V2 rebuild"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10150;
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
input ENUM_TIMEFRAMES strategy_timeframe         = PERIOD_D1;
input int             strategy_fast_sma_period  = 50;
input int             strategy_slow_sma_period  = 200;
input bool            strategy_shorts_enabled   = false;
input int             strategy_atr_period       = 14;
input double          strategy_atr_stop_mult    = 3.0;
input double          strategy_take_profit_rr   = 0.0;
input int             strategy_max_spread_points = 0;

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

int Strategy_SmaState(const int shift)
  {
   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= strategy_fast_sma_period || shift < 1)
      return 0;
   const double fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, shift, PRICE_CLOSE);
   const double slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, shift, PRICE_CLOSE);
   if(fast <= 0.0 || slow <= 0.0 || fast == slow) return 0;
   return (fast > slow) ? 1 : -1;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;

   if(Bars(_Symbol, strategy_timeframe) < strategy_slow_sma_period + 2) return false;
   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type)) return false;
   const int state = Strategy_SmaState(1);
   if(state == 0) return false;
   if(state < 0 && !strategy_shorts_enabled) return false;

   const QM_OrderType side = (state > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0) return false;
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0) return false;

   req.type = side; req.price = 0.0; req.sl = sl;
   req.tp = (strategy_take_profit_rr > 0.0) ? QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr) : 0.0;
   req.reason = (side == QM_BUY) ? "SMA50_GT_SMA200_LONG" : "SMA50_LE_SMA200_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_GetOurPosition(position_type)) return false;
   if(Bars(_Symbol, strategy_timeframe) < strategy_slow_sma_period + 2) return false;
   const int state = Strategy_SmaState(1);
   if(position_type == POSITION_TYPE_BUY && state <= 0) return true;
   if(position_type == POSITION_TYPE_SELL && state >= 0) return true;
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
