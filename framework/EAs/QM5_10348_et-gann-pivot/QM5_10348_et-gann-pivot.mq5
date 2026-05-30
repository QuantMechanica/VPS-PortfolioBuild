#property strict
#property version   "5.0"
#property description "QM5_10348 Elite Trader Gann Pivot Signal System"

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
input int    qm_ea_id                   = 10348;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M15;
input int             strategy_pivot_lookback     = 4;
input int             strategy_signal_expiry_bars = 50;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 2.0;
input double          strategy_rr_target          = 2.0;
input bool            strategy_ma_filter_enabled  = true;
input int             strategy_ma_period          = 50;
input int             strategy_max_daily_trades   = 2;
input int             strategy_session_start_hhmm = 700;
input int             strategy_session_end_hhmm   = 2000;
input int             strategy_index_exit_hhmm    = 1545;
input bool            strategy_index_time_exit    = true;
input bool            strategy_trail_enabled      = true;
input double          strategy_trail_atr_mult     = 1.5;
input int             strategy_spread_median_bars = 50;

double g_latest_pivot_high = 0.0;
double g_latest_pivot_low = 0.0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_IsIndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "GER40") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0);
  }

bool Strategy_DateKey(const datetime t, int &key)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   key = dt.year * 10000 + dt.mon * 100 + dt.day;
   return true;
  }

bool Strategy_IsPivotHigh(const int shift, const int lookback)
  {
   const double candidate = iHigh(_Symbol, strategy_timeframe, shift);
   if(candidate <= 0.0)
      return false;
   for(int offset = 1; offset <= lookback; ++offset)
     {
      if(iHigh(_Symbol, strategy_timeframe, shift - offset) >= candidate)
         return false;
      if(iHigh(_Symbol, strategy_timeframe, shift + offset) >= candidate)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(const int shift, const int lookback)
  {
   const double candidate = iLow(_Symbol, strategy_timeframe, shift);
   if(candidate <= 0.0)
      return false;
   for(int offset = 1; offset <= lookback; ++offset)
     {
      if(iLow(_Symbol, strategy_timeframe, shift - offset) <= candidate)
         return false;
      if(iLow(_Symbol, strategy_timeframe, shift + offset) <= candidate)
         return false;
     }
   return true;
  }

bool Strategy_FindLatestPivots(double &pivot_high, double &pivot_low)
  {
   pivot_high = 0.0;
   pivot_low = 0.0;
   const int lookback = strategy_pivot_lookback;
   if(lookback < 1 || strategy_signal_expiry_bars < 1)
      return false;

   const int bars_needed = lookback * 2 + strategy_signal_expiry_bars + 5;
   if(iBars(_Symbol, strategy_timeframe) < bars_needed)
      return false;

   const int first_confirmed_shift = lookback + 1;
   const int last_shift = first_confirmed_shift + strategy_signal_expiry_bars;
   for(int shift = first_confirmed_shift; shift <= last_shift; ++shift)
     {
      if(pivot_high <= 0.0 && Strategy_IsPivotHigh(shift, lookback))
         pivot_high = iHigh(_Symbol, strategy_timeframe, shift);
      if(pivot_low <= 0.0 && Strategy_IsPivotLow(shift, lookback))
         pivot_low = iLow(_Symbol, strategy_timeframe, shift);
      if(pivot_high > 0.0 && pivot_low > 0.0)
         return true;
     }
   return (pivot_high > 0.0 || pivot_low > 0.0);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_spread_median_bars <= 1)
      return true;

   int spreads[];
   const int copied = CopySpread(_Symbol, strategy_timeframe, 1, strategy_spread_median_bars, spreads);
   if(copied <= 0)
      return true;

   ArraySort(spreads);
   const int median_spread = spreads[copied / 2];
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (median_spread <= 0 || current_spread <= (int)MathCeil(2.5 * median_spread));
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
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
   const int now_hhmm = Strategy_Hhmm(TimeCurrent());
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return (now_hhmm < strategy_session_start_hhmm || now_hhmm > strategy_session_end_hhmm);
   return (now_hhmm > strategy_session_end_hhmm && now_hhmm < strategy_session_start_hhmm);
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

   static int  trade_day_key = 0;
   static int  trades_today = 0;
   static bool long_taken_today = false;
   static bool short_taken_today = false;

   int today_key = 0;
   Strategy_DateKey(TimeCurrent(), today_key);
   if(today_key != trade_day_key)
     {
      trade_day_key = today_key;
      trades_today = 0;
      long_taken_today = false;
      short_taken_today = false;
     }

   if(trades_today >= strategy_max_daily_trades)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   if(!Strategy_FindLatestPivots(pivot_high, pivot_low))
      return false;
   g_latest_pivot_high = pivot_high;
   g_latest_pivot_low = pivot_low;

   const double close1 = iClose(_Symbol, strategy_timeframe, 1);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(close1 <= 0.0 || tick_size <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, strategy_timeframe, strategy_ma_period, 1);
   const bool ma_long_ok = (!strategy_ma_filter_enabled || (sma > 0.0 && close1 > sma));
   const bool ma_short_ok = (!strategy_ma_filter_enabled || (sma > 0.0 && close1 < sma));

   if(pivot_high > 0.0 && close1 > pivot_high + tick_size && ma_long_ok && !long_taken_today)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_rr_target);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "QM5_10348_GANN_PIVOT_LONG";
      trades_today++;
      long_taken_today = true;
      return true;
     }

   if(pivot_low > 0.0 && close1 < pivot_low - tick_size && ma_short_ok && !short_taken_today)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_rr_target);
      if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "QM5_10348_GANN_PIVOT_SHORT";
      trades_today++;
      short_taken_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trail_enabled)
      return;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const double risk = MathAbs(open_price - sl);
      const double market = (ptype == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(risk <= 0.0 || market <= 0.0)
         continue;
      if(ptype == POSITION_TYPE_BUY && market >= open_price + risk)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
      if(ptype == POSITION_TYPE_SELL && market <= open_price - risk)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(Strategy_IsIndexSymbol() && strategy_index_time_exit)
     {
      if(Strategy_Hhmm(TimeCurrent()) >= strategy_index_exit_hhmm)
         return true;
     }

   if(g_latest_pivot_high <= 0.0 && g_latest_pivot_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, strategy_timeframe, 1);
   if(close1 <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_latest_pivot_low > 0.0 && close1 < g_latest_pivot_low)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_latest_pivot_high > 0.0 && close1 > g_latest_pivot_high)
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
