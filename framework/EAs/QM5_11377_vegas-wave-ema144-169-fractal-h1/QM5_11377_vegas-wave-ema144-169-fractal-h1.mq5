#property strict
#property version   "5.0"
#property description "QM5_11377 vegas-wave-ema144-169-fractal-h1 — Vegas Wave EMA144/169 tunnel + Williams fractal breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11377 vegas-wave-ema144-169-fractal-h1
// -----------------------------------------------------------------------------
// Source: "Forex Strategy Vegas Wave" (anonymous "Vegas", ForexFactory ~2004-06).
// Card: artifacts/cards_approved/QM5_11377_vegas-wave-ema144-169-fractal-h1.md
//       (g0_status: APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1+):
//   Trend STATE  : the EMA(144)/EMA(169) "tunnel".
//                  LONG  state  = last closed bar CLOSED ABOVE EMA(169).
//                  SHORT state  = last closed bar CLOSED BELOW EMA(144).
//   Entry EVENT  : a single Williams fractal that JUST confirmed this bar.
//                  A fractal centred at shift 3 is confirmed now (its two
//                  right-hand bars are shifts 1 and 2). Exactly ONE event per
//                  bar — never two crossings on the same bar (zero-trade trap).
//                  LONG  : a DOWN fractal (local low) confirmed -> BUY STOP
//                          1 pip above that fractal bar's HIGH.
//                  SHORT : an UP fractal (local high) confirmed -> SELL STOP
//                          1 pip below that fractal bar's LOW.
//   Pending life : order expires after `strategy_pending_bars` H1 candles
//                  (framework ORDER_TIME_SPECIFIED via req.expiration_seconds).
//   Stop loss    : opposite EMA boundary at placement (EMA169 for LONG,
//                  EMA144 for SHORT), capped at `strategy_sl_max_pips`.
//   Take profit  : ATR(14) * strategy_tp_atr_mult from the stop entry price
//                  (the runner target; see open_questions re TP1/TP2 split).
//   Break-even   : after price has moved `strategy_be_atr_mult` * ATR in favour,
//                  shift SL to entry (+buffer) — proxy for the card's
//                  "move to BE after TP1".
//   Session      : trade only inside [session_start, session_end) BROKER hours
//                  (London + NY). DXZ broker = NY-Close GMT+2/+3 (DST-aware).
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a
//                  genuinely wide spread > strategy_spread_cap_pips.
//
// One position per magic; one live pending order per magic at a time. Only the
// 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11377;
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
input int    strategy_ema_fast_period   = 144;   // Vegas tunnel fast EMA (SHORT boundary)
input int    strategy_ema_slow_period   = 169;   // Vegas tunnel slow EMA (LONG boundary)
input int    strategy_fractal_side_bars = 2;     // Williams fractal: bars on EACH side
input int    strategy_atr_period        = 14;    // ATR period (TP / BE distance)
input double strategy_tp_atr_mult       = 5.0;   // TP distance = mult * ATR (runner target)
input double strategy_be_atr_mult       = 3.0;   // move SL to BE after price moves mult*ATR
input double strategy_entry_buffer_pips = 1.0;   // stop trigger offset beyond the fractal extreme
input double strategy_sl_max_pips       = 30.0;  // P2 cap on the EMA-boundary stop distance
input int    strategy_pending_bars      = 4;     // cancel pending after N H1 candles
input int    strategy_session_start_hr  = 8;     // session open  (BROKER hour, inclusive)
input int    strategy_session_end_hr    = 19;    // session close (BROKER hour, exclusive)
input double strategy_spread_cap_pips   = 20.0;  // skip only a genuinely WIDE spread (pips)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Pip size for the current symbol (10 * point on 3/5-digit quotes, else point).
double Vegas_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Cheap O(1) wide-spread guard, fail-OPEN on .DWX zero modeled spread.
bool Vegas_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                 // no valid quote — never block on it
   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return false;
   const double spread = ask - bid;
   // Only a genuinely wide positive spread blocks; zero/negative passes.
   return (spread > 0.0 && spread > strategy_spread_cap_pips * pip);
  }

// Inside the trading session, in BROKER time (wrap-safe within a single day).
bool Vegas_InSession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_hr <= strategy_session_end_hr)
      return (h >= strategy_session_start_hr && h < strategy_session_end_hr);
   // Wrapped window (e.g. 22..6): inside if before end OR at/after start.
   return (h >= strategy_session_start_hr || h < strategy_session_end_hr);
  }

