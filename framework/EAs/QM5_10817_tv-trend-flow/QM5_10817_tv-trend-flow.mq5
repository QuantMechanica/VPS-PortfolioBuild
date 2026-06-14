#property strict
#property version   "5.0"
#property description "QM5_10817 TradingView Trend Flow Fixed Mode"

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
input int    qm_ea_id                   = 10817;
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
input int    strategy_fast_ema              = 20;
input int    strategy_slow_ema              = 50;
input int    strategy_supertrend_atr_period = 10;
input double strategy_supertrend_multiplier = 3.0;
input int    strategy_supertrend_lookback   = 160;
input int    strategy_atr_fallback_period   = 14;
input double strategy_atr_fallback_mult     = 2.0;
input int    strategy_max_bars_h1           = 120;
input int    strategy_max_bars_h4           = 80;

double g_st_line = 0.0;
double g_st_prev_line = 0.0;
double g_st_close = 0.0;
bool   g_st_bull = false;
bool   g_st_prev_bull = false;
bool   g_st_valid = false;

void Strategy_ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   return Strategy_SelectOurPosition(ticket, ptype, opened_at);
  }

bool Strategy_RefreshSuperTrendCache()
  {
   g_st_valid = false;
   if(strategy_supertrend_atr_period < 2 || strategy_supertrend_multiplier <= 0.0)
      return false;

   const int min_lookback = strategy_supertrend_atr_period * 5 + 5;
   const int lookback = (strategy_supertrend_lookback > min_lookback) ? strategy_supertrend_lookback : min_lookback;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, rates); // perf-allowed: bespoke SuperTrend OHLC sequence, called only from framework closed-bar EntrySignal.
   if(copied < strategy_supertrend_atr_period + 3)
      return false;

   double atr = 0.0;
   double tr_sum = 0.0;
   double final_upper = 0.0;
   double final_lower = 0.0;
   double st_line = 0.0;
   bool st_bull = false;
   bool st_ready = false;
   bool have_prev = false;
   bool have_curr = false;

   for(int i = 0; i < copied; ++i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double close = rates[i].close;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         return false;

      const double prev_close = (i > 0) ? rates[i - 1].close : close;
      const double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));

      if(i < strategy_supertrend_atr_period)
        {
         tr_sum += tr;
         if(i < strategy_supertrend_atr_period - 1)
            continue;
         atr = tr_sum / (double)strategy_supertrend_atr_period;
        }
      else
        {
         atr = ((atr * (strategy_supertrend_atr_period - 1)) + tr) / (double)strategy_supertrend_atr_period;
        }

      if(atr <= 0.0)
         return false;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + strategy_supertrend_multiplier * atr;
      const double basic_lower = hl2 - strategy_supertrend_multiplier * atr;

      if(!st_ready)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         st_line = (close >= hl2) ? final_lower : final_upper;
         st_bull = (st_line == final_lower);
         st_ready = true;
        }
      else
        {
         const double prev_final_upper = final_upper;
         const double prev_final_lower = final_lower;
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper) ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower) ? basic_lower : prev_final_lower;

         if(st_line == prev_final_upper)
            st_line = (close <= final_upper) ? final_upper : final_lower;
         else
            st_line = (close >= final_lower) ? final_lower : final_upper;

         st_bull = (st_line == final_lower);
        }

      if(i == copied - 2)
        {
         g_st_prev_line = st_line;
         g_st_prev_bull = st_bull;
         have_prev = true;
        }
      if(i == copied - 1)
        {
         g_st_line = st_line;
         g_st_bull = st_bull;
         g_st_close = close;
         have_curr = true;
        }
     }

   g_st_valid = (have_prev && have_curr && g_st_line > 0.0 && g_st_prev_line > 0.0 && g_st_close > 0.0);
   return g_st_valid;
  }

bool Strategy_StopMeetsBrokerDistance(const QM_OrderType side, const double entry, const double stop)
  {
   if(entry <= 0.0 || stop <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(side) && stop >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && stop <= entry)
      return false;

   const double min_distance = (stops_level > 0) ? point * stops_level : 0.0;
   return (min_distance <= 0.0 || MathAbs(entry - stop) >= min_distance);
  }

