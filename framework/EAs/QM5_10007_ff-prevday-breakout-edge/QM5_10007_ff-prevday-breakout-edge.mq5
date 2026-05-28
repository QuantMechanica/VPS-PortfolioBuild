#property strict
#property version   "5.0"
#property description "QM5_10007 ForexFactory Previous Day Breakout Edge"

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
input int    qm_ea_id                   = 10007;
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
input int    strategy_sma_period        = 34;
input bool   strategy_use_sma_filter    = true;
input double strategy_sl_pips           = 12.5;
input double strategy_tp_pips           = 25.0;
input double strategy_max_spread_pips   = 2.0;
input double strategy_spread_sl_frac    = 0.16;
input int    strategy_atr_period_d1     = 14;
input double strategy_min_range_atr     = 0.5;
input int    strategy_gmt_day_start_hour = 22;
input int    strategy_day_scan_bars     = 144;

long g_strategy_day_index = LONG_MIN;
bool g_long_taken_this_day = false;
bool g_short_taken_this_day = false;
long g_cached_range_day_index = LONG_MIN;
double g_cached_pdh = 0.0;
double g_cached_pdl = 0.0;

double Strategy_PipDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_SpreadPips()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy_PipDistance(1.0);
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

long Strategy_SourceDayIndex(const datetime broker_time)
  {
   const int boundary_hour = MathMax(0, MathMin(23, strategy_gmt_day_start_hour));
   const datetime gmt_time = QM_BrokerToUTC(broker_time);
   return (long)((gmt_time - boundary_hour * 3600) / 86400);
  }

void Strategy_SyncDayState(const long source_day_index)
  {
   if(source_day_index == g_strategy_day_index)
      return;

   g_strategy_day_index = source_day_index;
   g_long_taken_this_day = false;
   g_short_taken_this_day = false;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type, datetime &position_time)
  {
   position_type = POSITION_TYPE_BUY;
   position_time = 0;

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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_PreviousTradingDayRange(const long current_day_index,
                                      double &pdh,
                                      double &pdl,
                                      long &previous_day_index)
  {
   pdh = 0.0;
   pdl = 0.0;
   previous_day_index = LONG_MIN;
   bool have_day = false;

   const int max_scan = MathMax(24, strategy_day_scan_bars);
   for(int shift = 2; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H1, shift);
      if(bar_time <= 0)
         break;

      const long day_index = Strategy_SourceDayIndex(bar_time);
      if(day_index >= current_day_index)
         continue;

      if(!have_day)
        {
         previous_day_index = day_index;
         pdh = -DBL_MAX;
         pdl = DBL_MAX;
         have_day = true;
        }

      if(day_index != previous_day_index)
         break;

      const double high = iHigh(_Symbol, PERIOD_H1, shift);
      const double low = iLow(_Symbol, PERIOD_H1, shift);
      if(high <= 0.0 || low <= 0.0 || high < low)
         continue;

      if(high > pdh)
         pdh = high;
      if(low < pdl)
         pdl = low;
     }

   return (have_day && pdh > 0.0 && pdl > 0.0 && pdh > pdl);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double max_by_sl = strategy_sl_pips * strategy_spread_sl_frac;
   const double max_spread = MathMin(strategy_max_spread_pips, max_by_sl);
   return (Strategy_SpreadPips() > max_spread);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   ENUM_POSITION_TYPE position_type;
   datetime position_time;
   if(Strategy_HasOpenPosition(position_type, position_time))
      return false;

   const datetime signal_bar_time = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar_time <= 0)
      return false;

   const long current_day_index = Strategy_SourceDayIndex(signal_bar_time);
   Strategy_SyncDayState(current_day_index);

   double pdh = 0.0;
   double pdl = 0.0;
   long previous_day_index = LONG_MIN;
   if(!Strategy_PreviousTradingDayRange(current_day_index, pdh, pdl, previous_day_index))
      return false;
   g_cached_range_day_index = current_day_index;
   g_cached_pdh = pdh;
   g_cached_pdl = pdl;

   const double prior_range = pdh - pdl;
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(d1_atr <= 0.0 || prior_range < strategy_min_range_atr * d1_atr)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1, PRICE_CLOSE);
   const double entry = (close1 > 0.0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 0.0;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = Strategy_PipDistance(strategy_sl_pips);
   const double tp_dist = Strategy_PipDistance(strategy_tp_pips);
   if(sl_dist <= 0.0 || tp_dist <= 0.0 || entry <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > pdh && !g_long_taken_this_day)
     {
      if(strategy_use_sma_filter && (sma <= 0.0 || close1 <= sma))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry - sl_dist, _Digits);
      req.tp = NormalizeDouble(entry + tp_dist, _Digits);
      req.reason = "FF_PREVDAY_BREAKOUT_LONG";
      g_long_taken_this_day = true;
      return true;
     }

   if(close1 < pdl && !g_short_taken_this_day)
     {
      if(strategy_use_sma_filter && (sma <= 0.0 || close1 >= sma))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + sl_dist, _Digits);
      req.tp = NormalizeDouble(bid - tp_dist, _Digits);
      req.reason = "FF_PREVDAY_BREAKOUT_SHORT";
      g_short_taken_this_day = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial, or break-even logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime position_time;
   if(!Strategy_HasOpenPosition(position_type, position_time))
      return false;

   if(position_time > 0 && Strategy_SourceDayIndex(TimeCurrent()) > Strategy_SourceDayIndex(position_time))
      return true;

   const datetime signal_bar_time = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar_time <= 0)
      return false;

   const long current_day_index = Strategy_SourceDayIndex(signal_bar_time);
   if(g_cached_range_day_index != current_day_index || g_cached_pdh <= 0.0 || g_cached_pdl <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && close1 < g_cached_pdl)
      return true;
   if(position_type == POSITION_TYPE_SELL && close1 > g_cached_pdh)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework news filter
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
