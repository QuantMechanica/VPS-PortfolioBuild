#property strict
#property version   "5.0"
#property description "QM5_12361 tmom-ibs — Time-Series Momentum + Internal Bar Strength (long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12361 tmom-ibs
// -----------------------------------------------------------------------------
// Source: ThewindMom/151-trading-strategies, src/strategies/etfs/mean_reversion.py
//         "Strategy 4.4: Mean-Reversion (IBS)".
// Card: artifacts/cards_approved/QM5_12361_tmom-ibs.md (g0_status APPROVED).
//
// Mechanics (long/short, all reads on the CLOSED bar at shift 1, D1):
//   TMOM trend STATE : sign of the N-period return  ret = close[1] - close[1+N].
//                      ret > 0  -> uptrend   (long-only dips)
//                      ret < 0  -> downtrend (short-only rips)
//                      The trend is a persistent STATE, not the trigger event.
//   IBS (in-EA)      : IBS = (close - low) / (high - low) of the closed bar.
//                      If high == low -> IBS = 0.5. Bounded closed-bar OHLC
//                      (perf-allowed: 4 single-shift reads, no loops).
//   Trigger EVENT    : a FRESH threshold cross of IBS on the trigger bar.
//                      Long  (uptrend)   : IBS[1] < ibs_low  AND  IBS[2] >= ibs_low
//                      Short (downtrend) : IBS[1] > ibs_high AND  IBS[2] <= ibs_high
//                      The cross is the single EVENT; TMOM is the STATE. This
//                      avoids the two-cross-same-bar zero-trade trap.
//   Exit             : time stop after hold_bars completed D1 bars, OR an
//                      opposite IBS extreme on the closed bar (IBS back through
//                      the far threshold), whichever first. Hard ATR stop also.
//   Stop             : entry -/+ sl_atr_mult * ATR(atr_period).  No fixed TP
//                      (mean-reversion exits on time / opposite signal).
//   Spread guard     : block only a genuinely wide spread (> spread_pct_of_stop
//                      of the stop distance). Fail-open on .DWX zero spread.
//
// One open position per symbol/magic. Only the 5 Strategy_* hooks + Strategy
// inputs are EA-specific; everything else is framework wiring.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12361;
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
input int    strategy_tmom_lookback      = 50;     // N-period return lookback for TMOM trend STATE
input double strategy_ibs_low            = 0.2;    // long dip threshold (uptrend): IBS crosses below
input double strategy_ibs_high           = 0.8;    // short rip threshold (downtrend): IBS crosses above
input int    strategy_hold_bars          = 1;      // time-stop: close after this many completed D1 bars
input int    strategy_atr_period         = 14;     // ATR period for the protective stop
input double strategy_sl_atr_mult        = 1.5;    // hard stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // block only if spread > this % of stop distance

// File-scope: bar-open time of the entry bar, used by the time-stop exit. The
// hold-period counter is derived from closed-bar shifts only (no per-EA new-bar
// gate — the framework owns QM_IsNewBar).
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// IBS of a closed bar at the given shift. Bounded OHLC reads (perf-allowed).
// Returns 0.5 on a degenerate (high == low) bar.
// -----------------------------------------------------------------------------
double IBS_AtShift(const int shift)
  {
   const double hi = iHigh(_Symbol, _Period, shift);  // perf-allowed: single closed-bar read
   const double lo = iLow(_Symbol, _Period, shift);   // perf-allowed
   const double cl = iClose(_Symbol, _Period, shift); // perf-allowed
   const double rng = hi - lo;
   if(rng <= 0.0)
      return 0.5;
   double ibs = (cl - lo) / rng;
   if(ibs < 0.0) ibs = 0.0;
   if(ibs > 1.0) ibs = 1.0;
   return ibs;
  }

// TMOM trend STATE on the closed bar: +1 uptrend, -1 downtrend, 0 flat/invalid.
int TMOM_State()
  {
   const double close_now  = iClose(_Symbol, _Period, 1);                          // perf-allowed
   const double close_back = iClose(_Symbol, _Period, 1 + strategy_tmom_lookback); // perf-allowed
   if(close_now <= 0.0 || close_back <= 0.0)
      return 0;
   const double ret = close_now - close_back;
   if(ret > 0.0) return 1;
   if(ret < 0.0) return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// TMOM trend STATE picks the side; a fresh IBS threshold cross is the trigger.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- TMOM trend STATE (closed bar) ---
   const int trend = TMOM_State();
   if(trend == 0)
      return false;

   // --- IBS on the trigger bar (shift 1) and the prior bar (shift 2) ---
   const double ibs_now  = IBS_AtShift(1);
   const double ibs_prev = IBS_AtShift(2);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Trigger EVENT: a FRESH IBS threshold cross, in the trend direction ---
   if(trend > 0)
     {
      // Uptrend: buy the dip on a fresh cross BELOW ibs_low (was not below last bar).
      const bool fresh_dip = (ibs_now < strategy_ibs_low && ibs_prev >= strategy_ibs_low);
      if(!fresh_dip)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — time / opposite-signal exit
      req.reason = "tmom_ibs_long";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // open time of the bar we enter on
      return true;
     }

   // trend < 0 — Downtrend: short the rip on a fresh cross ABOVE ibs_high.
   const bool fresh_rip = (ibs_now > strategy_ibs_high && ibs_prev <= strategy_ibs_high);
   if(!fresh_rip)
      return false;

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
   req.reason = "tmom_ibs_short";
   g_entry_bar_time = iTime(_Symbol, _Period, 0);
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exits in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: time stop after hold_bars completed D1 bars, OR an opposite IBS extreme.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open side from the position registered to this magic.
   bool is_long  = false;
   bool have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time stop: close once enough completed bars have elapsed since entry. ---
   if(g_entry_bar_time > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open
      // Count fully-completed bars between the entry bar and the current bar.
      const int bars_since = iBarShift(_Symbol, _Period, g_entry_bar_time, false)
                             - iBarShift(_Symbol, _Period, cur_bar, false);
      if(bars_since >= strategy_hold_bars)
         return true;
     }

   // --- Opposite IBS extreme on the closed bar (mean-reversion completed). ---
   const double ibs_now = IBS_AtShift(1);
   if(is_long && ibs_now > strategy_ibs_high)
      return true;
   if(!is_long && ibs_now < strategy_ibs_low)
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_entry_bar_time = 0;
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
