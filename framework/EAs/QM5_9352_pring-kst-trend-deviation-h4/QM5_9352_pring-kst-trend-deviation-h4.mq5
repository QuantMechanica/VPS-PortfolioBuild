#property strict
#property version   "5.0"
#property description "QM5_9352 Pring KST Trend Deviation H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 9352;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_roc1_bars        = 60;
input int    strategy_roc2_bars        = 90;
input int    strategy_roc3_bars        = 120;
input int    strategy_roc4_bars        = 180;
input int    strategy_roc1_sma         = 60;
input int    strategy_roc2_sma         = 60;
input int    strategy_roc3_sma         = 60;
input int    strategy_roc4_sma         = 90;
input int    strategy_kst_trend_sma    = 90;
input int    strategy_price_sma_period = 200;
input int    strategy_atr_period       = 14;
input double strategy_atr_sl_mult      = 2.5;
input double strategy_spread_atr_mult  = 0.15;
input int    strategy_max_hold_h4_bars = 60;
input int    strategy_warmup_bars      = 270;

bool     g_state_ready = false;
double   g_kst_cur = 0.0;
double   g_kst_prev = 0.0;
double   g_kst_three_back = 0.0;
double   g_dev_cur = 0.0;
double   g_dev_prev = 0.0;
double   g_close_cur = 0.0;
double   g_price_sma = 0.0;
double   g_atr = 0.0;
datetime g_last_closed_bar_time = 0;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_H4;
  }

bool Strategy_ParametersValid()
  {
   return (strategy_roc1_bars > 0 &&
           strategy_roc2_bars > strategy_roc1_bars &&
           strategy_roc3_bars > strategy_roc2_bars &&
           strategy_roc4_bars > strategy_roc3_bars &&
           strategy_roc1_sma > 0 &&
           strategy_roc2_sma > 0 &&
           strategy_roc3_sma > 0 &&
           strategy_roc4_sma > 0 &&
           strategy_kst_trend_sma > 0 &&
           strategy_price_sma_period > 0 &&
           strategy_atr_period > 0 &&
           strategy_atr_sl_mult > 0.0 &&
           strategy_spread_atr_mult >= 0.0 &&
           strategy_max_hold_h4_bars > 0 &&
           strategy_warmup_bars > 0);
  }

int Strategy_Max2(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int Strategy_Max4(const int a, const int b, const int c, const int d)
  {
   return Strategy_Max2(Strategy_Max2(a, b), Strategy_Max2(c, d));
  }

int Strategy_BarsNeeded()
  {
   const int roc_need1 = strategy_roc1_bars + strategy_roc1_sma;
   const int roc_need2 = strategy_roc2_bars + strategy_roc2_sma;
   const int roc_need3 = strategy_roc3_bars + strategy_roc3_sma;
   const int roc_need4 = strategy_roc4_bars + strategy_roc4_sma;
   const int kst_need = Strategy_Max4(roc_need1, roc_need2, roc_need3, roc_need4);
   const int trend_need = kst_need + strategy_kst_trend_sma + 8;
   return Strategy_Max4(strategy_warmup_bars + 8,
                        trend_need,
                        strategy_price_sma_period + 8,
                        strategy_max_hold_h4_bars + 8);
  }

bool Strategy_CopyH4Rates(MqlRates &rates[])
  {
   if(!Strategy_ParametersValid())
      return false;

   ArraySetAsSeries(rates, true);
   const int need = Strategy_BarsNeeded();
   const int copied = CopyRates(_Symbol, Strategy_Timeframe(), 0, need, rates); // perf-allowed: bounded KST warmup window, called only after QM_IsNewBar(_Symbol, PERIOD_H4).
   return (copied >= need);
  }

bool Strategy_RocSma(const MqlRates &rates[],
                     const int shift,
                     const int roc_bars,
                     const int smooth_bars,
                     double &out_value)
  {
   out_value = 0.0;
   const int n = ArraySize(rates);
   if(shift < 1 || roc_bars <= 0 || smooth_bars <= 0)
      return false;
   if(shift + smooth_bars - 1 + roc_bars >= n)
      return false;

   double sum = 0.0;
   for(int i = 0; i < smooth_bars; ++i)
     {
      const double close_now = rates[shift + i].close;
      const double close_then = rates[shift + i + roc_bars].close;
      if(close_now <= 0.0 || close_then <= 0.0)
         return false;
      sum += ((close_now / close_then) - 1.0) * 100.0;
     }

   out_value = sum / (double)smooth_bars;
   return true;
  }

bool Strategy_KSTAt(const MqlRates &rates[], const int shift, double &out_kst)
  {
   out_kst = 0.0;

   double r1 = 0.0;
   double r2 = 0.0;
   double r3 = 0.0;
   double r4 = 0.0;
   if(!Strategy_RocSma(rates, shift, strategy_roc1_bars, strategy_roc1_sma, r1))
      return false;
   if(!Strategy_RocSma(rates, shift, strategy_roc2_bars, strategy_roc2_sma, r2))
      return false;
   if(!Strategy_RocSma(rates, shift, strategy_roc3_bars, strategy_roc3_sma, r3))
      return false;
   if(!Strategy_RocSma(rates, shift, strategy_roc4_bars, strategy_roc4_sma, r4))
      return false;

   out_kst = r1 + (2.0 * r2) + (3.0 * r3) + (4.0 * r4);
   return true;
  }

bool Strategy_KSTTrendAt(const MqlRates &rates[], const int shift, double &out_trend)
  {
   out_trend = 0.0;
   if(strategy_kst_trend_sma <= 0)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_kst_trend_sma; ++i)
     {
      double kst = 0.0;
      if(!Strategy_KSTAt(rates, shift + i, kst))
         return false;
      sum += kst;
     }

   out_trend = sum / (double)strategy_kst_trend_sma;
   return true;
  }

