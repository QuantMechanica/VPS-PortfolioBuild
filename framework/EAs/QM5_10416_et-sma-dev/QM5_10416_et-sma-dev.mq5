#property strict
#property version   "5.0"
#property description "QM5_10416 Elite Trader SMA Deviation Window — SMA-distance session breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10416 — Elite Trader SMA Deviation Window (et-sma-dev)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10416_et-sma-dev.md  (g0_status: APPROVED)
// Source: Elite Trader NinjaScript "CustomVolatilityBreakout" — SMA-distance
//         session entry with ATR-normalized deviation band, ATR target/stop.
//
// Mechanik (M5 baseline):
//   sma  = SMA(Close, sma_period)        on closed bar (shift 1)
//   dev  = |Close[1] - sma|
//   atr  = ATR(atr_period)               on closed bar (shift 1)
//   band = dev_atr_mult * atr            (lower edge of the deviation band, zn3)
//   tol  = tol_atr_mult * atr            (band width above the edge)
//   During the broker-time session window:
//     LONG  if Close[1] >= sma AND band <= dev <= band + tol
//     SHORT if Close[1] <= sma AND band <= dev <= band + tol
//   Stop   = stop_atr_mult * atr         (0.75 ATR baseline)
//   Target = tp_atr_mult   * atr         (1.00 ATR baseline)
//   Reject the entry if the live spread exceeds spread_pct_of_stop of the
//   stop distance.
//
// Session: source window is 08:30-11:30 US-exchange (ET) time. DXZ broker time
// tracks US DST (GMT+2/+3), so ET+7h is constant year-round → 15:30-18:30
// broker time. Exposed as broker-time hour:minute inputs so P3 can sweep them
// (card: "P3 should test whether the window is exchange-local or broker-server").
// Per .DWX invariant #5 the window is matched in BROKER time, not raw ET/UTC.
//
// One active position per magic; the next entry requires a new closed bar
// (framework new-bar entry gate), so no same-bar re-entry after a stop/target.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10416;
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
// SMA-distance / ATR-band parameters (card baseline values).
input int    sma_period          = 10;     // SMA(Close, st1) period
input int    atr_period          = 20;     // ATR period for band/stop/target scaling
input double dev_atr_mult        = 0.20;   // zn3    = 0.20 * ATR  (lower band edge)
input double tol_atr_mult        = 0.05;   // tol    = 0.05 * ATR  (band width)
input double stop_atr_mult       = 0.75;   // stop   = 0.75 * ATR
input double tp_atr_mult         = 1.00;   // target = 1.00 * ATR
input double spread_pct_of_stop  = 0.20;   // reject if spread > 20% of stop distance
// Session window in BROKER time (08:30-11:30 ET = 15:30-18:30 DXZ broker).
input int    session_start_hour  = 15;     // broker-time session open hour
input int    session_start_min   = 30;     // broker-time session open minute
input int    session_end_hour    = 18;     // broker-time session close hour
input int    session_end_min     = 30;     // broker-time session close minute

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Minutes-since-midnight of a broker datetime.
int Strategy_BrokerMinutes(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

// TRUE if the broker time is inside [start, end) session window (wrap-safe).
bool Strategy_InSession(const datetime broker_time)
  {
   const int now   = Strategy_BrokerMinutes(broker_time);
   const int start = session_start_hour * 60 + session_start_min;
   const int end   = session_end_hour   * 60 + session_end_min;
   if(start == end)
      return false;
   if(start < end)
      return (now >= start && now < end);
   // Wrap across midnight.
   return (now >= start || now < end);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading entirely outside the broker-time session window. O(1).
bool Strategy_NoTradeFilter()
  {
   return !Strategy_InSession(TimeCurrent());
  }

// Entry: SMA-distance band inside the session window. Caller guarantees a new
// closed bar. Reads only closed-bar (shift 1) values.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One active position per magic — no stacking.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_CURRENT, sma_period, 1, PRICE_CLOSE);
   if(sma <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: closed bar, new-bar gated
   if(close1 <= 0.0)
      return false;

   const double dev  = MathAbs(close1 - sma);
   const double band = dev_atr_mult * atr;          // lower band edge (zn3)
   const double tol  = tol_atr_mult * atr;          // band width (tolerance)

   // Deviation must sit inside the narrow band [band, band + tol].
   if(dev < band || dev > band + tol)
      return false;

   QM_OrderType side;
   if(close1 >= sma)
      side = QM_BUY;
   else if(close1 <= sma)
      side = QM_SELL;
   else
      return false;

   // Stop & target as prices off a market fill (req.price = 0.0 → market).
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, stop_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   // Spread guard: reject only a genuinely wide spread relative to stop distance.
   // .DWX quotes ask==bid (0 modeled spread) in the tester → fail-open.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread    = ask - bid;
      const double stop_dist = MathAbs(entry - sl);
      if(stop_dist > 0.0 && spread > spread_pct_of_stop * stop_dist)
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // market fill; framework sizes lots via QM_LotsForRisk
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "et_sma_dev_band";
   return true;
  }

// SL/TP are fixed ATR brackets set at entry; no per-tick management needed.
void Strategy_ManageOpenPosition()
  {
  }

// Close the open position at the session close (source: exit on session close).
bool Strategy_ExitSignal()
  {
   return !Strategy_InSession(TimeCurrent());
  }

// Defer to the central two-axis news filter.
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
     {
      // Outside the session: still allow a session-close exit before bailing.
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
      return;
     }

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
