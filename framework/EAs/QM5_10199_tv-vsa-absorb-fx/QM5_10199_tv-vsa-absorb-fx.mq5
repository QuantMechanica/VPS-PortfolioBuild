#property strict
#property version   "5.0"
#property description "QM5_10199 TradingView VSA Absorption Proxy FX"

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
input int    qm_ea_id                   = 10199;
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
input int    strategy_volume_sma_period = 20;
input int    strategy_atr_period        = 14;
input double strategy_volume_multiplier = 1.5;
input double strategy_range_multiplier  = 1.0;
input double strategy_stop_percent      = 1.0;
input double strategy_atr_stop_cap_mult = 3.0;
input double strategy_reward_r          = 3.5;
input double strategy_max_spread_stop   = 0.15;
input int    strategy_fx_session_start  = 13;
input int    strategy_fx_session_end    = 17;
input int    strategy_index_session_start = 15;
input int    strategy_index_session_end   = 22;

bool Strategy_IsFxSymbol()
  {
   return (StringFind(_Symbol, "EURUSD") >= 0 ||
           StringFind(_Symbol, "GBPUSD") >= 0);
  }

bool Strategy_IsIndexOrGoldSymbol()
  {
   return (StringFind(_Symbol, "XAUUSD") >= 0 ||
           StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "NDX") >= 0);
  }

bool Strategy_HourInWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

double Strategy_DeltaProxy(const MqlRates &bar)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(bar.open <= 0.0 || bar.close <= 0.0 || bar.high <= bar.low ||
      bar.tick_volume <= 0 || tick_size <= 0.0)
      return 0.0;

   const double range = MathMax(bar.high - bar.low, tick_size);
   return (double)bar.tick_volume * (bar.close - bar.open) / range;
  }

double Strategy_PreviousVolumeSma(const MqlRates &rates[])
  {
   if(strategy_volume_sma_period <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 1; i <= strategy_volume_sma_period; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return 0.0;
      sum += (double)rates[i].tick_volume;
     }

   return sum / (double)strategy_volume_sma_period;
  }

double Strategy_CappedStop(const QM_OrderType side,
                           const double entry,
                           const double source_stop,
                           const double atr)
  {
   if(entry <= 0.0 || source_stop <= 0.0 ||
      atr <= 0.0 || strategy_atr_stop_cap_mult <= 0.0)
      return 0.0;

   const double cap_distance = strategy_atr_stop_cap_mult * atr;
   double stop = source_stop;
   if(MathAbs(entry - source_stop) > cap_distance)
      stop = QM_OrderTypeIsBuy(side) ? (entry - cap_distance) : (entry + cap_distance);

   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(Strategy_IsFxSymbol())
      return !Strategy_HourInWindow(dt.hour, strategy_fx_session_start, strategy_fx_session_end);

   if(Strategy_IsIndexOrGoldSymbol())
      return !Strategy_HourInWindow(dt.hour, strategy_index_session_start, strategy_index_session_end);

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

   if(strategy_volume_sma_period < 1 || strategy_atr_period < 1 ||
      strategy_volume_multiplier <= 0.0 || strategy_range_multiplier <= 0.0 ||
      strategy_stop_percent <= 0.0 || strategy_atr_stop_cap_mult <= 0.0 ||
      strategy_reward_r <= 0.0 || strategy_max_spread_stop <= 0.0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const int bars_needed = strategy_volume_sma_period + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates) != bars_needed) // perf-allowed: bounded OHLCV proxy read inside framework closed-bar entry hook
      return false;

   const MqlRates signal_bar = rates[0];
   const MqlRates prior_bar = rates[1];
   if(signal_bar.open <= 0.0 || signal_bar.close <= 0.0 ||
      signal_bar.high <= signal_bar.low || signal_bar.tick_volume <= 0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double volume_sma = Strategy_PreviousVolumeSma(rates);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || volume_sma <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double bar_range = signal_bar.high - signal_bar.low;
   if((double)signal_bar.tick_volume <= volume_sma * strategy_volume_multiplier)
      return false;
   if(bar_range <= atr * strategy_range_multiplier)
      return false;

   const double delta_signal = Strategy_DeltaProxy(signal_bar);
   const double delta_prior = Strategy_DeltaProxy(prior_bar);
   if(delta_signal == 0.0 || delta_prior == 0.0)
      return false;

   const double stop_pct = strategy_stop_percent / 100.0;
   const double spread_distance = ask - bid;

   if(signal_bar.close > signal_bar.open && delta_signal > 0.0 && delta_prior < 0.0)
     {
      const double entry = ask;
      const double source_stop = signal_bar.low * (1.0 - stop_pct);
      const double stop = Strategy_CappedStop(QM_BUY, entry, source_stop, atr);
      const double risk_distance = entry - stop;
      if(stop <= 0.0 || risk_distance <= point ||
         spread_distance > risk_distance * strategy_max_spread_stop)
         return false;

      req.type = QM_BUY;
      req.price = entry;
      req.sl = stop;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry + risk_distance * strategy_reward_r);
      req.reason = "TV_VSA_ABSORB_LONG";
      return true;
     }

   if(signal_bar.close < signal_bar.open && delta_signal < 0.0 && delta_prior > 0.0)
     {
      const double entry = bid;
      const double source_stop = signal_bar.high * (1.0 + stop_pct);
      const double stop = Strategy_CappedStop(QM_SELL, entry, source_stop, atr);
      const double risk_distance = stop - entry;
      if(stop <= 0.0 || risk_distance <= point ||
         spread_distance > risk_distance * strategy_max_spread_stop)
         return false;

      req.type = QM_SELL;
      req.price = entry;
      req.sl = stop;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry - risk_distance * strategy_reward_r);
      req.reason = "TV_VSA_ABSORB_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial close, or break-even.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Source exit is fixed risk/reward; framework handles SL/TP and Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10199_tv-vsa-absorb-fx\"}");
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
