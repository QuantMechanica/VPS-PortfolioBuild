#property strict
#property version   "5.0"
#property description "QM5_20040 B3 relative-tick-volume breakout"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20040_b3-relvol-brk, G0 APPROVED 2026-07-22.
// TickVolume is treated only as a broker tick-count proxy. This EA makes no
// aggression, traded-volume, order-book, tape, or source-performance claim.

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
input int    qm_ea_id                   = 20040;
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
input int    qm_news_stale_max_hours      = 336;     // 14 days; framework news gate fails closed if older
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
input string strategy_variant_id        = "B3_RELVOL_BRK_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_force_level       = 70;
input int    strategy_rearm_level       = 25;
input int    strategy_volume_sma_period = 20;
input int    strategy_fast_sma_period   = 5;
input int    strategy_slow_sma_period   = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input double strategy_reward_r          = 1.5;
input int    strategy_timeout_bars      = 6;
input int    strategy_cash_open_hour_new_york = 9;
input int    strategy_cash_open_minute_new_york = 30;
input int    strategy_cash_close_hour_new_york = 16;
input int    strategy_cash_close_minute_new_york = 0;
input int    strategy_exit_hour_new_york = 15;
input int    strategy_exit_minute_new_york = 55;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_state_session_key = 0;
datetime g_state_open_utc = 0;
datetime g_state_close_utc = 0;
datetime g_state_exit_utc = 0;
datetime g_state_through_utc = 0;
bool     g_long_armed = true;
bool     g_short_armed = true;
int      g_session_attempts = 0;
int      g_pending_side = 0;
datetime g_pending_entry_utc = 0;
double   g_pending_atr = 0.0;
datetime g_active_timeout_broker = 0;
datetime g_active_exit_broker = 0;

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_NewYorkLocal(const datetime utc)
  {
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 60 * 60 : 5 * 60 * 60);
  }

datetime Strategy_NewYorkLocalToUtc(const int date_key,
                                    const int hour,
                                    const int minute)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = hour;
   parts.min = minute;
   datetime utc = StructToTime(parts) + 5 * 60 * 60;
   if(QM_IsUSDSTUTC(utc))
      utc -= 60 * 60;
   return utc;
  }

bool Strategy_IsUtcWeekday(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_utc,
                                 datetime &close_utc,
                                 datetime &exit_utc)
  {
   open_utc = Strategy_NewYorkLocalToUtc(date_key,
                                         strategy_cash_open_hour_new_york,
                                         strategy_cash_open_minute_new_york);
   close_utc = Strategy_NewYorkLocalToUtc(date_key,
                                          strategy_cash_close_hour_new_york,
                                          strategy_cash_close_minute_new_york);
   exit_utc = Strategy_NewYorkLocalToUtc(date_key,
                                         strategy_exit_hour_new_york,
                                         strategy_exit_minute_new_york);
   return (open_utc > 0 && close_utc - open_utc == 390 * 60 &&
           exit_utc > open_utc && exit_utc <= close_utc &&
           Strategy_IsUtcWeekday(open_utc));
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "WS30.DWX" || symbol == "SP500.DWX" || symbol == "NDX.DWX");
  }

bool Strategy_FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void Strategy_RecoverSessionAttempts(const datetime cash_open_utc)
  {
   g_session_attempts = 0;
   const datetime from_broker = QM_UTCToBroker(cash_open_utc);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_session_attempts = 2;
      return;
     }
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
         ++g_session_attempts;
     }
   if(g_session_attempts > 2)
      g_session_attempts = 2;
  }

void Strategy_ResetSessionState(const int session_key,
                                const datetime open_utc,
                                const datetime close_utc,
                                const datetime exit_utc)
  {
   g_state_session_key = session_key;
   g_state_open_utc = open_utc;
   g_state_close_utc = close_utc;
   g_state_exit_utc = exit_utc;
   g_state_through_utc = 0;
   g_long_armed = true;
   g_short_armed = true;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_atr = 0.0;
   Strategy_RecoverSessionAttempts(open_utc);
  }

