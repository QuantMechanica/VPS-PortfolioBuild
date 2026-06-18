#property strict
#property version   "5.0"
#property description "QM5_11642 robo-smma818-psar026-stoch1225-h1 — SMMA stack + PSAR flip + Stoch/MACD confirm (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11642 robo-smma818-psar026-stoch1225-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//   pages 68-69, strategy "SMMA + PSAR + Stoch + MACD".
// Card: artifacts/cards_approved/QM5_11642_robo-smma818-psar026-stoch1225-h1.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT  : Parabolic SAR FLIP. For a long, SAR was ABOVE price on the
//                    prior closed bar (shift 2) and is now BELOW price on the
//                    last closed bar (shift 1). One discrete flip event per bar
//                    — this is the single trigger, avoiding the two-cross trap.
//   SMMA STATE     : SMMA(8,Median) > SMMA(18,Median) for long (stack bullish);
//                    < for short. SMMA applied to median price (H+L)/2.
//   Stoch STATE    : Stochastic(12,12,5) %K position. Long requires %K > %D and
//                    %K not overbought (< stoch_ob); short requires %K < %D and
//                    %K not oversold (> stoch_os). Slow stochastic confirmation.
//   MACD STATE     : MACD(8,21,1) main line sign. Long requires main >= 0,
//                    short requires main <= 0.
//   Stop           : 2*ATR(14) (factory default; card SL = PSAR value at entry).
//   Take profit    : 4*ATR(14) (factory default).
//   Defensive exit : SAR flips back against the open position -> close manually.
//   Spread guard   : block only a genuinely wide spread > spread_pct_of_stop of
//                    the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11642;
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
input int    strategy_smma_fast_period   = 8;      // SMMA(8, median)
input int    strategy_smma_slow_period   = 18;     // SMMA(18, median)
input double strategy_sar_step           = 0.026;  // PSAR step (non-standard)
input double strategy_sar_max            = 0.5;    // PSAR maximum (non-standard)
input int    strategy_stoch_k_period     = 12;     // Stochastic %K period
input int    strategy_stoch_d_period     = 12;     // Stochastic %D period
input int    strategy_stoch_slowing      = 5;      // Stochastic slowing
input double strategy_stoch_ob           = 80.0;   // overbought ceiling for longs
input double strategy_stoch_os           = 20.0;   // oversold floor for shorts
input int    strategy_macd_fast          = 8;      // MACD fast EMA
input int    strategy_macd_slow          = 21;     // MACD slow EMA
input int    strategy_macd_signal        = 1;      // MACD signal period
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is in
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Trigger EVENT = PSAR flip; SMMA stack + Stoch + MACD are confirming STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Reference closed-bar prices for the SAR-vs-price comparison.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- PSAR values: prior closed bar (shift 2) and last closed bar (shift 1) ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   // SAR flip EVENTs (one discrete event per bar).
   const bool sar_flip_bull = (sar2 > close2 && sar1 < close1); // was above, now below
   const bool sar_flip_bear = (sar2 < close2 && sar1 > close1); // was below, now above

   // --- SMMA STATE: 8/18 stack on median price (closed bar) ---
   const double smma_fast = QM_SMMA(_Symbol, _Period, strategy_smma_fast_period, 1, PRICE_MEDIAN);
   const double smma_slow = QM_SMMA(_Symbol, _Period, strategy_smma_slow_period, 1, PRICE_MEDIAN);
   if(smma_fast <= 0.0 || smma_slow <= 0.0)
      return false;
   const bool smma_bull = (smma_fast > smma_slow);
   const bool smma_bear = (smma_fast < smma_slow);

   // --- Stochastic STATE: slow stoch (12,12,5) on the last closed bar ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(stoch_k <= 0.0 || stoch_d <= 0.0)
      return false;
   // Long: %K above %D and not already overbought. Short: %K below %D and not oversold.
   const bool stoch_bull = (stoch_k > stoch_d && stoch_k < strategy_stoch_ob);
   const bool stoch_bear = (stoch_k < stoch_d && stoch_k > strategy_stoch_os);

   // --- MACD STATE: main line sign on the last closed bar ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const bool macd_bull = (macd_main >= 0.0);
   const bool macd_bear = (macd_main <= 0.0);

   // --- Compose: SAR flip EVENT confirmed by SMMA + Stoch + MACD STATES ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(sar_flip_bull && smma_bull && stoch_bull && macd_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "robo_smma_psar_long";
      return true;
     }

   if(sar_flip_bear && smma_bear && stoch_bear && macd_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "robo_smma_psar_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target. The defensive
// PSAR-flip exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: PSAR flips against the open position. One flip event/bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   const bool sar_flip_bull = (sar2 > close2 && sar1 < close1); // flipped bullish
   const bool sar_flip_bear = (sar2 < close2 && sar1 > close1); // flipped bearish

   // Determine the direction of the open position for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Close a long when SAR flips bearish; close a short when SAR flips bullish.
   if(have_long && sar_flip_bear)
      return true;
   if(have_short && sar_flip_bull)
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
