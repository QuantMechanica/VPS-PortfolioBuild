#property strict
#property version   "5.0"
#property description "QM5_11417 lasker-triple-bb-mean-reversion-gbpjpy-m15 — Triple Bollinger Band mean reversion (GBPJPY M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11417 lasker-triple-bb-mean-reversion-gbpjpy-m15
// -----------------------------------------------------------------------------
// Source: Rita Lasker (Green Forex Group), "Forex GBP/JPY Scalping Strategy —
//         Triple Bollinger Bands". Card:
//         artifacts/cards_approved/QM5_11417_lasker-triple-bb-mean-reversion-gbpjpy-m15.md
//         (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1; all bands period 50 PRICE_CLOSE):
//   Three Bollinger Bands of increasing width, same period / source price:
//     BB1 (inner)  = period 50, deviation 2.0  -> bb1_upper / bb1_lower
//     BB2 (middle) = period 50, deviation 3.0  -> bb2_upper / bb2_lower
//     BB3 (outer)  = period 50, deviation 4.0  -> bb3_upper / bb3_lower
//     BB midline   = SMA50 (BB_Middle, any deviation; same value) = take-profit.
//
//   The signal is the band touch / extension into the middle zone:
//     SHORT: close[1] >= (bb1_upper + bb2_upper)/2  -- price extended above the
//            2-3 sigma midpoint, statistically extreme, expected to revert.
//     LONG : close[1] <= (bb1_lower + bb2_lower)/2  -- mirror.
//
//   Take profit : BB midline (SMA50) -- the mean-reversion target.
//   Stop loss   : outer band + buffer. SHORT: bb3_upper + buffer_pips; the
//                 LONG mirror: bb3_lower - buffer_pips. Pip distance via the
//                 scale-correct QM_StopRulesPipsToPriceDistance (JPY-safe).
//   Session     : London open through Tokyo close (avoid the dead NY-close ->
//                 Tokyo-open window) in BROKER time, set in the setfile.
//   Spread guard: skip only a genuinely wide spread (fail-OPEN on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11417;
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
input int    strategy_bb_period          = 50;     // Bollinger period (all three bands)
input double strategy_bb_dev_inner       = 2.0;    // BB1 deviation (inner)
input double strategy_bb_dev_middle      = 3.0;    // BB2 deviation (middle)
input double strategy_bb_dev_outer       = 4.0;    // BB3 deviation (outer)
input int    strategy_sl_buffer_pips     = 5;      // stop buffer beyond the outer band
input int    strategy_sl_cap_pips        = 30;     // hard stop-distance cap (card P2 cap)
input bool   strategy_session_enabled    = true;   // restrict to active Tokyo+London+NY hours
// Active window in BROKER time (DXZ NY-Close GMT+2/+3). The card asks to avoid
// the dead NY-close -> Tokyo-open window. Tokyo open ~00:00 UTC ~= 02:00 broker;
// NY close ~21:00 UTC ~= 23:00 broker. Active = [start,end); blocks only the
// dead ~23:00..02:00 gap. Per-symbol session tuning lives in the setfile.
input int    strategy_session_start_hour = 2;      // broker hour: Tokyo open
input int    strategy_session_end_hour   = 23;     // broker hour: NY close
input int    strategy_spread_cap_pips    = 30;     // card spread cap

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: optional session window + spread guard. Regime /
// signal work is on the closed-bar path in Strategy_EntrySignal. Fail-OPEN on
// .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session window (broker time). London open .. Tokyo close; the dead
   //     window (NY close -> Tokyo open) is excluded. Wrap-safe via QM_Sig_Session.
   if(strategy_session_enabled)
     {
      const datetime broker_now = TimeCurrent();
      if(QM_Sig_Session(broker_now, strategy_session_start_hour, strategy_session_end_hour) <= 0)
         return true; // outside the active session -> block
     }

   // --- Spread guard. Card cap is 30 pips; zero .DWX modeled spread passes.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false; // cannot size the cap — defer to entry gate

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Triple Bollinger bands on the last CLOSED bar (shift 1). The deviation
   //     arg is mandatory; all three share period + PRICE_CLOSE. ---
   const double bb1_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,  1);
   const double bb2_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_middle, 1);
   const double bb3_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer,  1);
   const double bb1_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,  1);
   const double bb2_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_middle, 1);
   const double bb3_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer,  1);
   const double bb_mid    = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   if(bb1_upper <= 0.0 || bb2_upper <= 0.0 || bb3_upper <= 0.0 ||
      bb1_lower <= 0.0 || bb2_lower <= 0.0 || bb3_lower <= 0.0 || bb_mid <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Upper / lower middle-zone thresholds (midpoint of 2 sigma and 3 sigma bands).
   const double upper_threshold   = (bb1_upper + bb2_upper) / 2.0;
   const double lower_threshold   = (bb1_lower + bb2_lower) / 2.0;

   // SHORT: price extended above the upper middle-zone midpoint.
   const bool short_event = (close1 >= upper_threshold);
   // LONG EVENT: mirror below the lower midpoint.
   const bool long_event  = (close1 <= lower_threshold);

   if(!short_event && !long_event)
      return false;

   const QM_OrderType side = short_event ? QM_SELL : QM_BUY;

   // Reference entry price (market). req.price=0 -> framework fills at send.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = short_event ? bid : ask;
   if(entry <= 0.0)
      return false;

   // --- Stop loss: outer band +/- buffer pips. Scale-correct pip distance. ---
   const double buffer_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(buffer_distance <= 0.0)
      return false;

   double sl = 0.0;
   double tp = bb_mid; // take profit = the BB midline (SMA50), the mean-reversion target.

   if(short_event)
      sl = bb3_upper + buffer_distance;
   else
      sl = bb3_lower - buffer_distance;

   // Hard stop-distance cap (card P2 cap = 30 pips): if the structural stop is
   // wider than the cap, clamp it to the cap distance from entry.
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance > 0.0)
     {
      if(short_event && (sl - entry) > cap_distance)
         sl = entry + cap_distance;
      else if(long_event && (entry - sl) > cap_distance)
         sl = entry - cap_distance;
     }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   // Sanity: TP must be on the reverting side and SL on the protective side.
   if(short_event)
     {
      if(!(tp < entry) || !(sl > entry))
         return false;
     }
   else
     {
      if(!(tp > entry) || !(sl < entry))
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = short_event ? "triple_bb_meanrev_short" : "triple_bb_meanrev_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management; the fixed SL (outer band) and TP (midline) govern
// the trade. Mean reversion exits on TP at the SMA50 or SL at the outer band.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP — the SMA50 take-profit IS the exit.
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
