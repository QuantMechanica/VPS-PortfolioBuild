#property strict
#property version   "5.0"
#property description "QM5_10721 TradingView Wyckoff Range SMA Cross"

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
input int    qm_ea_id                   = 10721;
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
input int    strategy_cross_over_length = 20;
input int    strategy_range_ma_length   = 20;
input int    strategy_atr_period        = 14;
input double strategy_stop_pct_index    = 1.0;
input double strategy_stop_pct_fx       = 0.5;
input double strategy_min_stop_atr      = 0.50;
input double strategy_max_stop_atr      = 4.00;

bool g_signal_cache_ready = false;
bool g_close_cross_up = false;
bool g_close_cross_down = false;
bool g_low_cross_up = false;
bool g_high_cross_down = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

void Strategy_FillDefaultRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadSignalBars(MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, rates); // perf-allowed: two closed bars only for OHLC cross tests.
   return (copied == 2);
  }

double Strategy_StopPct()
  {
   if(StringFind(_Symbol, "EUR") >= 0 || StringFind(_Symbol, "GBP") >= 0 ||
      StringFind(_Symbol, "JPY") >= 0 || StringFind(_Symbol, "CHF") >= 0 ||
      StringFind(_Symbol, "AUD") >= 0 || StringFind(_Symbol, "NZD") >= 0 ||
      StringFind(_Symbol, "CAD") >= 0)
      return strategy_stop_pct_fx;
   return strategy_stop_pct_index;
  }

bool Strategy_Crosses(MqlRates &rates[],
                      bool &close_cross_up,
                      bool &close_cross_down,
                      bool &low_cross_up,
                      bool &high_cross_down)
  {
   close_cross_up = false;
   close_cross_down = false;
   low_cross_up = false;
   high_cross_down = false;

   if(strategy_cross_over_length < 2 || strategy_range_ma_length < 2)
      return false;

   const double close_ma_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_cross_over_length, 1, PRICE_CLOSE);
   const double close_ma_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_cross_over_length, 2, PRICE_CLOSE);
   const double low_ma_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_range_ma_length, 1, PRICE_LOW);
   const double low_ma_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_range_ma_length, 2, PRICE_LOW);
   const double high_ma_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_range_ma_length, 1, PRICE_HIGH);
   const double high_ma_2 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_range_ma_length, 2, PRICE_HIGH);
   if(close_ma_1 <= 0.0 || close_ma_2 <= 0.0 ||
      low_ma_1 <= 0.0 || low_ma_2 <= 0.0 ||
      high_ma_1 <= 0.0 || high_ma_2 <= 0.0)
      return false;

   close_cross_up = (rates[0].close > close_ma_1 && rates[1].close <= close_ma_2);
   close_cross_down = (rates[0].close < close_ma_1 && rates[1].close >= close_ma_2);
   low_cross_up = (rates[0].low > low_ma_1 && rates[1].low <= low_ma_2);
   high_cross_down = (rates[0].high < high_ma_1 && rates[1].high >= high_ma_2);
   return true;
  }

bool Strategy_StopAllowed(const double stop_distance, const double atr)
  {
   if(stop_distance <= 0.0 || atr <= 0.0)
      return false;
   return (stop_distance >= strategy_min_stop_atr * atr &&
           stop_distance <= strategy_max_stop_atr * atr);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_FillDefaultRequest(req);
   g_signal_cache_ready = false;

   MqlRates rates[];
   if(!Strategy_LoadSignalBars(rates))
      return false;

   bool close_cross_up = false;
   bool close_cross_down = false;
   bool low_cross_up = false;
   bool high_cross_down = false;
   if(!Strategy_Crosses(rates, close_cross_up, close_cross_down, low_cross_up, high_cross_down))
      return false;

   g_signal_cache_ready = true;
   g_close_cross_up = close_cross_up;
   g_close_cross_down = close_cross_down;
   g_low_cross_up = low_cross_up;
   g_high_cross_down = high_cross_down;

   const double stop_pct = Strategy_StopPct();
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double stop_distance = rates[0].close * stop_pct / 100.0;
   if(!Strategy_StopAllowed(stop_distance, atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(close_cross_up && low_cross_up)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, rates[0].close - stop_distance);
      req.tp = 0.0;
      req.reason = "TV_WYCK_RANGE_LONG";
      return (req.sl > 0.0 && req.sl < ask && (ask - req.sl) / point > 0.0);
     }

   if(close_cross_down && high_cross_down)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, rates[0].close + stop_distance);
      req.tp = 0.0;
      req.reason = "TV_WYCK_RANGE_SHORT";
      return (req.sl > 0.0 && req.sl > bid && (req.sl - bid) / point > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_signal_cache_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
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
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (g_close_cross_down || g_high_cross_down);
   if(position_type == POSITION_TYPE_SELL)
      return (g_close_cross_up || g_low_cross_up);

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
