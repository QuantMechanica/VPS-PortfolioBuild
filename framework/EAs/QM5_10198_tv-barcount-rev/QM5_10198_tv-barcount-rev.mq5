#property strict
#property version   "5.0"
#property description "QM5_10198 TradingView Bar Counter Reversal"

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
input int    qm_ea_id                   = 10198;
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
input int    strategy_consecutive_bars       = 4;
input bool   strategy_volume_confirm_enabled = true;
input int    strategy_bb_period              = 20;
input double strategy_bb_deviation           = 2.0;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_target_r               = 2.0;
input int    strategy_time_stop_bars         = 12;
input int    strategy_rollover_skip_minutes  = 15;

int Strategy_ExpectedSlotForSymbol(const string symbol)
  {
   if(symbol == "EURUSD.DWX")
      return 0;
   if(symbol == "GBPUSD.DWX")
      return 1;
   if(symbol == "XAUUSD.DWX")
      return 2;
   if(symbol == "GDAXI.DWX")
      return 3;
   if(symbol == "NDX.DWX")
      return 4;
   return -1;
  }

bool Strategy_SelectOurPosition(ulong &ticket,
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
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   return Strategy_SelectOurPosition(ticket, position_type, open_time);
  }

bool Strategy_ConsecutiveFallingBars(const int bars)
  {
   if(bars <= 0)
      return false;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double open_price = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar candle body sequence, called only by framework-gated EntrySignal.
      const double close_price = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar candle body sequence, called only by framework-gated EntrySignal.
      if(open_price <= 0.0 || close_price <= 0.0 || close_price >= open_price)
         return false;

      if(strategy_volume_confirm_enabled && shift < bars)
        {
         const long newer_volume = iVolume(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded volume confirmation over N setup bars.
         const long older_volume = iVolume(_Symbol, PERIOD_H1, shift + 1); // perf-allowed: bounded volume confirmation over N setup bars.
         if(newer_volume <= older_volume)
            return false;
        }
     }

   return true;
  }

bool Strategy_ConsecutiveRisingBars(const int bars)
  {
   if(bars <= 0)
      return false;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double open_price = iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar candle body sequence, called only by framework-gated EntrySignal.
      const double close_price = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar candle body sequence, called only by framework-gated EntrySignal.
      if(open_price <= 0.0 || close_price <= 0.0 || close_price <= open_price)
         return false;

      if(strategy_volume_confirm_enabled && shift < bars)
        {
         const long newer_volume = iVolume(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded volume confirmation over N setup bars.
         const long older_volume = iVolume(_Symbol, PERIOD_H1, shift + 1); // perf-allowed: bounded volume confirmation over N setup bars.
         if(newer_volume <= older_volume)
            return false;
        }
     }

   return true;
  }

double Strategy_SetupLow(const int bars)
  {
   double lowest = DBL_MAX;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double value = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded setup-low scan over N closed bars.
      if(value > 0.0 && value < lowest)
         lowest = value;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double Strategy_SetupHigh(const int bars)
  {
   double highest = -DBL_MAX;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double value = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded setup-high scan over N closed bars.
      if(value > highest)
         highest = value;
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   const int expected_slot = Strategy_ExpectedSlotForSymbol(_Symbol);
   if(expected_slot < 0 || qm_magic_slot_offset != expected_slot)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == 0 && dt.min < strategy_rollover_skip_minutes)
      return true;
   if(dt.hour == 23 && dt.min >= 60 - strategy_rollover_skip_minutes)
      return true;

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

   if(strategy_consecutive_bars < 1 || strategy_bb_period < 2 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_target_r <= 0.0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 ||
      atr <= 0.0 || lower <= 0.0 || upper <= 0.0)
      return false;

   const double low_1 = iLow(_Symbol, PERIOD_H1, 1); // perf-allowed: closed setup bar band-touch check, EntrySignal is framework-gated by QM_IsNewBar().
   const double high_1 = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: closed setup bar band-touch check, EntrySignal is framework-gated by QM_IsNewBar().
   if(low_1 <= 0.0 || high_1 <= 0.0)
      return false;

   if(Strategy_ConsecutiveFallingBars(strategy_consecutive_bars) && low_1 <= lower)
     {
      const double setup_low = Strategy_SetupLow(strategy_consecutive_bars);
      if(setup_low <= 0.0)
         return false;

      const double atr_stop = ask - (strategy_atr_sl_mult * atr);
      const double stop_price = MathMin(atr_stop, setup_low);
      const double risk_distance = ask - stop_price;
      if(risk_distance <= point)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, stop_price);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + (risk_distance * strategy_target_r));
      req.reason = "TV_BARCOUNT_REV_LONG";
      return true;
     }

   if(Strategy_ConsecutiveRisingBars(strategy_consecutive_bars) && high_1 >= upper)
     {
      const double setup_high = Strategy_SetupHigh(strategy_consecutive_bars);
      if(setup_high <= 0.0)
         return false;

      const double atr_stop = bid + (strategy_atr_sl_mult * atr);
      const double stop_price = MathMax(atr_stop, setup_high);
      const double risk_distance = stop_price - bid;
      if(risk_distance <= point)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, stop_price);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - (risk_distance * strategy_target_r));
      req.reason = "TV_BARCOUNT_REV_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even shift, partial close, or averaging.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_time))
      return false;

   const double mid = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   if(mid > 0.0)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(position_type == POSITION_TYPE_BUY && bid >= mid)
         return true;
      if(position_type == POSITION_TYPE_SELL && ask <= mid)
         return true;
     }

   const int seconds_per_bar = PeriodSeconds(PERIOD_H1);
   if(open_time > 0 && seconds_per_bar > 0 &&
      TimeCurrent() - open_time >= strategy_time_stop_bars * seconds_per_bar)
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
