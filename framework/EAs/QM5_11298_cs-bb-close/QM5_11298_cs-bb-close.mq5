#property strict
#property version   "5.0"
#property description "QM5_11298 cs-bb-close — Bollinger close-break entry / midband exit (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11298 cs-bb-close
// -----------------------------------------------------------------------------
// Source: CryptoSignal/Crypto-Signal — app/analyzers/informants/bollinger_bands.py
//         + app/analyzers/crossover.py.
// Card: artifacts/cards_approved/QM5_11298_cs-bb-close.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Bands        : BB(period=21, deviation=2) on PRICE_CLOSE, H1.
//   Entry LONG   : EVENT = close crosses ABOVE the upper band
//                  (close[2] <= upper[2]  AND  close[1] > upper[1]).
//   Entry SHORT  : EVENT = close crosses BELOW the lower band
//                  (close[2] >= lower[2]  AND  close[1] < lower[1]).
//                  The close-break is the SINGLE event (DWX invariant #4); the
//                  long/short branches are mutually exclusive, so no two events
//                  are required on the same bar.
//   Exit LONG    : close crosses back BELOW the middle band
//                  (close[2] >= middle[2] AND close[1] < middle[1]).
//   Exit SHORT   : close crosses back ABOVE the middle band
//                  (close[2] <= middle[2] AND close[1] > middle[1]).
//   Stop         : catastrophic 2.5 * ATR(14) (source has no native stop).
//   Reversal     : only after flat state on the next completed bar — enforced by
//                  the one-position-per-magic gate (a new entry requires zero
//                  open positions, i.e. a prior exit must have flattened first).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  ATR stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11298;
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
input int    strategy_bb_period          = 21;    // Bollinger period (source: period_count=21)
input double strategy_bb_deviation       = 2.0;   // Bollinger deviations (source: 2 stddev)
input int    strategy_atr_period         = 14;    // catastrophic-stop ATR period
input double strategy_sl_atr_mult        = 2.5;   // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
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

// Bollinger close-break entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; reversal only after a flat bar.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Bands at the two most-recent CLOSED bars (shift 2 = prior, shift 1 = trigger).
   const double upper_prev = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double upper_now  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower_prev = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double lower_now  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(upper_prev <= 0.0 || upper_now <= 0.0 || lower_prev <= 0.0 || lower_now <= 0.0)
      return false;

   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_prev <= 0.0 || close_now <= 0.0)
      return false;

   // SINGLE EVENT: a fresh close-break of a band on the trigger bar.
   const bool cross_above_upper = (close_prev <= upper_prev && close_now > upper_now);
   const bool cross_below_lower = (close_prev >= lower_prev && close_now < lower_now);

   QM_OrderType dir;
   string reason;
   if(cross_above_upper)
     {
      dir    = QM_BUY;
      reason = "bb_close_break_long";
     }
   else if(cross_below_lower)
     {
      dir    = QM_SELL;
      reason = "bb_close_break_short";
     }
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit is the midband cross-back
   req.reason = reason;
   return true;
  }

// No active trade management beyond the catastrophic ATR stop. The midband
// cross-back exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Midband cross-back exit. One event at the trigger bar; direction-aware.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(mid_prev <= 0.0 || mid_now <= 0.0)
      return false;

   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_prev <= 0.0 || close_now <= 0.0)
      return false;

   // Determine the side of the currently open position for this magic.
   bool is_long = false;
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

   if(is_long)
      // Close long when close crosses back BELOW the middle band.
      return (close_prev >= mid_prev && close_now < mid_now);

   // Close short when close crosses back ABOVE the middle band.
   return (close_prev <= mid_prev && close_now > mid_now);
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
