#property strict
#property version   "5.0"
#property description "QM5_11339 TC20 H1 EMA5/21 RSI21 candle pattern"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11339
// Strategy Card: TC20 Strategy #15, source_id e78a9f1f-4e6a-563c-a080-915133d6ed28
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11339;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period     = 5;
input int    strategy_ema_slow_period     = 21;
input int    strategy_rsi_period          = 21;
input double strategy_rsi_mid_level       = 50.0;
input int    strategy_swing_lookback      = 10;
input int    strategy_swing_buffer_pips   = 2;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_hammer_wick_mult    = 2.0;
input double strategy_hammer_oppwick_pct  = 10.0;
input int    strategy_spread_cap_pips     = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(ask > bid && spread > spread_cap)
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

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= strategy_ema_fast_period ||
      strategy_rsi_period <= 0 ||
      strategy_swing_lookback < 5 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double ema_fast_3 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 3);
   const double ema_slow_3 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 3);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double atr_1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 ||
      ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0 ||
      ema_fast_3 <= 0.0 || ema_slow_3 <= 0.0 ||
      rsi_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   const bool cross_up_recent = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1) ||
                                (ema_fast_3 <= ema_slow_3 && ema_fast_2 > ema_slow_2);
   const bool cross_down_recent = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1) ||
                                  (ema_fast_3 >= ema_slow_3 && ema_fast_2 < ema_slow_2);

   const int bars_needed = strategy_swing_lookback + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(CopyRates(_Symbol, _Period, 0, bars_needed, rates) < bars_needed)
      return false;

   bool candle_long_recent = false;
   bool candle_short_recent = false;
   for(int s = 1; s <= 2; ++s)
     {
      const double o0 = rates[s].open;
      const double h0 = rates[s].high;
      const double l0 = rates[s].low;
      const double c0 = rates[s].close;
      const double o1 = rates[s + 1].open;
      const double h1 = rates[s + 1].high;
      const double l1 = rates[s + 1].low;
      const double c1 = rates[s + 1].close;
      if(o0 <= 0.0 || h0 <= 0.0 || l0 <= 0.0 || c0 <= 0.0 ||
         o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
         continue;

      const double range0 = h0 - l0;
      const double range1 = h1 - l1;
      const double body0 = MathAbs(c0 - o0);
      if(range0 <= 0.0 || range1 <= 0.0 || body0 <= 0.0)
         continue;

      const bool bullish_engulf = (o0 <= c1 && c0 > o1 && range0 > range1 && c0 > o0);
      const bool bearish_engulf = (o0 >= c1 && c0 < o1 && range0 > range1 && c0 < o0);

      const double lower_wick = MathMin(o0, c0) - l0;
      const double upper_wick = h0 - MathMax(o0, c0);
      const bool hammer = (lower_wick >= strategy_hammer_wick_mult * body0 &&
                           upper_wick <= (strategy_hammer_oppwick_pct / 100.0) * range0 &&
                           c0 > o0);
      const bool inverted_hammer = (upper_wick >= strategy_hammer_wick_mult * body0 &&
                                    lower_wick <= (strategy_hammer_oppwick_pct / 100.0) * range0 &&
                                    c0 < o0);

      if(bullish_engulf || hammer)
         candle_long_recent = true;
      if(bearish_engulf || inverted_hammer)
         candle_short_recent = true;
     }

   const bool go_long = cross_up_recent &&
                        candle_long_recent &&
                        ema_fast_1 > ema_slow_1 &&
                        rsi_1 > strategy_rsi_mid_level;
   const bool go_short = cross_down_recent &&
                         candle_short_recent &&
                         ema_fast_1 < ema_slow_1 &&
                         rsi_1 < strategy_rsi_mid_level;

   if(go_long == go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = SymbolInfoDouble(_Symbol, side == QM_BUY ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double swing_low = DBL_MAX;
   double swing_high = 0.0;
   for(int i = 1; i <= strategy_swing_lookback; ++i)
     {
      if(rates[i].low < swing_low)
         swing_low = rates[i].low;
      if(rates[i].high > swing_high)
         swing_high = rates[i].high;
     }
   if(swing_low <= 0.0 || swing_high <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_swing_buffer_pips);
   double sl = 0.0;
   if(side == QM_BUY)
     {
      const double structure_sl = swing_low - buffer;
      const double atr_sl = entry - atr_1 * strategy_atr_sl_mult;
      sl = QM_StopRulesNormalizePrice(_Symbol, MathMin(structure_sl, atr_sl));
      if(sl >= entry)
         return false;
     }
   else
     {
      const double structure_sl = swing_high + buffer;
      const double atr_sl = entry + atr_1 * strategy_atr_sl_mult;
      sl = QM_StopRulesNormalizePrice(_Symbol, MathMax(structure_sl, atr_sl));
      if(sl <= entry)
         return false;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = go_long ? "ema_rsi_candle_long" : "ema_rsi_candle_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool is_long = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         is_long = true;
      else if(position_type == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }

   if(!is_long && !is_short)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);

   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 ||
      ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0 ||
      rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   if(is_long)
     {
      const bool ema_recross = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);
      const bool rsi_recross = (rsi_2 >= strategy_rsi_mid_level && rsi_1 < strategy_rsi_mid_level);
      return(ema_recross || rsi_recross);
     }

   const bool ema_recross = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool rsi_recross = (rsi_2 <= strategy_rsi_mid_level && rsi_1 > strategy_rsi_mid_level);
   return(ema_recross || rsi_recross);
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
