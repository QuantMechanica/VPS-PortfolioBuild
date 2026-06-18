#property strict
#property version   "5.0"
#property description "QM5_11842 ait-macd-pos — MACD positive-zone crossover (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11842 ait-macd-pos
// -----------------------------------------------------------------------------
// Source: whchien/ai-trader, ai_trader/backtesting/strategies/classic/macd.py,
//         MACDStrategy (GitHub).
// Card: artifacts/cards_approved/QM5_11842_ait-macd-pos.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1):
//   Trigger EVENT : MACD main line crosses ABOVE the MACD signal line
//                   (main@2 <= signal@2  AND  main@1 > signal@1). One event/bar.
//   Positive-zone STATE : at the trigger bar BOTH MACD main AND signal lines
//                   are above zero (main@1 > 0 AND signal@1 > 0).
//   Exit EVENT    : MACD main line crosses BELOW the signal line
//                   (main@2 >= signal@2  AND  main@1 < signal@1).
//   Stop          : entry - sl_atr_mult * ATR(period).   (card P2 baseline 2.0*ATR(14))
//   Take profit   : none from source; left at 0.0 (signal-reversal exit drives close).
//   One open position per symbol/magic.
//
// Two-cross trap avoidance: the bullish MACD/signal cross is the SINGLE trigger
// EVENT. The positive-zone requirement is a STATE on the trigger bar (a level
// test, NOT a second cross). The exit is the opposite single cross EVENT.
//
// Symbol note: card lists GER40.DWX, which is NOT in dwx_symbol_matrix.csv.
// The canonical Darwinex DAX symbol is GDAXI.DWX (verified in the matrix) —
// registration ports GER40 -> GDAXI. SP500.DWX is backtest-only and not in
// the card's primary basket.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11842;
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
input int    strategy_macd_fast_period   = 12;    // MACD fast EMA period
input int    strategy_macd_slow_period   = 22;    // MACD slow EMA period
input int    strategy_macd_signal_period = 8;     // MACD signal EMA period
input bool   strategy_require_positive    = true; // require BOTH MACD lines > 0 at entry
input int    strategy_atr_period         = 14;    // ATR period for the protective stop
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — MACD/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- MACD main + signal, closed bars at shift 1 (now) and shift 2 (prev) ---
   const double main_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double main_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);
   const double sig_now   = QM_MACD_Signal(_Symbol, _Period,
                                           strategy_macd_fast_period,
                                           strategy_macd_slow_period,
                                           strategy_macd_signal_period, 1);
   const double sig_prev  = QM_MACD_Signal(_Symbol, _Period,
                                           strategy_macd_fast_period,
                                           strategy_macd_slow_period,
                                           strategy_macd_signal_period, 2);

   // --- Trigger EVENT: single bullish MACD/signal cross on the closed bar. ---
   const bool crossed_up = (main_prev <= sig_prev && main_now > sig_now);
   if(!crossed_up)
      return false;

   // --- Positive-zone STATE: both MACD lines above zero on the trigger bar.
   //     This is a level test, NOT a second cross event. ---
   if(strategy_require_positive)
     {
      if(!(main_now > 0.0 && sig_now > 0.0))
         return false;
     }

   // --- Protective stop from ATR. No source-defined TP (reversal-exit drives close). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
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
   req.tp     = 0.0;   // no take-profit; exit on bearish MACD cross
   req.reason = "macd_pos_zone_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. The reversal exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit EVENT: MACD main line crosses BELOW the signal line. One event at shift 1.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double main_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double main_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);
   const double sig_now   = QM_MACD_Signal(_Symbol, _Period,
                                           strategy_macd_fast_period,
                                           strategy_macd_slow_period,
                                           strategy_macd_signal_period, 1);
   const double sig_prev  = QM_MACD_Signal(_Symbol, _Period,
                                           strategy_macd_fast_period,
                                           strategy_macd_slow_period,
                                           strategy_macd_signal_period, 2);

   const bool crossed_down = (main_prev >= sig_prev && main_now < sig_now);
   return crossed_down;
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
