#property strict
#property version   "5.0"
#property description "QM5_11807 fin-kelt10 — Keltner(10) band-reversion (long+short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11807 fin-kelt10
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance, stock_analysis/backest_all_indicators.py,
//         strategy_KeltnerChannel_origin(df, n=10).
// Card: artifacts/cards_approved/QM5_11807_fin-kelt10.md (g0_status APPROVED).
//
// Keltner Channel built in-EA (no QM_Keltner helper):
//   midline = QM_EMA(period)        (closed bar, shift 1)
//   upper   = midline + mult * QM_ATR(period)
//   lower   = midline - mult * QM_ATR(period)
//
// Channel position is a STATE; the band CROSS is the single trigger EVENT.
//   Long  entry EVENT : close[1] <= lower[1]  AND  close[2] >  lower[2]
//                       (a fresh downward break of the lower band — touch).
//   Short entry EVENT : close[1] >= upper[1]  AND  close[2] <  upper[2].
//   Exit long  EVENT  : close[1] >= upper[1]  AND  close[2] <  upper[2]
//                       (opposite-band reversal exit; source EXIT_LONG).
//   Exit short EVENT  : close[1] <= lower[1]  AND  close[2] >  lower[2].
//   Stop  : ATR(14)-normalized hard stop = sl_atr_mult * ATR(stop_atr_period)
//           (P3 portable variant from the card; no fixed TP — reversal exits).
//
// One band is the trigger per direction; the prior-bar position is a STATE
// check, NOT a second cross EVENT — this avoids the two-cross zero-trade trap.
//
// Symbol port: card lists GER40.DWX which is NOT in dwx_symbol_matrix.csv;
// ported to GDAXI.DWX (DAX 40, present in matrix). Flagged for review.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11807;
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
input int    strategy_keltner_period     = 10;    // Keltner EMA + ATR period (n=10)
input double strategy_keltner_atr_mult   = 2.0;   // band width = mult * ATR(period)
input int    strategy_stop_atr_period    = 14;    // ATR period for the hard stop
input double strategy_sl_atr_mult        = 2.0;   // hard stop distance = mult * ATR(stop_atr_period)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// In-EA Keltner channel (closed-bar reads only). shift>=1.
// -----------------------------------------------------------------------------

// Lower band at the given closed-bar shift. Returns <=0.0 on warmup failure.
double KeltnerLower(const int shift)
  {
   const double mid = QM_EMA(_Symbol, _Period, strategy_keltner_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_keltner_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return 0.0;
   return mid - strategy_keltner_atr_mult * atr;
  }

// Upper band at the given closed-bar shift. Returns <=0.0 on warmup failure.
double KeltnerUpper(const int shift)
  {
   const double mid = QM_EMA(_Symbol, _Period, strategy_keltner_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_keltner_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return 0.0;
   return mid + strategy_keltner_atr_mult * atr;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — channel/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short reversion entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Keltner bands at the trigger bar (shift 1) and prior bar (shift 2) ---
   const double lower1 = KeltnerLower(1);
   const double lower2 = KeltnerLower(2);
   const double upper1 = KeltnerUpper(1);
   const double upper2 = KeltnerUpper(2);
   if(lower1 <= 0.0 || lower2 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Trigger EVENT (single cross per direction). Prior-bar side is a STATE.
   const bool long_signal  = (close1 <= lower1 && close2 >  lower2); // fresh break below lower band
   const bool short_signal = (close1 >= upper1 && close2 <  upper2); // fresh break above upper band

   if(!long_signal && !short_signal)
      return false;

   // --- ATR-normalized hard stop (portable across DWX symbols) ---
   const double atr_stop = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_stop <= 0.0)
      return false;

   if(long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_stop, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — opposite-band reversal exit
      req.reason = "kelt10_lower_reversion_long";
      return true;
     }

   // short_signal
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_stop, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "kelt10_upper_reversion_short";
   return true;
  }

// No active management beyond the fixed ATR stop. Reversal exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite-band reversal exit. One cross EVENT per direction at shift 1.
// Long exits on a fresh break above the upper band; short on a break below lower.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double lower1 = KeltnerLower(1);
   const double lower2 = KeltnerLower(2);
   const double upper1 = KeltnerUpper(1);
   const double upper2 = KeltnerUpper(2);
   if(lower1 <= 0.0 || lower2 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const bool exit_long_event  = (close1 >= upper1 && close2 <  upper2); // EXIT_LONG  (source)
   const bool exit_short_event = (close1 <= lower1 && close2 >  lower2); // EXIT_SHORT (source)
   if(!exit_long_event && !exit_short_event)
      return false;

   // Resolve the held direction; only signal an exit that matches it.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && exit_long_event)
         return true;
      if(ptype == POSITION_TYPE_SELL && exit_short_event)
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
