#property strict
#property version   "5.0"
#property description "QM5_10259 TradingView Stoch RSI MACD Confluence"

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
input int    qm_ea_id                   = 10259;
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
input int    strategy_stoch_k_period    = 14;
input int    strategy_stoch_d_period    = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_oversold    = 20.0;
input double strategy_stoch_overbought  = 80.0;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_midline       = 50.0;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_swing_left_bars   = 3;
input int    strategy_swing_right_bars  = 3;
input int    strategy_swing_search_bars = 80;
input int    strategy_atr_period        = 14;
input double strategy_min_stop_atr      = 0.5;
input double strategy_max_stop_atr      = 3.0;
input double strategy_take_profit_rr    = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool LoadSwingRates(MqlRates &rates[])
  {
   const int left_bars = MathMax(1, strategy_swing_left_bars);
   const int right_bars = MathMax(1, strategy_swing_right_bars);
   const int search_bars = MathMax(left_bars + right_bars + 2,
                                   strategy_swing_search_bars);
   const int bars_needed = search_bars + left_bars + right_bars + 2;
   ArraySetAsSeries(rates, true);
   return (CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates) == bars_needed);
  }

bool IsSwingLow(const MqlRates &rates[], const int shift,
                const int left_bars, const int right_bars)
  {
   const double pivot = rates[shift].low;
   if(pivot <= 0.0)
      return false;

   for(int i = 1; i <= left_bars; ++i)
      if(rates[shift + i].low <= 0.0 || rates[shift + i].low <= pivot)
         return false;
   for(int i = 1; i <= right_bars; ++i)
      if(rates[shift - i].low <= 0.0 || rates[shift - i].low < pivot)
         return false;
   return true;
  }

bool IsSwingHigh(const MqlRates &rates[], const int shift,
                 const int left_bars, const int right_bars)
  {
   const double pivot = rates[shift].high;
   if(pivot <= 0.0)
      return false;

   for(int i = 1; i <= left_bars; ++i)
      if(rates[shift + i].high <= 0.0 || rates[shift + i].high >= pivot)
         return false;
   for(int i = 1; i <= right_bars; ++i)
      if(rates[shift - i].high <= 0.0 || rates[shift - i].high > pivot)
         return false;
   return true;
  }

double RecentSwingLow(const MqlRates &rates[])
  {
   const int left_bars = MathMax(1, strategy_swing_left_bars);
   const int right_bars = MathMax(1, strategy_swing_right_bars);
   const int max_shift = MathMax(left_bars + right_bars + 2, strategy_swing_search_bars);

   for(int shift = right_bars + 1; shift <= max_shift; ++shift)
     {
      if(IsSwingLow(rates, shift, left_bars, right_bars))
         return rates[shift].low;
     }
   return 0.0;
  }

double RecentSwingHigh(const MqlRates &rates[])
  {
   const int left_bars = MathMax(1, strategy_swing_left_bars);
   const int right_bars = MathMax(1, strategy_swing_right_bars);
   const int max_shift = MathMax(left_bars + right_bars + 2, strategy_swing_search_bars);

   for(int shift = right_bars + 1; shift <= max_shift; ++shift)
     {
      if(IsSwingHigh(rates, shift, left_bars, right_bars))
         return rates[shift].high;
     }
   return 0.0;
  }

bool StopDistanceAllowed(const double entry_price, const double stop_price)
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(entry_price <= 0.0 || stop_price <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   return (stop_distance >= strategy_min_stop_atr * atr &&
           stop_distance <= strategy_max_stop_atr * atr);
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

   const double k = QM_Stoch_K(_Symbol, _Period,
                               strategy_stoch_k_period,
                               strategy_stoch_d_period,
                               strategy_stoch_slowing,
                               1);
   const double d = QM_Stoch_D(_Symbol, _Period,
                               strategy_stoch_k_period,
                               strategy_stoch_d_period,
                               strategy_stoch_slowing,
                               1);
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   const double macd_signal = QM_MACD_Signal(_Symbol, _Period,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal,
                                             1);
   if(k == EMPTY_VALUE || d == EMPTY_VALUE || rsi == EMPTY_VALUE ||
      macd_main == EMPTY_VALUE || macd_signal == EMPTY_VALUE)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   MqlRates rates[];
   if(!LoadSwingRates(rates))
      return false;

   if(k <= strategy_stoch_oversold &&
      d <= strategy_stoch_oversold &&
      rsi > strategy_rsi_midline &&
      macd_main > macd_signal)
     {
      const double sl = RecentSwingLow(rates);
      if(sl <= 0.0 || sl >= ask || !StopDistanceAllowed(ask, sl))
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_take_profit_rr), _Digits);
      req.reason = "STOCH_RSI_MACD_LONG";
      return (req.tp > ask);
     }

   if(k >= strategy_stoch_overbought &&
      d >= strategy_stoch_overbought &&
      rsi < strategy_rsi_midline &&
      macd_main < macd_signal)
     {
      const double sl = RecentSwingHigh(rates);
      if(sl <= 0.0 || sl <= bid || !StopDistanceAllowed(bid, sl))
         return false;

      req.type = QM_SELL;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_take_profit_rr), _Digits);
      req.reason = "STOCH_RSI_MACD_SHORT";
      return (req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Opposite-signal exit is P3 optional, so P1 exits via SL, TP, and framework Friday close.
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
