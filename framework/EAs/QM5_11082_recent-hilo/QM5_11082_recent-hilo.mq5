#property strict
#property version   "5.0"
#property description "QM5_11082 recent-hilo — EarnForex Recent High/Low N-bar breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11082 recent-hilo
// -----------------------------------------------------------------------------
// Source: EarnForex "Recent High/Low Alert" (GitHub + MQL5 source).
// Card: artifacts/cards_approved/QM5_11082_recent-hilo.md (g0_status APPROVED).
// Source id: 0693c604-4f96-56ef-be79-15efe9f48b86.
//
// Mechanics (symmetric long/short, closed-bar reads only):
//   Channel STATE : recent_high = highest HIGH over the N closed bars that
//                   PRECEDE the just-closed trigger bar (shifts 2..N+1);
//                   recent_low  = lowest LOW over the same window.
//                   On gapless .DWX CFDs the buffer is built from PRIOR closed
//                   bars (not the forming bar / not the trigger bar's own range)
//                   so the breakout is a real cross, not a tautology.
//   Long EVENT    : close[2] <= recent_high  AND  close[1] > recent_high
//                   (price was not already above the channel, now crossed up).
//   Short EVENT   : close[2] >= recent_low   AND  close[1] < recent_low.
//   Exit          : opposite breakout signal closes the open position
//                   (long closes on a fresh short signal and vice-versa).
//   Stop          : catastrophic ATR(period) stop at sl_atr_mult * ATR
//                   (card V5 P2 baseline = 2.5 ATR). No fixed TP — the
//                   opposite-signal rule is the primary exit.
//   Spread guard  : block only a genuinely wide spread (> spread_pct_of_stop
//                   of the stop distance); fail-OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11082;
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
input int    strategy_lookback_bars      = 20;     // N: recent high/low lookback (closed bars)
input int    strategy_atr_period         = 14;     // ATR period for the catastrophic stop
input double strategy_sl_atr_mult        = 2.5;    // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Compute the recent high/low channel from the N closed bars that PRECEDE the
// trigger bar (shifts 2..N+1). Returns false if any bar is unavailable.
bool RecentChannel(double &recent_high, double &recent_low)
  {
   const int n = strategy_lookback_bars;
   if(n < 1)
      return false;

   const int first_shift = 2;                 // skip the just-closed trigger bar
   const int last_shift  = strategy_lookback_bars + 1;

   double hi = -1.0;
   double lo = -1.0;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar structural read
      const double l = iLow(_Symbol, _Period, s);  // perf-allowed: closed-bar structural read
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(hi < 0.0 || h > hi) hi = h;
      if(lo < 0.0 || l < lo) lo = l;
     }

   recent_high = hi;
   recent_low  = lo;
   return (hi > 0.0 && lo > 0.0);
  }

// Detect a fresh breakout on the just-closed bar (shift 1). dir: +1 long, -1 short.
int BreakoutDirection()
  {
   double recent_high = 0.0;
   double recent_low  = 0.0;
   if(!RecentChannel(recent_high, recent_low))
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return 0;

   // Long: was at/below the channel high, now crossed above it (one event).
   if(close2 <= recent_high && close1 > recent_high)
      return +1;
   // Short: was at/above the channel low, now crossed below it (one event).
   if(close2 >= recent_low && close1 < recent_low)
      return -1;

   return 0;
  }

// Cheap O(1) per-tick gate. Spread guard only — channel work is on the
// closed-bar path. Fail-OPEN on .DWX zero modeled spread.
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

// Symmetric N-bar breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = BreakoutDirection();
   if(dir == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(dir > 0)
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
      req.tp     = 0.0;   // no fixed TP — opposite-signal exit
      req.reason = "recent_hilo_breakout_long";
      return true;
     }

   // dir < 0 — short
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
   req.reason = "recent_hilo_breakout_short";
   return true;
  }

// No active trade management beyond the fixed ATR catastrophic stop.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite-signal exit: close a long on a fresh short breakout and vice-versa.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = BreakoutDirection();
   if(dir == 0)
      return false;

   // Determine the direction of the currently open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      // Long open + fresh short signal => exit. Short open + fresh long => exit.
      if(pos_type == POSITION_TYPE_BUY && dir < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && dir > 0)
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
