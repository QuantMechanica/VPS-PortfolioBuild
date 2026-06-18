#property strict
#property version   "5.0"
#property description "QM5_11728 tc-m5-s16-wma-psar-adx — WMA/SMA bias + PSAR flip + ADX/DI trend (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11728 tc-m5-s16-wma-psar-adx
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         2013, Strategy #16.
// Card: artifacts/cards_approved/QM5_11728_tc-m5-s16-wma-psar-adx.md (APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; trigger compares shift 1 vs 2):
//   Direction STATE : WMA(fast) vs SMA(slow) bias.
//   Trend    STATE  : ADX(period) > adx_threshold  AND  DI+ vs DI- agree
//                     with the WMA bias.
//   Trigger  EVENT  : Parabolic SAR FLIPS to the trade side this bar
//                     (long: SAR above price @ shift2 -> below price @ shift1).
//                     The flip is the single EVENT; WMA bias + ADX/DI are
//                     STATES checked on the same closed bar. This avoids the
//                     two-cross-same-bar zero-trade trap.
//   Stop            : previous swing low (long) / swing high (short) on M5,
//                     via QM_StopStructure (lookback-based extreme).
//   Take profit     : RR multiple of the stop distance (card "hard TP at 2xSL").
//   Exit            : SAR flips back to the opposite side.
//   Spread guard    : block only a genuinely wide spread (fail-open on .DWX
//                     zero modeled spread).
//
// PSAR params: card states step=0.1, max=0.01 and flags them as inverted vs the
// standard convention (step=0.02, max=0.2). Implemented EXACTLY as carded via
// inputs; the unusual values are surfaced in open_questions for review.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11728;
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
input int    strategy_wma_period        = 5;      // fast WMA (direction bias)
input int    strategy_sma_period        = 11;     // slow SMA (direction bias)
input double strategy_sar_step          = 0.1;    // PSAR acceleration step (per card)
input double strategy_sar_max           = 0.01;   // PSAR acceleration max (per card)
input int    strategy_adx_period        = 14;     // ADX / DI period
input double strategy_adx_threshold     = 20.0;   // min ADX for a valid trend state
input int    strategy_struct_lookback   = 10;     // swing lookback for structural stop
input double strategy_tp_rr             = 2.0;    // take-profit = RR x stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// SAR position relative to bar price at a given closed-bar shift.
// Returns +1 if SAR is BELOW the bar (uptrend mode), -1 if ABOVE (downtrend
// mode), 0 if unreadable.
int SarSide(const int shift)
  {
   const double sar   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, shift);
   const double close = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close <= 0.0)
      return 0;
   if(sar < close)
      return +1; // SAR below price -> uptrend mode
   if(sar > close)
      return -1; // SAR above price -> downtrend mode
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread cap referenced to a fixed pip budget so it scales with the symbol.
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, 5); // ~5 pips
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Direction STATE: WMA(fast) vs SMA(slow) on the last closed bar ---
   const double wma = QM_WMA(_Symbol, _Period, strategy_wma_period, 1);
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(wma <= 0.0 || sma <= 0.0)
      return false;

   // --- Trend STATE: ADX above threshold + DI agreement ---
   const double adx     = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double di_plus  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0 || di_plus <= 0.0 || di_minus <= 0.0)
      return false;
   if(adx < strategy_adx_threshold)
      return false;

   // --- Trigger EVENT: a fresh PSAR flip on the just-closed bar ---
   // Long: SAR was ABOVE price at shift 2, now BELOW price at shift 1.
   // Short: mirror. One event per bar; states above gate the direction.
   const int side_prev = SarSide(2);
   const int side_now  = SarSide(1);
   if(side_prev == 0 || side_now == 0)
      return false;

   const bool flip_up   = (side_prev < 0 && side_now > 0);
   const bool flip_down = (side_prev > 0 && side_now < 0);

   bool go_long  = false;
   bool go_short = false;

   if(flip_up &&
      wma > sma &&             // bullish bias state
      di_plus > di_minus)      // +DI leads
      go_long = true;

   if(flip_down &&
      wma < sma &&             // bearish bias state
      di_minus > di_plus)      // -DI leads
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Structural stop: previous swing low (long) / high (short) ---
   const double sl = QM_StopStructure(_Symbol, otype, entry,
                                      strategy_struct_lookback);
   if(sl <= 0.0)
      return false;

   // --- Take profit: RR multiple of the realised stop distance ---
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "wma_psar_adx_long" : "wma_psar_adx_short";
   return true;
  }

// No active management beyond the structural stop / RR target; SAR-flip exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: SAR flips to the side opposite the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int side_now = SarSide(1);
   if(side_now == 0)
      return false;

   // Determine current position direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Long open + SAR now above price (downtrend mode) -> exit.
      if(ptype == POSITION_TYPE_BUY && side_now < 0)
         return true;
      // Short open + SAR now below price (uptrend mode) -> exit.
      if(ptype == POSITION_TYPE_SELL && side_now > 0)
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
