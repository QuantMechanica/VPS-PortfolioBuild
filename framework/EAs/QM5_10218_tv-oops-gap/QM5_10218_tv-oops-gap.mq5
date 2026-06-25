#property strict
#property version   "5.0"
#property description "QM5_10218 TradingView Larry Williams Oops Gap-Reversal (intraday M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10218_tv-oops-gap
// -----------------------------------------------------------------------------
// Larry Williams "Oops" gap-reversal. Daily bars drive the setup; the M15
// chart drives intraday execution, the day-extreme trailing stop and the
// session exit.
//
//   Long  setup: today's D1 open < yesterday's D1 low  AND yesterday bearish.
//                A buy-stop is staged at yesterday's low + tick filter so the
//                fill only happens when price reclaims the prior-day low.
//   Short setup: today's D1 open > yesterday's D1 high AND yesterday bullish.
//                A sell-stop is staged at yesterday's high - tick filter so the
//                fill only happens when price reclaims the prior-day high.
//
// Stop: trails the current day's extreme (low for longs, high for shorts) with
// an emergency cap at strategy_atr_emergency_mult * ATR(14) from entry so the
// baseline risk is never blown out on a wide day. No fixed take-profit.
// Force-close at session end — no overnight carry.
//
// Helpers: QM_IsNewBar, QM_ATR, QM_FrameworkMagic, QM_TM_OpenPosition,
// QM_TM_ClosePosition, QM_TM_MoveSL. Raw OHLC of CLOSED daily/intraday bars via
// iOpen/iClose/iHigh/iLow (shift>=1) is permitted; today's forming day-bar
// (shift 0) is read for the running intraday extreme, which is raw OHLC and not
// an indicator read.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10218;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Larry Williams Oops gap-reversal parameters (from Strategy Card).
input int    strategy_tick_filter_points  = 2;     // ticks beyond prior extreme to confirm the reclaim
input int    strategy_atr_period          = 14;    // ATR period for the emergency stop cap
input double strategy_atr_emergency_mult  = 3.0;   // emergency stop cap = mult * ATR(14)
input int    strategy_session_close_hour  = 21;    // broker hour to force-close (no overnight carry)
input int    strategy_max_spread_points   = 80;    // skip entries when spread exceeds this

// -----------------------------------------------------------------------------
// Strategy hooks — implemented against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (wrong TF, wide spread). Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Day-extreme protective stop with a mult*ATR(14) emergency cap. Longs trail
// the current day's low; shorts trail the current day's high. If the day-extreme
// stop is wider than the ATR cap, the stop is tightened to the ATR cap.
double OopsDayExtremeStop(const ENUM_POSITION_TYPE ptype, const double entry)
  {
   // perf-allowed: raw OHLC of the forming day-bar (shift 0) for the running
   // intraday extreme; OHLC, not an indicator read.
   const double day_low  = iLow(_Symbol, PERIOD_D1, 0);
   const double day_high = iHigh(_Symbol, PERIOD_D1, 0);
   if(day_low <= 0.0 || day_high <= 0.0 || entry <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_emergency_mult <= 0.0)
      return 0.0;
   const double cap_dist = atr * strategy_atr_emergency_mult;

   if(ptype == POSITION_TYPE_BUY)
     {
      double stop = day_low;
      const double cap_stop = entry - cap_dist;     // never further than ATR cap
      if(stop <= 0.0 || stop >= entry)
         stop = cap_stop;
      stop = MathMax(stop, cap_stop);               // tighten if day-extreme too wide
      return (stop > 0.0 && stop < entry) ? stop : 0.0;
     }

   double stop = day_high;
   const double cap_stop = entry + cap_dist;
   if(stop <= 0.0 || stop <= entry)
      stop = cap_stop;
   stop = MathMin(stop, cap_stop);
   return (stop > entry) ? stop : 0.0;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true (one closed M15 bar per call). The
// entry is a stop order at the prior-day extreme +/- the tick filter, so the
// fill only triggers when price reclaims that extreme intraday.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_tick_filter_points < 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_emergency_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // One position per magic, one staged stop per magic — no pyramiding.
   if(QM_TM_OpenPositionCount(magic) > 0 || OopsHasPendingOrder(magic))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   // --- Daily setup (yesterday body + extremes, today's open) ----------------
   // perf-allowed: raw OHLC of closed/forming daily bars; no QM OHLC reader.
   const double y_open  = iOpen(_Symbol, PERIOD_D1, 1);
   const double y_close = iClose(_Symbol, PERIOD_D1, 1);
   const double y_high  = iHigh(_Symbol, PERIOD_D1, 1);
   const double y_low   = iLow(_Symbol, PERIOD_D1, 1);
   const double t_open  = iOpen(_Symbol, PERIOD_D1, 0); // today's daily open
   if(y_open <= 0.0 || y_close <= 0.0 || y_high <= 0.0 || y_low <= 0.0 || t_open <= 0.0)
      return false;

   const bool yesterday_bearish = (y_close < y_open);
   const bool yesterday_bullish = (y_close > y_open);
   const bool down_gap = (t_open < y_low);   // gapped below prior low -> long setup
   const bool up_gap   = (t_open > y_high);  // gapped above prior high -> short setup
   if(!(down_gap && yesterday_bearish) && !(up_gap && yesterday_bullish))
      return false;

   const double offset = strategy_tick_filter_points * point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const int stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_dist = MathMax(1, stop_level_points) * point;

   // Long: buy-stop at yesterday's low + filter. Only valid as a stop above ask.
   if(down_gap && yesterday_bearish)
     {
      const double entry = y_low + offset;
      if(entry <= ask + min_dist)
         return false;

      const double sl = OopsDayExtremeStop(POSITION_TYPE_BUY, entry);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(sl, _Digits);
      req.reason = "oops_down_gap_reclaim_long";
      return true;
     }

   // Short: sell-stop at yesterday's high - filter. Only valid as a stop below bid.
   const double entry = y_high - offset;
   if(entry >= bid - min_dist)
      return false;

   const double sl = OopsDayExtremeStop(POSITION_TYPE_SELL, entry);
   if(sl <= 0.0 || sl <= entry)
      return false;

   req.type = QM_SELL_STOP;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = "oops_up_gap_reclaim_short";
   return true;
  }

// TRUE if this EA's magic already has a staged stop order on this symbol.
bool OopsHasPendingOrder(const int magic)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

// Called every tick when an open position exists. Trail the protective stop to
// the current day's extreme (low for longs, high for shorts), ATR-capped, only
// ever in the protective direction.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(magic <= 0 || point <= 0.0)
      return;

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
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      const double new_sl = OopsDayExtremeStop(ptype, entry);
      if(new_sl <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         if(new_sl < entry && (cur_sl <= 0.0 || new_sl > cur_sl + point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "trail_current_day_low");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(new_sl > entry && (cur_sl <= 0.0 || new_sl < cur_sl - point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "trail_current_day_high");
        }
     }
  }

// Return TRUE to force-close the open position now — session end / no overnight.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_session_close_hour);
  }

// Optional news-filter override. Defer to the central two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
