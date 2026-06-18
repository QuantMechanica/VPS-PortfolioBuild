#property strict
#property version   "5.0"
#property description "QM5_11359 robo-adx-mom — RoboForex ADX + Momentum Trend Scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11359 robo-adx-mom
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy ADX and Momentum".
// Card: artifacts/cards_approved/QM5_11359_robo-adx-mom.md (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; one open position per magic):
//   Trigger EVENT : the DI dominance FLIP is the single entry event.
//                     LONG  -> +DI crosses above -DI on the trigger bar
//                              (+DI@2 <= -DI@2  AND  +DI@1 > -DI@1).
//                     SHORT -> -DI crosses above +DI on the trigger bar.
//                   Per the build NOTE and .DWX invariant #4, only ONE cross is
//                   the EVENT; ADX strength, Momentum, PSAR and EMA are STATES
//                   that confirm it (never a second same-bar cross requirement).
//   Strength STATE: ADX(adx_period) > adx_threshold (trend strong enough).
//   DI floor STATE: dominant DI > di_threshold (LONG: +DI; SHORT: -DI).
//   Momentum STATE: Momentum(mom_period) > 100+mom_band (LONG) /
//                   < 100-mom_band (SHORT). MT5 iMomentum is ratio*100 around 100.
//   PSAR STATE    : SAR dot below price (LONG) / above price (SHORT), shift 1.
//   EMA STATE     : close > EMA(ema_period) (LONG) / close < EMA (SHORT),
//                   enabled by ema_filter_enabled (baseline ON per card).
//   Stop / Take   : fixed pip distances (sl_pips / tp_pips), scale-correct via
//                   QM_StopRulesPipsToPriceDistance (5-digit / JPY aware).
//   Early exit    : opposite DI becomes dominant OR Momentum crosses back
//                   through 100 against the open position.
//   Spread guard  : skip only a genuinely wide spread > spread_cap_pips
//                   (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11359;
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
input int    strategy_adx_period        = 14;     // ADX / DI period
input double strategy_adx_threshold     = 25.0;   // ADX strength floor (trend on)
input double strategy_di_threshold      = 25.0;   // dominant-DI floor
input int    strategy_mom_period        = 14;     // Momentum period (iMomentum ~100)
input double strategy_mom_band          = 0.0;    // band around 100 (0 = strict >/< 100)
input double strategy_sar_step          = 0.02;   // Parabolic SAR step
input double strategy_sar_max           = 0.2;    // Parabolic SAR maximum
input bool   strategy_ema_filter_enabled = true;  // EMA(55) trend filter (baseline ON)
input int    strategy_ema_period        = 55;     // EMA trend-context period
input int    strategy_sl_pips           = 7;      // stop-loss distance in pips
input int    strategy_tp_pips           = 15;     // take-profit distance in pips
input double strategy_spread_cap_pips   = 1.5;    // skip only if spread wider than this

// Convert a fixed pip count to a scale-correct price distance for this symbol.
double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = PipDistance((int)MathCeil(strategy_spread_cap_pips));
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The DI dominance FLIP is the single trigger EVENT; everything else is STATE.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- DI readings at the trigger bar (1) and the bar before it (2) ---
   const double plus_now   = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_now  = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double plus_prev  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 2);
   if(plus_now <= 0.0 || minus_now <= 0.0 || plus_prev <= 0.0 || minus_prev <= 0.0)
      return false;

   // Single EVENT: a fresh DI dominance flip on the trigger bar.
   const bool long_cross  = (plus_prev  <= minus_prev && plus_now  > minus_now);
   const bool short_cross = (minus_prev <= plus_prev  && minus_now > plus_now);
   if(!long_cross && !short_cross)
      return false;

   // --- Confirming STATE: ADX strength ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0 || adx <= strategy_adx_threshold)
      return false;

   // --- Confirming STATE: Momentum regime (iMomentum oscillates around 100) ---
   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   // --- Confirming STATE: Parabolic SAR side vs price (closed bar) ---
   const double sar   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close1 <= 0.0)
      return false;

   // --- Optional confirming STATE: EMA(55) trend context ---
   double ema = 0.0;
   if(strategy_ema_filter_enabled)
     {
      ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      if(ema <= 0.0)
         return false;
     }

   bool go_long  = false;
   bool go_short = false;

   if(long_cross)
     {
      const bool ok = (plus_now > strategy_di_threshold) &&
                      (mom > 100.0 + strategy_mom_band) &&
                      (sar < close1) &&
                      (!strategy_ema_filter_enabled || close1 > ema);
      go_long = ok;
     }
   else if(short_cross)
     {
      const bool ok = (minus_now > strategy_di_threshold) &&
                      (mom < 100.0 - strategy_mom_band) &&
                      (sar > close1) &&
                      (!strategy_ema_filter_enabled || close1 < ema);
      go_short = ok;
     }

   if(!go_long && !go_short)
      return false;

   const QM_OrderType type = go_long ? QM_BUY : QM_SELL;

   const double entry = (type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, type, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, type, entry, sl,
                               (double)strategy_tp_pips / (double)strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = type;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "robo_adx_mom_long" : "robo_adx_mom_short";
   return true;
  }

// No active trade management beyond the fixed pip stop/target; early exit
// (opposite DI / Momentum reversal) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Early defensive exit: opposite DI becomes dominant OR Momentum crosses back
// through 100 against the open position. Closed-bar STATE checks at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
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
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double mom      = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0 || mom <= 0.0)
      return false;

   if(is_long)
     {
      const bool di_against  = (minus_di > plus_di);
      const bool mom_against = (mom < 100.0);
      return (di_against || mom_against);
     }

   // is_short
   const bool di_against  = (plus_di > minus_di);
   const bool mom_against = (mom > 100.0);
   return (di_against || mom_against);
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