bool Strategy_CalculateMetrics(const MqlRates &rates[],
                               const int index,
                               double &force,
                               double &sma_fast,
                               double &sma_slow)
  {
   force = 0.0;
   sma_fast = 0.0;
   sma_slow = 0.0;
   if(index < strategy_slow_sma_period - 1 || index >= ArraySize(rates))
      return false;
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double raw_range = rates[index].high - rates[index].low;
   if(tick_size <= 0.0 || raw_range < 0.0 || rates[index].open <= 0.0 ||
      rates[index].close <= 0.0 || !MathIsValidNumber(raw_range))
      return false;

   double volume_sum = 0.0;
   double slow_sum = 0.0;
   for(int i = index - strategy_slow_sma_period + 1; i <= index; ++i)
     {
      if(rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         return false;
      volume_sum += (double)rates[i].tick_volume;
      slow_sum += rates[i].close;
     }
   const double volume_sma = volume_sum / (double)strategy_volume_sma_period;
   if(volume_sma <= 0.0 || !MathIsValidNumber(volume_sma))
      return false;

   double fast_sum = 0.0;
   for(int i = index - strategy_fast_sma_period + 1; i <= index; ++i)
      fast_sum += rates[i].close;
   const double denominator = MathMax(raw_range, tick_size);
   const double body_fraction = (rates[index].close - rates[index].open) / denominator;
   const double relative_tick_volume = (double)rates[index].tick_volume / volume_sma;
   const double raw_force = 100.0 * body_fraction * relative_tick_volume;
   if(!MathIsValidNumber(raw_force))
      return false;
   force = MathMax(-100.0, MathMin(100.0, raw_force));
   sma_fast = fast_sum / (double)strategy_fast_sma_period;
   sma_slow = slow_sum / (double)strategy_slow_sma_period;
   return (MathIsValidNumber(sma_fast) && MathIsValidNumber(sma_slow));
  }

bool Strategy_EntryClockAllowed(const datetime entry_utc)
  {
   if(entry_utc >= g_state_exit_utc)
      return false;
   const datetime local = Strategy_NewYorkLocal(entry_utc);
   MqlDateTime parts;
   if(!TimeToStruct(local, parts) || Strategy_DateKey(local) != g_state_session_key ||
      parts.sec != 0)
      return false;
   const int minute_of_day = parts.hour * 60 + parts.min;
   return (minute_of_day >= 9 * 60 + 45 && minute_of_day <= 15 * 60 + 30);
  }

bool Strategy_ProcessSignalBar(const MqlRates &rates[],
                               const int index,
                               const datetime bar_utc,
                               const datetime next_open_utc,
                               const bool allow_pending)
  {
   g_state_through_utc = bar_utc;
   double current_force = 0.0;
   double current_fast = 0.0;
   double current_slow = 0.0;
   double prior_force = 0.0;
   double prior_fast = 0.0;
   double prior_slow = 0.0;
   if(!Strategy_CalculateMetrics(rates, index, current_force, current_fast, current_slow) ||
      !Strategy_CalculateMetrics(rates, index - 1, prior_force, prior_fast, prior_slow))
      return true;

   if(MathAbs(current_force) < (double)strategy_rearm_level)
     {
      g_long_armed = true;
      g_short_armed = true;
     }

   const bool long_signal = (g_long_armed && prior_force < (double)strategy_force_level &&
                             current_force >= (double)strategy_force_level &&
                             rates[index].close > rates[index - 1].high &&
                             rates[index].close > current_slow && current_fast > current_slow);
   const bool short_signal = (g_short_armed && prior_force > -(double)strategy_force_level &&
                              current_force <= -(double)strategy_force_level &&
                              rates[index].close < rates[index - 1].low &&
                              rates[index].close < current_slow && current_fast < current_slow);
   int side = 0;
   if(long_signal)
     {
      g_long_armed = false;
      side = 1;
     }
   else if(short_signal)
     {
      g_short_armed = false;
      side = -1;
     }
   if(side == 0 || !allow_pending || g_session_attempts >= 2 ||
      g_state_session_key <= 0 || !Strategy_EntryClockAllowed(next_open_utc))
      return true;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return true;
   const double frozen_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(frozen_atr <= 0.0 || !MathIsValidNumber(frozen_atr))
      return true;
   g_pending_side = side;
   g_pending_entry_utc = next_open_utc;
   g_pending_atr = frozen_atr;
   return true;
  }

bool Strategy_RebuildSessionState(const int session_key,
                                  const datetime open_utc,
                                  const datetime close_utc,
                                  const datetime exit_utc,
                                  const datetime current_open_utc)
  {
   Strategy_ResetSessionState(session_key, open_utc, close_utc, exit_utc);
   const datetime start_broker = QM_UTCToBroker(open_utc - 20 * 15 * 60);
   const datetime stop_broker = QM_UTCToBroker(current_open_utc) - 1;
   if(start_broker <= 0 || stop_broker < start_broker)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded one-time session rebuild behind QM_IsNewBar.
                                strategy_signal_tf,
                                start_broker,
                                stop_broker,
                                rates);
   if(copied <= 20 || copied > 48)
      return false;

   datetime previous_utc = 0;
   int processed = 0;
   for(int i = 20; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc < open_utc || bar_utc >= close_utc || bar_utc >= current_open_utc)
         continue;
      if(previous_utc > 0 && bar_utc != previous_utc + 15 * 60)
         return false;
      const bool is_latest = (bar_utc + 15 * 60 == current_open_utc);
      if(!Strategy_ProcessSignalBar(rates, i, bar_utc, current_open_utc, is_latest))
         return false;
      previous_utc = bar_utc;
      ++processed;
     }
   return (processed > 0 && g_state_through_utc + 15 * 60 == current_open_utc);
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_atr = 0.0;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_signal_tf != PERIOD_M15)
      return false;

   MqlRates current_bar;
   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, closed_bar))
      return false;
   const datetime current_open_utc = QM_BrokerToUTC(current_bar.time);
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar.time);
   const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(closed_bar_utc));
   datetime open_utc = 0;
   datetime close_utc = 0;
   datetime exit_utc = 0;
   if(!Strategy_ResolveCashSession(date_key, open_utc, close_utc, exit_utc) ||
      closed_bar_utc < open_utc || closed_bar_utc >= close_utc)
      return false;

   if(g_state_session_key != date_key || g_state_open_utc != open_utc ||
      g_state_close_utc != close_utc || g_state_exit_utc != exit_utc ||
      g_state_through_utc == 0 ||
      g_state_through_utc + 15 * 60 != closed_bar_utc)
      return Strategy_RebuildSessionState(date_key,
                                          open_utc,
                                          close_utc,
                                          exit_utc,
                                          current_open_utc);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const datetime start_broker = QM_UTCToBroker(closed_bar_utc - 20 * 15 * 60);
   const int copied = CopyRates(_Symbol, // perf-allowed: fixed 21-bar force/SMA cache advance behind QM_IsNewBar.
                                strategy_signal_tf,
                                start_broker,
                                closed_bar.time,
                                rates);
   if(copied != 21 || QM_BrokerToUTC(rates[20].time) != closed_bar_utc)
      return false;
   return Strategy_ProcessSignalBar(rates,
                                    20,
                                    closed_bar_utc,
                                    current_open_utc,
                                    true);
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price,
                                          const double target_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 || point <= 0.0 ||
      tick_size <= 0.0 || tick_value <= 0.0 || entry_price <= 0.0 ||
      stop_price <= 0.0 || target_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 || target_distance <= 0.0)
      return false;

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

