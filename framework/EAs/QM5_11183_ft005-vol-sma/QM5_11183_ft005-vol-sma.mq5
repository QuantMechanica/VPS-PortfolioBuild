#property strict
#property version   "5.0"
#property description "QM5_11183 Freqtrade Strategy005 Volume Spike SMA Reversal"

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
input int    qm_ea_id                   = 11183;
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
input int    buy_volumeAVG              = 150;
input double buy_volume_spike_mult      = 4.0;
input double buy_rsi                    = 26.0;
input double buy_fastd                  = 1.0;
input double buy_fishRsiNorma           = 5.0;
input int    strategy_sma_period        = 40;
input int    strategy_rsi_period        = 14;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slow        = 3;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_di_period         = 14;
input double sell_rsi                   = 74.0;
input double sell_minusDI               = 4.0;
input double strategy_stop_loss_pct     = 10.0;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles global
   // time/news/Friday gates; this card adds M5-only and optional spread guard.
   if(_Period != PERIOD_M5)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points <= 0 || spread_points > strategy_max_spread_points)
         return true;
     }

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

   if(buy_volumeAVG < 1 || buy_volume_spike_mult <= 0.0 ||
      strategy_sma_period < 1 || strategy_rsi_period < 1 ||
      strategy_stoch_k < 1 || strategy_stoch_d < 1 || strategy_stoch_slow < 1 ||
      strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 || strategy_di_period < 1 ||
      strategy_stop_loss_pct <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int required_bars = MathMax(buy_volumeAVG, 2);
   MqlRates rates[];
   ArrayResize(rates, required_bars);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, required_bars, rates); // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied != required_bars)
      return false;

   const int newest = required_bars - 1;
   const double close_last = rates[newest].close;
   const long volume_last = rates[newest].tick_volume;
   if(close_last <= 0.00000200 || volume_last <= 0)
      return false;

   double volume_sum = 0.0;
   for(int i = required_bars - buy_volumeAVG; i < required_bars; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;
      volume_sum += (double)rates[i].tick_volume;
     }

   const double volume_avg = volume_sum / (double)buy_volumeAVG;
   if(volume_avg <= 0.0 || (double)volume_last <= volume_avg * buy_volume_spike_mult)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_period, 1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1, PRICE_CLOSE);
   const double fastk = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double fastd = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   if(sma <= 0.0 || rsi <= 0.0)
      return false;

   const double clipped_rsi = MathMax(0.0, MathMin(100.0, rsi));
   const double fisher_scaled = 0.1 * (clipped_rsi - 50.0);
   const double fisher_exp = MathExp(2.0 * fisher_scaled);
   const double fisher = (fisher_exp - 1.0) / (fisher_exp + 1.0);
   const double fisher_norm = 50.0 * (fisher + 1.0);

   if(close_last >= sma)
      return false;
   if(fastd <= fastk)
      return false;
   if(rsi <= buy_rsi)
      return false;
   if(fastd <= buy_fastd)
      return false;
   if(fisher_norm >= buy_fishRsiNorma)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = NormalizeDouble(entry * (1.0 - strategy_stop_loss_pct / 100.0), _Digits);
   req.tp = NormalizeDouble(entry * 1.05, _Digits);
   if(req.sl <= 0.0 || req.tp <= 0.0 || req.sl >= entry || req.tp <= entry)
      return false;

   req.reason = "FT005_VOLUME_SMA_REVERSAL_LONG";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: source minimal ROI ladder; no trailing, pyramiding,
   // grid, martingale, or adaptive parameter logic.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(open_price <= 0.0 || bid <= 0.0)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const long hold_minutes = (long)(now - open_time) / 60;
      double roi_threshold_pct = 1.0;
      if(hold_minutes < 20)
         roi_threshold_pct = 5.0;
      else if(hold_minutes < 40)
         roi_threshold_pct = 4.0;
      else if(hold_minutes < 80)
         roi_threshold_pct = 3.0;
      else if(hold_minutes < 1440)
         roi_threshold_pct = 2.0;

      const double profit_pct = 100.0 * (bid - open_price) / open_price;
      if(profit_pct >= roi_threshold_pct)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         has_long = true;
         break;
        }
     }
   if(!has_long)
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2, PRICE_CLOSE);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1,
                                         PRICE_CLOSE);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_di_period, 1);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   return (rsi_prev <= sell_rsi &&
           rsi_now > sell_rsi &&
           macd_main < 0.0 &&
           minus_di > sell_minusDI);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: P8 can call this section; the central two-axis news
   // filter remains authoritative for this card's high-impact blackout.
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
