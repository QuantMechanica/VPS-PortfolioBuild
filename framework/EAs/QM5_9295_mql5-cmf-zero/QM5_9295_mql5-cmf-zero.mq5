#property strict
#property version   "5.0"
#property description "QM5_9295 MQL5 CMF Zero Crossover"

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
input int    qm_ea_id                   = 9295;
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
input int    strategy_cmf_period        = 20;
input int    strategy_stop_loss_points  = 300;
input int    strategy_take_profit_points = 900;
input int    strategy_spread_cap_points = 1000;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): no card-specific session rule;
   // framework handles news and Friday close. Zero spread is valid on .DWX.
   if(strategy_spread_cap_points <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_spread_cap_points)
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

   if(strategy_cmf_period <= 0 ||
      strategy_stop_loss_points <= 0 ||
      strategy_take_profit_points <= 0)
      return false;

   const int bars_needed = strategy_cmf_period + 1;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, bars_needed, rates); // perf-allowed: bounded closed-bar OHLCV CMF; no QM_CMF helper exists.
   if(copied < bars_needed)
      return false;

   double mfv_previous = 0.0;
   double vol_previous = 0.0;
   double mfv_current = 0.0;
   double vol_current = 0.0;

   const int prev_start = copied - strategy_cmf_period - 1;
   const int curr_start = copied - strategy_cmf_period;
   for(int i = 0; i < strategy_cmf_period; ++i)
     {
      const int prev_idx = prev_start + i;
      const double prev_range = rates[prev_idx].high - rates[prev_idx].low;
      const double prev_volume = (double)rates[prev_idx].tick_volume;
      if(prev_range > 0.0 && prev_volume > 0.0)
        {
         const double prev_mult = ((rates[prev_idx].close - rates[prev_idx].low) -
                                   (rates[prev_idx].high - rates[prev_idx].close)) / prev_range;
         mfv_previous += prev_mult * prev_volume;
         vol_previous += prev_volume;
        }

      const int curr_idx = curr_start + i;
      const double curr_range = rates[curr_idx].high - rates[curr_idx].low;
      const double curr_volume = (double)rates[curr_idx].tick_volume;
      if(curr_range > 0.0 && curr_volume > 0.0)
        {
         const double curr_mult = ((rates[curr_idx].close - rates[curr_idx].low) -
                                   (rates[curr_idx].high - rates[curr_idx].close)) / curr_range;
         mfv_current += curr_mult * curr_volume;
         vol_current += curr_volume;
        }
     }

   if(vol_previous <= 0.0 || vol_current <= 0.0)
      return false;

   const double cmf_previous = mfv_previous / vol_previous;
   const double cmf_current = mfv_current / vol_current;

   QM_OrderType side = QM_BUY;
   if(cmf_previous < 0.0 && cmf_current > 0.0)
      side = QM_BUY;
   else if(cmf_previous > 0.0 && cmf_current < 0.0)
      side = QM_SELL;
   else
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((side == QM_BUY && position_type == POSITION_TYPE_BUY) ||
         (side == QM_SELL && position_type == POSITION_TYPE_SELL))
         return false;

      // Trade Close: opposite CMF zero-cross closes the current side first.
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
      break;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl_distance = (double)strategy_stop_loss_points * point;
   const double tp_distance = (double)strategy_take_profit_points * point;
   double sl = 0.0;
   double tp = 0.0;
   if(side == QM_BUY)
     {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_distance);
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_distance);
      if(sl >= entry || tp <= entry)
         return false;
     }
   else
     {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_distance);
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_distance);
      if(sl <= entry || tp >= entry)
         return false;
     }

   if(QM_LotsForRisk(_Symbol, (double)strategy_stop_loss_points) <= 0.0)
      return false;

   // Trade Entry: CMF(20) closed-bar zero crossover.
   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "CMF_ZERO_LONG" : "CMF_ZERO_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing stop, break-even, partial
   // close, scale-in, or adaptive position management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: fixed SL/TP is broker-managed. Opposite CMF zero-cross is
   // handled on the closed-bar entry gate to avoid per-tick OHLCV scans.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no strategy-specific override; defer to framework P8.
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
