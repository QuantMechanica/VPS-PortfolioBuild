#property strict
#property version   "5.0"
#property description "QM5_11850 vegas-wave-ema144169-h1 — Vegas Wave EMA144/169 channel breakout STATE + Williams fractal breakout EVENT (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11850 vegas-wave-ema144169-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Forex Strategy Vegas-Wave" (~2010). source_id
//         b61870d4-4397-5e38-8f46-aaca7b7a1bb0.
// Card: artifacts/cards_approved/QM5_11850_vegas-wave-ema144169-h1.md
//       (g0_status: APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1+):
//   Channel STATE: EMA(144)/EMA(169) form the "Vegas tunnel" channel.
//                  BULLISH breakout STATE = last closed bar Close[1] is above
//                      BOTH EMAs (Close[1] > EMA144[1] AND Close[1] > EMA169[1]).
//                  BEARISH breakout STATE = Close[1] below BOTH EMAs.
//                  This is a STATE (currently broken out), not the trigger.
//   Entry EVENT  : a single Williams fractal that JUST confirmed on this bar
//                  in the breakout direction. A fractal centred at shift
//                  (side+1) has its `side` right-hand confirming bars at shifts
//                  1..side, so it confirms exactly once — ONE event per bar,
//                  never two crossings on one bar (.DWX zero-trade trap #4).
//                  LONG : an UP fractal (local HIGH) above the channel ->
//                         BUY STOP `entry_buffer_pips` above that fractal HIGH.
//                  SHORT: a DOWN fractal (local LOW) below the channel ->
//                         SELL STOP `entry_buffer_pips` below that fractal LOW.
//   Pending life : order expires after `strategy_pending_bars` H1 candles
//                  (framework ORDER_TIME_SPECIFIED via req.expiration_seconds).
//                  Card: cancel if not triggered within 10 bars.
//   Stop loss    : ATR(14)[1] * strategy_sl_atr_mult from the stop entry price
//                  (card factory default 2x ATR; the "prior fractal" proxy).
//   Take profit  : ATR(14)[1] * strategy_tp_atr_mult from the stop entry
//                  (card factory default 4x ATR).
//   Exit (extra) : close the open position if price RE-ENTERS the channel, i.e.
//                  a closed bar's Close is between EMA144 and EMA169 (card Exit).
//   Session      : card filters EURUSD/GBPUSD entries to 07:00-18:00 GMT; cross
//                  rates (GBPJPY/EURGBP) have NO time filter. .DWX invariant #5:
//                  sessions are matched in BROKER time (DXZ = NY-Close GMT+2/+3,
//                  DST-aware). Per-symbol the filter is toggled by
//                  strategy_session_filter_on; defaults below are the 07-18 GMT
//                  window shifted +2 (standard time), set-file tunable.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a
//                  genuinely WIDE spread > strategy_spread_cap_pips.
//
// One position per magic; one live pending order per magic at a time. Only the
// 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11850;
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
input int    strategy_ema_fast_period    = 144;   // Vegas tunnel fast EMA (channel boundary)
input int    strategy_ema_slow_period    = 169;   // Vegas tunnel slow EMA (channel boundary)
input int    strategy_fractal_side_bars  = 2;     // Williams fractal: bars on EACH side
input int    strategy_atr_period         = 14;    // ATR period (SL / TP distance)
input double strategy_sl_atr_mult        = 2.0;   // SL distance = mult * ATR (card factory default)
input double strategy_tp_atr_mult        = 4.0;   // TP distance = mult * ATR (card factory default)
input double strategy_entry_buffer_pips  = 1.0;   // stop trigger offset beyond the fractal extreme
input int    strategy_pending_bars       = 10;    // cancel pending after N H1 candles (card: 10 bars)
input bool   strategy_session_filter_on  = true;  // EURUSD/GBPUSD: ON; cross rates: set OFF in setfile
input int    strategy_session_start_hr   = 9;     // session open  (BROKER hour, inclusive; ~07 GMT +2)
input int    strategy_session_end_hr     = 20;    // session close (BROKER hour, exclusive; ~18 GMT +2)
input double strategy_spread_cap_pips    = 20.0;  // skip only a genuinely WIDE spread

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
// Only consulted when strategy_session_filter_on is true (EURUSD/GBPUSD).
bool Vegas_InSession(const datetime broker_now)
  {
   if(!strategy_session_filter_on)
      return true;                  // cross rates: no time filter (card)
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

// Williams UP fractal centred at `shift`: local HIGH with `side` strictly
// higher-bounded bars on each side. Raw bar reads (perf-allowed: bounded
// structural pivot, closed-bar only, gated by QM_IsNewBar in OnTick).
bool Vegas_IsUpFractal(const int shift, const int side)
  {
   const double center = iHigh(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(center <= 0.0)
      return false;
   for(int k = 1; k <= side; ++k)
     {
      if(!(center > iHigh(_Symbol, _Period, shift - k)))  // right side (newer bars)
         return false;
      if(!(center > iHigh(_Symbol, _Period, shift + k)))  // left side (older bars)
         return false;
     }
   return true;
  }

// Williams DOWN fractal centred at `shift`: local LOW with `side` strictly
// lower-bounded bars on each side.
bool Vegas_IsDownFractal(const int shift, const int side)
  {
   const double center = iLow(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(center <= 0.0)
      return false;
   for(int k = 1; k <= side; ++k)
     {
      if(!(center < iLow(_Symbol, _Period, shift - k)))
         return false;
      if(!(center < iLow(_Symbol, _Period, shift + k)))
         return false;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time, EURUSD/GBPUSD only) +
// wide-spread guard.
bool Strategy_NoTradeFilter()
  {
   if(!Vegas_InSession(TimeCurrent()))
      return true;
   if(Vegas_WideSpread())
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The channel breakout (Close above/below BOTH EMAs) is a STATE; the freshly
// confirmed fractal in the breakout direction is the single EVENT.
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

   const double buffer  = strategy_entry_buffer_pips * pip;
   const double sl_dist = strategy_sl_atr_mult * atr_value;
   const double tp_dist = strategy_tp_atr_mult * atr_value;

   // Channel boundaries (the higher EMA is the upper edge, the lower the lower).
   const double channel_hi = MathMax(ema_fast, ema_slow);
   const double channel_lo = MathMin(ema_fast, ema_slow);

   // --- LONG: bullish channel breakout STATE + UP fractal EVENT confirmed ---
   // Breakout STATE: last closed bar closed ABOVE both EMAs (above the channel).
   if(close1 > channel_hi &&
      Vegas_IsUpFractal(center_shift, strategy_fractal_side_bars))
     {
      const double fr_high = iHigh(_Symbol, _Period, center_shift); // perf-allowed
      if(fr_high <= 0.0)
         return false;
      const double entry = fr_high + buffer;            // BUY STOP trigger
      const double sl    = entry - sl_dist;             // ATR stop below entry
      const double tp    = entry + tp_dist;             // ATR target above entry
      if(!(sl < entry))
         return false;
      req.type   = QM_BUY_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "vegas_long_buystop";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return true;
     }

   // --- SHORT: bearish channel breakout STATE + DOWN fractal EVENT confirmed ---
   // Breakout STATE: last closed bar closed BELOW both EMAs (below the channel).
   if(close1 < channel_lo &&
      Vegas_IsDownFractal(center_shift, strategy_fractal_side_bars))
     {
      const double fr_low = iLow(_Symbol, _Period, center_shift); // perf-allowed
      if(fr_low <= 0.0)
         return false;
      const double entry = fr_low - buffer;             // SELL STOP trigger
      const double sl    = entry + sl_dist;             // ATR stop above entry
      const double tp    = entry - tp_dist;             // ATR target below entry
      if(!(sl > entry))
         return false;
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

// No active trade management — exits are the ATR SL / ATR TP plus the
// re-enter-channel discretionary exit in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: price RE-ENTERS the channel, i.e. the last closed bar's
// Close sits BETWEEN EMA144 and EMA169 (card Exit). One state check per bar.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1); // EMA144
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1); // EMA169
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double channel_hi = MathMax(ema_fast, ema_slow);
   const double channel_lo = MathMin(ema_fast, ema_slow);

   // Re-entry into the channel = close back inside [channel_lo, channel_hi].
   return (close1 <= channel_hi && close1 >= channel_lo);
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
