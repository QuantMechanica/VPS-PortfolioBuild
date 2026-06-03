#property strict
#property version   "5.0"
#property description "QM5_10668 TradingView VWAP ORB Pullback"

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
input int    qm_ea_id                   = 10668;
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
input int    strategy_opening_range_minutes = 15;
input int    strategy_ema_period            = 9;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 1.0;
input double strategy_rr_target             = 1.5;
input double strategy_max_or_atr_mult       = 1.5;
input int    strategy_max_vwap_crosses      = 3;
input int    strategy_pullback_tolerance_pts = 5;
input int    strategy_session_open_hour     = -1;
input int    strategy_session_open_minute   = -1;
input int    strategy_session_end_hour      = -1;
input int    strategy_session_end_minute    = -1;

int     g_session_key = -1;
double  g_or_high = 0.0;
double  g_or_low = 0.0;
double  g_vwap_pv = 0.0;
double  g_vwap_vol = 0.0;
double  g_session_vwap = 0.0;
bool    g_opening_complete = false;
bool    g_or_width_blocked = false;
int     g_breakout_dir = 0;
int     g_vwap_crosses = 0;
bool    g_trade_taken_session = false;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool Strategy_SymbolContains(const string token)
  {
   return (StringFind(_Symbol, token) >= 0);
  }

int Strategy_DefaultOpenMinutes()
  {
   if(Strategy_SymbolContains("GDAXI") || Strategy_SymbolContains("GER40") ||
      Strategy_SymbolContains("DE30") || Strategy_SymbolContains("UK100"))
      return 9 * 60;
   return 15 * 60 + 30;
  }

int Strategy_DefaultEndMinutes()
  {
   if(Strategy_SymbolContains("GDAXI") || Strategy_SymbolContains("GER40") ||
      Strategy_SymbolContains("DE30") || Strategy_SymbolContains("UK100"))
      return 17 * 60 + 30;
   return 22 * 60;
  }

int Strategy_OpenMinutes()
  {
   if(strategy_session_open_hour >= 0 && strategy_session_open_minute >= 0)
      return strategy_session_open_hour * 60 + strategy_session_open_minute;
   return Strategy_DefaultOpenMinutes();
  }

int Strategy_EndMinutes()
  {
   if(strategy_session_end_hour >= 0 && strategy_session_end_minute >= 0)
      return strategy_session_end_hour * 60 + strategy_session_end_minute;
   return Strategy_DefaultEndMinutes();
  }

bool Strategy_InSessionMinutes(const int minute_of_day)
  {
   const int open_min = Strategy_OpenMinutes();
   const int end_min = Strategy_EndMinutes();
   if(end_min > open_min)
      return (minute_of_day >= open_min && minute_of_day < end_min);
   return (minute_of_day >= open_min || minute_of_day < end_min);
  }

bool Strategy_AfterSessionEnd(const int minute_of_day)
  {
   const int open_min = Strategy_OpenMinutes();
   const int end_min = Strategy_EndMinutes();
   if(end_min > open_min)
      return (minute_of_day >= end_min || minute_of_day < open_min);
   return (minute_of_day >= end_min && minute_of_day < open_min);
  }

