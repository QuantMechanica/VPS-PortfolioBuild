#property strict
#property version   "5.0"
#property description "QM5_11074 adj-ma-3g — 3rd Generation MA crossover (single-position, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11074 adj-ma-3g
// -----------------------------------------------------------------------------
// Source: EarnForex "Adjustable MA 3G" (https://github.com/EarnForex/Adjustable-MA-3G).
// Card: artifacts/cards_approved/QM5_11074_adj-ma-3g.md (g0_status APPROVED).
//
// "3G" = "3rd Generation Moving Average" (Dürschner), NOT a 3-position grid.
// This is a SINGLE-POSITION trend EA. One open position per symbol/magic.
//
// 3rd Generation MA (Dürschner 2008) reduces lag by sampling a longer EMA:
//   lambda = period / (sampling - period)
//   MA3G   = (1 + lambda) * EMA(period) - lambda * EMA(sampling)
// Both EMAs use TYPICAL price (HLC/3). Requires sampling > period.
//
// Mechanics (closed-bar reads at shift 1; D1):
//   Fast 3G MA : period = min(p1,p2)=30, sampling = sampling_fast=196.
//   Slow 3G MA : period = max(p1,p2)=35, sampling = sampling_slow=160.
//   Definitive bullish STATE : fast - slow >=  min_diff (price distance).
//   Definitive bearish STATE : slow - fast >=  min_diff (price distance).
//   Long ENTRY  : previous definitive state was bearish AND current bar is
//                 definitively bullish (a fresh flip).
//   Short ENTRY : mirror.
//   Exit        : opposite definitive cross closes the open position
//                 (Strategy_ExitSignal), independent of the fixed SL/TP.
//   Stop / Take : fixed pip distances (source point intent normalised to pips).
//   Spread guard: skip only a genuinely wide spread (.DWX fail-open on 0 spread).
//
// min_diff is expressed in PIPS (scale-correct via QM_StopRulesPipsToPriceDistance)
// rather than raw points so it does not mis-scale on 5-digit / JPY / metal symbols.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11074;
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
input int    strategy_ma_period_fast    = 30;    // fast 3G MA averaging period (lower of source P1/P2)
input int    strategy_ma_period_slow    = 35;    // slow 3G MA averaging period (higher of source P1/P2)
input int    strategy_sampling_fast     = 196;   // fast 3G MA sampling period (source Period_Sampling_Fast)
input int    strategy_sampling_slow     = 160;   // slow 3G MA sampling period (source Period_Sampling_Slow)
input int    strategy_min_diff_pips     = 1;     // min fast/slow separation for a definitive state (pips)
input int    strategy_sl_pips           = 170;   // stop distance in pips (source 1700 points / 10)
input int    strategy_tp_pips           = 60;    // target distance in pips (source 600 points / 10)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance
input bool   strategy_allow_long        = true;  // TradeDirection: permit long entries
input bool   strategy_allow_short       = true;  // TradeDirection: permit short entries

// -----------------------------------------------------------------------------
// 3rd Generation MA helper — Dürschner formula over TYPICAL price.
// Returns the 3G MA value at `shift`, or 0.0 if inputs are degenerate.
// Pure read of two pooled EMA handles (QM_EMA) — no raw iMA, no CopyBuffer.
// -----------------------------------------------------------------------------
double Strategy_MA3G(const int period, const int sampling, const int shift)
  {
   if(period <= 0 || sampling <= period)
      return 0.0;

   const double ema_p = QM_EMA(_Symbol, _Period, period,   shift, PRICE_TYPICAL);
   const double ema_s = QM_EMA(_Symbol, _Period, sampling, shift, PRICE_TYPICAL);
   if(ema_p <= 0.0 || ema_s <= 0.0)
      return 0.0;

   const double lambda = (double)period / (double)(sampling - period);
   return (1.0 + lambda) * ema_p - lambda * ema_s;
  }

// Definitive state at `shift`: +1 bullish, -1 bearish, 0 neither (inside min_diff).
int Strategy_DefinitiveState(const int shift, const double min_diff_distance)
  {
   const double fast = Strategy_MA3G(strategy_ma_period_fast, strategy_sampling_fast, shift);
   const double slow = Strategy_MA3G(strategy_ma_period_slow, strategy_sampling_slow, shift);
   if(fast <= 0.0 || slow <= 0.0)
      return 0;

   if(fast - slow >= min_diff_distance)
      return +1;
   if(slow - fast >= min_diff_distance)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is closed-bar.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on a fresh definitive 3G-MA cross. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double min_diff = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_diff_pips);
   if(min_diff <= 0.0)
      return false;

   // Current definitive state (closed bar, shift 1) and the prior definitive
   // state seen at shift 2. A flip from one definitive sign to the opposite is
   // the trigger — the prior state is a STATE, the flip is the single EVENT.
   const int state_now  = Strategy_DefinitiveState(1, min_diff);
   const int state_prev = Strategy_DefinitiveState(2, min_diff);
   if(state_now == 0 || state_prev == 0)
      return false;

   const double entry = (state_now > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Long: previous definitive bearish, now definitive bullish.
   if(state_prev < 0 && state_now > 0 && strategy_allow_long)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_StopRulesNormalizePrice(_Symbol,
                          entry + QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ma3g_cross_long";
      return true;
     }

   // Short: previous definitive bullish, now definitive bearish.
   if(state_prev > 0 && state_now < 0 && strategy_allow_short)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_StopRulesNormalizePrice(_Symbol,
                          entry - QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ma3g_cross_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed SL/TP. The reversal exit lives in
// Strategy_ExitSignal (close on the opposite definitive cross).
void Strategy_ManageOpenPosition()
  {
  }

// Reversal exit: close the open position when the definitive state flips against
// it. One event at shift 1 (flip vs the shift-2 state).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double min_diff = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_diff_pips);
   if(min_diff <= 0.0)
      return false;

   const int state_now  = Strategy_DefinitiveState(1, min_diff);
   const int state_prev = Strategy_DefinitiveState(2, min_diff);
   if(state_now == 0 || state_prev == 0)
      return false;

   // A fresh definitive flip in either direction; the framework close loop only
   // closes positions on this magic, so a flip against the held side exits it.
   const bool flipped = (state_prev > 0 && state_now < 0) ||
                        (state_prev < 0 && state_now > 0);
   return flipped;
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
