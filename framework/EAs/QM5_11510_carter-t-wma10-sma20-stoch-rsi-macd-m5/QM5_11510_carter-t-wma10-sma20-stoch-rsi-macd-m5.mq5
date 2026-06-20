#property strict
#property version   "5.0"
#property description "QM5_11510 carter-t-wma10-sma20-stoch-rsi-macd-m5 — WMA/SMA cross + Stoch/RSI/MACD five-filter (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11510 carter-t-wma10-sma20-stoch-rsi-macd-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #5, self-published 2014.
// Card: artifacts/cards_approved/QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; cross compares shift 1 vs 2):
//   Trigger EVENT : WMA(10) crosses SMA(20). LONG = WMA crosses UP through SMA
//                   (wma[2] <= sma[2] && wma[1] > sma[1]); SHORT = mirror.
//                   Exactly ONE cross event drives entry — avoids the
//                   two-cross-same-bar zero-trade trap.
//   Confirm STATE (LONG, all at shift 1):
//       Stoch  : K > D  (fast above slow, momentum up)
//       RSI    : RSI(28) > 50  (medium-term momentum up)
//       MACD   : MACD_Main - MACD_Signal > 0  (histogram positive)
//   Confirm STATE (SHORT): K < D, RSI(28) < 50, histogram < 0.
//   Stop          : fixed 10 pips via QM_StopFixedPips.
//   Take profit   : 1:1 R/R via QM_TakeRR (rr = 1.0).
//   No-Friday      : optional entry block on Fridays (card filter).
//   Spread guard  : block only a genuinely wide spread over 10 pips
//                   (fail-open on .DWX
//                   zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11510;
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
input int    strategy_wma_period        = 10;     // fast WMA (LWMA) period
input int    strategy_sma_period        = 20;     // slow SMA period
input int    strategy_stoch_k           = 10;     // Stochastic %K period
input int    strategy_stoch_d           = 6;      // Stochastic %D period
input int    strategy_stoch_slowing     = 6;      // Stochastic slowing
input int    strategy_rsi_period        = 28;     // RSI lookback period
input double strategy_rsi_level         = 50.0;   // RSI momentum dividing line
input int    strategy_macd_fast         = 24;     // MACD fast EMA period
input int    strategy_macd_slow         = 52;     // MACD slow EMA period
input int    strategy_macd_signal       = 18;     // MACD signal SMA period
input int    strategy_sl_pips           = 10;     // fixed stop distance in pips
input double strategy_tp_rr             = 1.0;    // take-profit R/R multiple (1:1 source)
input bool   strategy_no_friday_entry   = true;   // suppress new entries on Friday
input int    strategy_spread_cap_pips   = 10;     // skip if spread exceeds this cap in pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
// The Friday-entry block lives in Strategy_EntrySignal so it does not interfere
// with exits/management.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry: WMA/SMA cross trigger + Stoch/RSI/MACD confirming states.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Optional: no new entries on Friday (card filter).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Trigger EVENT: WMA(10) vs SMA(20) cross (shift 2 -> shift 1) ---
   const double wma1 = QM_WMA(_Symbol, _Period, strategy_wma_period, 1);
   const double wma2 = QM_WMA(_Symbol, _Period, strategy_wma_period, 2);
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(wma1 <= 0.0 || wma2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   const bool crossed_up   = (wma2 <= sma2 && wma1 >  sma1);
   const bool crossed_down = (wma2 >= sma2 && wma1 <  sma1);
   if(!crossed_up && !crossed_down)
      return false; // no fresh cross this bar — the single trigger event

   // --- Confirming STATES at shift 1 ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double rsi     = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(stoch_k <= 0.0 || stoch_d <= 0.0 || rsi <= 0.0)
      return false;

   const double macd_main   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_hist   = macd_main - macd_signal;

   QM_OrderType dir;
   if(crossed_up)
     {
      // LONG confirmations: Stoch fast>slow, RSI>level, histogram>0.
      if(!(stoch_k > stoch_d))
         return false;
      if(!(rsi > strategy_rsi_level))
         return false;
      if(!(macd_hist > 0.0))
         return false;
      dir = QM_BUY;
     }
   else
     {
      // SHORT confirmations: Stoch fast<slow, RSI<level, histogram<0.
      if(!(stoch_k < stoch_d))
         return false;
      if(!(rsi < strategy_rsi_level))
         return false;
      if(!(macd_hist < 0.0))
         return false;
      dir = QM_SELL;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "carter_wma_cross_long" : "carter_wma_cross_short";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL (fixed pips) and TP (1:1 RR) handle the close.
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
