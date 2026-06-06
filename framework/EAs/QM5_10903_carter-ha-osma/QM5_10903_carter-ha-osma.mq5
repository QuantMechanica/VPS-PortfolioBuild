#property strict
#property version   "5.0"
#property description "QM5_10903 Carter Heiken Ashi OsMA Momentum"

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
input int    qm_ea_id                   = 10903;
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
input int    strategy_sma_period        = 14;
input int    strategy_osma_fast         = 12;
input int    strategy_osma_slow         = 26;
input int    strategy_osma_signal       = 9;
input int    strategy_momentum_period   = 10;
input int    strategy_rsi_period        = 5;
input int    strategy_swing_lookback    = 10;
input int    strategy_stop_buffer_pips  = 2;
input double strategy_take_profit_rr    = 2.0;
input int    strategy_ha_seed_bars      = 32;

double Strategy_PipDistance(const int pips)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || pips <= 0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return (double)pips * point * (double)pip_factor;
  }

double Strategy_Close(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar custom HA/momentum math inside Strategy_EntrySignal.
  }

double Strategy_Open(const int shift)
  {
   return iOpen(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar custom HA math inside Strategy_EntrySignal.
  }

double Strategy_High(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar custom HA math inside Strategy_EntrySignal.
  }

double Strategy_Low(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar custom HA math inside Strategy_EntrySignal.
  }

bool Strategy_HeikenAshi(const int target_shift, double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   if(target_shift < 1 || strategy_ha_seed_bars < 2)
      return false;

   const int start_shift = target_shift + strategy_ha_seed_bars;
   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;

   for(int shift = start_shift; shift >= target_shift; --shift)
     {
      const double open = Strategy_Open(shift);
      const double high = Strategy_High(shift);
      const double low = Strategy_Low(shift);
      const double close = Strategy_Close(shift);
      if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
         return false;

      const double cur_ha_close = (open + high + low + close) / 4.0;
      const double cur_ha_open = (shift == start_shift)
                                 ? ((open + close) / 2.0)
                                 : ((prev_ha_open + prev_ha_close) / 2.0);

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;
     }

   ha_open = prev_ha_open;
   ha_close = prev_ha_close;
   return true;
  }

double Strategy_OsMA(const int shift)
  {
   return QM_MACD_Main(_Symbol, _Period, strategy_osma_fast, strategy_osma_slow,
                       strategy_osma_signal, shift)
        - QM_MACD_Signal(_Symbol, _Period, strategy_osma_fast, strategy_osma_slow,
                         strategy_osma_signal, shift);
  }

double Strategy_Momentum100(const int shift)
  {
   const double current_close = Strategy_Close(shift);
   const double prior_close = Strategy_Close(shift + strategy_momentum_period);
   if(current_close <= 0.0 || prior_close <= 0.0)
      return 0.0;
   return 100.0 * current_close / prior_close;
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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
   // Card permits only the default V5 spread/session/news filters.
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

   if(strategy_sma_period < 2 || strategy_osma_fast < 1 || strategy_osma_slow <= strategy_osma_fast ||
      strategy_osma_signal < 1 || strategy_momentum_period < 1 || strategy_rsi_period < 1 ||
      strategy_swing_lookback < 2 || strategy_take_profit_rr <= 0.0)
      return false;

   double ha_open_1 = 0.0;
   double ha_close_1 = 0.0;
   double ha_open_2 = 0.0;
   double ha_close_2 = 0.0;
   if(!Strategy_HeikenAshi(1, ha_open_1, ha_close_1) ||
      !Strategy_HeikenAshi(2, ha_open_2, ha_close_2))
      return false;

   const double sma_1 = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_2 = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   const double osma_1 = Strategy_OsMA(1);
   const double osma_2 = Strategy_OsMA(2);
   const double momentum_1 = Strategy_Momentum100(1);
   const double momentum_2 = Strategy_Momentum100(2);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(sma_1 <= 0.0 || sma_2 <= 0.0 || momentum_1 <= 0.0 || momentum_2 <= 0.0 ||
      rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   const bool long_signal = (ha_close_1 > ha_open_1 &&
                             ha_close_2 <= sma_2 && ha_close_1 > sma_1 &&
                             osma_2 <= 0.0 && osma_1 > 0.0 &&
                             momentum_2 <= 100.0 && momentum_1 > 100.0 &&
                             rsi_2 <= 50.0 && rsi_1 > 50.0);

   const bool short_signal = (ha_close_1 < ha_open_1 &&
                              ha_close_2 >= sma_2 && ha_close_1 < sma_1 &&
                              osma_2 >= 0.0 && osma_1 < 0.0 &&
                              momentum_2 >= 100.0 && momentum_1 < 100.0 &&
                              rsi_2 >= 50.0 && rsi_1 < 50.0);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = SymbolInfoDouble(_Symbol, long_signal ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = Strategy_PipDistance(strategy_stop_buffer_pips);
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   sl = long_signal ? (sl - buffer) : (sl + buffer);
   sl = NormalizeDouble(sl, _Digits);
   if((long_signal && sl >= entry) || (short_signal && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "CARTER_HA_OSMA_LONG" : "CARTER_HA_OSMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_FindOurPosition(position_type))
      return false;

   const double osma_1 = Strategy_OsMA(1);
   const double osma_2 = Strategy_OsMA(2);
   if(position_type == POSITION_TYPE_BUY)
      return (osma_2 >= 0.0 && osma_1 < 0.0);
   if(position_type == POSITION_TYPE_SELL)
      return (osma_2 <= 0.0 && osma_1 > 0.0);

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
