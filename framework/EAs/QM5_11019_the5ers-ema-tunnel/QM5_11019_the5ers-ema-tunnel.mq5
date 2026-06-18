#property strict
#property version   "5.0"
#property description "QM5_11019 the5ers-ema-tunnel"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11019 the5ers-ema-tunnel
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11019_the5ers-ema-tunnel.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11019;
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
input int    strategy_tunnel_fast_period       = 144;
input int    strategy_tunnel_slow_period       = 169;
input int    strategy_fast_ema_period          = 12;
input int    strategy_atr_period               = 14;
input int    strategy_mn_proxy_fast_d1_period  = 252;
input int    strategy_mn_proxy_slow_d1_period  = 300;
input double strategy_compression_pips         = 5.0;
input double strategy_compression_atr_fraction = 0.15;
input double strategy_stop_atr_mult            = 0.5;
input double strategy_partial_rr               = 1.0;
input double strategy_partial_fraction         = 0.5;
input double strategy_trail_atr_mult           = 0.5;
input int    strategy_entry_start_hour_tokyo   = 6;
input int    strategy_entry_end_hour_tokyo     = 22;
input int    strategy_near_entry_days          = 7;
input int    strategy_hard_stop_days           = 20;
input double strategy_near_entry_r_fraction    = 0.25;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const datetime tokyo_now = utc_now + 9 * 60 * 60;
   MqlDateTime tokyo;
   TimeToStruct(tokyo_now, tokyo);

   bool in_asian_proxy = false;
   if(strategy_entry_start_hour_tokyo < strategy_entry_end_hour_tokyo)
      in_asian_proxy = (tokyo.hour < strategy_entry_start_hour_tokyo ||
                        tokyo.hour >= strategy_entry_end_hour_tokyo);
   else
      in_asian_proxy = (tokyo.hour >= strategy_entry_end_hour_tokyo &&
                        tokyo.hour < strategy_entry_start_hour_tokyo);
   if(in_asian_proxy)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(spread > 0.0 && atr_h1 > 0.0 && spread > atr_h1)
      return true;

   return false;
  }

