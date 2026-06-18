#property strict
#property version   "5.0"
#property description "QM5_11852 bb50-234-meanturn-m1 — BB(50,2.34) mean-turn fade (M1, JPY FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11852 bb50-234-meanturn-m1
// -----------------------------------------------------------------------------
// Source: Chelo (via Rita Lasker / Green Forex Group), "Great GBP/JPY 1M
//   Scalping Strategy" (~2012). Card: artifacts/cards_approved/
//   QM5_11852_bb50-234-meanturn-m1.md (g0_status APPROVED).
//
// Mechanics (mean-reversion fade, closed-bar reads; trigger bar = shift 1):
//   The card frames three BB(50) bands at deviation 2/3/4. We realize it as a
//   primary INNER band at deviation `bb_dev_inner` (2.34, per slug/prompt) and
//   an OUTER band at `bb_dev_outer` (3.0) used only for the "at least halfway
//   to the next band" extension check. Target = BB(50) midline = SMA50.
//
//   SELL setup:
//     Overextension STATE (shift 2): close[2] > inner_upper[2]   (beyond inner band)
//                AND close[2] >= midpoint(inner_upper[2], outer_upper[2])
//     Turn  EVENT  (shift 1)       : close[1] <= inner_upper[1]   (retraced back inside)
//     -> fade SELL toward the midline.
//   BUY setup: mirror at the lower bands.
//
//   The retrace-back-inside at shift 1 is the SINGLE trigger EVENT; the
//   overextension at shift 2 is a STATE observed on the PRIOR bar — never the
//   same bar (avoids the two-cross-same-bar zero-trade trap).
//
//   Stop  : sl_atr_mult * ATR(atr_period) from entry (source: very tight 1xATR).
//   Take  : the BB(50) midline (SMA50) captured at signal time, clamped to a
//           minimum RR via QM_TakeRR so a near-midline entry still has a target.
//   Session filter (BROKER time): London-open..Tokyo-close window. DXZ broker is
//           GMT+2/+3 (US-DST aware); the card's 07:00-13:00 GMT maps to broker
//           ~09:00-15:00 / ~10:00-16:00. Window is derived from UTC via
//           QM_BrokerToUTC so it tracks the real session regardless of DST.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11852;
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
input int    strategy_bb_period         = 50;     // Bollinger period (all bands)
input double strategy_bb_dev_inner      = 2.34;   // inner band deviation (touch/turn)
input double strategy_bb_dev_outer      = 3.0;    // outer band deviation (extension target)
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 1.0;    // stop distance = mult * ATR (card: ~1xATR)
input double strategy_min_rr            = 1.0;    // floor RR if midline target is too close
input bool   strategy_session_enabled   = true;   // restrict to London-open..Tokyo-close
input int    strategy_session_start_utc = 7;      // session start hour, UTC (card: 07:00 GMT)
input int    strategy_session_end_utc   = 13;     // session end hour, UTC (card: 13:00 GMT)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
// The session/regime logic lives on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// True if `broker_now` falls inside the configured UTC session window.
// Converts broker time to UTC so the window tracks the real London/Tokyo
// session regardless of DXZ DST (GMT+2/+3). Wrap-safe.
bool InSession(const datetime broker_now)
  {
   if(!strategy_session_enabled)
      return true;
   const datetime utc = QM_BrokerToUTC(broker_now);
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   const int h = dt.hour;
   const int s = strategy_session_start_utc;
   const int e = strategy_session_end_utc;
   if(s == e)
      return true; // degenerate full-day window
   if(s < e)
      return (h >= s && h < e);
   // wrap past midnight
   return (h >= s || h < e);
  }

// Mean-reversion fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Session filter (broker time -> UTC inside InSession).
   if(!InSession(TimeCurrent()))
      return false;

   // --- Bollinger bands at the trigger bar (shift 1) and prior bar (shift 2) ---
   const double inner_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1, PRICE_CLOSE);
   const double inner_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1, PRICE_CLOSE);
   const double mid_1      = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1, PRICE_CLOSE);

   const double inner_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2, PRICE_CLOSE);
   const double inner_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2, PRICE_CLOSE);
   const double outer_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2, PRICE_CLOSE);
   const double outer_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2, PRICE_CLOSE);

   if(inner_up_1 <= 0.0 || inner_lo_1 <= 0.0 || mid_1 <= 0.0 ||
      inner_up_2 <= 0.0 || inner_lo_2 <= 0.0 || outer_up_2 <= 0.0 || outer_lo_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_bid <= 0.0 || entry_ask <= 0.0)
      return false;

   // --- SELL: overextension STATE on shift 2, turn-back-inside EVENT on shift 1 ---
   const double up_midpoint = (inner_up_2 + outer_up_2) * 0.5;
   const bool sell_extended = (close2 > inner_up_2) && (close2 >= up_midpoint);
   const bool sell_turn     = (close1 <= inner_up_1);   // retraced back inside inner band
   if(sell_extended && sell_turn)
     {
      const double entry = entry_bid;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      // Target = BB midline (SMA50). For a SELL the midline is below; clamp to a
      // minimum RR so a near-midline entry still carries a sensible target.
      double tp = mid_1;
      const double rr_tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_min_rr);
      if(rr_tp > 0.0 && rr_tp < tp)   // for SELL, lower TP = further = better; pick the further of midline vs min-RR
         tp = rr_tp;
      if(tp <= 0.0 || tp >= entry)    // TP must be below entry for a SELL
         tp = rr_tp;
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb50_meanturn_sell";
      return true;
     }

   // --- BUY: mirror at the lower bands ---
   const double lo_midpoint = (inner_lo_2 + outer_lo_2) * 0.5;
   const bool buy_extended = (close2 < inner_lo_2) && (close2 <= lo_midpoint);
   const bool buy_turn     = (close1 >= inner_lo_1);   // retraced back inside inner band
   if(buy_extended && buy_turn)
     {
      const double entry = entry_ask;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      // Target = BB midline (SMA50), which sits above for a BUY. Clamp to min RR.
      double tp = mid_1;
      const double rr_tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_min_rr);
      if(rr_tp > 0.0 && rr_tp > tp)   // for BUY, higher TP = further = better; pick the further of midline vs min-RR
         tp = rr_tp;
      if(tp <= 0.0 || tp <= entry)    // TP must be above entry for a BUY
         tp = rr_tp;
      if(tp <= 0.0 || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb50_meanturn_buy";
      return true;
     }

   return false;
  }

// Fixed ATR stop + midline target only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP (the midline target IS the take-profit).
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
