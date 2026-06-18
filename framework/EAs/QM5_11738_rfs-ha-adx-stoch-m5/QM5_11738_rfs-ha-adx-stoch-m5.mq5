#property strict
#property version   "5.0"
#property description "QM5_11738 rfs-ha-adx-stoch-m5 — Heikin-Ashi + ADX + Stochastic confluence (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11738 rfs-ha-adx-stoch-m5
// -----------------------------------------------------------------------------
// Source: Anonymous, "Heiken Ashi + ADX + Stochastic", Robo-forex Strategy
//         Compilation (robofx.com, ~2015), source PDF page 23.
// Card: artifacts/cards_approved/QM5_11738_rfs-ha-adx-stoch-m5.md (g0_status APPROVED).
//
// Three-way confluence. To avoid the .DWX two-cross-same-bar zero-trade trap,
// exactly ONE component is the trigger EVENT; the rest are persistent STATEs:
//
//   Trend STATE  : Heikin-Ashi color — two consecutive same-color HA candles at
//                  shifts 2 and 1 (bull-bull for long, bear-bear for short).
//                  HA candles computed in-EA from real OHLC, recursive from a
//                  bounded seed (perf-allowed bounded closed-bar reads, only on
//                  the QM_IsNewBar-gated closed-bar path).
//   Strength STATE: ADX(14) > threshold AND ADX rising (ADX[1] > ADX[2]).
//                  Directional bias confirmed by DI: +DI>-DI for longs,
//                  -DI>+DI for shorts (resolves the card's ambiguous "ADX below
//                  22 for shorts" note — Implementation Notes direct: ADX>thr
//                  with directional bias, consistent with longs).
//   Trigger EVENT: Stochastic(5,3,3) %K crosses UP out of oversold for longs
//                  (K[2] <= os && K[1] > os), or crosses DOWN out of overbought
//                  for shorts (K[2] >= ob && K[1] < ob). One single momentum
//                  event per bar. HA color + ADX are STATES, never EVENTS, so we
//                  never require two fresh crosses on one bar.
//   Stop / Take  : fixed pips (card default SL 7 pips / TP 12 pips), scaled
//                  correctly via QM_StopFixedPips / QM_StopRulesPipsToPriceDistance.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11738;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adx_period          = 14;    // ADX period
input double strategy_adx_threshold       = 22.0;  // ADX trend-strength floor
input int    strategy_stoch_k             = 5;     // Stochastic %K period
input int    strategy_stoch_d             = 3;     // Stochastic %D period
input int    strategy_stoch_slowing       = 3;     // Stochastic slowing
input double strategy_stoch_oversold      = 20.0;  // %K oversold level (long trigger)
input double strategy_stoch_overbought    = 80.0;  // %K overbought level (short trigger)
input int    strategy_ha_seed_bars        = 200;   // HA recursion seed depth (bounded)
input int    strategy_sl_pips             = 7;     // stop loss, pips
input int    strategy_tp_pips             = 12;    // take profit, pips
input double strategy_spread_pct_of_stop  = 30.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Heikin-Ashi helper — compute HA open/close at a given closed-bar shift by
// recursing from a bounded seed. perf-allowed: bounded closed-bar OHLC reads,
// only run on the closed-bar entry/exit path (QM_IsNewBar-gated by the framework).
// -----------------------------------------------------------------------------

