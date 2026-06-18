#property strict
#property version   "5.0"
#property description "QM5_11520 carter-t-ema18-adx12-pullback — EMA18 trend + ADX12 + pullback resume (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11520 carter-t-ema18-adx12-pullback
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #17 (self-published 2014).
// Card: artifacts/cards_approved/QM5_11520_carter-t-ema18-adx12-pullback.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; both directions):
//   Trend STATE  : single EMA(ema_period) defines the side. LONG = close above
//                  the EMA; SHORT = close below the EMA.
//   Strength STATE: ADX(adx_period) > adx_threshold (trending, not ranging).
//   Pullback STATE: within the last pb_lookback closed bars PRECEDING the
//                   trigger bar, price pulled back to the EMA — for longs a bar
//                   LOW touched/pierced the EMA (low <= EMA); for shorts a bar
//                   HIGH touched/pierced the EMA (high >= EMA).
//   Trigger EVENT : the trigger bar (shift 1) RESUMES in the trend direction —
//                   for longs its low touched the EMA but it closed back above
//                   the EMA AND made a higher high than its own prior bar; for
//                   shorts the mirror. This single resume candle is the event;
//                   the trend side, ADX strength, and earlier pullback are all
//                   states. No two same-bar cross events are required, so the
//                   .DWX two-cross zero-trade trap is avoided.
//   Stop         : fixed-pip stop (sl_pips), scaled correctly via pip distance.
//   Take profit  : RR multiple of the stop distance (tp_rr).
//   Friday entry : suppressed when no_friday_entry is true (card filter).
//   Spread guard : block only a genuinely wide spread (> cap pips); fail-open on
//                  .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11520;
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
input int    strategy_ema_period         = 18;     // single trend EMA period
input int    strategy_adx_period         = 12;     // ADX period (short, responsive)
input double strategy_adx_threshold      = 25.0;   // ADX must exceed this = trending
input int    strategy_pullback_lookback  = 5;      // closed bars before trigger to scan for the pullback touch
input int    strategy_sl_pips            = 25;     // fixed stop distance in pips
input double strategy_tp_rr              = 2.0;    // take-profit = tp_rr * stop distance
input double strategy_spread_cap_pips    = 15.0;   // block only if spread > this many pips
input bool   strategy_no_friday_entry    = true;   // card filter: no Friday entries

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX zero modeled spread — never block on it

   // Convert the pip cap to a price distance for this symbol (5-digit / JPY safe).
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance > 0.0 && spread > cap_distance)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card filter: no Friday entries (use broker-bar open time of the trigger bar).
   if(strategy_no_friday_entry)
     {
      const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar open time
      MqlDateTime dt;
      TimeToStruct(bar_time, dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Strength STATE: ADX above threshold (trending market) ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_threshold))
      return false;

   // --- Trend STATE on the trigger bar: EMA at shift 1 ---
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema1 <= 0.0)
      return false;

   // Trigger bar OHLC (single closed-bar reads — perf-allowed).
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high2  = iHigh(_Symbol, _Period, 2);
   const double low2   = iLow(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   // ============================ LONG ====================================
   // Trend side: closed back above EMA. Pullback EVENT on the trigger bar:
   // its low touched/pierced the EMA (low1 <= ema1) but it closed above
   // (close1 > ema1) and resumed up (higher high than the prior bar).
   const bool long_trend   = (close1 > ema1);
   const bool long_resume  = (low1 <= ema1) && (close1 > ema1) && (high1 > high2);
   if(long_trend && long_resume)
     {
      // Pullback STATE: confirm price actually approached the EMA within the
      // lookback window that PRECEDES the trigger bar (shifts 2..lookback+1).
      // This is a state observed earlier — never the same bar as the trigger.
      if(PullbackTouchedLong(ema1))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
         const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "ema18_adx12_pullback_long";
         return true;
        }
     }

   // ============================ SHORT ===================================
   // Mirror: closed back below EMA; trigger bar high touched/pierced the EMA
   // but closed below it and resumed down (lower low than the prior bar).
   const bool short_trend  = (close1 < ema1);
   const bool short_resume = (high1 >= ema1) && (close1 < ema1) && (low1 < low2);
   if(short_trend && short_resume)
     {
      if(PullbackTouchedShort(ema1))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
         const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "ema18_adx12_pullback_short";
         return true;
        }
     }

   return false;
  }

// Pullback STATE (long): within shifts 2..lookback+1, a bar low reached the EMA
// (low <= EMA at that bar) — i.e. price retraced into the trend EMA before the
// resume. EMA recomputed per shift so the comparison is against that bar's EMA.
bool PullbackTouchedLong(const double ema_ref)
  {
   const int first_shift = 2;
   const int last_shift  = strategy_pullback_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(ema_s <= 0.0)
         continue;
      const double low_s = iLow(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(low_s <= 0.0)
         continue;
      if(low_s <= ema_s)
         return true;
     }
   return false;
  }

// Pullback STATE (short): within shifts 2..lookback+1, a bar high reached the EMA.
bool PullbackTouchedShort(const double ema_ref)
  {
   const int first_shift = 2;
   const int last_shift  = strategy_pullback_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(ema_s <= 0.0)
         continue;
      const double high_s = iHigh(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(high_s <= 0.0)
         continue;
      if(high_s >= ema_s)
         return true;
     }
   return false;
  }

// Fixed pip stop + RR target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP handle the trade lifecycle.
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
