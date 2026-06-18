#property strict
#property version   "5.0"
#property description "QM5_11751 nfs-tom-demark-ema-momentum-h1 — EMA9/30 cross + Momentum(14) level (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11751 nfs-tom-demark-ema-momentum-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Tom Demark FX System", 9 Forex Systems compilation (~2005),
//         452915895-9-Forex-Systems-pdf.pdf p.13.
// Card: artifacts/cards_approved/QM5_11751_nfs-tom-demark-ema-momentum-h1.md
//       (g0_status APPROVED).
//
// NOTE ON NAME: the source system is named after Tom DeMark but the card's
// mechanical body uses ONLY standard EMA(9/30) crossover + Momentum(14) level
// confirmation. It explicitly omits the proprietary TD-indicator / trendline /
// turn-of-month components. This EA implements the card's mechanical rules
// verbatim — there is no calendar/seasonal or DeMark-count component in the card.
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Trigger EVENT (long) : EMA9 crosses ABOVE EMA30
//                          (EMA9[2] <= EMA30[2] AND EMA9[1] > EMA30[1]).
//   State filter (long)  : Momentum(14)[1] > 100  (price above its 14-bar ref).
//   Trigger EVENT (short): EMA9 crosses BELOW EMA30.
//   State filter (short) : Momentum(14)[1] < 100.
//   The EMA cross is the single EVENT; Momentum-vs-100 is a STATE level read on
//   the same closed bar (never a second event) — avoids the two-cross trap.
//   Stop         : 2 * ATR(14) (card factory default).
//   Take profit  : 3 * ATR(14) safety (card: no fixed TP, ride to EMA-cross exit).
//   Defensive exit: EMA9 crosses back through EMA30 in the opposite direction.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11751;
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
input int    strategy_ema_fast_period   = 9;      // EMA fast (direction)
input int    strategy_ema_slow_period   = 30;     // EMA slow (direction)
input int    strategy_mom_period        = 14;     // Momentum period
input double strategy_mom_level         = 100.0;  // Momentum level: >100 bullish / <100 bearish
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 3.0;    // safety target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
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

   // --- EMA values on the two most recent closed bars (shift 2 -> 1) ---
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double ema_fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0 ||
      ema_fast_now  <= 0.0 || ema_slow_now  <= 0.0)
      return false;

   // --- Trigger EVENT: a fresh EMA cross between shift 2 and shift 1 ---
   const bool cross_up   = (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now);
   const bool cross_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now);
   if(!cross_up && !cross_down)
      return false;

   // --- State filter: Momentum(14) level on the same closed bar (shift 1) ---
   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   QM_OrderType side;
   string reason;
   if(cross_up && mom > strategy_mom_level)
     {
      side   = QM_BUY;
      reason = "ema_cross_up_mom_bull";
     }
   else if(cross_down && mom < strategy_mom_level)
     {
      side   = QM_SELL;
      reason = "ema_cross_down_mom_bear";
     }
   else
      return false; // cross present but Momentum did not confirm

   // --- Stop / target from a single ATR value ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. The defensive
// EMA-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA9 crosses back through EMA30 against the open position.
// One event at shift 2 -> 1, direction-aware versus the held position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(fast_prev <= 0.0 || slow_prev <= 0.0 || fast_now <= 0.0 || slow_now <= 0.0)
      return false;

   const bool cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
   const bool cross_up   = (fast_prev <= slow_prev && fast_now > slow_now);

   // Determine the side of the open position for this magic.
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Close a long on bearish cross; close a short on bullish cross.
   if(have_long && cross_down)
      return true;
   if(have_short && cross_up)
      return true;
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