bool Strategy_CloseSmaAt(const MqlRates &rates[],
                         const int shift,
                         const int period,
                         double &out_sma)
  {
   out_sma = 0.0;
   const int n = ArraySize(rates);
   if(shift < 1 || period <= 0 || shift + period > n)
      return false;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double close_i = rates[shift + i].close;
      if(close_i <= 0.0)
         return false;
      sum += close_i;
     }

   out_sma = sum / (double)period;
   return true;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;

   MqlRates rates[];
   if(!Strategy_CopyH4Rates(rates))
      return false;

   double kst_cur = 0.0;
   double kst_prev = 0.0;
   double kst_three_back = 0.0;
   double trend_cur = 0.0;
   double trend_prev = 0.0;
   double price_sma = 0.0;
   if(!Strategy_KSTAt(rates, 1, kst_cur))
      return false;
   if(!Strategy_KSTAt(rates, 2, kst_prev))
      return false;
   if(!Strategy_KSTAt(rates, 4, kst_three_back))
      return false;
   if(!Strategy_KSTTrendAt(rates, 1, trend_cur))
      return false;
   if(!Strategy_KSTTrendAt(rates, 2, trend_prev))
      return false;
   if(!Strategy_CloseSmaAt(rates, 1, strategy_price_sma_period, price_sma))
      return false;

   const double atr = QM_ATR(_Symbol, Strategy_Timeframe(), strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   g_kst_cur = kst_cur;
   g_kst_prev = kst_prev;
   g_kst_three_back = kst_three_back;
   g_dev_cur = kst_cur - trend_cur;
   g_dev_prev = kst_prev - trend_prev;
   g_close_cur = rates[1].close;
   g_price_sma = price_sma;
   g_atr = atr;
   g_last_closed_bar_time = rates[1].time;
   g_state_ready = true;
   return true;
  }

bool Strategy_GetOurPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &position_type,
                             datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   return Strategy_GetOurPosition(ticket, position_type, open_time);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_spread_atr_mult <= 0.0)
      return true;
   if(g_atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) <= strategy_spread_atr_mult * g_atr);
  }

bool Strategy_LongSignal()
  {
   return (g_state_ready &&
           g_dev_prev <= 0.0 &&
           g_dev_cur > 0.0 &&
           g_kst_cur > g_kst_three_back &&
           g_close_cur > g_price_sma);
  }

bool Strategy_ShortSignal()
  {
   return (g_state_ready &&
           g_dev_prev >= 0.0 &&
           g_dev_cur < 0.0 &&
           g_kst_cur < g_kst_three_back &&
           g_close_cur < g_price_sma);
  }

int Strategy_BarsHeld(const datetime open_time)
  {
   if(open_time <= 0 || g_last_closed_bar_time <= 0)
      return 0;

   const int seconds_per_bar = PeriodSeconds(Strategy_Timeframe());
   if(seconds_per_bar <= 0 || g_last_closed_bar_time <= open_time)
      return 0;

   return (int)MathFloor((double)(g_last_closed_bar_time - open_time) / (double)seconds_per_bar);
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   if(!g_state_ready)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Use QM_LotsForRisk + QM_Stop* helpers; do
// NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready || Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(Strategy_LongSignal())
     {
      side = QM_BUY;
      reason = "PRING_KST_DEV_LONG";
     }
   else if(Strategy_ShortSignal())
     {
      side = QM_SELL;
      reason = "PRING_KST_DEV_SHORT";
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, g_atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_GetOurPosition(ticket, position_type, open_time))
      return false;

   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_h4_bars)
      return true;

   if(position_type == POSITION_TYPE_BUY)
      return (g_dev_prev >= 0.0 && g_dev_cur < 0.0);
   if(position_type == POSITION_TYPE_SELL)
      return (g_dev_prev <= 0.0 && g_dev_cur > 0.0);

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - intentionally updates H4 strategy state before exit/entry.
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

   if(!QM_IsNewBar(_Symbol, Strategy_Timeframe()))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_RefreshState();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
