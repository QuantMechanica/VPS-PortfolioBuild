#property strict
#property version   "5.0"
#property description "QM5_11287 tc20-sma3-ema50-stoch-macd-h1 — SMA3/EMA50 trend + Stoch(50,60,30) %K vs EMA(8) trigger, MACD(65,75,35) sign state (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11287 tc20-sma3-ema50-stoch-macd-h1
// -----------------------------------------------------------------------------
// Source: "20 Forex Trading Strategies (1 Hour Time Frame)" by Thomas Carter,
//         2014 — Forex Trading Strategy #1. Card g0_status APPROVED.
// Card: artifacts/cards_approved/QM5_11287_tc20-sma3-ema50-stoch-macd-h1.md
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT : Full Stochastic(50,60,30) %K crosses its OWN EMA(8).
//                   Up-cross => long candidate; down-cross => short candidate.
//                   ONE event per bar — avoids the two-cross-same-bar 0-trade trap.
//   Trend  STATE  : SMA(3) vs EMA(50).  Long needs sma3 > ema50; short sma3<ema50.
//   MACD   STATE  : MACD(65,75,35) Main vs its OWN EMA(8) (optional confirm).
//                   Long needs macd_main > macd_ema8; short the inverse.
//                   MACD value may be negative — only the relative sign matters,
//                   never a `macd>0` gate. Toggle via strategy_require_macd.
//   Stop          : fixed strategy_sl_pips (pip-scaled, 5-digit/JPY safe).
//   Take profit   : strategy_rr * stop distance (card 1:2 RR => 100/50 pips).
//   Spread guard  : block only a genuinely wide spread; fail-OPEN on .DWX
//                   zero modeled spread.
//
// The %K-EMA(8) and MACD-EMA(8) are smoothed signal lines NOT provided as a
// native buffer, so they are computed once per closed bar over a bounded shift
// window (seeded SMA + EMA recursion) and cached. No per-tick recompute.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11287;
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
input int    strategy_sma_period         = 3;      // fast trigger MA (SMA)
input int    strategy_ema_period         = 50;     // trend direction MA (EMA)
input int    strategy_stoch_k            = 50;     // Stochastic %K period
input int    strategy_stoch_d            = 60;     // Stochastic %D period
input int    strategy_stoch_slow         = 30;     // Stochastic slowing
input int    strategy_stoch_ema          = 8;      // EMA(8) of %K (smoothed signal)
input int    strategy_macd_fast          = 65;     // MACD fast EMA
input int    strategy_macd_slow          = 75;     // MACD slow EMA
input int    strategy_macd_signal        = 35;     // MACD signal EMA (native, unused here)
input int    strategy_macd_ema           = 8;      // EMA(8) of MACD main (smoothed)
input bool   strategy_require_macd       = true;   // require MACD-EMA8 sign confirm
input int    strategy_sl_pips            = 50;     // fixed stop (card: 50 pips)
input double strategy_rr                 = 2.0;    // TP = rr * stop (card 1:2)
input double strategy_spread_pct_of_stop = 25.0;   // block spread > this % of stop dist

// -----------------------------------------------------------------------------
// Cached closed-bar state (advanced once per new bar — never per tick).
// -----------------------------------------------------------------------------
double g_stoch_ema_now  = 0.0;   // EMA(8) of %K at shift 1
double g_stoch_ema_prev = 0.0;   // EMA(8) of %K at shift 2
double g_stoch_k_now    = 0.0;   // %K at shift 1
double g_stoch_k_prev   = 0.0;   // %K at shift 2
double g_macd_main_now  = 0.0;   // MACD main at shift 1
double g_macd_ema_now   = 0.0;   // EMA(8) of MACD main at shift 1
bool   g_state_ready    = false; // true once the window seeded successfully

// Compute EMA(period) of a closed-bar buffer ending at `end_shift`.
// `is_stoch` selects the source buffer (Stoch %K vs MACD main). Seeds with an
// SMA over the oldest `period` samples, then EMA-recurses forward to end_shift.
// Bounded single pass: O(period + warmup). Called only on a new closed bar.
double ComputeBufferEMA(const bool is_stoch, const int period, const int end_shift)
  {
   if(period < 1)
      return 0.0;
   const int warmup  = period;                  // extra bars to stabilise the EMA seed
   const int seedlen = period;                  // SMA seed length
   const int oldest  = end_shift + warmup + seedlen; // oldest shift sampled
   const double alpha = 2.0 / (period + 1.0);

   // Seed: SMA over the oldest `seedlen` samples [oldest .. oldest-seedlen+1].
   double sum = 0.0;
   for(int s = oldest; s > oldest - seedlen; --s)
     {
      const double v = is_stoch
                       ? QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, s)
                       : QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      sum += v;
     }
   double ema = sum / seedlen;

   // Recurse forward from (oldest-seedlen) down to end_shift.
   for(int s = oldest - seedlen; s >= end_shift; --s)
     {
      const double v = is_stoch
                       ? QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, s)
                       : QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      ema = alpha * v + (1.0 - alpha) * ema;
     }
   return ema;
  }

// Advance cached oscillator state once per closed bar (called after QM_IsNewBar).
void AdvanceState_OnNewBar()
  {
   g_state_ready = false;

   g_stoch_k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   g_stoch_k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

   g_stoch_ema_now  = ComputeBufferEMA(true, strategy_stoch_ema, 1);
   g_stoch_ema_prev = ComputeBufferEMA(true, strategy_stoch_ema, 2);

   g_macd_main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   g_macd_ema_now   = ComputeBufferEMA(false, strategy_macd_ema, 1);

   // %K oscillates in [0,100]; a non-positive read means the window is not yet
   // warm. MACD can legitimately be negative, so only guard the Stoch reads.
   if(g_stoch_k_now > 0.0 && g_stoch_k_prev > 0.0 &&
      g_stoch_ema_now > 0.0 && g_stoch_ema_prev > 0.0)
      g_state_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Cached oscillator state must be warm for this bar.
   if(!g_state_ready)
      return false;

   // --- Trend STATE: SMA(3) vs EMA(50) at the closed bar ---
   const double sma_fast = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(sma_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const bool trend_long  = (sma_fast > ema_slow);
   const bool trend_short = (sma_fast < ema_slow);
   if(!trend_long && !trend_short)
      return false;

   // --- Trigger EVENT: Stoch %K crosses its EMA(8). One event per bar. ---
   const bool stoch_cross_up   = (g_stoch_k_prev <= g_stoch_ema_prev &&
                                  g_stoch_k_now   >  g_stoch_ema_now);
   const bool stoch_cross_down = (g_stoch_k_prev >= g_stoch_ema_prev &&
                                  g_stoch_k_now   <  g_stoch_ema_now);

   // --- MACD STATE (optional confirm): main vs its EMA(8); sign-relative. ---
   const bool macd_long_ok  = (!strategy_require_macd) || (g_macd_main_now > g_macd_ema_now);
   const bool macd_short_ok = (!strategy_require_macd) || (g_macd_main_now < g_macd_ema_now);

   bool go_long  = (trend_long  && stoch_cross_up   && macd_long_ok);
   bool go_short = (trend_short && stoch_cross_down && macd_short_ok);
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   const double entry = go_long
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "tc20_sma3_ema50_stoch_long" : "tc20_sma3_ema50_stoch_short";
   return true;
  }

// Fixed stop/target only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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

   // Advance cached oscillator state ONCE per closed bar before entry eval.
   AdvanceState_OnNewBar();

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