bool Strategy_InputsValid()
  {
   return (strategy_variant_id == "B3_RELVOL_BRK_BASELINE" &&
           strategy_signal_tf == PERIOD_M15 && strategy_force_level == 70 &&
           strategy_rearm_level == 25 && strategy_volume_sma_period == 20 &&
           strategy_fast_sma_period == 5 && strategy_slow_sma_period == 20 &&
           strategy_atr_period == 14 && strategy_atr_stop_mult == 1.0 &&
           strategy_reward_r == 1.5 && strategy_timeout_bars == 6 &&
           strategy_cash_open_hour_new_york == 9 &&
           strategy_cash_open_minute_new_york == 30 &&
           strategy_cash_close_hour_new_york == 16 &&
           strategy_cash_close_minute_new_york == 0 &&
           strategy_exit_hour_new_york == 15 && strategy_exit_minute_new_york == 55 &&
           strategy_max_spread_points >= 0);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points < 0 || spread_points > strategy_max_spread_points);
  }

datetime Strategy_FloorM15(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return (datetime)(((long)utc / (15 * 60)) * (15 * 60));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
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

   if(g_pending_side == 0 || g_pending_entry_utc <= 0 || g_pending_atr <= 0.0 ||
      g_state_session_key <= 0 || g_session_attempts >= 2 ||
      !Strategy_EntryClockAllowed(g_pending_entry_utc))
      return false;
   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      QM_BrokerToUTC(current_bar.time) != g_pending_entry_utc)
      return false;
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   if(Strategy_WideSpread())
      return false;

   const bool is_long = (g_pending_side > 0);
   const double frozen_atr = g_pending_atr;
   ++g_session_attempts;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_atr = 0.0;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
      return false;
   const double entry_price = is_long ? tick.ask : tick.bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         is_long
                                                         ? entry_price - strategy_atr_stop_mult * frozen_atr
                                                         : entry_price + strategy_atr_stop_mult * frozen_atr);
   if(stop_price <= 0.0 || (is_long && stop_price >= entry_price) ||
      (!is_long && stop_price <= entry_price))
      return false;
   const double initial_risk = MathAbs(entry_price - stop_price);
   const double target_price = QM_StopRulesNormalizePrice(_Symbol,
                                                           is_long
                                                           ? entry_price + strategy_reward_r * initial_risk
                                                           : entry_price - strategy_reward_r * initial_risk);
   if(target_price <= 0.0 || (is_long && target_price <= entry_price) ||
      (!is_long && target_price >= entry_price) ||
      !Strategy_TradeGeometryAndVolumeAllow(entry_price, stop_price, target_price))
      return false;

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = target_price;
   req.reason = is_long ? "B3_RELVOL_BRK_LONG" : "B3_RELVOL_BRK_SHORT";
   const datetime entry_bar_utc = QM_BrokerToUTC(current_bar.time);
   g_active_timeout_broker = QM_UTCToBroker(entry_bar_utc + strategy_timeout_bars * 15 * 60);
   g_active_exit_broker = QM_UTCToBroker(g_state_exit_utc);
   return (g_active_timeout_broker > 0 && g_active_exit_broker > 0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
     {
      g_active_timeout_broker = 0;
      g_active_exit_broker = 0;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_timeout_broker <= 0 || g_active_exit_broker <= 0)
     {
      const datetime open_utc = QM_BrokerToUTC(open_time);
      const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(open_utc));
      datetime cash_open_utc = 0;
      datetime cash_close_utc = 0;
      datetime exit_utc = 0;
      if(!Strategy_ResolveCashSession(date_key,
                                      cash_open_utc,
                                      cash_close_utc,
                                      exit_utc))
         return true;
      const datetime entry_bar_utc = Strategy_FloorM15(open_utc);
      g_active_timeout_broker = QM_UTCToBroker(entry_bar_utc + strategy_timeout_bars * 15 * 60);
      g_active_exit_broker = QM_UTCToBroker(exit_utc);
     }
   return ((g_active_timeout_broker > 0 && TimeCurrent() >= g_active_timeout_broker) ||
           (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker));
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline retains the framework default news pause.
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

   // Consume and cache the completed M15 signal before the central news gate.
   // If news blocks this exact next-open opportunity, it is never delayed.
   const bool strategy_new_bar = QM_IsNewBar();
   if(strategy_new_bar)
      Strategy_AdvanceStateOnNewBar();

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

   if(!strategy_new_bar)
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