// Trade Entry
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

   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double w1_close = iClose(_Symbol, PERIOD_W1, 1); // perf-allowed
   const double d1_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double d1_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed
   if(h1_close <= 0.0 || d1_close <= 0.0 || w1_close <= 0.0 || d1_high <= 0.0 || d1_low <= 0.0)
      return false;

   const double h1_ema_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_tunnel_fast_period, 1);
   const double h1_ema_slow = QM_EMA(_Symbol, PERIOD_H1, strategy_tunnel_slow_period, 1);
   const double h1_ema_12 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 1);
   const double d1_ema_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_tunnel_fast_period, 1);
   const double d1_ema_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_tunnel_slow_period, 1);
   const double w1_ema_fast = QM_EMA(_Symbol, PERIOD_W1, strategy_tunnel_fast_period, 1);
   const double w1_ema_slow = QM_EMA(_Symbol, PERIOD_W1, strategy_tunnel_slow_period, 1);
   const double mn_proxy_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_mn_proxy_fast_d1_period, 1);
   const double mn_proxy_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_mn_proxy_slow_d1_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(h1_ema_fast <= 0.0 || h1_ema_slow <= 0.0 || h1_ema_12 <= 0.0 ||
      d1_ema_fast <= 0.0 || d1_ema_slow <= 0.0 ||
      w1_ema_fast <= 0.0 || w1_ema_slow <= 0.0 ||
      mn_proxy_fast <= 0.0 || mn_proxy_slow <= 0.0 ||
      atr_h1 <= 0.0 || atr_d1 <= 0.0)
      return false;

   const double h1_tunnel_top = MathMax(h1_ema_fast, h1_ema_slow);
   const double h1_tunnel_bottom = MathMin(h1_ema_fast, h1_ema_slow);
   const double d1_tunnel_top = MathMax(d1_ema_fast, d1_ema_slow);
   const double d1_tunnel_bottom = MathMin(d1_ema_fast, d1_ema_slow);
   const int compression_pips = (int)MathRound(strategy_compression_pips);
   const double compression_price = QM_StopRulesPipsToPriceDistance(_Symbol, compression_pips);
   const double compression_limit = MathMax(compression_price,
                                            strategy_compression_atr_fraction * atr_h1);
   if(compression_limit <= 0.0)
      return false;

   const double fast_to_nearest = MathMin(MathAbs(h1_ema_12 - h1_tunnel_top),
                                          MathAbs(h1_ema_12 - h1_tunnel_bottom));
   if(fast_to_nearest > compression_limit)
      return false;

   const bool long_align = (h1_close > h1_tunnel_top &&
                            d1_close > d1_tunnel_top &&
                            w1_close > MathMax(w1_ema_fast, w1_ema_slow) &&
                            d1_close > MathMax(mn_proxy_fast, mn_proxy_slow));
   const bool short_align = (h1_close < h1_tunnel_bottom &&
                             d1_close < d1_tunnel_bottom &&
                             w1_close < MathMin(w1_ema_fast, w1_ema_slow) &&
                             d1_close < MathMin(mn_proxy_fast, mn_proxy_slow));
   const bool long_pierce = (d1_low <= d1_tunnel_top && d1_close > d1_tunnel_top);
   const bool short_pierce = (d1_high >= d1_tunnel_bottom && d1_close < d1_tunnel_bottom);

   bool want_long = false;
   bool want_short = false;
   if(long_align && long_pierce)
      want_long = true;
   if(short_align && short_pierce)
      want_short = true;
   if(want_long == want_short)
      return false;

   const string this_base = StringSubstr(_Symbol, 0, 3);
   const string this_quote = StringSubstr(_Symbol, 3, 3);
   const double candidate_base_sign = want_long ? 1.0 : -1.0;
   const double candidate_quote_sign = -candidate_base_sign;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const string pos_symbol = PositionGetString(POSITION_SYMBOL);
      if(StringLen(pos_symbol) < 6)
         continue;
      const string pos_base = StringSubstr(pos_symbol, 0, 3);
      const string pos_quote = StringSubstr(pos_symbol, 3, 3);
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double pos_base_sign = (pos_type == POSITION_TYPE_BUY) ? 1.0 : -1.0;
      const double pos_quote_sign = -pos_base_sign;

      if(pos_base == this_base && pos_base_sign * candidate_base_sign > 0.0)
         return false;
      if(pos_quote == this_base && pos_quote_sign * candidate_base_sign > 0.0)
         return false;
      if(pos_base == this_quote && pos_base_sign * candidate_quote_sign > 0.0)
         return false;
      if(pos_quote == this_quote && pos_quote_sign * candidate_quote_sign > 0.0)
         return false;
     }

   if(want_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, d1_low - strategy_stop_atr_mult * atr_d1);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "the5ers_ema_tunnel_long";
      return true;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, d1_high + strategy_stop_atr_mult * atr_d1);
   if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
      return false;
   req.type = QM_SELL;
   req.sl = sl;
   req.reason = "the5ers_ema_tunnel_short";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_sl <= 0.0 || current_volume <= 0.0)
         continue;

      const string risk_key = StringFormat("QM5_11019_%d_%I64u_R", magic, ticket);
      double initial_r = GlobalVariableCheck(risk_key) ? GlobalVariableGet(risk_key) : 0.0;
      if(initial_r <= 0.0)
        {
         initial_r = MathAbs(open_price - current_sl);
         if(initial_r > 0.0)
            GlobalVariableSet(risk_key, initial_r);
        }
      if(initial_r <= 0.0)
         continue;

      const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
      const double h1_ema_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_tunnel_fast_period, 1);
      const double h1_ema_slow = QM_EMA(_Symbol, PERIOD_H1, strategy_tunnel_slow_period, 1);
      const double tunnel_top = MathMax(h1_ema_fast, h1_ema_slow);
      const double tunnel_bottom = MathMin(h1_ema_fast, h1_ema_slow);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(h1_close > 0.0 && tunnel_top > 0.0 && tunnel_bottom > 0.0 && point > 0.0 &&
         h1_close >= tunnel_bottom && h1_close <= tunnel_top)
        {
         if(pos_type == POSITION_TYPE_BUY && (current_sl <= 0.0 || current_sl < open_price - point))
            QM_TM_MoveSL(ticket, open_price, "ema_tunnel_h1_close_inside_be");
         if(pos_type == POSITION_TYPE_SELL && (current_sl <= 0.0 || current_sl > open_price + point))
            QM_TM_MoveSL(ticket, open_price, "ema_tunnel_h1_close_inside_be");
        }

      const string partial_key = StringFormat("QM5_11019_%d_%I64u_PARTIAL", magic, ticket);
      bool partial_done = (GlobalVariableCheck(partial_key) && GlobalVariableGet(partial_key) > 0.5);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!partial_done && bid > 0.0 && ask > 0.0)
        {
         bool hit_partial = false;
         if(pos_type == POSITION_TYPE_BUY)
            hit_partial = (bid >= open_price + strategy_partial_rr * initial_r);
         else
            hit_partial = (ask <= open_price - strategy_partial_rr * initial_r);

         if(hit_partial)
           {
            const double close_lots = QM_TM_NormalizeVolume(_Symbol,
                                      current_volume * strategy_partial_fraction);
            if(close_lots > 0.0 && close_lots < current_volume)
              {
               if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
                 {
                  GlobalVariableSet(partial_key, 1.0);
                  partial_done = true;
                 }
              }
            else
              {
               GlobalVariableSet(partial_key, 1.0);
               partial_done = true;
              }
           }
        }

      if(partial_done)
        {
         const double ema_12 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 1);
         const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
         if(ema_12 <= 0.0 || atr_h1 <= 0.0 || point <= 0.0)
            continue;
         const double buffer = strategy_trail_atr_mult * atr_h1;
         double target_sl = 0.0;
         if(pos_type == POSITION_TYPE_BUY)
           {
            target_sl = QM_StopRulesNormalizePrice(_Symbol, ema_12 - buffer);
            if(target_sl > current_sl + point && target_sl < bid)
               QM_TM_MoveSL(ticket, target_sl, "ema12_atr_buffer_trail");
           }
         else
           {
            target_sl = QM_StopRulesNormalizePrice(_Symbol, ema_12 + buffer);
            if(target_sl < current_sl - point && target_sl > ask)
               QM_TM_MoveSL(ticket, target_sl, "ema12_atr_buffer_trail");
           }
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;

      const long age_seconds = (long)(TimeCurrent() - open_time);
      if(age_seconds >= (long)strategy_hard_stop_days * 24L * 60L * 60L)
         return true;

      const string risk_key = StringFormat("QM5_11019_%d_%I64u_R", magic, ticket);
      double initial_r = GlobalVariableCheck(risk_key) ? GlobalVariableGet(risk_key) : 0.0;
      if(initial_r <= 0.0)
         initial_r = MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL));
      if(initial_r <= 0.0)
         continue;

      if(age_seconds >= (long)strategy_near_entry_days * 24L * 60L * 60L)
        {
         const long pos_type = PositionGetInteger(POSITION_TYPE);
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double current_price = (pos_type == POSITION_TYPE_BUY)
                                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open_price > 0.0 && current_price > 0.0 &&
            MathAbs(current_price - open_price) <= strategy_near_entry_r_fraction * initial_r)
            return true;
        }
     }

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
