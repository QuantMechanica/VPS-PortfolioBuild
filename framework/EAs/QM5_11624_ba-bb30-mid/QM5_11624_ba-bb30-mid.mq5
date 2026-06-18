#property strict
#property version   "5.0"
#property description "QM5_11624 ba-bb30-mid — Basana Bollinger(30,2) outer-band reversion, midline-cross exit (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11624 ba-bb30-mid
// -----------------------------------------------------------------------------
// Source: Gabriel Martin Becedillas Ruiz / gbeced, Basana Bollinger Bands
//   sample strategy (samples/strategies/bbands.py).
// Card: artifacts/cards_approved/QM5_11624_ba-bb30-mid.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads, D1):
//   Bollinger Bands on close, period = bb_period (30), deviation = bb_dev (2.0).
//   Entry LONG  EVENT : close[2] >= lower[2]  AND  close[1] <  lower[1]
//                       (close crosses DOWN below the lower band — reversion buy).
//   Entry SHORT EVENT : close[2] <= upper[2]  AND  close[1] >  upper[1]
//                       (close crosses UP above the upper band — reversion sell).
//   Exit  LONG  EVENT : close[2] <  mid[2]    AND  close[1] >= mid[1]
//                       (close crosses UP through the midline basis MA).
//   Exit  SHORT EVENT : close[2] >  mid[2]    AND  close[1] <= mid[1]
//                       (close crosses DOWN through the midline basis MA).
//   Emergency stop    : stop_atr_mult * ATR(atr_period) from entry. No fixed TP;
//                       the position is meant to be neutralised at the midline.
//
// Two-cross trap avoided: entry is ONE band-cross event; exit is a SEPARATE
// midline-cross event evaluated only while a position is open. They never
// require two fresh crosses on the same bar.
//
// .DWX invariants: spread guard fails OPEN on zero modeled spread; no swap gate;
// QM_IsNewBar() consumed exactly once (framework OnTick gate).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11624;
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
input int    strategy_bb_period          = 30;    // Bollinger period (basis MA + bands)
input double strategy_bb_dev             = 2.0;   // Bollinger standard-deviation multiple
input int    strategy_atr_period         = 20;    // ATR period for the emergency stop
input double strategy_stop_atr_mult      = 3.0;   // emergency stop = mult * ATR(atr_period)
input int    strategy_warmup_bars        = 60;    // minimum closed bars before trading
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric reversion entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warmup guard: enough closed bars for stable bands.
   if(Bars(_Symbol, _Period) < strategy_warmup_bars)
      return false;

   // Closed-bar Bollinger reads (deviation arg MANDATORY).
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double lower2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double upper2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   if(lower1 <= 0.0 || lower2 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG EVENT: close crosses DOWN below the lower band ---
   const bool cross_below_lower = (close2 >= lower2 && close1 < lower1);
   // --- SHORT EVENT: close crosses UP above the upper band ---
   const bool cross_above_upper = (close2 <= upper2 && close1 > upper1);

   if(cross_below_lower)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit at the midline cross
      req.reason = "bb30_lower_reversion_long";
      return true;
     }

   if(cross_above_upper)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit at the midline cross
      req.reason = "bb30_upper_reversion_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR emergency stop. Midline-cross exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Midline-cross exit. Closes the open position when price crosses back through
// the Bollinger basis MA in the neutralising direction. One event at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double mid1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double mid2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   if(mid1 <= 0.0 || mid2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Determine current position direction for this magic.
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

   // Long neutralises when close crosses UP through the midline.
   const bool cross_up_mid   = (close2 <  mid2 && close1 >= mid1);
   // Short neutralises when close crosses DOWN through the midline.
   const bool cross_down_mid = (close2 >  mid2 && close1 <= mid1);

   if(is_long && cross_up_mid)
      return true;
   if(!is_long && cross_down_mid)
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
