#property strict
#property version   "5.0"
#property description "QM5_11587 bf-ha-ema — Heikin-Ashi color-flip + EMA(200) trend (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11587 bf-ha-ema
// -----------------------------------------------------------------------------
// Source: conor19w/Binance-Futures-Trading-Bot, TradingStrats.py heikin_ashi_ema().
// Card: artifacts/cards_approved/QM5_11587_bf-ha-ema.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; HA candles computed in-EA from real
// OHLC, recursive from a bounded seed — perf-allowed bounded closed-bar reads):
//   Trend STATE  : EMA(period) side. Long if HA_close(1) > EMA; short if below.
//   Trigger EVENT: Heikin-Ashi candle COLOR FLIP into the EMA direction —
//                  the first bullish HA candle (HA_close>HA_open) after a bearish
//                  one (long), or the first bearish HA candle after a bullish one
//                  (short). One single trigger event per bar; the EMA side is the
//                  STATE filter, so we never require two cross EVENTS on one bar
//                  (.DWX two-cross trap).
//   Exit         : source check_close_pos() — close long when current HA candle
//                  turns bearish (HA_close<HA_open); close short when it turns
//                  bullish (HA_close>HA_open).
//   Stop / Take  : source default % mode — SL = sl_pct of entry, TP = tp_pct of
//                  entry, normalized to symbol tick size.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// NOTE (open_question): the card body also narrates a StochRSI %K/%D extreme+cross
// gate. The build directive for this EA scopes it to "Heikin-Ashi + EMA trend"
// (slug bf-ha-ema) with the HA color-flip as the SINGLE trigger event. StochRSI is
// therefore intentionally omitted to avoid the two-cross-same-bar zero-trade trap;
// the HA flip + EMA side is the literal HA+EMA core of heikin_ashi_ema(). Flagged
// for the reviewer.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11587;
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
input int    strategy_ema_period          = 200;   // trend-state EMA period
input int    strategy_ha_seed_bars        = 200;   // HA recursion seed depth (bounded)
input double strategy_sl_pct              = 1.5;   // stop loss, percent of entry price
input double strategy_tp_pct              = 1.0;   // take profit, percent of entry price
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

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

   // Stop distance reference = sl_pct of the current ask, so the cap scales.
   const double stop_distance = (strategy_sl_pct / 100.0) * ask;
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

   // --- Trend STATE: EMA side, evaluated against the HA close of the last bar. ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   // --- Trigger EVENT: HA color flip INTO the EMA direction (single event). ---
   // Long  : flip bear(2) -> bull(1), and HA price above EMA (trend state up).
   // Short : flip bull(2) -> bear(1), and HA price below EMA (trend state down).
   const bool flip_up   = (bear_2 && bull_1);
   const bool flip_down = (bull_2 && bear_1);

   if(flip_up && ha_close_1 > ema)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_sl_pct / 100.0));
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_tp_pct / 100.0));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_ema_flip_long";
      return true;
     }

   if(flip_down && ha_close_1 < ema)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_sl_pct / 100.0));
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_tp_pct / 100.0));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_ema_flip_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed % stop/target. Discretionary HA-flip
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit (source check_close_pos): close long when the current HA candle
// is bearish; close short when the current HA candle is bullish.
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

   // Determine current position direction for this magic.
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
