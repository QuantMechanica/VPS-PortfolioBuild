#property strict
#property version   "5.0"
#property description "QM5_20041 cash-session post-close continuation"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20041_postclose-cont, G0 APPROVED 2026-07-22.
// Cash-session anchors use the fixed broker clock. Holiday and blackout
// protection remains with the framework news gate and Friday guard.

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
input int    qm_ea_id                   = 20041;
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
input string strategy_variant_id        = "POSTCLOSE_CONT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input int    strategy_hold_minutes      = 240;
input int    strategy_cash_open_hour_broker = 10;
input int    strategy_cash_open_minute_broker = 0;
input int    strategy_cash_close_hour_broker = 18;
input int    strategy_cash_close_minute_broker = 30;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_pending_session_date_key = 0;
int      g_pending_side = 0;
datetime g_pending_entry_bar_utc = 0;
ulong    g_pending_entry_tick_msc = 0;
datetime g_pending_exit_utc = 0;
double   g_pending_atr = 0.0;
bool     g_session_attempted = false;
datetime g_active_exit_broker = 0;

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_BrokerDateTime(const int date_key,
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
   return StructToTime(parts);
  }

bool Strategy_IsUtcWeekday(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_broker,
                                 datetime &close_broker,
                                 datetime &open_utc,
                                 datetime &close_utc)
  {
   open_broker = Strategy_BrokerDateTime(date_key,
                                         strategy_cash_open_hour_broker,
                                         strategy_cash_open_minute_broker);
   close_broker = Strategy_BrokerDateTime(date_key,
                                          strategy_cash_close_hour_broker,
                                          strategy_cash_close_minute_broker);
   open_utc = QM_BrokerToUTC(open_broker);
   close_utc = QM_BrokerToUTC(close_broker);
   return (open_broker > 0 && close_broker - open_broker == 510 * 60 &&
           open_utc > 0 && close_utc > open_utc && Strategy_IsUtcWeekday(open_utc));
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GDAXI.DWX" || symbol == "UK100.DWX");
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

void Strategy_RecoverAttempt(const datetime cash_close_utc)
  {
   g_session_attempted = false;
   const datetime from_broker = QM_UTCToBroker(cash_close_utc);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_session_attempted = true;
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
        {
         g_session_attempted = true;
         return;
        }
     }
  }

bool Strategy_TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0 && MathIsValidNumber(mid));
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

bool Strategy_FirstSessionMid(const datetime cash_open_utc,
                              const datetime cash_close_utc,
                              double &mid)
  {
   mid = 0.0;
   ulong cursor = (ulong)cash_open_utc * 1000;
   const ulong stop_msc = (ulong)cash_close_utc * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   long previous_msc = 0;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_LastSessionMid(const datetime cash_open_utc,
                             const datetime cash_close_utc,
                             double &mid)
  {
   mid = 0.0;
   const ulong start_msc = (ulong)cash_open_utc * 1000;
   ulong window_end = (ulong)cash_close_utc * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   while(window_end >= start_msc)
     {
      ulong window_start = start_msc;
      if(window_end - start_msc + 1 > chunk_width)
         window_start = window_end - chunk_width + 1;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO,
                                        window_start, window_end);
      if(copied < 0)
         return false;
      long previous_msc = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
        }
      for(int i = copied - 1; i >= 0; --i)
        {
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(window_start == start_msc)
         break;
      window_end = window_start - 1;
     }
   return false;
  }

