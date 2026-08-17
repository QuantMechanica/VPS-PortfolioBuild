#property strict
#property version   "5.0"
#property description "QM5_33007 George Pruitt King Keltner Channel Trend Buster"
// Strategy Card: QM5_33007 (george-pruitt-king-keltner-trend-buster), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33007
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33007;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ma_period           = 20;   // Mid MA lookback (Typical Price)
input int    strategy_atr_period          = 10;   // ATR channel lookback
input double strategy_atr_multiplier      = 1.50; // Keltner envelope multiplier
input double strategy_sl_atr_multiplier   = 2.0;  // Initial SL in ATR multiples
input double strategy_tp_sl_multiplier    = 2.0;  // 1:2.0 Risk:Reward multiplier
input int    strategy_spread_atr_period   = 14;   // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;  // Spread filter threshold

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_spread_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double mid_ma_1 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 1, PRICE_TYPICAL);
   const double mid_ma_2 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 2, PRICE_TYPICAL);
   const double atr_10   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double close_1  = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar evaluation behind QM_IsNewBar()

   if(mid_ma_1 <= 0.0 || mid_ma_2 <= 0.0 || atr_10 <= 0.0 || close_1 <= 0.0)
      return false;

   const double upper_1 = mid_ma_1 + strategy_atr_multiplier * atr_10;
   const double lower_1 = mid_ma_1 - strategy_atr_multiplier * atr_10;
   const double sl_dist = strategy_sl_atr_multiplier * atr_10;
   const double tp_dist = sl_dist * strategy_tp_sl_multiplier;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long entry: Close[1] > Upper[1] AND Mid_MA[1] > Mid_MA[2]
   if(close_1 > upper_1 && mid_ma_1 > mid_ma_2)
   {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "QM5_33007_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short entry: Close[1] < Lower[1] AND Mid_MA[1] < Mid_MA[2]
   if(close_1 < lower_1 && mid_ma_1 < mid_ma_2)
   {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "QM5_33007_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double mid_ma_1 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 1, PRICE_TYPICAL);
   const double close_1  = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar evaluation behind QM_IsNewBar()
   if(mid_ma_1 <= 0.0 || close_1 <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_1 < mid_ma_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > mid_ma_1)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
   {
      QM_EquityStreamOnNewBar();
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
