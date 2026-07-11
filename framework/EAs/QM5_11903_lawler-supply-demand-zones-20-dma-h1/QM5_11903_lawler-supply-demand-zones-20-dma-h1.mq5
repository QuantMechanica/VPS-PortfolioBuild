#property strict
#property version   "5.0"
#property description "QM5_11903 Lawler supply/demand zone retest + SMA20 slope (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11903
// Approved card: Lawler supply/demand zone retest with a 20-period SMA slope.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11903;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
// Backtests use RISK_FIXED. Full live after the owner gates uses a separate
// setfile with RISK_FIXED=0 and RISK_PERCENT=0.5 (HR4).
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_dma_period         = 20;
input int    strategy_dma_slope_bars     = 10;
input int    strategy_atr_period         = 14;
input double strategy_erc_atr_mult       = 2.0;
input int    strategy_zone_min_candles   = 1;
input int    strategy_zone_max_candles   = 10;
input int    strategy_zone_validity      = 240;
input double strategy_target_rr          = 3.0;
input int    strategy_time_stop_bars     = 480;
input int    strategy_sl_buffer_pips     = 5;
input int    strategy_entry_buffer_pips  = 1;
// Zero disables the optional execution guard. A positive value caps only a
// genuinely non-zero spread; .DWX zero-spread ticks remain valid.
input int    strategy_max_spread_points  = 0;

bool   g_has_active_zone = false;
int    g_zone_type       = 0; // +1 demand, -1 supply
double g_zone_high       = 0.0;
double g_zone_low        = 0.0;
int    g_zone_age_bars   = 0;

