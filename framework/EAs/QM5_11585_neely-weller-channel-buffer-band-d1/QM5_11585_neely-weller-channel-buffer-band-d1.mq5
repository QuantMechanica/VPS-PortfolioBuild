#property strict
#property version   "5.0"
#property description "QM5_11585 neely-weller-channel-buffer-band-d1 — Channel breakout + buffer band flip (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11585 neely-weller-channel-buffer-band-d1
// -----------------------------------------------------------------------------
// Source: Neely & Weller (2013) "Lessons from the Evolution of Foreign Exchange
//   Trading Strategies" (source_id 577eb0aa-7880-5c0a-a8f9-56cd126c19f9).
// Card: artifacts/cards_approved/QM5_11585_neely-weller-channel-buffer-band-d1.md
//   (g0_status APPROVED).
//
// Mechanics (always-in-market flip rule, closed-bar reads at shift 1; D1):
//   Channel STATE (levels): Donchian-style channel over the prior N CLOSES,
//     measured strictly BEFORE the current closed bar (shifts 2..N+1):
//       chanHi = max(close[2..N+1]) ; chanLo = min(close[2..N+1]).
//     A buffer band of fraction x widens the channel:
//       upper = chanHi * (1 + x) ; lower = chanLo * (1 - x).
//   Trigger EVENT (single, per bar): the latest closed bar's close beyond a
//     buffered band edge:
//       longBreak  : close[1] > upper   -> desired state = LONG.
//       shortBreak : close[1] < lower   -> desired state = SHORT.
//     The two breaks are mutually exclusive (upper > lower), so there is no
//     two-cross-same-bar trap — each is its own trigger.
//   This is an always-in-market trend system: a position changes direction only
//     on an OPPOSITE buffered break. We map that onto the framework's one-
//     position-per-magic model as: Strategy_ExitSignal closes the open position
//     on the first opposite break, and Strategy_EntrySignal opens the new
//     direction on the same break (no flat state held between).
//   Safety stop : entry -/+ sl_atr_mult * ATR(atr_period) (card: 3xATR(14)).
//     No fixed TP — the edge is captured by the opposite-break flip.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//     stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11585;
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
input int    strategy_channel_len       = 20;     // N: lookback in closes for the channel (sweep 5,10,20,40)
input double strategy_buffer_band        = 0.001;  // x: buffer fraction beyond channel edge (sweep 0.0005..0.003)
input int    strategy_atr_period         = 14;     // ATR period for the safety stop
input double strategy_sl_atr_mult        = 3.0;    // safety stop distance = mult * ATR (card: 3x, trend system)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Channel + buffered-band helper (closed-bar math; called only on the new-bar
// path or after a one-per-tick gate that the framework already enforces).
//   Computes the buffered upper/lower band edges from the prior N closes
//   (shifts 2..N+1) and reports whether the latest closed bar (shift 1) broke
//   the upper band (returns +1), the lower band (returns -1), or neither (0).
//   Returns 0 on insufficient/invalid data.
// -----------------------------------------------------------------------------
int ChannelBreakState()
  {
   const int n = strategy_channel_len;
   if(n < 1)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return 0;

   // Channel over the N closes strictly BEFORE the trigger bar: shifts 2..N+1.
   double chan_hi = -1.0;
   double chan_lo = -1.0;
   for(int s = 2; s <= n + 1; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(c <= 0.0)
         return 0; // history not warm enough -> no signal
      if(chan_hi < 0.0 || c > chan_hi)
         chan_hi = c;
      if(chan_lo < 0.0 || c < chan_lo)
         chan_lo = c;
     }
   if(chan_hi <= 0.0 || chan_lo <= 0.0)
      return 0;

   const double upper = chan_hi * (1.0 + strategy_buffer_band);
   const double lower = chan_lo * (1.0 - strategy_buffer_band);

   if(close1 > upper)
      return +1; // long break
   if(close1 < lower)
      return -1; // short break
   return 0;      // inside the buffered channel -> hold current state
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — channel work is on the closed-
// bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: open in the direction of a fresh buffered-channel break. Caller
// guarantees QM_IsNewBar() == true (closed-bar gate). One position per magic;
// the opposite-break flip is handled by Strategy_ExitSignal closing first.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic — if one is open, the flip is managed
   // by the exit hook (it closes on the opposite break before re-entry).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int state = ChannelBreakState();
   if(state == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(state > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit is the opposite-break flip
      req.reason = "nw_channel_buffer_long";
      return true;
     }

   // state < 0 -> short break
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "nw_channel_buffer_short";
   return true;
  }

// No active trade management beyond the fixed ATR safety stop. Direction change
// is handled by the opposite-break flip in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Flip exit: close the open position when an OPPOSITE buffered break fires.
// A long is closed on a short break; a short is closed on a long break. After
// this closes, the same break re-opens the new direction via Strategy_EntrySignal
// on a subsequent closed-bar evaluation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int state = ChannelBreakState();
   if(state == 0)
      return false; // inside the buffered channel — hold the position

   // Determine the current open direction for this EA's magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Opposite break only: long open + short break, or short open + long break.
   if(have_long && state < 0)
      return true;
   if(have_short && state > 0)
      return true;
   return false; // break agrees with current direction — stay in
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