bool Strategy_IsFirstTradableTick(const datetime entry_bar_utc,
                                  const MqlTick &current_tick)
  {
   double current_mid = 0.0;
   if(!Strategy_TickMid(current_tick, current_mid))
      return false;
   ulong cursor = (ulong)entry_bar_utc * 1000;
   const ulong stop_msc = (ulong)current_tick.time_msc;
   if(stop_msc < cursor)
      return false;
   const ulong chunk_width = 60 * 1000;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      long previous_msc = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         double mid = 0.0;
         if(Strategy_TickMid(ticks[i], mid))
            return ((ulong)ticks[i].time_msc == (ulong)current_tick.time_msc);
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_BindClockExit(const datetime entry_utc,
                            datetime &exit_utc)
  {
   exit_utc = entry_utc + strategy_hold_minutes * 60;
   const datetime entry_broker = QM_UTCToBroker(entry_utc);
   const datetime exit_broker = QM_UTCToBroker(exit_utc);
   if(entry_utc <= 0 || entry_broker <= 0 || exit_broker <= entry_broker ||
      Strategy_DateKey(entry_broker) != Strategy_DateKey(exit_broker))
     {
      exit_utc = 0;
      return false;
     }
   return true;
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_session_date_key = 0;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_entry_tick_msc = 0;
   g_pending_exit_utc = 0;
   g_pending_atr = 0.0;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_signal_tf != PERIOD_M15 ||
      !SymbolIsSynchronized(_Symbol))
      return false;

   MqlRates current_bar;
   MqlRates observation_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, observation_bar))
      return false;
   const datetime entry_bar_utc = QM_BrokerToUTC(current_bar.time);
   const datetime observation_bar_utc = QM_BrokerToUTC(observation_bar.time);
   const int session_date_key = Strategy_DateKey(observation_bar.time);
   datetime cash_open_broker = 0;
   datetime cash_close_broker = 0;
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   if(!Strategy_ResolveCashSession(session_date_key,
                                   cash_open_broker,
                                   cash_close_broker,
                                   cash_open_utc,
                                   cash_close_utc) ||
      observation_bar.time != cash_close_broker || observation_bar_utc != cash_close_utc ||
      current_bar.time != cash_close_broker + 15 * 60 ||
      entry_bar_utc != cash_close_utc + 15 * 60 ||
      observation_bar.open <= 0.0 || observation_bar.high <= 0.0 ||
      observation_bar.low <= 0.0 || observation_bar.close <= 0.0)
      return false;

   Strategy_RecoverAttempt(cash_close_utc);
   if(g_session_attempted)
      return true;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) ||
      !Strategy_IsFirstTradableTick(entry_bar_utc, tick))
      return true;

   double cash_open_mid = 0.0;
   double cash_close_mid = 0.0;
   if(!Strategy_FirstSessionMid(cash_open_utc, cash_close_utc, cash_open_mid) ||
      !Strategy_LastSessionMid(cash_open_utc, cash_close_utc, cash_close_mid))
      return true;
   cash_open_mid = Strategy_TickNormalizedPrice(cash_open_mid);
   cash_close_mid = Strategy_TickNormalizedPrice(cash_close_mid);
   if(cash_open_mid <= 0.0 || cash_close_mid <= 0.0 || cash_open_mid == cash_close_mid)
      return true;

   const double frozen_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const datetime entry_tick_utc = (datetime)(tick.time_msc / 1000);
   datetime verified_exit_utc = 0;
   if(frozen_atr <= 0.0 || !MathIsValidNumber(frozen_atr) ||
      !Strategy_BindClockExit(entry_tick_utc, verified_exit_utc))
      return true;

   g_pending_session_date_key = session_date_key;
   g_pending_side = (cash_close_mid > cash_open_mid) ? 1 : -1;
   g_pending_entry_bar_utc = entry_bar_utc;
   g_pending_entry_tick_msc = (ulong)tick.time_msc;
   g_pending_exit_utc = verified_exit_utc;
   g_pending_atr = frozen_atr;
   return true;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 || point <= 0.0 ||
      tick_size <= 0.0 || tick_value <= 0.0 || entry_price <= 0.0 ||
      stop_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   if(stop_distance <= 0.0 || risk_per_lot <= 0.0)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
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
   return (strategy_variant_id == "POSTCLOSE_CONT_BASELINE" &&
           strategy_signal_tf == PERIOD_M15 && strategy_atr_period == 14 &&
           strategy_atr_stop_mult == 1.0 && strategy_hold_minutes == 240 &&
           strategy_cash_open_hour_broker == 10 &&
           strategy_cash_open_minute_broker == 0 &&
           strategy_cash_close_hour_broker == 18 &&
           strategy_cash_close_minute_broker == 30 &&
           strategy_max_spread_points >= 0);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points < 0 || spread_points > strategy_max_spread_points);
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

   if(g_pending_session_date_key <= 0 || g_pending_side == 0 ||
      g_pending_entry_bar_utc <= 0 || g_pending_entry_tick_msc == 0 ||
      g_pending_exit_utc <= 0 || g_pending_atr <= 0.0 || g_session_attempted)
      return false;
   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      QM_BrokerToUTC(current_bar.time) != g_pending_entry_bar_utc)
      return false;
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || (ulong)tick.time_msc != g_pending_entry_tick_msc ||
      tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
      return false;
   if(Strategy_WideSpread())
      return false;

   const int session_date_key = g_pending_session_date_key;
   const bool is_long = (g_pending_side > 0);
   const double frozen_atr = g_pending_atr;
   const datetime verified_exit_utc = g_pending_exit_utc;
   g_session_attempted = true;
   g_pending_session_date_key = 0;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_entry_tick_msc = 0;
   g_pending_exit_utc = 0;
   g_pending_atr = 0.0;

   const double entry_price = is_long ? tick.ask : tick.bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         is_long
                                                         ? entry_price - strategy_atr_stop_mult * frozen_atr
                                                         : entry_price + strategy_atr_stop_mult * frozen_atr);
   if(stop_price <= 0.0 || (is_long && stop_price >= entry_price) ||
      (!is_long && stop_price <= entry_price) ||
      !Strategy_TradeGeometryAndVolumeAllow(entry_price, stop_price))
      return false;

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = is_long ? "POSTCLOSE_CONT_LONG" : "POSTCLOSE_CONT_SHORT";
   g_active_exit_broker = QM_UTCToBroker(verified_exit_utc);
   if(g_active_exit_broker <= 0)
      return false;
   QM_LogEvent(QM_INFO,
               "SESSION_ENTRY_ARMED",
               StringFormat("{\"symbol\":\"%s\",\"session_date\":%d,\"session_source\":\"broker_clock\",\"exit_utc\":%I64d}",
                            _Symbol, session_date_key, (long)verified_exit_utc));
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const int session_date_key = Strategy_DateKey(open_time);
      datetime cash_open_broker = 0;
      datetime cash_close_broker = 0;
      datetime cash_open_utc = 0;
      datetime cash_close_utc = 0;
      if(!Strategy_ResolveCashSession(session_date_key,
                                      cash_open_broker,
                                      cash_close_broker,
                                      cash_open_utc,
                                      cash_close_utc) ||
         open_time < cash_close_broker + 15 * 60 ||
         open_time >= cash_close_broker + 30 * 60)
         return true;
      const datetime open_utc = QM_BrokerToUTC(open_time);
      datetime verified_exit_utc = 0;
      if(!Strategy_BindClockExit(open_utc, verified_exit_utc))
         return true;
      g_active_exit_broker = QM_UTCToBroker(verified_exit_utc);
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline retains the framework default high-impact pause.
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

   // Freeze the cash anchors and exactly one completed post-close observation
   // before the central news gate. A blocked intended entry is never delayed.
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