// Count this EA's live PENDING orders (stop orders awaiting trigger).
int Vegas_PendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         count++;
     }
   return count;
  }

// Williams DOWN fractal centred at `shift`: local LOW with `side` lower-bounded
// bars on each side. Uses raw bar reads (perf-allowed: bounded structural pivot,
// closed-bar only, gated by QM_IsNewBar in OnTick).
bool Vegas_IsDownFractal(const int shift, const int side)
  {
   const double center = iLow(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(center <= 0.0)
      return false;
   for(int k = 1; k <= side; ++k)
     {
      if(!(center < iLow(_Symbol, _Period, shift - k)))  // right side (newer bars)
         return false;
      if(!(center < iLow(_Symbol, _Period, shift + k)))  // left side (older bars)
         return false;
     }
   return true;
  }

// Williams UP fractal centred at `shift`: local HIGH with `side` higher-bounded
// bars on each side.
bool Vegas_IsUpFractal(const int shift, const int side)
  {
   const double center = iHigh(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(center <= 0.0)
      return false;
   for(int k = 1; k <= side; ++k)
     {
      if(!(center > iHigh(_Symbol, _Period, shift - k)))
         return false;
      if(!(center > iHigh(_Symbol, _Period, shift + k)))
         return false;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + wide-spread guard.
bool Strategy_NoTradeFilter()
  {
   if(!Vegas_InSession(TimeCurrent()))
      return true;
   if(Vegas_WideSpread())
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The tunnel break is a STATE; the freshly-confirmed fractal is the single EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One position per magic; and only one resting pending order at a time.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(Vegas_PendingCount(magic) > 0)
      return false;

   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1); // EMA144
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1); // EMA169
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // The fractal centre sits `side` bars back from the last closed bar so its
   // right-hand confirming bars (shifts 1..side) all exist => ONE event/bar.
   const int center_shift = strategy_fractal_side_bars + 1;

   const double buffer = strategy_entry_buffer_pips * pip;
   const double sl_cap = strategy_sl_max_pips * pip;

   // --- LONG: tunnel broken UP (closed above EMA169) + DOWN fractal confirmed ---
   if(close1 > ema_slow && Vegas_IsDownFractal(center_shift, strategy_fractal_side_bars))
     {
      const double fr_high = iHigh(_Symbol, _Period, center_shift); // perf-allowed
      if(fr_high <= 0.0)
         return false;
      const double entry = fr_high + buffer;            // BUY STOP trigger
      double sl = ema_slow;                             // opposite boundary (EMA169)
      // Stop must sit below entry; cap distance at sl_max_pips.
      if(!(sl < entry))
         return false;
      if((entry - sl) > sl_cap)
         sl = entry - sl_cap;
      const double tp = entry + strategy_tp_atr_mult * atr_value;
      req.type   = QM_BUY_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "vegas_long_buystop";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return true;
     }

   // --- SHORT: tunnel broken DOWN (closed below EMA144) + UP fractal confirmed ---
   if(close1 < ema_fast && Vegas_IsUpFractal(center_shift, strategy_fractal_side_bars))
     {
      const double fr_low = iLow(_Symbol, _Period, center_shift); // perf-allowed
      if(fr_low <= 0.0)
         return false;
      const double entry = fr_low - buffer;             // SELL STOP trigger
      double sl = ema_fast;                             // opposite boundary (EMA144)
      if(!(sl > entry))
         return false;
      if((sl - entry) > sl_cap)
         sl = entry + sl_cap;
      const double tp = entry - strategy_tp_atr_mult * atr_value;
      req.type   = QM_SELL_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "vegas_short_sellstop";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return true;
     }

   return false;
  }

// Break-even shift after price moves strategy_be_atr_mult * ATR in favour
// (proxy for the card's "move to BE after TP1"). Operates on the open position.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return;

   // Trigger distance (ATR*mult) and a tiny 1-pip BE buffer, in pip units.
   const int trigger_pips = (int)MathRound((strategy_be_atr_mult * atr_value) / pip);
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, /*buffer_pips=*/1);
     }
  }

// No discretionary exit — exits are SL (EMA boundary) / TP (ATR) / break-even.
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
