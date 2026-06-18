#property strict
#property version   "5.0"
#property description "QM5_12399 New-high breakout with ATR stop"

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
input int    qm_ea_id                   = 12399;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_new_high_lookback = 520;  // D1 closes used for the new-high threshold.
input int    strategy_min_warmup_bars   = 520;  // Minimum D1 history before entries are allowed.
input int    strategy_atr_period        = 10;   // ATR stop lookback from the card.
input double strategy_atr_mult          = 1.0;  // Close-minus-ATR trailing stop multiplier.
input int    strategy_spread_median_days = 60;  // D1 spread window for the 2x median cap.
input double strategy_spread_cap_mult   = 2.0;  // Block only if current spread is above this median multiple.

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_SelectOurLongPosition(ulong &ticket, double &current_sl)
  {
   ticket = 0;
   current_sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = pos_ticket;
      current_sl = PositionGetDouble(POSITION_SL);
      return true;
     }

   return false;
  }

double Strategy_D1Close(const int shift)
  {
   double close_values[];
   ArraySetAsSeries(close_values, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, shift, 1, close_values); // perf-allowed: one closed D1 close read inside skeleton QM_IsNewBar gate.
   if(copied != 1)
      return 0.0;
   return close_values[0];
  }

bool Strategy_HasWarmup()
  {
   const int warmup = MathMax(strategy_min_warmup_bars, 1);
   double probe[];
   ArraySetAsSeries(probe, true);
   return (CopyClose(_Symbol, PERIOD_D1, warmup, 1, probe) == 1); // perf-allowed: one D1 warmup probe inside skeleton QM_IsNewBar gate.
  }

double Strategy_HighestPriorClose()
  {
   int lookback = strategy_new_high_lookback;
   if(lookback <= 0)
      lookback = 520;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 2, lookback, closes); // perf-allowed: bounded D1 close window for structural new-high rule.
   if(copied < lookback)
      return 0.0;

   double highest = 0.0;
   for(int i = 0; i < copied; ++i)
      if(closes[i] > highest)
         highest = closes[i];

   return highest;
  }

double Strategy_MedianSpreadPoints()
  {
   const int days = MathMax(strategy_spread_median_days, 1);
   int spreads[];
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, days, spreads); // perf-allowed: bounded D1 spread window for card spread cap.
   if(copied <= 0)
      return 0.0;

   double positive[];
   ArrayResize(positive, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(spreads[i] > 0)
        {
         positive[n] = (double)spreads[i];
         n++;
        }
     }
   if(n <= 0)
      return 0.0;

   ArrayResize(positive, n);
   ArraySort(positive);
   if((n % 2) == 1)
      return positive[n / 2];

   return (positive[(n / 2) - 1] + positive[n / 2]) * 0.5;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_cap_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double median_spread = Strategy_MedianSpreadPoints();
   if(median_spread <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_cap_mult);
  }

double Strategy_ClosedBarAtrStop()
  {
   const double close_last = Strategy_D1Close(1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_last <= 0.0 || atr <= 0.0 || strategy_atr_mult <= 0.0)
      return 0.0;

   return QM_StopRulesNormalizePrice(_Symbol, close_last - atr * strategy_atr_mult);
  }

void Strategy_AdvanceClosedBarTrail()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   if(!Strategy_SelectOurLongPosition(ticket, current_sl))
      return;

   const double target_sl = Strategy_ClosedBarAtrStop();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(target_sl <= 0.0 || point <= 0.0 || bid <= 0.0)
      return;

   if(bid <= target_sl)
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return;
     }

   const bool improves = (current_sl <= 0.0 || target_sl > current_sl + point * 0.5);
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "d1_close_minus_atr_trail");
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no time/session gate; news is handled by the framework hook.
   // The 60D median spread rule is evaluated in Strategy_EntrySignal on the
   // closed D1 bar so this per-tick hook stays O(1).
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   Strategy_AdvanceClosedBarTrail();

   ulong existing_ticket = 0;
   double existing_sl = 0.0;
   if(Strategy_SelectOurLongPosition(existing_ticket, existing_sl))
      return false;

   if(strategy_atr_period <= 0 || strategy_atr_mult <= 0.0)
      return false;
   if(!Strategy_HasWarmup())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double close_last = Strategy_D1Close(1);
   const double highest_prior = Strategy_HighestPriorClose();
   if(atr <= 0.0 || close_last <= 0.0 || highest_prior <= 0.0)
      return false;
   if(close_last < highest_prior)
      return false;

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr, strategy_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "D1_NEW_HIGH_ATR_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Closed-bar ATR trailing is advanced in Strategy_EntrySignal after the
   // framework's single QM_IsNewBar() gate, avoiding a second bar-gate consume.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Broker SL plus closed-bar trail/fallback handles the card exit.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework news axes; default inputs leave them off.
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