double Strategy_InitialStop(const QM_OrderType side, const double entry)
  {
   double stop = 0.0;
   if(g_st_valid)
     {
      if(QM_OrderTypeIsBuy(side) && g_st_line < entry)
         stop = g_st_line;
      else if(!QM_OrderTypeIsBuy(side) && g_st_line > entry)
         stop = g_st_line;
     }

   if(!Strategy_StopMeetsBrokerDistance(side, entry, stop))
      stop = QM_StopATR(_Symbol, side, entry, strategy_atr_fallback_period, strategy_atr_fallback_mult);

   if(!Strategy_StopMeetsBrokerDistance(side, entry, stop))
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

bool Strategy_EMACrossReversal(const ENUM_POSITION_TYPE ptype)
  {
   const int fast = MathMax(1, strategy_fast_ema);
   const int slow = MathMax(fast + 1, strategy_slow_ema);
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_EMA(_Symbol, tf, fast, 1);
   const double slow_1 = QM_EMA(_Symbol, tf, slow, 1);
   const double fast_2 = QM_EMA(_Symbol, tf, fast, 2);
   const double slow_2 = QM_EMA(_Symbol, tf, slow, 2);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (fast_2 >= slow_2 && fast_1 < slow_1);
   if(ptype == POSITION_TYPE_SELL)
      return (fast_2 <= slow_2 && fast_1 > slow_1);
   return false;
  }

bool Strategy_MaxBarsExceeded(const datetime opened_at)
  {
   if(opened_at <= 0)
      return false;

   int max_bars = 0;
   if(_Period == PERIOD_H1)
      max_bars = strategy_max_bars_h1;
   else if(_Period == PERIOD_H4)
      max_bars = strategy_max_bars_h4;

   if(max_bars <= 0)
      return false;

   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      return false;

   const long elapsed_seconds = (long)(TimeCurrent() - opened_at);
   const long limit_seconds = (long)max_bars * (long)seconds;
   return (elapsed_seconds >= limit_seconds);
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
   Strategy_ResetEntryRequest(req);

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_RefreshSuperTrendCache())
      return false;

   const int fast = MathMax(1, strategy_fast_ema);
   const int slow = MathMax(fast + 1, strategy_slow_ema);
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_EMA(_Symbol, tf, fast, 1);
   const double slow_1 = QM_EMA(_Symbol, tf, slow, 1);
   const double fast_2 = QM_EMA(_Symbol, tf, fast, 2);
   const double slow_2 = QM_EMA(_Symbol, tf, slow, 2);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return false;

   const bool long_signal = (fast_2 <= slow_2 && fast_1 > slow_1 &&
                             g_st_close > fast_1 && g_st_close > slow_1 &&
                             g_st_bull);
   const bool short_signal = (fast_2 >= slow_2 && fast_1 < slow_1 &&
                              g_st_close < fast_1 && g_st_close < slow_1 &&
                              !g_st_bull);
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = Strategy_InitialStop(req.type, entry);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = long_signal ? "ema20_50_cross_supertrend_long" : "ema20_50_cross_supertrend_short";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!g_st_valid || g_st_line <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const bool valid_side = is_buy ? (g_st_bull && g_st_line < market)
                                     : (!g_st_bull && g_st_line > market);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (g_st_line > current_sl + point * 0.5)
                                    : (g_st_line < current_sl - point * 0.5));
      if(valid_side && improves)
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, g_st_line), "supertrend_trail");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!Strategy_SelectOurPosition(ticket, ptype, opened_at))
      return false;

   if(Strategy_EMACrossReversal(ptype))
      return true;

   if(g_st_valid)
     {
      if(ptype == POSITION_TYPE_BUY && !g_st_bull)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_st_bull)
         return true;
     }

   if(Strategy_MaxBarsExceeded(opened_at))
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