void Strategy_ResetSession(const int key)
  {
   g_session_key = key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_vwap_pv = 0.0;
   g_vwap_vol = 0.0;
   g_session_vwap = 0.0;
   g_opening_complete = false;
   g_or_width_blocked = false;
   g_breakout_dir = 0;
   g_vwap_crosses = 0;
   g_trade_taken_session = false;
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

void Strategy_UpdateSessionState()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return;

   const int key = Strategy_SessionKey(bar_time);
   if(key != g_session_key)
      Strategy_ResetSession(key);

   const int bar_min = Strategy_MinutesOfDay(bar_time);
   if(!Strategy_InSessionMinutes(bar_min))
      return;

   const int open_min = Strategy_OpenMinutes();
   const int since_open = (bar_min >= open_min) ? (bar_min - open_min) : (bar_min + 1440 - open_min);
   if(since_open < 0)
      return;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double volume1_raw = (double)iVolume(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return;

   const double prev_vwap = g_session_vwap;
   const double typical = (high1 + low1 + close1) / 3.0;
   const double volume1 = (volume1_raw > 0.0) ? volume1_raw : 1.0;
   g_vwap_pv += typical * volume1;
   g_vwap_vol += volume1;
   if(g_vwap_vol > 0.0)
      g_session_vwap = g_vwap_pv / g_vwap_vol;

   if(since_open < strategy_opening_range_minutes)
     {
      if(g_or_high <= 0.0 || high1 > g_or_high)
         g_or_high = high1;
      if(g_or_low <= 0.0 || low1 < g_or_low)
         g_or_low = low1;
      return;
     }

   if(!g_opening_complete)
     {
      g_opening_complete = true;
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr > 0.0 && g_or_high > g_or_low)
         g_or_width_blocked = ((g_or_high - g_or_low) > atr * strategy_max_or_atr_mult);
     }

   if(prev_vwap > 0.0 && g_session_vwap > 0.0)
     {
      const double prev_close = iClose(_Symbol, _Period, 2);
      if(prev_close > 0.0)
        {
         const bool was_above = (prev_close > prev_vwap);
         const bool is_above = (close1 > g_session_vwap);
         if(was_above != is_above)
            g_vwap_crosses++;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   const int now_min = Strategy_MinutesOfDay(TimeCurrent());
   if(!Strategy_InSessionMinutes(now_min))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask > 0.0 && bid > 0.0 && (ask - bid) / point > 80.0)
         return true;
     }

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

   Strategy_UpdateSessionState();

   if(Strategy_HasOpenPosition() || g_trade_taken_session)
      return false;
   if(!g_opening_complete || g_or_width_blocked || g_or_high <= g_or_low || g_session_vwap <= 0.0)
      return false;
   if(strategy_opening_range_minutes <= 0 || strategy_ema_period <= 0 || strategy_atr_period <= 0)
      return false;
   if(strategy_max_vwap_crosses >= 0 && g_vwap_crosses > strategy_max_vwap_crosses)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0 || !Strategy_InSessionMinutes(Strategy_MinutesOfDay(bar_time)))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || ema <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   if(g_breakout_dir == 0)
     {
      if(close1 > g_or_high && close1 > g_session_vwap && close1 > ema)
         g_breakout_dir = 1;
      else if(close1 < g_or_low && close1 < g_session_vwap && close1 < ema)
         g_breakout_dir = -1;
      return false;
     }

   const double tol = MathMax(0, strategy_pullback_tolerance_pts) * point;
   if(g_breakout_dir > 0)
     {
      const bool retested_or = (low1 <= g_or_high + tol && close1 > g_or_high);
      const bool retested_vwap = (low1 <= g_session_vwap + tol && close1 > g_session_vwap);
      if((retested_or || retested_vwap) && close1 > ema)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double structure_sl = MathMin(low1, g_session_vwap);
         double atr_sl = entry - atr * strategy_atr_stop_mult;
         double sl = MathMax(structure_sl, atr_sl);
         if(sl >= entry)
            sl = atr_sl;
         const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr_target);
         if(entry > 0.0 && sl > 0.0 && tp > 0.0)
           {
            req.type = QM_BUY;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
            req.tp = tp;
            req.reason = "TV_VWAP_ORB_PB_LONG";
            g_trade_taken_session = true;
            return true;
           }
        }
     }
   else if(g_breakout_dir < 0)
     {
      const bool retested_or = (high1 >= g_or_low - tol && close1 < g_or_low);
      const bool retested_vwap = (high1 >= g_session_vwap - tol && close1 < g_session_vwap);
      if((retested_or || retested_vwap) && close1 < ema)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double structure_sl = MathMax(high1, g_session_vwap);
         double atr_sl = entry + atr * strategy_atr_stop_mult;
         double sl = MathMin(structure_sl, atr_sl);
         if(sl <= entry)
            sl = atr_sl;
         const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr_target);
         if(entry > 0.0 && sl > 0.0 && tp > 0.0)
           {
            req.type = QM_SELL;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
            req.tp = tp;
            req.reason = "TV_VWAP_ORB_PB_SHORT";
            g_trade_taken_session = true;
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline uses one full-position target; no runner or trailing variant.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int now_min = Strategy_MinutesOfDay(TimeCurrent());
   if(Strategy_AfterSessionEnd(now_min))
      return true;

   return false;
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
