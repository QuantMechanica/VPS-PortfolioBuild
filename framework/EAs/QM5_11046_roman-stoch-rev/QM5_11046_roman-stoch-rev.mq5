#property strict
#property version   "5.0"
#property description "QM5_11046 Roman Fixed Stochastic Reversal"
// rework v2 2026-06-16 — inverted K/D cross direction at extremes caused ~0 trades.
// Reversal sells when %K crosses DOWN through %D while overbought, and buys when %K
// crosses UP through %D while oversold (source StrategyStoch mechanic). The prior
// code paired overbought with a bullish up-cross (and oversold with a down-cross),
// a geometrically near-impossible combination -> Q02 MIN_TRADES. Exit opposite-cross
// flipped to stay opposite of the corrected entry.

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
input int    qm_ea_id                   = 11046;
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
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_stoch_k_period       = 5;
input int    strategy_stoch_d_period       = 3;
input int    strategy_stoch_slowing        = 3;
input double strategy_top_limit            = 80.0;
input double strategy_bottom_limit         = 20.0;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 1.5;
input double strategy_tp_rr                = 1.0;
input int    strategy_max_bars_in_trade    = 24;
input bool   strategy_break_even_enabled   = true;
input double strategy_break_even_rr        = 0.75;
input int    strategy_break_even_buffer_pips = 0;
input int    strategy_spread_median_bars   = 20;
input double strategy_spread_median_mult   = 2.0;
input int    strategy_atr_percentile_bars  = 100;
input double strategy_min_atr_percentile   = 20.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: the card specifies no session/time filter. Framework
   // news and Friday-close filters run before this hook; spread and ATR
   // compression are checked inside the new-bar entry path.
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

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(strategy_spread_median_bars > 0 && strategy_spread_median_mult > 0.0)
     {
      double spreads[128];
      int spread_count = 0;
      const int spread_bars = MathMin(strategy_spread_median_bars, 128);
      for(int i = 1; i <= spread_bars; ++i)
        {
         const long bar_spread = iSpread(_Symbol, _Period, i);
         if(bar_spread <= 0)
            continue;
         spreads[spread_count] = (double)bar_spread;
         ++spread_count;
        }

      if(spread_count <= 0)
         return false;

      for(int i = 1; i < spread_count; ++i)
        {
         const double v = spreads[i];
         int j = i - 1;
         while(j >= 0 && spreads[j] > v)
           {
            spreads[j + 1] = spreads[j];
            --j;
           }
         spreads[j + 1] = v;
        }

      const int mid = spread_count / 2;
      const double median_spread = (spread_count % 2 == 1)
                                   ? spreads[mid]
                                   : (spreads[mid - 1] + spreads[mid]) * 0.5;
      const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(median_spread <= 0.0 || current_spread > median_spread * strategy_spread_median_mult)
         return false;
     }

   if(strategy_atr_percentile_bars > 0 && strategy_min_atr_percentile > 0.0)
     {
      const double current_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(current_atr <= 0.0)
         return false;

      int atr_count = 0;
      int atr_lower_or_equal = 0;
      const int atr_bars = MathMin(strategy_atr_percentile_bars, 256);
      for(int i = 2; i <= atr_bars + 1; ++i)
        {
         const double sample_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, i);
         if(sample_atr <= 0.0)
            continue;
         ++atr_count;
         if(sample_atr <= current_atr)
            ++atr_lower_or_equal;
        }

      if(atr_count <= 0)
         return false;

      const double atr_percentile = 100.0 * (double)atr_lower_or_equal / (double)atr_count;
      if(atr_percentile < strategy_min_atr_percentile)
         return false;
     }

   const double main_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double sig_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double main_done = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double sig_done = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(main_prev < 0.0 || sig_prev < 0.0 || main_done < 0.0 || sig_done < 0.0)
      return false;

   // Reversal: SELL when %K crosses DOWN through %D while overbought; BUY when %K
   // crosses UP through %D while oversold (faithful StrategyStoch reversal mechanic).
   const bool short_cross = (main_prev >= sig_prev && main_done < sig_done && main_prev > strategy_top_limit);
   const bool long_cross = (main_prev <= sig_prev && main_done > sig_done && main_prev < strategy_bottom_limit);
   if(!short_cross && !long_cross)
      return false;

   req.type = long_cross ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? ask : bid;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
   req.reason = long_cross ? "ROMAN_STOCH_REV_LONG" : "ROMAN_STOCH_REV_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && (req.sl >= entry || req.tp <= entry))
      return false;
   if(req.type == QM_SELL && (req.sl <= entry || req.tp >= entry))
      return false;

   // Trade Entry: market entry at the next bar after the completed-bar signal.
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: optional break-even at 0.75R, no trailing or partials.
   if(!strategy_break_even_enabled || strategy_break_even_rr <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
      const double pip_distance = point * pip_factor;
      if(open_price <= 0.0 || sl <= 0.0 || pip_distance <= 0.0)
         continue;

      const int trigger_pips = (int)MathRound((MathAbs(open_price - sl) * strategy_break_even_rr) / pip_distance);
      if(trigger_pips <= 0)
         continue;

      QM_TM_MoveToBreakEven(ticket, trigger_pips, strategy_break_even_buffer_pips);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: close after max bars or on the next opposite Stochastic cross.
   const int magic = QM_FrameworkMagic();
   bool have_buy = false;
   bool have_sell = false;
   bool time_exit = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_buy = have_buy || (type == POSITION_TYPE_BUY);
      have_sell = have_sell || (type == POSITION_TYPE_SELL);

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int seconds_per_bar = PeriodSeconds(_Period);
      if(strategy_max_bars_in_trade > 0 && seconds_per_bar > 0 && open_time > 0 &&
         TimeCurrent() - open_time >= strategy_max_bars_in_trade * seconds_per_bar)
         time_exit = true;
     }

   if(!have_buy && !have_sell)
      return false;
   if(time_exit)
      return true;

   const double main_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double sig_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double main_done = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double sig_done = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(main_prev < 0.0 || sig_prev < 0.0 || main_done < 0.0 || sig_done < 0.0)
      return false;

   const bool cross_up = (main_prev <= sig_prev && main_done > sig_done);
   const bool cross_down = (main_prev >= sig_prev && main_done < sig_done);
   // Opposite-cross exit: a long (entered on an up-cross) closes on a down-cross,
   // and a short (entered on a down-cross) closes on an up-cross.
   if((have_buy && cross_down) || (have_sell && cross_up))
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; central framework news mode applies.
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
