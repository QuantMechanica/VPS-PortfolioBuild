#property strict
#property version   "5.0"
#property description "QM5_11714 chelo-gbpjpy-triple-bb50-scalp — Triple BB(50,2/3/4) mean-reversion fade (GBPJPY, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11714 chelo-gbpjpy-triple-bb50-scalp
// -----------------------------------------------------------------------------
// Source: Chelo / Rita Lasker, "Great GBPJPY 1M Scalping Strategy",
//         ritalasker.com (180977573), ~2012.
// Card: artifacts/cards_approved/QM5_11714_chelo-gbpjpy-triple-bb50-scalp.md
//       (g0_status APPROVED).
//
// Mechanics (mean-reversion fade, closed-bar reads at shift 1):
//   Three BB(50) with escalating deviations 2 / 3 / 4 sigma build a multi-zone
//   band structure around the shared SMA(50) basis. Price extending beyond the
//   inner band (dev 2) and at least halfway to the middle band (dev 3) is
//   "overextended" -> expect mean reversion back to SMA(50).
//
//   Overextension threshold (STATE), upper side:
//        thr_up = (BB(50,dev2).upper + BB(50,dev3).upper) / 2
//   lower side symmetric with the lower bands.
//
//   Literal card trigger:
//     SHORT: close[1] >= thr_up[1]
//     LONG : close[1] <= thr_dn[1]
//
//   Take profit  : fixed 7 pips, the factory target for the SMA(50) mean
//                  reversion move on GBPJPY M5.
//   Stop loss    : fixed 10 pips (card default; JPY-scaled via QM_StopFixedPips).
//   Session      : London-open to Tokyo-close, 08:00-17:00 broker time (param).
//   Spread guard : fail-open on .DWX zero modeled spread; only a genuinely wide
//                  spread > spread_pips blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11714;
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
input int    strategy_bb_period         = 50;     // shared BB / SMA basis period
input double strategy_bb_dev_inner      = 2.0;    // inner band (dev 2) "red"
input double strategy_bb_dev_middle     = 3.0;    // middle band (dev 3) "orange"
input double strategy_bb_dev_outer      = 4.0;    // outer band (dev 4) "yellow" (context)
input int    strategy_tp_pips           = 7;     // fixed TP cap toward SMA(50) center
input int    strategy_sl_pips           = 10;    // fixed stop loss (pips)
input bool   strategy_use_session       = true;   // restrict to session window
input int    strategy_session_start_hr  = 8;      // broker-hour session open (incl.)
input int    strategy_session_end_hr    = 17;     // broker-hour session close (excl.)
input double strategy_spread_pips       = 4.0;    // block only genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + wide-spread guard. Fail-open on
// .DWX zero modeled spread (never block on zero/negative spread).
bool Strategy_NoTradeFilter()
  {
   // --- Session filter in BROKER time (DXZ NY-Close GMT+2/+3) ---
   if(strategy_use_session)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt); // TimeCurrent() == broker time in tester
      const int hr = dt.hour;
      bool in_session;
      if(strategy_session_start_hr <= strategy_session_end_hr)
         in_session = (hr >= strategy_session_start_hr && hr < strategy_session_end_hr);
      else // wrap-around window (e.g. 22 -> 06)
         in_session = (hr >= strategy_session_start_hr || hr < strategy_session_end_hr);
      if(!in_session)
         return true; // outside session -> block
     }

   // --- Wide-spread guard (fail-open on zero spread) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_pips);
      if(spread_cap > 0.0 && (ask - bid) > spread_cap)
         return true; // genuinely wide spread -> block
     }

   return false;
  }

// Mean-reversion fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar BB reads. deviation arg is MANDATORY on every call. ---
   const double bb2u_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,  1);
   const double bb3u_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_middle, 1);
   const double bb2l_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,  1);
   const double bb3l_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_middle, 1);
   if(bb2u_1 <= 0.0 || bb3u_1 <= 0.0 || bb2l_1 <= 0.0 || bb3l_1 <= 0.0)
      return false;

   // Overextension thresholds: halfway between dev2 and dev3 bands.
   const double thr_up_1 = (bb2u_1 + bb3u_1) / 2.0;
   const double thr_dn_1 = (bb2l_1 + bb3l_1) / 2.0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool short_fade = (close1 >= thr_up_1);
   const bool long_fade  = (close1 <= thr_dn_1);

   if(!short_fade && !long_fade)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(short_fade && !long_fade)
     {
      const double entry = bid;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;                   // framework fills market at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "triple_bb50_fade_short";
      return true;
     }

   if(long_fade && !short_fade)
     {
      const double entry = ask;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "triple_bb50_fade_long";
      return true;
     }

   return false; // both sides fired (degenerate) -> stand aside
  }

// Fixed SL/TP do the work; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP (TP sits at the SMA(50) center).
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