bool Strategy_ReadBar(const int shift, MqlRates &bar)
  {
   if(shift < 0)
      return false;
   // One completed H1 record per call; all callers are behind the shared
   // new-bar edge and the structural base scan is bounded at ten candles.
   MqlRates rates[1];
   if(CopyRates(_Symbol, PERIOD_H1, shift, 1, rates) != 1) // perf-allowed: bounded closed-H1 structural base scan
      return false;
   bar = rates[0];
   return (bar.time > 0);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid &&
      (ask - bid) / point > (double)strategy_max_spread_points)
      return false;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_FindBaseBeforeBreakout(const MqlRates &breakout,
                                     double &base_high,
                                     double &base_low)
  {
   base_high = 0.0;
   base_low = 0.0;
   const int min_len = MathMax(1, strategy_zone_min_candles);
   const int max_len = MathMax(min_len, strategy_zone_max_candles);

   for(int len = min_len; len <= max_len; ++len)
     {
      bool is_base = true;
      double candidate_high = -DBL_MAX;
      double candidate_low = DBL_MAX;
      for(int i = 0; i < len; ++i)
        {
         const int shift = 2 + i;
         MqlRates bar;
         if(!Strategy_ReadBar(shift, bar))
            return false;
         const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
         if(atr <= 0.0 || bar.high <= 0.0 || bar.low <= 0.0 ||
            bar.high < bar.low || (bar.high - bar.low) >= atr)
           {
            is_base = false;
            break;
           }
         if(bar.high > candidate_high)
            candidate_high = bar.high;
         if(bar.low < candidate_low)
            candidate_low = bar.low;
        }
      if(!is_base)
         continue;

      // The approved rule measures the ERC against ATR at the end of the
      // base, i.e. the closed H1 bar immediately before the breakout.
      const double base_end_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 2);
      if(base_end_atr <= 0.0 ||
         (breakout.high - breakout.low) < strategy_erc_atr_mult * base_end_atr)
         return false;

      base_high = candidate_high;
      base_low = candidate_low;
      return (base_high > base_low && base_low > 0.0);
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_dma_period <= 1 || strategy_dma_slope_bars <= 0 ||
      strategy_atr_period <= 0 || strategy_erc_atr_mult <= 0.0)
      return true;
   if(strategy_zone_min_candles <= 0 ||
      strategy_zone_max_candles < strategy_zone_min_candles ||
      strategy_zone_validity <= 0 || strategy_target_rr <= 0.0)
      return true;
   if(strategy_time_stop_bars <= 0 || strategy_sl_buffer_pips < 0 ||
      strategy_entry_buffer_pips < 0)
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

   if(Strategy_HasOpenPosition())
      return false;

   MqlRates signal_bar;
   if(!Strategy_ReadBar(1, signal_bar) || signal_bar.close <= 0.0)
      return false;

   if(g_has_active_zone)
     {
      g_zone_age_bars++;
      if(g_zone_age_bars > strategy_zone_validity)
         g_has_active_zone = false;
      else if(g_zone_type == 1 && signal_bar.close < g_zone_low)
         g_has_active_zone = false;
      else if(g_zone_type == -1 && signal_bar.close > g_zone_high)
         g_has_active_zone = false;

      if(g_has_active_zone)
        {
         const double entry_buffer = QM_StopRulesPipsToPriceDistance(
            _Symbol, strategy_entry_buffer_pips);
         const double sl_buffer = QM_StopRulesPipsToPriceDistance(
            _Symbol, strategy_sl_buffer_pips);
         if(entry_buffer < 0.0 || sl_buffer < 0.0)
            return false;

         if(g_zone_type == 1)
           {
            const double entry_level = g_zone_high - entry_buffer;
            const double sl = g_zone_low - sl_buffer;
            const double risk = entry_level - sl;
            if(signal_bar.low <= entry_level && signal_bar.close > g_zone_low &&
               risk > 0.0 && Strategy_SpreadAllowsEntry())
              {
               g_has_active_zone = false;
               req.type = QM_BUY;
               req.price = 0.0; // closed-bar price-through simulation of the limit retest
               req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
               req.tp = QM_StopRulesNormalizePrice(
                  _Symbol, entry_level + risk * strategy_target_rr);
               req.reason = "LAWLER_DEMAND_ZONE_RETEST";
               return (req.sl > 0.0 && req.tp > 0.0);
              }
           }
         else if(g_zone_type == -1)
           {
            const double entry_level = g_zone_low + entry_buffer;
            const double sl = g_zone_high + sl_buffer;
            const double risk = sl - entry_level;
            if(signal_bar.high >= entry_level && signal_bar.close < g_zone_high &&
               risk > 0.0 && Strategy_SpreadAllowsEntry())
              {
               g_has_active_zone = false;
               req.type = QM_SELL;
               req.price = 0.0; // closed-bar price-through simulation of the limit retest
               req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
               req.tp = QM_StopRulesNormalizePrice(
                  _Symbol, entry_level - risk * strategy_target_rr);
               req.reason = "LAWLER_SUPPLY_ZONE_RETEST";
               return (req.sl > 0.0 && req.tp > 0.0);
              }
           }
        }

      if(g_has_active_zone)
         return false;
     }

   double base_high = 0.0;
   double base_low = 0.0;
   if(!Strategy_FindBaseBeforeBreakout(signal_bar, base_high, base_low))
      return false;

   const double sma_current = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1);
   const double sma_past = QM_SMA(
      _Symbol, PERIOD_H1, strategy_dma_period, 1 + strategy_dma_slope_bars);
   if(sma_current <= 0.0 || sma_past <= 0.0)
      return false;

   const bool bullish_break = (signal_bar.close > base_high);
   const bool bearish_break = (signal_bar.close < base_low);
   if(bullish_break && sma_current > sma_past)
     {
      g_has_active_zone = true;
      g_zone_type = 1;
     }
   else if(bearish_break && sma_current < sma_past)
     {
      g_has_active_zone = true;
      g_zone_type = -1;
     }
   else
      return false;

   g_zone_high = base_high;
   g_zone_low = base_low;
   g_zone_age_bars = 0;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies static SL/TP; no trailing or partial management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 &&
         iBarShift(_Symbol, PERIOD_H1, opened) >= strategy_time_stop_bars)
         return true;

      const double sma_current = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1);
      const double sma_past = QM_SMA(
         _Symbol, PERIOD_H1, strategy_dma_period, 1 + strategy_dma_slope_bars);
      if(sma_current <= 0.0 || sma_past <= 0.0)
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && sma_current < sma_past)
         return true;
      if(type == POSITION_TYPE_SELL && sma_current > sma_past)
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11903_lawler-supply-demand-zones-20-dma-h1\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   // Both the trend exit and the zone state are closed-H1-bar rules. Consume
   // the framework edge once, then share it between exit and entry paths.
   const bool signal_bar_opened = QM_IsNewBar(_Symbol, PERIOD_H1);
   if(signal_bar_opened)
     {
      QM_EquityStreamOnNewBar();
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
     }

   // News policy is entry-only. Management, Friday-close, and the approved
   // rule exit above remain live during blackout windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(
         _Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !signal_bar_opened)
      return;

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
