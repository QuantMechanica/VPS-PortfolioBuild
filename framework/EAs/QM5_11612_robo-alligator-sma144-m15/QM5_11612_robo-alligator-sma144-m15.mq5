#property strict
#property version   "5.0"
#property description "QM5_11612 robo-alligator-sma144-m15 — Alligator + SMA144 trend follow (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11612 robo-alligator-sma144-m15
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         strategy "Alligator", pages 34-35.
// Card: artifacts/cards_approved/QM5_11612_robo-alligator-sma144-m15.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1, Bill Williams Alligator on M15):
//   Alligator = three SMMAs on the bar MEDIAN price (HL2), forward-shifted:
//     Jaw  (blue) : SMMA period 13, shifted forward 8 bars
//     Teeth (red) : SMMA period  8, shifted forward 5 bars
//     Lips (green): SMMA period  5, shifted forward 3 bars
//   The forward shift is read by sampling the SMMA at (1 + forward_shift), i.e.
//   the Alligator value plotted on the just-closed bar (shift 1) is the SMMA of
//   prices `forward_shift` bars earlier.
//
//   Bias  STATE : close[1] > SMA(144) -> bullish zone (longs only);
//                 close[1] < SMA(144) -> bearish zone (shorts only).
//   Trend STATE : the Alligator "mouth" is open and ordered in the bias
//                 direction. Long  -> lips > teeth > jaw (with min spread).
//                 Short -> lips < teeth < jaw (with min spread).
//   Trigger EVENT (ONE cross — avoids the two-cross same-bar zero-trade trap):
//                 the lips (green) crossing the teeth (red) in the bias
//                 direction on the just-closed bar. The teeth/jaw ordering is a
//                 STATE checked above, NOT a second required cross EVENT.
//   Stop        : 1 pip below SMA(144) for longs / 1 pip above for shorts
//                 (source-specified), clamped to a sane minimum stop distance.
//   Take profit : entry +/- tp_atr_mult * ATR(14) (ceiling TP per card factory note).
//   Exit        : lips crossing back through teeth in the reverse direction.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11612;
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
// --- Alligator (Bill Williams: period + forward shift per line) ---
input int    strategy_jaw_period        = 13;    // blue line SMMA period
input int    strategy_jaw_shift         = 8;     // blue line forward shift (bars)
input int    strategy_teeth_period      = 8;     // red line SMMA period
input int    strategy_teeth_shift       = 5;     // red line forward shift (bars)
input int    strategy_lips_period       = 5;     // green line SMMA period
input int    strategy_lips_shift        = 3;     // green line forward shift (bars)
// --- Trend filter / stop reference ---
input int    strategy_sma_period        = 144;   // long-term trend SMA
input double strategy_sma_stop_pips     = 1.0;   // SL offset from SMA144 (source: 1 pip)
input double strategy_min_spread_pips   = 0.5;   // min lips/teeth/jaw gap = "mouth open"
input double strategy_min_stop_pips     = 5.0;   // floor for the SMA-derived stop distance
// --- Take profit (ceiling) ---
input int    strategy_atr_period        = 14;    // ATR period for TP ceiling
input double strategy_tp_atr_mult       = 4.0;   // TP = entry +/- mult * ATR(14)

// -----------------------------------------------------------------------------
// Helpers (Alligator line reads — forward shift = sample SMMA at 1 + shift)
// -----------------------------------------------------------------------------

double Alligator_Jaw(const int extra_shift)
  {
   return QM_SMMA(_Symbol, _Period, strategy_jaw_period,
                  1 + strategy_jaw_shift + extra_shift, PRICE_MEDIAN);
  }
double Alligator_Teeth(const int extra_shift)
  {
   return QM_SMMA(_Symbol, _Period, strategy_teeth_period,
                  1 + strategy_teeth_shift + extra_shift, PRICE_MEDIAN);
  }
double Alligator_Lips(const int extra_shift)
  {
   return QM_SMMA(_Symbol, _Period, strategy_lips_period,
                  1 + strategy_lips_shift + extra_shift, PRICE_MEDIAN);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate — no spread/swap gating on .DWX (zero modeled
// spread/swap would fail-closed). All signal work is on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // no valid quote yet — block this tick only
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar price + SMA144 bias STATE ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;

   // --- Alligator lines: current (shift 1 plot) and previous (shift 2 plot) ---
   const double lips_now  = Alligator_Lips(0);
   const double teeth_now = Alligator_Teeth(0);
   const double jaw_now   = Alligator_Jaw(0);
   const double lips_prev  = Alligator_Lips(1);
   const double teeth_prev = Alligator_Teeth(1);
   if(lips_now <= 0.0 || teeth_now <= 0.0 || jaw_now <= 0.0 ||
      lips_prev <= 0.0 || teeth_prev <= 0.0)
      return false;

   const double min_gap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_spread_pips));
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   // ---------------------------- LONG ----------------------------------------
   // Bias: price above SMA144. Trend STATE: mouth open & ordered up
   // (lips > teeth > jaw with spread). Trigger EVENT: lips cross UP through
   // teeth on the just-closed bar (ONE cross only).
   if(close1 > sma)
     {
      const bool mouth_up    = (lips_now > teeth_now + min_gap &&
                                teeth_now > jaw_now + min_gap);
      const bool lips_cross_up = (lips_prev <= teeth_prev && lips_now > teeth_now);
      if(mouth_up && lips_cross_up)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         double sl = sma - QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sma_stop_pips));
         // Clamp to a minimum stop distance below entry so the trade is valid.
         const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_stop_pips));
         if(entry - sl < min_dist)
            sl = entry - min_dist;
         double tp = 0.0;
         if(atr_value > 0.0)
            tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
         req.type   = QM_BUY;
         req.price  = 0.0; // framework fills market price at send
         req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp     = (tp > 0.0 ? tp : 0.0);
         req.reason = "alligator_sma144_long";
         return true;
        }
      return false;
     }

   // ---------------------------- SHORT ---------------------------------------
   if(close1 < sma)
     {
      const bool mouth_down    = (lips_now < teeth_now - min_gap &&
                                  teeth_now < jaw_now - min_gap);
      const bool lips_cross_dn = (lips_prev >= teeth_prev && lips_now < teeth_now);
      if(mouth_down && lips_cross_dn)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         double sl = sma + QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sma_stop_pips));
         const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_stop_pips));
         if(sl - entry < min_dist)
            sl = entry + min_dist;
         double tp = 0.0;
         if(atr_value > 0.0)
            tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp     = (tp > 0.0 ? tp : 0.0);
         req.reason = "alligator_sma144_short";
         return true;
        }
      return false;
     }

   return false;
  }

// No active management beyond the SMA-derived stop + ATR ceiling TP. The
// reverse-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: lips cross back through teeth in the reverse direction (one event/bar),
// matched to the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double lips_now   = Alligator_Lips(0);
   const double teeth_now  = Alligator_Teeth(0);
   const double lips_prev  = Alligator_Lips(1);
   const double teeth_prev = Alligator_Teeth(1);
   if(lips_now <= 0.0 || teeth_now <= 0.0 || lips_prev <= 0.0 || teeth_prev <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
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
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }

   if(is_long)
      return (lips_prev >= teeth_prev && lips_now < teeth_now);   // lips cross down through teeth
   if(is_short)
      return (lips_prev <= teeth_prev && lips_now > teeth_now);   // lips cross up through teeth
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
