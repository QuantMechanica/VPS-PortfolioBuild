#property strict
#property version   "5.0"
#property description "QM5_12943 Robopip HLHB Trend Catcher (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12943 — Robopip HLHB Trend Catcher (H1)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12943;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_fast_period    = 5;
input int    strategy_ema_slow_period    = 10;
input int    strategy_rsi_period         = 10;
input double strategy_rsi_midline        = 50.0;
input int    strategy_daily_atr_period   = 14;
input double strategy_min_daily_atr_pips = 30.0;
input double strategy_tp_pips            = 100.0;
input double strategy_sl_pips            = 50.0;
input int    strategy_time_stop_bars     = 96;
input double strategy_max_spread_pips    = 3.0;
input bool   strategy_asian_filter       = false;
input int    strategy_asian_start_hour   = 0;
input int    strategy_asian_end_hour     = 7;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_H1)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > bid && strategy_max_spread_pips > 0.0)
   {
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_spread_pips);
      if(max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
         return true;
   }

   if(strategy_asian_filter)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= strategy_asian_start_hour && dt.hour < strategy_asian_end_hour)
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ema5_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double ema10_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double ema10_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 2, PRICE_CLOSE);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1, PRICE_CLOSE);

   if(ema5_1 <= 0.0 || ema5_2 <= 0.0 || ema10_1 <= 0.0 || ema10_2 <= 0.0 || rsi_1 <= 0.0)
      return false;

   double atr_daily = QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, 1);
   if(atr_daily <= 0.0)
   {
      const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_daily_atr_period, 1);
      atr_daily = atr_h1 * 24.0;
   }

   const double min_atr_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_min_daily_atr_pips);
   if(min_atr_dist > 0.0 && atr_daily < min_atr_dist)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   // Bullish Signal: EMA5 crosses above EMA10 and RSI10 > 50
   if(ema5_2 <= ema10_2 && ema5_1 > ema10_1 && rsi_1 > strategy_rsi_midline)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry_p = (ask > 0.0) ? ask : iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: entry reference
      if(entry_p <= 0.0) return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_p - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_p + tp_dist);
      req.reason = "hlhb_trend_catch_long";
      return true;
   }

   // Bearish Signal: EMA5 crosses below EMA10 and RSI10 < 50
   if(ema5_2 >= ema10_2 && ema5_1 < ema10_1 && rsi_1 < strategy_rsi_midline)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry_p = (bid > 0.0) ? bid : iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: entry reference
      if(entry_p <= 0.0) return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_p + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_p - tp_dist);
      req.reason = "hlhb_trend_catch_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   const double ema5_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double ema10_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double ema10_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 2, PRICE_CLOSE);

   const bool bear_cross = (ema5_2 >= ema10_2 && ema5_1 < ema10_1);
   const bool bull_cross = (ema5_2 <= ema10_2 && ema5_1 > ema10_1);

   const datetime now_time = TimeCurrent();
   const int max_hold_sec = (strategy_time_stop_bars > 0) ? (strategy_time_stop_bars * 3600) : 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_sec > 0 && open_time > 0 && (now_time - open_time) >= max_hold_sec)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && bear_cross)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }
      else if(pos_type == POSITION_TYPE_SELL && bull_cross)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;

   if(Strategy_NoTradeFilter()) return;

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
