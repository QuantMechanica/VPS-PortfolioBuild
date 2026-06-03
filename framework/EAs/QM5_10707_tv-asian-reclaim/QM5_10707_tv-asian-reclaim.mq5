#property strict
#property version   "5.0"
#property description "QM5_10707 TradingView Asian Reclaim ATR Stop"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10707;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_asian_start_hour  = 0;
input int    strategy_asian_start_min   = 0;
input int    strategy_asian_end_hour    = 6;
input int    strategy_asian_end_min     = 0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_tp_r              = 1.5;
input double strategy_be_trigger_frac   = 0.5;
input double strategy_min_stop_atr      = 0.5;
input double strategy_max_stop_atr      = 3.0;
input double strategy_max_spread_stop   = 0.15;

int    g_session_key = 0;
double g_asian_high = 0.0;
double g_asian_low = 0.0;
bool   g_asian_has_range = false;
bool   g_long_taken = false;
bool   g_short_taken = false;
bool   g_swept_low = false;
bool   g_swept_high = false;

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionStartMinute()
  {
   return strategy_asian_start_hour * 60 + strategy_asian_start_min;
  }

int Strategy_SessionEndMinute()
  {
   return strategy_asian_end_hour * 60 + strategy_asian_end_min;
  }

bool Strategy_TimeInputsValid()
  {
   if(strategy_asian_start_hour < 0 || strategy_asian_start_hour > 23)
      return false;
   if(strategy_asian_end_hour < 0 || strategy_asian_end_hour > 23)
      return false;
   if(strategy_asian_start_min < 0 || strategy_asian_start_min > 59)
      return false;
   if(strategy_asian_end_min < 0 || strategy_asian_end_min > 59)
      return false;
   return Strategy_SessionStartMinute() != Strategy_SessionEndMinute();
  }

bool Strategy_InAsianSession(const datetime t)
  {
   if(!Strategy_TimeInputsValid())
      return false;

   const int m = Strategy_MinutesOfDay(t);
   const int start_m = Strategy_SessionStartMinute();
   const int end_m = Strategy_SessionEndMinute();
   if(start_m < end_m)
      return (m >= start_m && m < end_m);
   return (m >= start_m || m < end_m);
  }

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);

   datetime midnight = t - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   const int start_m = Strategy_SessionStartMinute();
   const int end_m = Strategy_SessionEndMinute();
   const int m = dt.hour * 60 + dt.min;
   if(start_m > end_m && m < end_m)
      midnight -= 86400;

   TimeToStruct(midnight, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_AfterAsianSession(const datetime t)
  {
   if(!Strategy_TimeInputsValid())
      return false;
   if(Strategy_InAsianSession(t))
      return false;

   const int m = Strategy_MinutesOfDay(t);
   const int start_m = Strategy_SessionStartMinute();
   const int end_m = Strategy_SessionEndMinute();
   if(start_m < end_m)
      return (m >= end_m);
   return (m >= end_m && m < start_m);
  }

void Strategy_ResetSession(const int session_key)
  {
   g_session_key = session_key;
   g_asian_high = 0.0;
   g_asian_low = 0.0;
   g_asian_has_range = false;
   g_long_taken = false;
   g_short_taken = false;
   g_swept_low = false;
   g_swept_high = false;
  }

void Strategy_UpdateAsianRangeFromClosedBar(const datetime bar_time)
  {
   const int key = Strategy_SessionKey(bar_time);
   if(key != g_session_key)
      Strategy_ResetSession(key);

   if(!Strategy_InAsianSession(bar_time))
      return;

   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   if(h1 <= 0.0 || l1 <= 0.0)
      return;

   if(!g_asian_has_range)
     {
      g_asian_high = h1;
      g_asian_low = l1;
      g_asian_has_range = true;
      return;
     }

   g_asian_high = MathMax(g_asian_high, h1);
   g_asian_low = MathMin(g_asian_low, l1);
  }

bool Strategy_BodyInsideAsianRange(const double open_price, const double close_price)
  {
   if(!g_asian_has_range || g_asian_high <= g_asian_low)
      return false;
   const double body_high = MathMax(open_price, close_price);
   const double body_low = MathMin(open_price, close_price);
   return (body_low >= g_asian_low && body_high <= g_asian_high);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;
   if(!Strategy_TimeInputsValid())
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   Strategy_UpdateAsianRangeFromClosedBar(bar_time);
   if(!Strategy_AfterAsianSession(bar_time))
      return false;
   if(!g_asian_has_range || g_asian_high <= g_asian_low)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double o1 = iOpen(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   if(l1 < g_asian_low)
      g_swept_low = true;
   if(h1 > g_asian_high)
      g_swept_high = true;

   if(!Strategy_BodyInsideAsianRange(o1, c1))
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   const double spread = ask - bid;

   if(g_swept_low && !g_long_taken)
     {
      const double entry = ask;
      const double sl = l1 - strategy_atr_sl_mult * atr;
      const double stop_dist = entry - sl;
      if(stop_dist >= strategy_min_stop_atr * atr &&
         stop_dist <= strategy_max_stop_atr * atr &&
         spread <= strategy_max_spread_stop * stop_dist)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(entry + strategy_tp_r * stop_dist, _Digits);
         req.reason = "ASIAN_RECLAIM_LONG";
         g_long_taken = true;
         return true;
        }
     }

   if(g_swept_high && !g_short_taken)
     {
      const double entry = bid;
      const double sl = h1 + strategy_atr_sl_mult * atr;
      const double stop_dist = sl - entry;
      if(stop_dist >= strategy_min_stop_atr * atr &&
         stop_dist <= strategy_max_stop_atr * atr &&
         spread <= strategy_max_spread_stop * stop_dist)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(entry - strategy_tp_r * stop_dist, _Digits);
         req.reason = "ASIAN_RECLAIM_SHORT";
         g_short_taken = true;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_tp <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double target_dist = MathAbs(current_tp - open_price);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(target_dist <= 0.0 || moved < strategy_be_trigger_frac * target_dist)
         continue;

      const double be_sl = NormalizeDouble(open_price, _Digits);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (be_sl > current_sl) : (be_sl < current_sl));
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "asian_reclaim_be_50pct_to_target");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return Strategy_InAsianSession(TimeCurrent());
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
