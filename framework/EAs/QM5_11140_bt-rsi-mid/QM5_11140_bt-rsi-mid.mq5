#property strict
#property version   "5.0"
#property description "QM5_11140 bt-rsi-mid — Backtrader RSI Midline Reversion (D1, both sides)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11140 bt-rsi-mid
// -----------------------------------------------------------------------------
// Source: backtrader sample samples/kselrsi/ksignal.py (Daniel Rodriguez /
//   backtrader), "Sample after post at keithselover.wordpress.com".
// Card: artifacts/cards_approved/QM5_11140_bt-rsi-mid.md (g0_status APPROVED).
//
// Mechanics (both-sided RSI mean reversion, closed-bar reads at shift 1):
//   RSI period 14 on D1.
//   Long entry  EVENT : RSI crosses UP through the lower threshold (35).
//   Short entry EVENT : RSI crosses DOWN through the upper threshold (65).
//                       The cross is the trigger; one event per bar.
//   Long exit   STATE : RSI rises above the midline exit threshold (50).
//   Short exit  STATE : RSI falls below the midline exit threshold (50).
//   One position per symbol/magic. A fresh OPPOSITE entry signal first closes
//   the current side (handled in Strategy_ExitSignal via opposite-cross check),
//   then the next closed bar can open the new side.
//   Emergency stop : entry -/+ sl_atr_mult * ATR (source is silent on stops;
//                    V5 default 3.0 ATR emergency stop). No fixed take-profit —
//                    the strategy exits on the RSI midline (Strategy_ExitSignal).
//   Spread guard   : skip only a genuinely wide spread > spread_pct_of_stop of
//                    the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11140;
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
input int    strategy_rsi_period         = 14;    // RSI lookback period
input double strategy_rsi_lower          = 35.0;  // long entry: cross UP through this
input double strategy_rsi_upper          = 65.0;  // short entry: cross DOWN through this
input double strategy_rsi_exit           = 50.0;  // midline exit threshold
input int    strategy_atr_period         = 14;    // ATR period for emergency stop
input double strategy_sl_atr_mult        = 3.0;   // emergency stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
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

// Both-sided RSI midline reversion. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // RSI at the two most recent CLOSED bars (shift 2 -> shift 1).
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_prev <= 0.0 || rsi_now <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Long entry EVENT: RSI crosses UP through the lower threshold ---
   const bool cross_up_lower = (rsi_prev <= strategy_rsi_lower &&
                                rsi_now  >  strategy_rsi_lower);
   // --- Short entry EVENT: RSI crosses DOWN through the upper threshold ---
   const bool cross_dn_upper = (rsi_prev >= strategy_rsi_upper &&
                                rsi_now  <  strategy_rsi_upper);

   if(!cross_up_lower && !cross_dn_upper)
      return false;

   if(cross_up_lower)
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
      req.tp     = 0.0;   // no fixed TP — exit on RSI midline (Strategy_ExitSignal)
      req.reason = "rsi_mid_long";
      return true;
     }

   // cross_dn_upper — short
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;      // no fixed TP — exit on RSI midline
   req.reason = "rsi_mid_short";
   return true;
  }

// No active trade management beyond the emergency ATR stop. Exit is RSI midline.
void Strategy_ManageOpenPosition()
  {
  }

// Midline exit STATE + opposite-signal exit. Closes long when RSI is above the
// exit threshold, short when RSI is below it; also closes on a fresh opposite
// entry cross so the next bar can flip side (card: "a new opposite signal first
// closes the current side").
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_prev <= 0.0 || rsi_now <= 0.0)
      return false;

   // Determine the side of the currently open position for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }

   if(is_long)
     {
      // Midline exit: RSI rose above the exit threshold.
      if(rsi_now > strategy_rsi_exit)
         return true;
      // Opposite signal: fresh short cross (RSI down through upper).
      if(rsi_prev >= strategy_rsi_upper && rsi_now < strategy_rsi_upper)
         return true;
     }
   else if(is_short)
     {
      // Midline exit: RSI fell below the exit threshold.
      if(rsi_now < strategy_rsi_exit)
         return true;
      // Opposite signal: fresh long cross (RSI up through lower).
      if(rsi_prev <= strategy_rsi_lower && rsi_now > strategy_rsi_lower)
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
