#property strict
#property version   "5.0"
#property description "QM5_36003 NNFX Hull MA ZeroLag MACD STC"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 36003;
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
input int    strategy_hma_period             = 20;
input int    strategy_zl_macd_fast           = 12;
input int    strategy_zl_macd_slow           = 26;
input int    strategy_zl_macd_signal         = 9;
input int    strategy_stc_fast               = 23;
input int    strategy_stc_slow               = 50;
input int    strategy_stc_cycle              = 10;
input double strategy_stc_smoothing          = 0.50;
input double strategy_stc_long_level         = 75.0;
input double strategy_stc_short_level        = 25.0;
input int    strategy_better_volume_lookback = 20;
input int    strategy_atr_period             = 14;
input double strategy_stop_atr_mult          = 1.00;
input double strategy_tp1_atr_mult           = 1.00;
input double strategy_tp1_fraction           = 0.50;
input int    strategy_be_buffer_pips         = 1;
input double strategy_spread_atr_mult        = 1.80;
input double strategy_daily_loss_halt_pct    = 2.00;
input double strategy_daily_hard_stop_pct    = 2.50;
input double strategy_total_dd_stop_pct      = 5.00;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Configure the card's capital-preservation thresholds through the shared
   // kill switch. The framework has already initialized it; this one-time
   // reconfiguration preserves its state-file and close-all implementation.
   static bool kill_switch_configured = false;
   if(!kill_switch_configured)
     {
      if(!QM_KillSwitchInit(qm_ea_id,
                            QM_FrameworkMagic(),
                            strategy_daily_hard_stop_pct,
                            strategy_total_dd_stop_pct,
                            1.0))
         return true;
      kill_switch_configured = true;
     }

   // Cache D1 ATR and the realized-PnL balance anchor once per broker day.
   // QM_CalendarPeriodKey keeps this .DWX-safe without a local iTime gate.
   static int    cached_day_key       = 0;
   static double cached_atr           = 0.0;
   static double day_start_balance    = 0.0;
   const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(day_key > 0 && day_key != cached_day_key)
     {
      cached_day_key    = day_key;
      cached_atr        = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
     }

   // An existing position is protected by management, exit, server SL and
   // framework duplicate-entry checks. Entry-only filters must not make those
   // paths unreachable.
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Card rollover blackout: 23:55 through 00:05 GMT, converted from the
   // Darwinex broker clock by the framework's DST-aware helper.
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc_parts;
   TimeToStruct(utc_now, utc_parts);
   const int utc_hhmm = utc_parts.hour * 100 + utc_parts.min;
   if(utc_hhmm >= 2355 || utc_hhmm <= 5)
      return true;

   // .DWX tester spread can be exactly zero. Block only a genuinely positive,
   // wide spread; zero modeled spread remains tradeable.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && cached_atr > 0.0 &&
      (ask - bid) > strategy_spread_atr_mult * cached_atr)
      return true;

   // The card distinguishes this 2% realized-loss entry halt from its 2.5%
   // equity hard stop. Balance is used here so floating PnL does not gate entry.
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   if(strategy_daily_loss_halt_pct > 0.0 && day_start_balance > 0.0 &&
      balance_now <= day_start_balance * (1.0 - strategy_daily_loss_halt_pct / 100.0))
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(strategy_hma_period < 4 ||
      strategy_zl_macd_fast < 2 || strategy_zl_macd_slow <= strategy_zl_macd_fast ||
      strategy_zl_macd_signal < 2 ||
      strategy_stc_fast < 2 || strategy_stc_slow <= strategy_stc_fast ||
      strategy_stc_cycle < 2 ||
      strategy_stc_smoothing <= 0.0 || strategy_stc_smoothing > 1.0 ||
      strategy_better_volume_lookback < 2 ||
      strategy_atr_period < 2 || strategy_stop_atr_mult <= 0.0 ||
      strategy_tp1_atr_mult <= 0.0 || strategy_tp1_fraction <= 0.0 ||
      strategy_tp1_fraction >= 1.0)
      return false;

   // One bounded closed-bar read supplies the bespoke ZeroLag MACD, standard
   // two-stage Schaff Trend Cycle, and DWX tick-volume proxy. The skeleton calls
   // this hook only after QM_IsNewBar(), so this never runs per tick.
   int bars_needed = strategy_zl_macd_slow * 8;
   const int stc_bars_needed = strategy_stc_slow * 6;
   if(stc_bars_needed > bars_needed)
      bars_needed = stc_bars_needed;
   if(bars_needed < 180)
      bars_needed = 180;
   if(bars_needed > 600)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: one bounded bespoke read on the framework closed-bar path.
   int minimum_bars = strategy_zl_macd_slow + strategy_zl_macd_signal * 4;
   const int minimum_stc_bars = strategy_stc_slow + strategy_stc_cycle * 4;
   if(minimum_stc_bars > minimum_bars)
      minimum_bars = minimum_stc_bars;
   if(copied < minimum_bars || copied < strategy_better_volume_lookback + 2)
      return false;

   double zl_macd[];
   double zl_signal[];
   double stc_macd[];
   double stc_first[];
   double stc_value[];
   ArrayResize(zl_macd, copied);
   ArrayResize(zl_signal, copied);
   ArrayResize(stc_macd, copied);
   ArrayResize(stc_first, copied);
   ArrayResize(stc_value, copied);

   const double zl_fast_alpha = 2.0 / ((double)strategy_zl_macd_fast + 1.0);
   const double zl_slow_alpha = 2.0 / ((double)strategy_zl_macd_slow + 1.0);
   const double zl_signal_alpha = 2.0 / ((double)strategy_zl_macd_signal + 1.0);
   const double stc_fast_alpha = 2.0 / ((double)strategy_stc_fast + 1.0);
   const double stc_slow_alpha = 2.0 / ((double)strategy_stc_slow + 1.0);

   double zl_fast_first  = 0.0;
   double zl_fast_second = 0.0;
   double zl_slow_first  = 0.0;
   double zl_slow_second = 0.0;
   double stc_fast_ema   = 0.0;
   double stc_slow_ema   = 0.0;

   // CopyRates stores the oldest requested bar at index 0. Advance every EMA
   // forward exactly once, ending at index copied-1 == closed bar [1].
   for(int i = 0; i < copied; ++i)
     {
      const double close_i = rates[i].close;
      if(close_i <= 0.0)
         return false;

      if(i == 0)
        {
         zl_fast_first  = close_i;
         zl_fast_second = close_i;
         zl_slow_first  = close_i;
         zl_slow_second = close_i;
         stc_fast_ema   = close_i;
         stc_slow_ema   = close_i;
         zl_macd[i]     = 0.0;
         zl_signal[i]   = 0.0;
         stc_macd[i]    = 0.0;
         continue;
        }

      zl_fast_first = zl_fast_alpha * close_i + (1.0 - zl_fast_alpha) * zl_fast_first;
      const double zl_fast_price = close_i + (close_i - zl_fast_first);
      zl_fast_second = zl_fast_alpha * zl_fast_price + (1.0 - zl_fast_alpha) * zl_fast_second;

      zl_slow_first = zl_slow_alpha * close_i + (1.0 - zl_slow_alpha) * zl_slow_first;
      const double zl_slow_price = close_i + (close_i - zl_slow_first);
      zl_slow_second = zl_slow_alpha * zl_slow_price + (1.0 - zl_slow_alpha) * zl_slow_second;

      zl_macd[i] = zl_fast_second - zl_slow_second;
      zl_signal[i] = zl_signal_alpha * zl_macd[i] +
                     (1.0 - zl_signal_alpha) * zl_signal[i - 1];

      stc_fast_ema = stc_fast_alpha * close_i + (1.0 - stc_fast_alpha) * stc_fast_ema;
      stc_slow_ema = stc_slow_alpha * close_i + (1.0 - stc_slow_alpha) * stc_slow_ema;
      stc_macd[i] = stc_fast_ema - stc_slow_ema;
     }

   // Rolling min/max queues keep both STC stochastic passes O(N), rather than
   // rescanning a lookback window for every historical bar.
   int min_queue[];
   int max_queue[];
   ArrayResize(min_queue, copied);
   ArrayResize(max_queue, copied);
   int min_head = 0;
   int min_tail = 0;
   int max_head = 0;
   int max_tail = 0;

   for(int i = 0; i < copied; ++i)
     {
      while(min_tail > min_head && stc_macd[min_queue[min_tail - 1]] >= stc_macd[i])
         --min_tail;
      min_queue[min_tail++] = i;
      while(max_tail > max_head && stc_macd[max_queue[max_tail - 1]] <= stc_macd[i])
         --max_tail;
      max_queue[max_tail++] = i;

      int window_start = i - strategy_stc_cycle + 1;
      if(window_start < 0)
         window_start = 0;
      while(min_head < min_tail && min_queue[min_head] < window_start)
         ++min_head;
      while(max_head < max_tail && max_queue[max_head] < window_start)
         ++max_head;

      const double low_macd = stc_macd[min_queue[min_head]];
      const double high_macd = stc_macd[max_queue[max_head]];
      const double macd_range = high_macd - low_macd;
      double stochastic_one = (i > 0) ? stc_first[i - 1] : 50.0;
      if(macd_range > 0.0)
         stochastic_one = 100.0 * (stc_macd[i] - low_macd) / macd_range;
      stc_first[i] = (i == 0)
         ? stochastic_one
         : stc_first[i - 1] + strategy_stc_smoothing * (stochastic_one - stc_first[i - 1]);
     }

   min_head = 0;
   min_tail = 0;
   max_head = 0;
   max_tail = 0;
   for(int i = 0; i < copied; ++i)
     {
      while(min_tail > min_head && stc_first[min_queue[min_tail - 1]] >= stc_first[i])
         --min_tail;
      min_queue[min_tail++] = i;
      while(max_tail > max_head && stc_first[max_queue[max_tail - 1]] <= stc_first[i])
         --max_tail;
      max_queue[max_tail++] = i;

      int window_start = i - strategy_stc_cycle + 1;
      if(window_start < 0)
         window_start = 0;
      while(min_head < min_tail && min_queue[min_head] < window_start)
         ++min_head;
      while(max_head < max_tail && max_queue[max_head] < window_start)
         ++max_head;

      const double low_first = stc_first[min_queue[min_head]];
      const double high_first = stc_first[max_queue[max_head]];
      const double first_range = high_first - low_first;
      double stochastic_two = (i > 0) ? stc_value[i - 1] : 50.0;
      if(first_range > 0.0)
         stochastic_two = 100.0 * (stc_first[i] - low_first) / first_range;
      stc_value[i] = (i == 0)
         ? stochastic_two
         : stc_value[i - 1] + strategy_stc_smoothing * (stochastic_two - stc_value[i - 1]);
     }

   const int latest = copied - 1;
   const double close_1 = rates[latest].close;
   const double hma_1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_period, 1);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_1 <= 0.0 || hma_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   double prior_volume_sum = 0.0;
   for(int k = 1; k <= strategy_better_volume_lookback; ++k)
      prior_volume_sum += (double)rates[latest - k].tick_volume;
   const double prior_volume_average = prior_volume_sum / (double)strategy_better_volume_lookback;
   const bool better_volume_high = ((double)rates[latest].tick_volume > prior_volume_average &&
                                    prior_volume_average > 0.0);
   if(!better_volume_high)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(close_1 > hma_1 &&
      zl_macd[latest] > zl_signal[latest] &&
      stc_value[latest] >= strategy_stc_long_level)
     {
      if(ask <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, ask, atr_1, strategy_stop_atr_mult);
      req.tp     = 0.0;
      req.reason = "NNFX_HMA_ZLMACD_STC_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_1 < hma_1 &&
      zl_macd[latest] < zl_signal[latest] &&
      stc_value[latest] <= strategy_stc_short_level)
     {
      if(bid <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, bid, atr_1, strategy_stop_atr_mult);
      req.tp     = 0.0;
      req.reason = "NNFX_HMA_ZLMACD_STC_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_stop_atr_mult <= 0.0 ||
      strategy_tp1_atr_mult <= 0.0 || strategy_tp1_fraction <= 0.0 ||
      strategy_tp1_fraction >= 1.0)
      return;

   static ulong partial_done_ticket = 0;
   bool own_position_found = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      own_position_found = true;
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market_price = is_buy
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || stop_price <= 0.0 || volume <= 0.0 || market_price <= 0.0)
         continue;

      const bool stop_is_protected = is_buy
         ? (stop_price >= open_price)
         : (stop_price <= open_price);

      // A successful partial is remembered for the current ticket. If the BE
      // modify was temporarily rejected, retry only that protection step and
      // never halve the position again.
      if(partial_done_ticket == ticket)
        {
         if(!stop_is_protected)
           {
            const double be_distance = (strategy_be_buffer_pips > 0)
               ? QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips)
               : 0.0;
            const double be_stop = is_buy
               ? open_price + be_distance
               : open_price - be_distance;
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, be_stop), "NNFX_TP1_BE_RETRY");
           }
         continue;
        }

      if(stop_is_protected)
        {
         partial_done_ticket = ticket;
         continue;
        }

      const double initial_risk_distance = MathAbs(open_price - stop_price);
      const double trigger_distance = initial_risk_distance *
                                      strategy_tp1_atr_mult / strategy_stop_atr_mult;
      const double favorable_move = is_buy
         ? market_price - open_price
         : open_price - market_price;
      if(initial_risk_distance <= 0.0 || favorable_move < trigger_distance)
         continue;

      const double partial_lots =
         QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(partial_lots <= 0.0 || partial_lots >= volume ||
         (volume - partial_lots) < min_lot - 1e-8)
         continue;

      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
        {
         partial_done_ticket = ticket;
         const double be_distance = (strategy_be_buffer_pips > 0)
            ? QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips)
            : 0.0;
         const double be_stop = is_buy
            ? open_price + be_distance
            : open_price - be_distance;
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, be_stop), "NNFX_TP1_BE_PROTECTION");
        }
     }

   if(!own_position_found)
      partial_done_ticket = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Runner exits are closed-bar events. This framework cadence tracker is
   // independent of the entry QM_IsNewBar key, so it cannot consume/starve the
   // entry gate. It also evaluates once immediately after attaching/restarting.
   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   if(strategy_zl_macd_fast < 2 || strategy_zl_macd_slow <= strategy_zl_macd_fast ||
      strategy_zl_macd_signal < 2)
      return false;

   int bars_needed = strategy_zl_macd_slow * 8;
   if(bars_needed < 180)
      bars_needed = 180;
   if(bars_needed > 600)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: once-per-D1 ZeroLag MACD runner crossover.
   if(copied < strategy_zl_macd_slow + strategy_zl_macd_signal * 4 || copied < 3)
      return false;

   double zl_macd[];
   double zl_signal[];
   ArrayResize(zl_macd, copied);
   ArrayResize(zl_signal, copied);

   const double fast_alpha = 2.0 / ((double)strategy_zl_macd_fast + 1.0);
   const double slow_alpha = 2.0 / ((double)strategy_zl_macd_slow + 1.0);
   const double signal_alpha = 2.0 / ((double)strategy_zl_macd_signal + 1.0);
   double fast_first  = 0.0;
   double fast_second = 0.0;
   double slow_first  = 0.0;
   double slow_second = 0.0;

   for(int i = 0; i < copied; ++i)
     {
      const double close_i = rates[i].close;
      if(close_i <= 0.0)
         return false;
      if(i == 0)
        {
         fast_first  = close_i;
         fast_second = close_i;
         slow_first  = close_i;
         slow_second = close_i;
         zl_macd[i]   = 0.0;
         zl_signal[i] = 0.0;
         continue;
        }

      fast_first = fast_alpha * close_i + (1.0 - fast_alpha) * fast_first;
      const double fast_price = close_i + (close_i - fast_first);
      fast_second = fast_alpha * fast_price + (1.0 - fast_alpha) * fast_second;

      slow_first = slow_alpha * close_i + (1.0 - slow_alpha) * slow_first;
      const double slow_price = close_i + (close_i - slow_first);
      slow_second = slow_alpha * slow_price + (1.0 - slow_alpha) * slow_second;

      zl_macd[i] = fast_second - slow_second;
      zl_signal[i] = signal_alpha * zl_macd[i] +
                     (1.0 - signal_alpha) * zl_signal[i - 1];
     }

   const int latest = copied - 1;
   const int previous = copied - 2;
   const bool crossed_down = (zl_macd[previous] >= zl_signal[previous] &&
                              zl_macd[latest] < zl_signal[latest]);
   const bool crossed_up = (zl_macd[previous] <= zl_signal[previous] &&
                            zl_macd[latest] > zl_signal[latest]);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && crossed_down)
         return true;
      if(position_type == POSITION_TYPE_SELL && crossed_up)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // No card-specific override. The callable P8 hook remains present while the
   // framework's two-axis news gate controls only the entry path below exits.
   return false;
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
