#property strict
#property version   "5.0"
#property description "QM5_11045 Roman Fixed MA Reversal Cross"

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
input int    qm_ea_id                   = 11045;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H1;
input int    strategy_short_sma_period  = 8;
input int    strategy_long_sma_period   = 55;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_tp_sl_ratio       = 1.0;
input int    strategy_max_bars_in_trade = 24;
input bool   strategy_break_even_enabled = true;
input double strategy_break_even_r      = 0.75;
input int    strategy_atr_percentile_lookback = 100;
input double strategy_min_atr_percentile = 20.0;
input int    strategy_min_atr_samples   = 40;
input int    strategy_median_spread_points = 20;
input double strategy_spread_max_mult   = 2.0;
input bool   strategy_session_filter_enabled = false;
input int    strategy_session_start_hour = 7;
input int    strategy_session_end_hour   = 21;

int Strategy_ReversalSignal()
  {
   if(strategy_short_sma_period <= 0 ||
      strategy_long_sma_period <= 0 ||
      strategy_short_sma_period >= strategy_long_sma_period)
      return 0;

   const double short_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_short_sma_period, 1, PRICE_CLOSE);
   const double short_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_short_sma_period, 2, PRICE_CLOSE);
   const double long_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, 1, PRICE_CLOSE);
   const double long_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, 2, PRICE_CLOSE);
   if(short_1 <= 0.0 || short_2 <= 0.0 || long_1 <= 0.0 || long_2 <= 0.0)
      return 0;

   const bool long_sma_rising = (long_1 > long_2);
   const bool long_sma_falling = (long_1 < long_2);
   const bool short_crossed_above = (short_1 > long_1 && short_2 < long_2);
   const bool short_crossed_below = (short_1 < long_1 && short_2 > long_2);

   if(long_sma_rising && short_crossed_above)
      return -1;
   if(long_sma_falling && short_crossed_below)
      return 1;
   return 0;
  }

bool Strategy_ATRPassesPercentileFilter()
  {
   if(strategy_atr_percentile_lookback <= 0 || strategy_min_atr_percentile <= 0.0)
      return true;

   const double current_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   int samples = 0;
   int less_or_equal = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_lookback; ++shift)
     {
      const double sample_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, shift);
      if(sample_atr <= 0.0)
         continue;
      samples++;
      if(sample_atr <= current_atr)
         less_or_equal++;
     }

   if(samples < strategy_min_atr_samples)
      return false;

   const double percentile_rank = 100.0 * (double)less_or_equal / (double)samples;
   return (percentile_rank > strategy_min_atr_percentile);
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                                datetime &open_time,
                                double &open_price,
                                double &sl,
                                ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;
   sl = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      ticket = candidate;
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
   if(strategy_median_spread_points > 0 && strategy_spread_max_mult > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const double max_spread = (double)strategy_median_spread_points * strategy_spread_max_mult;
      if(spread_points > max_spread)
         return true;
     }

   if(strategy_session_filter_enabled)
     {
      MqlDateTime now;
      TimeToStruct(TimeCurrent(), now);
      int start_h = strategy_session_start_hour;
      int end_h = strategy_session_end_hour;
      if(start_h < 0)
         start_h = 0;
      if(start_h > 23)
         start_h = 23;
      if(end_h < 0)
         end_h = 0;
      if(end_h > 23)
         end_h = 23;
      const bool in_session = (start_h <= end_h)
                              ? (now.hour >= start_h && now.hour < end_h)
                              : (now.hour >= start_h || now.hour < end_h);
      if(!in_session)
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

   if(!Strategy_ATRPassesPercentileFilter())
      return false;

   const int signal = Strategy_ReversalSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry,
                                                  atr * strategy_atr_sl_mult * strategy_tp_sl_ratio);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "ROMAN_MA_REV_BUY" : "ROMAN_MA_REV_SELL";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_break_even_enabled || strategy_break_even_r <= 0.0)
      return;

   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   double open_price;
   double sl;
   ulong ticket;
   if(!Strategy_SelectOurPosition(position_type, open_time, open_price, sl, ticket))
      return;
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if((is_buy && sl >= open_price) || (!is_buy && sl <= open_price))
      return;

   const double risk_distance = MathAbs(open_price - sl);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(risk_distance <= 0.0 || market_price <= 0.0)
      return;

   const double favorable_distance = is_buy ? (market_price - open_price)
                                            : (open_price - market_price);
   if(favorable_distance >= risk_distance * strategy_break_even_r)
      QM_TM_MoveSL(ticket, open_price, "roman_ma_rev_break_even");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   double open_price;
   double sl;
   ulong ticket;
   if(!Strategy_SelectOurPosition(position_type, open_time, open_price, sl, ticket))
      return false;

   const int signal = Strategy_ReversalSignal();
   if(position_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && signal > 0)
      return true;

   if(strategy_max_bars_in_trade > 0 && open_time > 0)
     {
      const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
      if(seconds_per_bar > 0)
        {
         const int bars_held = (int)((TimeCurrent() - open_time) / seconds_per_bar);
         if(bars_held >= strategy_max_bars_in_trade)
            return true;
        }
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
