#property strict
#property version   "5.0"
#property description "QM5_11320 tc-m5-13-cci100-macd — CCI(14) +/-100 cross + MACD momentum (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11320 tc-m5-13-cci100-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #13 (CCI +/-100 breakout + MACD momentum).
// Card: artifacts/cards_approved/QM5_11320_tc-m5-13-cci100-macd.md (APPROVED).
//
// Mechanics (closed-bar reads, M5):
//   Trigger EVENT (the ONLY cross): CCI(14) crosses the +/- level.
//     LONG : cci[2] <= +level  AND  cci[1] >  +level
//     SHORT: cci[2] >= -level  AND  cci[1] <  -level
//   MACD STATE (confirmation, NOT a second cross — avoids the two-cross
//   same-bar zero-trade trap; MACD main may be negative, that's fine):
//     LONG : macd_main[1] > macd_signal[1]  (bullish alignment)
//            AND histogram rising: (main-signal)[1] > (main-signal)[2]
//     SHORT: macd_main[1] < macd_signal[1]  (bearish alignment)
//            AND histogram falling: (main-signal)[1] < (main-signal)[2]
//   Stop  : fixed pips (default 14), scale-correct via QM_StopFixedPips.
//   Target: fixed pips (default 8 baseline), via QM_TakeFixedPips.
//   Spread guard: fail-OPEN on .DWX zero modeled spread; block only a
//                 genuinely wide spread > spread_cap_points.
//   One open position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else below the marker is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11320;
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
input int    strategy_cci_period        = 14;     // CCI lookback period
input double strategy_cci_level         = 100.0;  // +/- level the CCI must cross (the trigger EVENT)
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_sl_pips           = 14;     // stop-loss distance in pips
input int    strategy_tp_pips           = 8;      // take-profit distance in pips (baseline)
input int    strategy_spread_cap_points = 15;     // block only if modeled spread exceeds this many points

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_spread_cap_points <= 0)
      return false;

   const double spread = ask - bid;
   const double cap    = strategy_spread_cap_points * point;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > 0.0 && bid > 0.0 && ask > bid && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- CCI values: shift 1 = last closed bar, shift 2 = prior closed bar ---
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   // --- MACD STATE: main vs signal alignment + histogram slope ---
   // MACD main can be negative — never gate on its sign.
   const double macd_main_1   = QM_MACD_Main  (_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1    = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2   = QM_MACD_Main  (_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_2    = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double hist_1        = macd_main_1 - macd_sig_1;
   const double hist_2        = macd_main_2 - macd_sig_2;

   const double pos_level = strategy_cci_level;
   const double neg_level = -strategy_cci_level;

   // --- LONG: CCI crosses up through +level (EVENT) + bullish MACD STATE ---
   const bool cci_cross_up = (cci_prev <= pos_level && cci_now > pos_level);
   if(cci_cross_up)
     {
      const bool macd_bull = (macd_main_1 > macd_sig_1) && (hist_1 > hist_2);
      if(macd_bull)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
         const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "cci_cross_up_macd_bull";
         return true;
        }
     }

   // --- SHORT: CCI crosses down through -level (EVENT) + bearish MACD STATE ---
   const bool cci_cross_down = (cci_prev >= neg_level && cci_now < neg_level);
   if(cci_cross_down)
     {
      const bool macd_bear = (macd_main_1 < macd_sig_1) && (hist_1 < hist_2);
      if(macd_bear)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
         const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "cci_cross_down_macd_bear";
         return true;
        }
     }

   return false;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
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
