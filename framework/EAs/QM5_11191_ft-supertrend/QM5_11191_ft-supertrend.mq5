#property strict
#property version   "5.0"
#property description "QM5_11191 ft-supertrend"

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
input int    qm_ea_id                   = 11191;
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
input int    strategy_buy_st_1_period       = 8;
input double strategy_buy_st_1_mult         = 4.0;
input int    strategy_buy_st_2_period       = 9;
input double strategy_buy_st_2_mult         = 7.0;
input int    strategy_buy_st_3_period       = 8;
input double strategy_buy_st_3_mult         = 1.0;
input int    strategy_sell_st_1_period      = 16;
input double strategy_sell_st_1_mult        = 1.0;
input int    strategy_sell_st_2_period      = 18;
input double strategy_sell_st_2_mult        = 3.0;
input int    strategy_sell_st_3_period      = 18;
input double strategy_sell_st_3_mult        = 6.0;
input int    strategy_atr_failsafe_period   = 14;
input double strategy_atr_failsafe_mult     = 3.0;
input int    strategy_warmup_bars           = 199;
input double strategy_max_spread_stop_pct   = 8.0;
input double strategy_source_stoploss_pct   = 26.5;
input int    strategy_roi_1_minutes         = 0;
input double strategy_roi_1_pct             = 8.7;
input int    strategy_roi_2_minutes         = 372;
input double strategy_roi_2_pct             = 5.8;
input int    strategy_roi_3_minutes         = 861;
input double strategy_roi_3_pct             = 2.9;
input int    strategy_roi_4_minutes         = 2221;
input double strategy_roi_4_pct             = 0.0;

bool g_strategy_cached_entry_long = false;
bool g_strategy_cached_exit_long = false;
bool g_strategy_cached_volume_ok = false;

double Strategy_Max3(const double a, const double b, const double c)
  {
   return MathMax(a, MathMax(b, c));
  }

int Strategy_SupertrendDirection(const MqlRates &rates[],
                                 const int copied,
                                 const double multiplier,
                                 const int period)
  {
   if(copied <= period + 2 || period <= 0 || multiplier <= 0.0)
      return 0;

   double atr = 0.0;
   int atr_samples = 0;
   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int prev_direction = 0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      const double prev_close = (i == copied - 1) ? close : rates[i + 1].close;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high < low)
         continue;

      const double tr = Strategy_Max3(high - low,
                                      MathAbs(high - prev_close),
                                      MathAbs(low - prev_close));
      if(tr <= 0.0)
         continue;

      if(atr_samples < period)
        {
         atr += tr;
         atr_samples++;
         if(atr_samples < period)
            continue;
         atr /= (double)period;
        }
      else
        {
         atr = ((atr * (double)(period - 1)) + tr) / (double)period;
        }

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + multiplier * atr;
      const double basic_lower = hl2 - multiplier * atr;

      double final_upper = basic_upper;
      double final_lower = basic_lower;
      int direction = prev_direction;

      if(prev_direction == 0)
        {
         direction = (close >= basic_lower) ? 1 : -1;
        }
      else
        {
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper)
                       ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower)
                       ? basic_lower : prev_final_lower;

         if(prev_direction < 0 && close > final_upper)
            direction = 1;
         else if(prev_direction > 0 && close < final_lower)
            direction = -1;
        }

      prev_final_upper = final_upper;
      prev_final_lower = final_lower;
      prev_direction = direction;
     }

   return prev_direction;
  }

bool Strategy_RecomputeSignals()
  {
   g_strategy_cached_entry_long = false;
   g_strategy_cached_exit_long = false;
   g_strategy_cached_volume_ok = false;

   const int bars_needed = MathMax(strategy_warmup_bars, 240);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates); // perf-allowed: closed-bar Supertrend state cache; no QM OHLC array helper exists.
   if(copied < strategy_warmup_bars || copied <= 0)
      return false;

   g_strategy_cached_volume_ok = (rates[0].tick_volume > 0);
   if(!g_strategy_cached_volume_ok)
      return false;

   const int buy1 = Strategy_SupertrendDirection(rates, copied, strategy_buy_st_1_mult, strategy_buy_st_1_period);
   const int buy2 = Strategy_SupertrendDirection(rates, copied, strategy_buy_st_2_mult, strategy_buy_st_2_period);
   const int buy3 = Strategy_SupertrendDirection(rates, copied, strategy_buy_st_3_mult, strategy_buy_st_3_period);
   const int sell1 = Strategy_SupertrendDirection(rates, copied, strategy_sell_st_1_mult, strategy_sell_st_1_period);
   const int sell2 = Strategy_SupertrendDirection(rates, copied, strategy_sell_st_2_mult, strategy_sell_st_2_period);
   const int sell3 = Strategy_SupertrendDirection(rates, copied, strategy_sell_st_3_mult, strategy_sell_st_3_period);

   g_strategy_cached_entry_long = (buy1 > 0 && buy2 > 0 && buy3 > 0);
   g_strategy_cached_exit_long = (sell1 < 0 && sell2 < 0 && sell3 < 0);
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

double Strategy_CurrentRoiThresholdPct(const int hold_minutes)
  {
   if(hold_minutes >= strategy_roi_4_minutes)
      return strategy_roi_4_pct;
   if(hold_minutes >= strategy_roi_3_minutes)
      return strategy_roi_3_pct;
   if(hold_minutes >= strategy_roi_2_minutes)
      return strategy_roi_2_pct;
   return strategy_roi_1_pct;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_failsafe_period, 1);
   if(atr <= 0.0 || strategy_atr_failsafe_mult <= 0.0)
      return true;

   const double planned_stop_distance = atr * strategy_atr_failsafe_mult;
   if(planned_stop_distance <= 0.0)
      return true;

   const double spread = ask - bid;
   return (spread > planned_stop_distance * strategy_max_spread_stop_pct / 100.0);
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

   if(!Strategy_RecomputeSignals())
      return false;
   if(!g_strategy_cached_entry_long)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr_stop = QM_StopATR(_Symbol, QM_BUY, ask,
                                     strategy_atr_failsafe_period,
                                     strategy_atr_failsafe_mult);
   if(atr_stop <= 0.0 || atr_stop >= ask)
      return false;

   req.sl = atr_stop;
   req.tp = 0.0;
   req.reason = "TRIPLE_SUPERTREND_LONG";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card management is expressed through the ATR fail-safe SL at entry and
   // the source ROI ladder / sell-state exits in Strategy_ExitSignal().
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      if(g_strategy_cached_exit_long && g_strategy_cached_volume_ok)
         return true;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price <= 0.0 || bid <= 0.0)
         continue;

      const double profit_pct = ((bid - open_price) / open_price) * 100.0;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int hold_minutes = (int)((now - open_time) / 60);
      if(strategy_source_stoploss_pct > 0.0 && profit_pct <= -strategy_source_stoploss_pct)
         return true;

      const double roi_threshold = Strategy_CurrentRoiThresholdPct(hold_minutes);
      if(profit_pct >= roi_threshold)
         return true;
     }

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
