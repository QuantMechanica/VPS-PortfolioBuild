#property strict
#property version   "5.0"
#property description "QM5_11811 fin-wr14x — Williams %R(14) threshold re-entry reversal (D1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11811 fin-wr14x
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance, stock_analysis/backest_all_indicators.py,
//         strategy_WR(df, n=14). Card:
//         artifacts/cards_approved/QM5_11811_fin-wr14x.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads; MT5 iWPR returns %R in [-100, 0]):
//   Williams %R(n=14) threshold re-entry reversal, symmetric long+short.
//
//   ENTRY (single cross EVENT, evaluated once per closed bar):
//     LONG  : %R(1) > OS  AND  %R(2) <= OS   (re-enters UP from oversold)
//     SHORT : %R(1) < OB  AND  %R(2) >= OB   (re-enters DOWN from overbought)
//     OS = -80 (oversold floor), OB = -20 (overbought ceiling).
//
//   EXIT (opposite threshold re-entry, single cross EVENT):
//     close LONG  when %R(1) < OB AND %R(2) >= OB  (re-enters down from OB)
//     close SHORT when %R(1) > OS AND %R(2) <= OS  (re-enters up from OS)
//     An opposite ENTRY signal also closes the active position first, then the
//     next-bar entry gate opens the reversed side (one position per magic).
//
//   STOP: 2.0 * ATR(14) hard stop from entry (card P3 variant). No fixed TP;
//         the strategy exits on the opposite re-entry signal.
//
//   Two-cross trap: the LONG-entry cross (up through OS=-80) and the LONG-exit
//   cross (down through OB=-20) are distinct events at opposite ends of the
//   range — they cannot coincide on one bar, so there is no zero-trade trap.
//
//   Spread guard fails OPEN on .DWX zero modeled spread (only a genuinely wide
//   spread blocks). No swap gate.
//
// SYMBOL PORT: card lists GER40.DWX which is NOT in dwx_symbol_matrix.csv.
//   Ported GER40 -> GDAXI.DWX (DAX 40, present in matrix). Flagged.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11811;
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
input int    strategy_wpr_period         = 14;     // Williams %R lookback (n)
input double strategy_wpr_oversold       = -80.0;  // OS floor (re-entry up = long)
input double strategy_wpr_overbought     = -20.0;  // OB ceiling (re-entry down = short)
input int    strategy_atr_period         = 14;     // ATR period for the hard stop
input double strategy_sl_atr_mult        = 2.0;    // hard stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
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

// Symmetric long+short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Williams %R at the last closed bar (shift 1) and the bar before (shift 2).
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // iWPR is bounded to [-100, 0]; exactly 0.0 on both = no data yet.
   if(wpr_now == 0.0 && wpr_prev == 0.0)
      return false;

   // LONG: %R re-enters UP from oversold (single cross EVENT).
   const bool long_cross  = (wpr_prev <= strategy_wpr_oversold &&
                             wpr_now  >  strategy_wpr_oversold);
   // SHORT: %R re-enters DOWN from overbought (single cross EVENT).
   const bool short_cross = (wpr_prev >= strategy_wpr_overbought &&
                             wpr_now  <  strategy_wpr_overbought);

   if(!long_cross && !short_cross)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(long_cross)
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
      req.tp     = 0.0;   // no fixed TP — exit on opposite re-entry
      req.reason = "wpr_reentry_long";
      return true;
     }

   // short_cross
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "wpr_reentry_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit logic is the
// opposite-re-entry signal in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on opposite threshold re-entry, OR when an opposite ENTRY signal is
// forming (close the active side first; the next-bar entry gate then reverses).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   if(wpr_now == 0.0 && wpr_prev == 0.0)
      return false;

   // Re-entry crosses (same definitions as entry).
   const bool reenter_up   = (wpr_prev <= strategy_wpr_oversold &&
                              wpr_now  >  strategy_wpr_oversold);   // up from OS
   const bool reenter_down = (wpr_prev >= strategy_wpr_overbought &&
                              wpr_now  <  strategy_wpr_overbought); // down from OB

   // Determine the open side for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Long closes on a down re-entry from OB (its own exit) OR on a fresh short
   // entry cross (reversal). Both are the SAME down-from-OB event here.
   if(have_long && reenter_down)
      return true;

   // Short closes on an up re-entry from OS (its own exit) OR on a fresh long
   // entry cross (reversal). Both are the SAME up-from-OS event here.
   if(have_short && reenter_up)
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
