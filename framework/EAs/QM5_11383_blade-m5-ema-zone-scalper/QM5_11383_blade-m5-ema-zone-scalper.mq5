#property strict
#property version   "5.0"
#property description "QM5_11383 blade-m5-ema-zone-scalper — Blade M5 EMA-Zone Pullback Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11383 blade-m5-ema-zone-scalper
// -----------------------------------------------------------------------------
// Source: "The Blade Forex Strategies" (ForexSuccessSecrets.com), M5 Scalping
// System, local PDF. Card: artifacts/cards_approved/QM5_11383_blade-m5-ema-zone-scalper.md
// (g0_status APPROVED, source_id f4fa8966-3aa0-5df0-9d8f-3872df92309a).
//
// Mechanics (M5, closed-bar reads at shift 1; long + short symmetric):
//   Trend STATE  : EMA(50) slope + price on the trend side of EMA(50).
//                  Long  -> ema50[1] > ema50[1+slope] (rising) AND close[1] > ema50[1].
//                  Short -> ema50[1] < ema50[1+slope] (falling) AND close[1] < ema50[1].
//   Zone STATE   : the band between EMA(10) and EMA(21).
//                  Long  -> bar's LOW dipped at/below EMA(10) AND CLOSE held >= EMA(21).
//                  Short -> bar's HIGH reached at/above EMA(10) AND CLOSE held <= EMA(21).
//                  (Card: "candle dipped into or below EMA10 but closed above EMA21".)
//   Entry EVENT  : the closed bar FRESHLY retraces into the zone — the prior closed
//                  bar's CLOSE was OUTSIDE the zone on the trend side (long: prior
//                  close above the zone top = EMA(10)). One event per retrace, not a
//                  per-bar state, so a single trend pullback fires exactly once.
//   Session STATE: London + NY only (card "08:00-22:00 GMT, NO Asian"), evaluated
//                  in BROKER time converted to UTC via QM_BrokerToUTC.
//   Stop         : fixed 5 pips from entry (card: "5 pips + spread"; .DWX models 0
//                  spread so the "+ spread" term is 0). P2 cap 10 pips honoured by
//                  the small default.
//   Take profit  : fixed 10 pips from entry.
//   Break-even   : SL -> entry once price is +be_trigger_pips (5) in profit.
//   One position per magic (single position per symbol).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11383;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_zone_fast     = 10;     // EMA(10) — fast zone edge
input int    strategy_ema_zone_slow     = 21;     // EMA(21) — slow zone edge / close-hold side
input int    strategy_ema_trend         = 50;     // EMA(50) — trend / slope filter
input int    strategy_slope_lookback    = 10;     // EMA(50) slope proxy: shift 1 vs shift 1+this
input int    strategy_sl_pips           = 5;      // stop loss, fixed pips from entry
input int    strategy_tp_pips           = 10;     // take profit, fixed pips from entry
input int    strategy_be_trigger_pips   = 5;      // move SL to break-even at +this many pips
// Session windows in UTC (card states London/NY in GMT == UTC; 08:00-22:00 GMT).
input int    strategy_session_start_utc = 8;      // London open hour (UTC)
input int    strategy_session_end_utc   = 22;     // NY close hour (UTC)
input int    strategy_spread_cap_pips   = 8;      // skip only if spread exceeds this many pips

// -----------------------------------------------------------------------------
// Helpers (EA-local, pure)
// -----------------------------------------------------------------------------

// True if broker timestamp is inside the London+NY trading window (UTC). The
// card treats London+NY as one contiguous 08:00-22:00 GMT block (no Asian).
bool BladeSessionActive(const datetime broker_now)
  {
   const datetime utc  = QM_BrokerToUTC(broker_now);
   const datetime day0 = utc - (utc % 86400);            // UTC midnight
   const datetime lo   = day0 + strategy_session_start_utc * 3600;
   const datetime hi   = day0 + strategy_session_end_utc   * 3600;
   if(hi <= lo)
      return false;
   return (utc >= lo && utc < hi);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + fail-open spread guard.
bool Strategy_NoTradeFilter()
  {
   // Session filter (broker time -> UTC). Outside London/NY: block.
   if(!BladeSessionActive(TimeCurrent()))
      return true;

   // Fail-open spread guard. .DWX models 0 spread; only a genuinely wide spread blocks.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar EMA reads (shift 1 = last closed bar) ---
   const double ema10_1 = QM_EMA(_Symbol, _Period, strategy_ema_zone_fast, 1);
   const double ema21_1 = QM_EMA(_Symbol, _Period, strategy_ema_zone_slow, 1);
   const double ema50_1 = QM_EMA(_Symbol, _Period, strategy_ema_trend,     1);
   if(ema10_1 <= 0.0 || ema21_1 <= 0.0 || ema50_1 <= 0.0)
      return false;

   // EMA(50) slope proxy: shift 1 versus shift 1+slope_lookback (card "sloping").
   const double ema50_back = QM_EMA(_Symbol, _Period, strategy_ema_trend,
                                    1 + strategy_slope_lookback);
   if(ema50_back <= 0.0)
      return false;

   // Closed-bar OHLC reads (single shift each — perf-allowed structural reads).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol,  _Period, 1);  // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   // Zone edges (shift 1). EMA(10) is the "fast" outer edge in a trend pullback,
   // EMA(21) the "slow" inner edge the close must hold.
   const double zone_top = MathMax(ema10_1, ema21_1);
   const double zone_bot = MathMin(ema10_1, ema21_1);

   // ---------------- LONG ----------------
   // Trend STATE: EMA(50) rising AND prior close above EMA(50).
   const bool long_slope = (ema50_1 > ema50_back);
   const bool long_trend = (close1 > ema50_1);
   if(long_slope && long_trend)
     {
      // Zone STATE: LOW dipped at/below EMA(10) AND CLOSE held >= EMA(21)
      // (card: candle dipped into/below EMA10 but closed above EMA21).
      const bool in_zone_now = (low1 <= ema10_1 && close1 >= ema21_1);
      // Entry EVENT: fresh retrace — prior closed bar's CLOSE was above the zone top.
      const bool fresh_retrace = (close2 > zone_top);
      if(in_zone_now && fresh_retrace)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
         const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_zone_long";
         return true;
        }
     }

   // ---------------- SHORT ----------------
   const bool short_slope = (ema50_1 < ema50_back);
   const bool short_trend = (close1 < ema50_1);
   if(short_slope && short_trend)
     {
      // Zone STATE: HIGH reached at/above EMA(10) AND CLOSE held <= EMA(21).
      const bool in_zone_now = (high1 >= ema10_1 && close1 <= ema21_1);
      // Entry EVENT: fresh retrace — prior closed bar's CLOSE was below the zone bottom.
      const bool fresh_retrace = (close2 < zone_bot);
      if(in_zone_now && fresh_retrace)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
         const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_zone_short";
         return true;
        }
     }

   return false;
  }

// Break-even management: move SL to entry once +be_trigger_pips in profit.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 0);
     }
  }

// No discretionary exit: positions close on fixed TP/SL or break-even stop.
bool Strategy_ExitSignal()
  {
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
