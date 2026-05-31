#property strict
#property version   "5.0"
#property description "QM5_10647 TradingView Crypto SuperTrend BBW"

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
input int    qm_ea_id                   = 10647;
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
input ENUM_TIMEFRAMES strategy_timeframe              = PERIOD_M15;
input int             strategy_supertrend_atr_period  = 10;
input double          strategy_supertrend_mult        = 3.0;
input int             strategy_supertrend_warmup_bars = 80;
input int             strategy_bbw_period             = 20;
input double          strategy_bbw_deviation          = 2.0;
input int             strategy_bbw_ma_period          = 20;
input int             strategy_emergency_atr_period   = 14;
input double          strategy_emergency_atr_mult     = 3.0;
input int             strategy_max_hold_bars          = 96;

bool   g_strategy_state_ready = false;
int    g_strategy_dir_1       = 0;
int    g_strategy_dir_2       = 0;
double g_strategy_line_1      = 0.0;
double g_strategy_bbw_1       = 0.0;
double g_strategy_bbw_base    = 0.0;
bool   g_strategy_trending    = false;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double Strategy_BBWidth(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, strategy_timeframe, strategy_bbw_period,
                                    strategy_bbw_deviation, shift, PRICE_CLOSE);
   const double middle = QM_BB_Middle(_Symbol, strategy_timeframe, strategy_bbw_period,
                                      strategy_bbw_deviation, shift, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, strategy_timeframe, strategy_bbw_period,
                                    strategy_bbw_deviation, shift, PRICE_CLOSE);
   if(upper <= 0.0 || middle == 0.0 || lower <= 0.0 || upper <= lower)
      return 0.0;
   return (upper - lower) / MathAbs(middle);
  }

double Strategy_BBWidthBase()
  {
   const int samples = MathMax(1, strategy_bbw_ma_period);
   double sum = 0.0;
   int count = 0;
   for(int shift = 1; shift <= samples; ++shift)
     {
      const double width = Strategy_BBWidth(shift);
      if(width <= 0.0)
         continue;
      sum += width;
      count++;
     }

   if(count <= 0)
      return 0.0;
   return sum / (double)count;
  }

bool Strategy_ReadSuperTrendPair(double &line_1, int &dir_1, double &line_2, int &dir_2)
  {
   line_1 = 0.0;
   line_2 = 0.0;
   dir_1 = 0;
   dir_2 = 0;

   const int atr_period = MathMax(1, strategy_supertrend_atr_period);
   const int warmup = MathMax(strategy_supertrend_warmup_bars, atr_period + 20);
   if(Bars(_Symbol, strategy_timeframe) < warmup + 5)
      return false;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int dir = 0;

   for(int shift = warmup + 2; shift >= 1; --shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      const double close = iClose(_Symbol, strategy_timeframe, shift);
      const double atr = QM_ATR(_Symbol, strategy_timeframe, atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         return false;

      const double midpoint = (high + low) * 0.5;
      const double basic_upper = midpoint + strategy_supertrend_mult * atr;
      const double basic_lower = midpoint - strategy_supertrend_mult * atr;

      if(dir == 0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (close >= midpoint) ? 1 : -1;
        }
      else
        {
         const double prev_upper = final_upper;
         const double prev_lower = final_lower;
         const double prev_close = iClose(_Symbol, strategy_timeframe, shift + 1);
         if(prev_close <= 0.0)
            return false;

         final_upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
         final_lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

         if(dir < 0 && close > final_upper)
            dir = 1;
         else if(dir > 0 && close < final_lower)
            dir = -1;
        }

      const double line = (dir > 0) ? final_lower : final_upper;
      if(shift == 2)
        {
         line_2 = line;
         dir_2 = dir;
        }
      else if(shift == 1)
        {
         line_1 = line;
         dir_1 = dir;
        }
     }

   return (line_1 > 0.0 && line_2 > 0.0 && dir_1 != 0 && dir_2 != 0);
  }

bool Strategy_RefreshCachedState()
  {
   g_strategy_state_ready = false;
   g_strategy_trending = false;

   double line_1 = 0.0;
   double line_2 = 0.0;
   int dir_1 = 0;
   int dir_2 = 0;
   if(!Strategy_ReadSuperTrendPair(line_1, dir_1, line_2, dir_2))
      return false;

   const double bbw = Strategy_BBWidth(1);
   const double bbw_base = Strategy_BBWidthBase();
   if(bbw <= 0.0 || bbw_base <= 0.0)
      return false;

   g_strategy_line_1 = line_1;
   g_strategy_dir_1 = dir_1;
   g_strategy_dir_2 = dir_2;
   g_strategy_bbw_1 = bbw;
   g_strategy_bbw_base = bbw_base;
   g_strategy_trending = (bbw > bbw_base);
   g_strategy_state_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(!Strategy_RefreshCachedState())
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!g_strategy_trending)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_emergency_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_strategy_dir_2 < 0 && g_strategy_dir_1 > 0)
     {
      const double emergency_sl = ask - strategy_emergency_atr_mult * atr;
      double stop = g_strategy_line_1;
      if(stop <= 0.0 || stop >= ask - point || stop < emergency_sl)
         stop = emergency_sl;
      if(stop <= 0.0 || stop >= ask - point)
         return false;

      req.type = QM_BUY;
      req.sl = Strategy_NormalizePrice(stop);
      req.reason = "bbw_supertrend_flip_long";
      return true;
     }

   if(g_strategy_dir_2 > 0 && g_strategy_dir_1 < 0)
     {
      const double emergency_sl = bid + strategy_emergency_atr_mult * atr;
      double stop = g_strategy_line_1;
      if(stop <= bid + point || stop > emergency_sl)
         stop = emergency_sl;
      if(stop <= bid + point)
         return false;

      req.type = QM_SELL;
      req.sl = Strategy_NormalizePrice(stop);
      req.reason = "bbw_supertrend_flip_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!g_strategy_state_ready || g_strategy_line_1 <= 0.0)
      return;

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double current_sl = PositionGetDouble(POSITION_SL);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   const double stop = Strategy_NormalizePrice(g_strategy_line_1);
   if(ptype == POSITION_TYPE_BUY && g_strategy_dir_1 > 0 && stop < bid - point)
     {
      if(current_sl <= 0.0 || stop > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, stop, "supertrend_dynamic_stop_long");
     }
   else if(ptype == POSITION_TYPE_SELL && g_strategy_dir_1 < 0 && stop > ask + point)
     {
      if(current_sl <= 0.0 || stop < current_sl - point * 0.5)
         QM_TM_MoveSL(ticket, stop, "supertrend_dynamic_stop_short");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_timeframe);
   if(seconds_per_bar > 0 && strategy_max_hold_bars > 0)
     {
      const long elapsed = (long)(TimeCurrent() - open_time);
      if(elapsed >= (long)strategy_max_hold_bars * (long)seconds_per_bar)
         return true;
     }

   if(!g_strategy_state_ready)
      return false;

   if(ptype == POSITION_TYPE_BUY && g_strategy_dir_1 < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_strategy_dir_1 > 0)
      return true;

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