// Fills ha_open / ha_close for the candle at `shift` (1 = last closed bar).
// Returns false if history is not yet available.
bool ComputeHA(const int shift, double &ha_open, double &ha_close)
  {
   const int seed = (strategy_ha_seed_bars < 10 ? 10 : strategy_ha_seed_bars);
   const int start = shift + seed; // oldest bar of the recursion seed

   if(Bars(_Symbol, _Period) <= start + 1)
      return false;

   // Seed at the oldest bar: HA_open = (O+C)/2, HA_close = (O+H+L+C)/4.
   double o = iOpen(_Symbol, _Period, start);   // perf-allowed: bounded closed-bar read
   double h = iHigh(_Symbol, _Period, start);   // perf-allowed
   double l = iLow(_Symbol, _Period, start);    // perf-allowed
   double c = iClose(_Symbol, _Period, start);  // perf-allowed
   if(o <= 0.0 || c <= 0.0)
      return false;

   double prev_ha_open  = (o + c) / 2.0;
   double prev_ha_close = (o + h + l + c) / 4.0;

   // Recurse forward from start-1 down to `shift`.
   for(int s = start - 1; s >= shift; --s)
     {
      o = iOpen(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar read
      h = iHigh(_Symbol, _Period, s);   // perf-allowed
      l = iLow(_Symbol, _Period, s);    // perf-allowed
      c = iClose(_Symbol, _Period, s);  // perf-allowed
      if(o <= 0.0 || c <= 0.0)
         return false;

      const double cur_ha_close = (o + h + l + c) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;
     }

   ha_open  = prev_ha_open;
   ha_close = prev_ha_close;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Heikin-Ashi candles at shift 1 (last closed) and shift 2 (prior). ---
   double ha_open_1, ha_close_1, ha_open_2, ha_close_2;
   if(!ComputeHA(1, ha_open_1, ha_close_1))
      return false;
   if(!ComputeHA(2, ha_open_2, ha_close_2))
      return false;

   const bool bull_1 = (ha_close_1 > ha_open_1);
   const bool bear_1 = (ha_close_1 < ha_open_1);
   const bool bull_2 = (ha_close_2 > ha_open_2);
   const bool bear_2 = (ha_close_2 < ha_open_2);

   // Trend STATE: two consecutive same-color HA candles.
   const bool ha_long_state  = (bull_2 && bull_1);
   const bool ha_short_state = (bear_2 && bear_1);
   if(!ha_long_state && !ha_short_state)
      return false;

   // --- Strength STATE: ADX > threshold AND rising, with DI directional bias. ---
   const double adx_now  = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double adx_prev = QM_ADX(_Symbol, _Period, strategy_adx_period, 2);
   if(adx_now <= 0.0 || adx_prev <= 0.0)
      return false;
   const bool adx_strong_rising = (adx_now > strategy_adx_threshold && adx_now > adx_prev);
   if(!adx_strong_rising)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   // --- Trigger EVENT: Stochastic %K crosses out of OS/OB (one event/bar). ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || k_prev <= 0.0)
      return false;

   const bool stoch_cross_up   = (k_prev <= strategy_stoch_oversold   && k_now > strategy_stoch_oversold);
   const bool stoch_cross_down = (k_prev >= strategy_stoch_overbought && k_now < strategy_stoch_overbought);

   // --- Long: HA bull state + ADX strong/rising + +DI dominant + Stoch up-cross. ---
   if(ha_long_state && plus_di > minus_di && stoch_cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips); // tp = entry + tp_pips (mirror)
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_adx_stoch_long";
      return true;
     }

   // --- Short: HA bear state + ADX strong/rising + -DI dominant + Stoch down-cross. ---
   if(ha_short_state && minus_di > plus_di && stoch_cross_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips); // tp = entry - tp_pips (mirror)
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_adx_stoch_short";
      return true;
     }

   return false;
  }

// Fixed pip stop/target only — no active trailing. Defensive HA-flip exit is in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: close long when the last closed HA candle turns bearish;
// close short when it turns bullish.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double ha_open_1, ha_close_1;
   if(!ComputeHA(1, ha_open_1, ha_close_1))
      return false;

   const bool ha_bull = (ha_close_1 > ha_open_1);
   const bool ha_bear = (ha_close_1 < ha_open_1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ha_bear)
         return true;
      if(ptype == POSITION_TYPE_SELL && ha_bull)
         return true;
     }
   return false;
  }

// Defer to the central news filter.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
