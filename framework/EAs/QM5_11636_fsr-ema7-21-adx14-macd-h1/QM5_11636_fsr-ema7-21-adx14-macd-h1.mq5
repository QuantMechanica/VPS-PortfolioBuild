#property strict
#property version   "5.0"
#property description "QM5_11636 fsr-ema7-21-adx14-macd-h1 — FSR Egudu EMA(7/21)+ADX(14)+MACD (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11636 fsr-ema7-21-adx14-macd-h1
// -----------------------------------------------------------------------------
// Source: forex-strategies-revealed.com, Strategy #19 "Egudu Simple 4 Tools
//         Trading" (contributor Egudu).
// Card: artifacts/cards_approved/QM5_11636_fsr-ema7-21-adx14-macd-h1.md
//       (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads at shift 1; H1):
//   Trigger EVENT : EMA(fast) crosses EMA(slow) — exactly ONE event per bar.
//                     LONG  = fast_prev <= slow_prev AND fast_now > slow_now
//                     SHORT = fast_prev >= slow_prev AND fast_now < slow_now
//   Trend STATE   : ADX(adx_period) > adx_threshold (trend strong enough).
//   Momentum STATE: MACD main line on the trade side AND sloping with the trade
//                     (LONG  needs main[1] > main[2]; SHORT needs main[1] < main[2]).
//   Consolidation : skip the trade when |MACD main| is below macd_consol_floor
//                     ("stay away when MACD is consolidating" — source note).
//   Stop          : sl_atr_mult * ATR(atr_period). No fixed TP (card: no TP).
//   Exit          : EMA(fast) crosses back AGAINST the open position direction.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                     modeled spread).
//
// Two-cross trap avoidance: only the EMA cross is an EVENT. ADX and MACD are
// STATES evaluated on the same closed bar, so a single fresh trigger suffices.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11636;
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
input int    strategy_ema_fast_period    = 7;       // fast EMA (cross trigger)
input int    strategy_ema_slow_period    = 21;      // slow EMA (cross trigger)
input int    strategy_adx_period         = 14;      // ADX trend-strength period
input double strategy_adx_threshold      = 25.0;    // ADX must exceed this
input int    strategy_macd_fast          = 12;      // MACD fast EMA
input int    strategy_macd_slow          = 26;      // MACD slow EMA
input int    strategy_macd_signal        = 9;       // MACD signal SMA
input double strategy_macd_consol_floor  = 0.0;     // skip if |MACD main| < this (0 = off)
input int    strategy_atr_period         = 14;      // ATR period (stop)
input double strategy_sl_atr_mult        = 2.0;     // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;    // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Entry (long + short). Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA values (closed bars: shift 1 = last closed, shift 2 = prior) ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // --- Trigger EVENT: fresh EMA cross on the last closed bar (one per bar) ---
   const bool cross_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!cross_up && !cross_down)
      return false;

   // --- Trend STATE: ADX above threshold ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_threshold))
      return false;

   // --- Momentum STATE: MACD main side + slope must confirm the cross ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 2);

   // --- Consolidation filter: skip when MACD main is too flat/near zero ---
   if(strategy_macd_consol_floor > 0.0 && MathAbs(macd_now) < strategy_macd_consol_floor)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   QM_OrderType side;
   double ref_price;
   if(cross_up)
     {
      // LONG: MACD trending up (main rising)
      if(!(macd_now > macd_prev))
         return false;
      side      = QM_BUY;
      ref_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else
     {
      // SHORT: MACD trending down (main falling)
      if(!(macd_now < macd_prev))
         return false;
      side      = QM_SELL;
      ref_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   if(ref_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, ref_price, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP (card: no TP)
   req.reason = (side == QM_BUY) ? "fsr_egudu_long" : "fsr_egudu_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active management beyond the fixed ATR stop. The defensive EMA-cross exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(fast) crosses back AGAINST the open position direction.
// One cross event per bar; check the side actually held.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool cross_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!cross_up && !cross_down)
      return false;

   // Determine which side this EA currently holds.
   bool have_long  = false;
   bool have_short = false;
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

   // Close a long on a fresh down-cross; close a short on a fresh up-cross.
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
