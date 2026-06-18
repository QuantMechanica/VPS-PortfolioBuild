#property strict
#property version   "5.0"
#property description "QM5_11511 carter-t-sma32-band-psar-sma100-200 — SMA(32) High/Low band breakout + PSAR + SMA100/200 trend (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11511 carter-t-sma32-band-psar-sma100-200
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #6, self-published 2014 (R1 CONDITIONAL).
// Card: artifacts/cards_approved/QM5_11511_carter-t-sma32-band-psar-sma100-200.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; TF = M30):
//   Band       : SMA(32) on HIGH = upper channel, SMA(32) on LOW = lower channel.
//   Trend STATE: SMA100/SMA200 macro structure + price relative to both, and a
//                bullish/bearish closed bar. These describe the regime — they are
//                STATES, currently-true conditions, not events.
//   Trigger EVENT (the single fresh event per bar, avoids the two-cross trap):
//     LONG  : close crosses ABOVE the SMA(32,High) upper channel
//             (close[2] <= upper[2]  AND  close[1] > upper[1]).
//     SHORT : close crosses BELOW the SMA(32,Low) lower channel.
//   PSAR       : STATE confirmation of momentum direction
//                LONG  -> SAR below the prior low ; SHORT -> SAR above prior high.
//   Stop       : PSAR dot at the trigger bar, capped at sl_cap_pips (card: 20p).
//   Take profit: fixed tp_pips (card M30 default: 13 pips).
//   No-Friday  : the card forbids Friday entries -> handled in the entry gate.
//   Spread     : skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11511;
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
input int    strategy_sma_band_period   = 32;     // SMA channel period (High/Low band)
input int    strategy_sma_trend_fast    = 100;    // macro trend filter fast SMA
input int    strategy_sma_trend_slow    = 200;    // macro trend filter slow SMA
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_max           = 0.2;    // Parabolic SAR acceleration cap
input double strategy_tp_pips           = 13.0;   // fixed take-profit (M30 default per card)
input double strategy_sl_cap_pips       = 20.0;   // P2 cap on the PSAR-derived stop distance
input bool   strategy_no_friday_entry   = true;   // card: no Friday entries
input double strategy_spread_cap_pips   = 12.0;   // card spread cap (only blocks genuinely wide spread)

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

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double spread = ask - bid;
   if(spread > 0.0)
     {
      const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
      if(cap_distance > 0.0 && spread > cap_distance)
         return true;
     }
   return false;
  }

// Long/short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card: no Friday entries. Bar-open time of the forming bar (shift 0).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(iTime(_Symbol, _Period, 0), dt); // perf-allowed: single bar-open read
      if(dt.day_of_week == 5)
         return false;
     }

   // --- SMA(32) High/Low band, at the trigger bar (shift 1) and prior (shift 2) ---
   const double upper1 = QM_SMA(_Symbol, _Period, strategy_sma_band_period, 1, PRICE_HIGH);
   const double upper2 = QM_SMA(_Symbol, _Period, strategy_sma_band_period, 2, PRICE_HIGH);
   const double lower1 = QM_SMA(_Symbol, _Period, strategy_sma_band_period, 1, PRICE_LOW);
   const double lower2 = QM_SMA(_Symbol, _Period, strategy_sma_band_period, 2, PRICE_LOW);
   if(upper1 <= 0.0 || upper2 <= 0.0 || lower1 <= 0.0 || lower2 <= 0.0)
      return false;

   // --- Macro trend SMA(100)/SMA(200) (closed bar) ---
   const double sma_fast = QM_SMA(_Symbol, _Period, strategy_sma_trend_fast, 1, PRICE_CLOSE);
   const double sma_slow = QM_SMA(_Symbol, _Period, strategy_sma_trend_slow, 1, PRICE_CLOSE);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;

   // --- Parabolic SAR at the trigger bar (shift 1) ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;

   // --- Closed-bar OHLC at the trigger bar / prior bar (perf-allowed single reads) ---
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double open1  = iOpen (_Symbol, _Period, 1);
   const double high1  = iHigh (_Symbol, _Period, 1);
   const double low1   = iLow  (_Symbol, _Period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // ===== LONG =====================================================
   // Trigger EVENT: close crosses ABOVE the SMA(32,High) upper channel.
   // STATES: bullish bar, price above SMA100 & SMA200, PSAR below price.
   const bool long_cross   = (close2 <= upper2 && close1 > upper1);
   const bool long_bull    = (close1 > open1);
   const bool long_trend   = (close1 > sma_fast && close1 > sma_slow);
   const bool long_psar    = (sar1 < low1);
   if(long_cross && long_bull && long_trend && long_psar)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop = PSAR dot, capped at sl_cap_pips below entry.
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      double sl = sar1;
      if(sl >= entry)                          // SAR not below price — fall back to cap
         sl = entry - cap_dist;
      else if(cap_dist > 0.0 && (entry - sl) > cap_dist)
         sl = entry - cap_dist;                // clamp an over-wide PSAR stop to the cap
      const double tp = entry + QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "carter_sma32band_psar_long";
      return true;
     }

   // ===== SHORT ====================================================
   // Trigger EVENT: close crosses BELOW the SMA(32,Low) lower channel.
   // STATES: bearish bar, price below SMA100 & SMA200, PSAR above price.
   const bool short_cross  = (close2 >= lower2 && close1 < lower1);
   const bool short_bear   = (close1 < open1);
   const bool short_trend  = (close1 < sma_fast && close1 < sma_slow);
   const bool short_psar   = (sar1 > high1);
   if(short_cross && short_bear && short_trend && short_psar)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      double sl = sar1;
      if(sl <= entry)                          // SAR not above price — fall back to cap
         sl = entry + cap_dist;
      else if(cap_dist > 0.0 && (sl - entry) > cap_dist)
         sl = entry + cap_dist;                // clamp an over-wide PSAR stop to the cap
      const double tp = entry - QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "carter_sma32band_psar_short";
      return true;
     }

   return false;
  }

// Fixed PSAR-stop / fixed-TP strategy — no active management.
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
