#property strict
#property version   "5.0"
#property description "QM5_10831 TradingView Refined Supertrend ATR TSL"

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
input int    qm_ea_id                   = 10831;
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
input int    strategy_supertrend_atr_period = 10;
input double strategy_supertrend_factor     = 3.0;
input bool   strategy_use_ema_filter        = true;
input int    strategy_ema_period            = 200;
input bool   strategy_use_adx_filter        = true;
input int    strategy_adx_period            = 14;
input double strategy_adx_threshold         = 20.0;
input int    strategy_trail_atr_period      = 14;
input double strategy_atr_trail_mult        = 2.0;
input double strategy_breakeven_atr_mult    = 1.5;
input bool   strategy_use_fixed_target      = true;
input double strategy_target_atr_mult       = 3.0;
input bool   strategy_use_session_filter    = false;
input int    strategy_session_start_hour    = 0;
input int    strategy_session_end_hour      = 24;

double g_strategy_st_line = 0.0;
int    g_strategy_st_dir  = 0;
double g_strategy_atr     = 0.0;
double g_strategy_close   = 0.0;

bool Strategy_SessionAllows(const datetime broker_time)
  {
   if(!strategy_use_session_filter)
      return true;

   int start_hour = MathMax(0, MathMin(23, strategy_session_start_hour));
   int end_hour = MathMax(0, MathMin(24, strategy_session_end_hour));
   if(end_hour == 24)
      end_hour = 0;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

bool Strategy_SuperTrendAtShift(const int target_shift, double &out_line, int &out_dir)
  {
   out_line = 0.0;
   out_dir = 0;
   if(target_shift < 1 || strategy_supertrend_atr_period < 1 || strategy_supertrend_factor <= 0.0)
      return false;

   int warmup = strategy_supertrend_atr_period * 10;
   if(warmup < 80)
      warmup = 80;
   if(warmup > 300)
      warmup = 300;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int dir = 0;

   for(int shift = target_shift + warmup; shift >= target_shift; --shift)
     {
      const double high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);     // perf-allowed: bespoke SuperTrend OHLC reconstruction, called only from closed-bar EntrySignal
      const double low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);       // perf-allowed: bespoke SuperTrend OHLC reconstruction, called only from closed-bar EntrySignal
      const double close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);   // perf-allowed: bespoke SuperTrend OHLC reconstruction, called only from closed-bar EntrySignal
      const double prev_close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + 1); // perf-allowed: bespoke SuperTrend OHLC reconstruction, called only from closed-bar EntrySignal
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_supertrend_atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         continue;

      const double median = (high + low) * 0.5;
      const double basic_upper = median + strategy_supertrend_factor * atr;
      const double basic_lower = median - strategy_supertrend_factor * atr;

      if(dir == 0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (close >= median) ? 1 : -1;
        }
      else
        {
         final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
         final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;
         if(dir < 0 && close > final_upper)
            dir = 1;
         else if(dir > 0 && close < final_lower)
            dir = -1;
        }

      if(shift == target_shift)
        {
         out_dir = dir;
         out_line = (dir > 0) ? final_lower : final_upper;
         return (out_line > 0.0);
        }
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
   return !Strategy_SessionAllows(TimeCurrent());
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

   double st_now = 0.0;
   double st_prev = 0.0;
   int dir_now = 0;
   int dir_prev = 0;
   if(!Strategy_SuperTrendAtShift(1, st_now, dir_now))
      return false;
   if(!Strategy_SuperTrendAtShift(2, st_prev, dir_prev))
      return false;

   const double close_now = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);       // perf-allowed: SuperTrend cross uses closed-bar close
   const double close_prev = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);      // perf-allowed: SuperTrend cross uses closed-bar close
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trail_atr_period, 1);
   if(close_now <= 0.0 || close_prev <= 0.0 || atr <= 0.0)
      return false;

   g_strategy_st_line = st_now;
   g_strategy_st_dir = dir_now;
   g_strategy_atr = atr;
   g_strategy_close = close_now;

   if(strategy_use_ema_filter)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
      if(ema <= 0.0)
         return false;
      if(dir_now > 0 && close_now <= ema)
         return false;
      if(dir_now < 0 && close_now >= ema)
         return false;
     }

   if(strategy_use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
      if(adx <= strategy_adx_threshold)
         return false;
     }

   const bool long_cross = (close_prev <= st_prev && close_now > st_now && dir_now > 0);
   const bool short_cross = (close_prev >= st_prev && close_now < st_now && dir_now < 0);
   if(!long_cross && !short_cross)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_cross)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = st_now;
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.tp = strategy_use_fixed_target ? (ask + strategy_target_atr_mult * atr) : 0.0;
      req.reason = "QM5_10831_SUPERTREND_LONG";
      return true;
     }

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = st_now;
   if(req.sl <= bid)
      return false;
   req.tp = strategy_use_fixed_target ? (bid - strategy_target_atr_mult * atr) : 0.0;
   req.reason = "QM5_10831_SUPERTREND_SHORT";
   return true;
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double market = is_buy ? bid : ask;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double atr = (g_strategy_atr > 0.0) ? g_strategy_atr : QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trail_atr_period, 1);
      if(open_price <= 0.0 || market <= 0.0 || point <= 0.0 || atr <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      const bool trail_active = (strategy_breakeven_atr_mult <= 0.0 || moved >= strategy_breakeven_atr_mult * atr);

      if(trail_active && strategy_breakeven_atr_mult > 0.0)
        {
         const double be_sl = open_price;
         const bool be_improves = (current_sl <= 0.0) ||
                                  (is_buy ? (be_sl > current_sl + point * 0.5)
                                          : (be_sl < current_sl - point * 0.5));
         if(be_improves)
            QM_TM_MoveSL(ticket, be_sl, "supertrend_atr_breakeven");
        }

      double target_sl = g_strategy_st_line;
      if(trail_active)
        {
         const double close_ref = (g_strategy_close > 0.0) ? g_strategy_close : market;
         const double atr_stop = is_buy ? (close_ref - strategy_atr_trail_mult * atr)
                                        : (close_ref + strategy_atr_trail_mult * atr);
         target_sl = is_buy ? MathMax(target_sl, atr_stop) : MathMin(target_sl, atr_stop);
        }

      if(target_sl <= 0.0)
         continue;
      if(is_buy && target_sl >= bid)
         continue;
      if(!is_buy && target_sl <= ask)
         continue;

      const double refreshed_sl = PositionGetDouble(POSITION_SL);
      const bool improves = (refreshed_sl <= 0.0) ||
                            (is_buy ? (target_sl > refreshed_sl + point * 0.5)
                                    : (target_sl < refreshed_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, trail_active ? "supertrend_atr_trail" : "supertrend_primary_stop");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
