#property strict
#property version   "5.0"
#property description "QM5_10311 High-Frequency Momentum Buffer"
// rework v2 2026-06-16: mom_z normalized by ATR-as-return (atr/close) instead of
// raw price-unit ATR. mom is a dimensionless return; dividing by absolute ATR made
// the +-0.75 z-threshold scale with price level, requiring physically impossible
// returns (hundreds of %) on high-priced symbols (XAUUSD/GDAXI/NDX) -> 0 trades.

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
input int    qm_ea_id                   = 10311;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M1;
input int    strategy_momentum_lookback_bars      = 5;
input int    strategy_target_bars                 = 10;
input int    strategy_atr_period                  = 14;
input double strategy_mom_z_threshold             = 0.75;
input double strategy_spread_buffer_mult          = 2.0;
input double strategy_sl_atr_mult                 = 0.75;
input double strategy_tp_atr_mult                 = 1.0;
input int    strategy_spread_percentile_lookback  = 80;
input double strategy_spread_max_percentile       = 0.80;
input int    strategy_volume_percentile_lookback  = 20;
input double strategy_volume_min_percentile       = 0.20;
input double strategy_opposite_wick_body_mult     = 1.0;
input int    strategy_liquid_start_hour           = 7;
input int    strategy_liquid_end_hour             = 21;
input int    strategy_daily_stop_limit            = 3;

int Strategy_Sign(const double value)
  {
   if(value > 0.0)
      return 1;
   if(value < 0.0)
      return -1;
   return 0;
  }

bool Strategy_SessionAllowsTrade(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(strategy_liquid_start_hour == strategy_liquid_end_hour)
      return true;
   if(strategy_liquid_start_hour < strategy_liquid_end_hour)
      return (dt.hour >= strategy_liquid_start_hour && dt.hour < strategy_liquid_end_hour);
   return (dt.hour >= strategy_liquid_start_hour || dt.hour < strategy_liquid_end_hour);
  }

datetime Strategy_DayStart(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

double Strategy_CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

bool Strategy_SpreadWithinRollingPercentile(const double current_spread_points)
  {
   if(current_spread_points <= 0.0 || strategy_spread_percentile_lookback <= 0)
      return false;

   int usable = 0;
   int less_or_equal = 0;
   for(int i = 1; i <= strategy_spread_percentile_lookback; ++i)
     {
      const long hist_spread = iSpread(_Symbol, strategy_signal_tf, i);
      if(hist_spread <= 0)
         continue;
      ++usable;
      if((double)hist_spread <= current_spread_points)
         ++less_or_equal;
     }
   if(usable <= 0)
      return false;

   const double rank = (double)less_or_equal / (double)usable;
   return (rank <= strategy_spread_max_percentile);
  }

bool Strategy_VolumeAboveRollingPercentile()
  {
   if(strategy_volume_percentile_lookback <= 0)
      return true;

   const long current_volume = iVolume(_Symbol, strategy_signal_tf, 1);
   if(current_volume <= 0)
      return false;

   int usable = 0;
   int less_or_equal = 0;
   for(int i = 2; i <= strategy_volume_percentile_lookback + 1; ++i)
     {
      const long hist_volume = iVolume(_Symbol, strategy_signal_tf, i);
      if(hist_volume <= 0)
         continue;
      ++usable;
      if(hist_volume <= current_volume)
         ++less_or_equal;
     }
   if(usable <= 0)
      return false;

   const double rank = (double)less_or_equal / (double)usable;
   return (rank > strategy_volume_min_percentile);
  }

bool Strategy_HasLargeOppositeWick(const int direction)
  {
   const double open1 = iOpen(_Symbol, strategy_signal_tf, 1);
   const double high1 = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low1 = iLow(_Symbol, strategy_signal_tf, 1);
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return true;

   const double body = MathMax(MathAbs(close1 - open1), SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   const double upper_wick = high1 - MathMax(open1, close1);
   const double lower_wick = MathMin(open1, close1) - low1;
   if(direction > 0)
      return (upper_wick >= strategy_opposite_wick_body_mult * body);
   if(direction < 0)
      return (lower_wick >= strategy_opposite_wick_body_mult * body);
   return true;
  }

double Strategy_MomentumReturn(const int shift)
  {
   const int back_shift = shift + strategy_momentum_lookback_bars;
   const double c_now = iClose(_Symbol, strategy_signal_tf, shift);
   const double c_back = iClose(_Symbol, strategy_signal_tf, back_shift);
   if(c_now <= 0.0 || c_back <= 0.0)
      return 0.0;
   return (c_now / c_back) - 1.0;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
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

int Strategy_StoppedTradesToday()
  {
   const int magic = QM_FrameworkMagic();
   const datetime start_time = Strategy_DayStart(TimeCurrent());
   if(!HistorySelect(start_time, TimeCurrent()))
      return 0;

   int stopped = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) == DEAL_REASON_SL)
         ++stopped;
     }
   return stopped;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_SessionAllowsTrade(TimeCurrent()))
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

   if(strategy_momentum_lookback_bars < 1 || strategy_target_bars < 1)
      return false;
   if(Strategy_StoppedTradesToday() >= strategy_daily_stop_limit)
      return false;

   ulong existing_ticket;
   ENUM_POSITION_TYPE existing_type;
   datetime existing_open_time;
   if(Strategy_SelectOurPosition(existing_ticket, existing_type, existing_open_time))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(atr <= 0.0 || close1 <= 0.0)
      return false;

   const double mom = Strategy_MomentumReturn(1);
   // mom is a dimensionless return; normalize by ATR expressed as a return
   // (atr/close) so the z-threshold is price-level independent across symbols.
   const double atr_ret = atr / close1;
   if(atr_ret <= 0.0)
      return false;
   const double mom_z = mom / atr_ret;
   const int direction = Strategy_Sign(mom_z);
   if(direction == 0)
      return false;

   const double spread_points = Strategy_CurrentSpreadPoints();
   if(!Strategy_SpreadWithinRollingPercentile(spread_points))
      return false;
   if(!Strategy_VolumeAboveRollingPercentile())
      return false;
   if(Strategy_HasLargeOppositeWick(direction))
      return false;

   const double expected_move_points = MathAbs(mom) * close1 / point;
   if(expected_move_points <= strategy_spread_buffer_mult * spread_points)
      return false;

   if(mom_z >= strategy_mom_z_threshold)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask - (strategy_sl_atr_mult * atr);
      req.tp = ask + (strategy_tp_atr_mult * atr);
      req.reason = "HF_MOMO_BUFFER_LONG";
      return true;
     }

   if(mom_z <= -strategy_mom_z_threshold)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = bid + (strategy_sl_atr_mult * atr);
      req.tp = bid - (strategy_tp_atr_mult * atr);
      req.reason = "HF_MOMO_BUFFER_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
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

   if(TimeCurrent() - open_time >= strategy_target_bars * PeriodSeconds(strategy_signal_tf))
      return true;

   const double mom = Strategy_MomentumReturn(1);
   if(position_type == POSITION_TYPE_BUY && mom < 0.0)
      return true;
   if(position_type == POSITION_TYPE_SELL && mom > 0.0)
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
