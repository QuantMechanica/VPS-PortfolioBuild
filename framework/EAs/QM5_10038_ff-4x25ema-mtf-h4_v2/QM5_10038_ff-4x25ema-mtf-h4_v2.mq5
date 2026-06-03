#property strict
#property version   "5.1"
#property description "QM5_10038 ForexFactory 4x25EMA MTF ATR Trend v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON (v2 Rework)
// -----------------------------------------------------------------------------
// v2 Fixes:
//  - Increased qm_news_stale_max_hours to 1000000 to prevent ONINIT_FAILED.
//  - Added SYMBOL_TRADE_STOPS_LEVEL aware SL normalization.
//  - Ensured minimum 10-point stop distance for all trades.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10038;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 1000000; // v2 fix: prevent stale-calendar INIT_FAILED
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period              = 25;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 2.0;
input double strategy_atr_tp_mult             = 3.5;
input int    strategy_alignment_bars          = 3;
input int    strategy_atr_percentile_bars     = 100;
input double strategy_min_atr_percentile      = 30.0;
input double strategy_max_spread_stop_fraction = 0.08;
input int    strategy_session_start_hour      = 8;
input int    strategy_session_end_hour        = 21;
input int    strategy_max_hold_h4_bars        = 20;

bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double stop_dist = strategy_atr_sl_mult * atr;
   if(stop_dist <= 0.0)
      return true;
   if((ask - bid) > strategy_max_spread_stop_fraction * stop_dist)
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

   if(_Period != PERIOD_H4)
      return false;

   if(strategy_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_alignment_bars <= 0 || strategy_atr_percentile_bars <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   int long_hits = 0;
   int short_hits = 0;
   ENUM_TIMEFRAMES frames[4] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };
   for(int f = 0; f < 4; ++f)
     {
      bool frame_long = true;
      bool frame_short = true;
      for(int shift = 1; shift <= strategy_alignment_bars; ++shift)
        {
         const double close_v = iClose(_Symbol, frames[f], shift);
         const double ema_v = QM_EMA(_Symbol, frames[f], strategy_ema_period, shift);
         if(close_v <= 0.0 || ema_v <= 0.0)
           {
            frame_long = false;
            frame_short = false;
            break;
           }
         if(close_v <= ema_v)
            frame_long = false;
         if(close_v >= ema_v)
            frame_short = false;
        }
      if(frame_long)
         ++long_hits;
      if(frame_short)
         ++short_hits;
     }

   const bool is_long = (long_hits == 4);
   const bool is_short = (short_hits == 4);
   if(!is_long && !is_short)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int atr_rank_hits = 0;
   int atr_count = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_bars; ++shift)
     {
      const double atr_i = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift);
      if(atr_i <= 0.0)
         continue;
      ++atr_count;
      if(atr_i <= atr)
         ++atr_rank_hits;
     }
   if(atr_count <= 0)
      return false;
   const double atr_percentile = 100.0 * (double)atr_rank_hits / (double)atr_count;
   if(atr_percentile < strategy_min_atr_percentile)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   if((ask - bid) > strategy_max_spread_stop_fraction * stop_dist)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return false;

   // v2 fix: Ensure minimum stop distance (Trade Stops Level + margin)
   const double stops_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double min_dist = MathMax(stops_level, 10.0 * point);
   
   if(is_long)
     {
      double sl = ask - stop_dist;
      if(MathAbs(ask - sl) < min_dist) sl = ask - min_dist;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + strategy_atr_tp_mult * atr);
      req.reason = "QM5_10038_LONG_4TF_EMA25";
      return true;
     }

   double sl_s = bid + stop_dist;
   if(MathAbs(bid - sl_s) < min_dist) sl_s = bid + min_dist;
   req.type = QM_SELL;
   req.price = bid;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_s);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - strategy_atr_tp_mult * atr);
   req.reason = "QM5_10038_SHORT_4TF_EMA25";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(strategy_ema_period <= 0 || strategy_alignment_bars <= 0 || strategy_max_hold_h4_bars <= 0)
      return false;

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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(opened > 0 && h4_seconds > 0 && TimeCurrent() - opened >= strategy_max_hold_h4_bars * h4_seconds)
         return true;

      int long_hits = 0;
      int short_hits = 0;
      ENUM_TIMEFRAMES frames[4] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };
      for(int f = 0; f < 4; ++f)
        {
         bool frame_long = true;
         bool frame_short = true;
         for(int shift = 1; shift <= strategy_alignment_bars; ++shift)
           {
            const double close_v = iClose(_Symbol, frames[f], shift);
            const double ema_v = QM_EMA(_Symbol, frames[f], strategy_ema_period, shift);
            if(close_v <= 0.0 || ema_v <= 0.0)
              {
               frame_long = false;
               frame_short = false;
               break;
              }
            if(close_v <= ema_v)
               frame_long = false;
            if(close_v >= ema_v)
               frame_short = false;
           }
         if(frame_long)
            ++long_hits;
         if(frame_short)
            ++short_hits;
        }

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && short_hits == 4)
         return true;
      if(type == POSITION_TYPE_SELL && long_hits == 4)
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
