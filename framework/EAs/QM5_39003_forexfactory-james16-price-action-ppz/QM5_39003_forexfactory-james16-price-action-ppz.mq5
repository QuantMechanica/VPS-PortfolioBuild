#property strict
#property version   "5.0"
#property description "QM5_39003 James16 D1 pinbar rejection at Price Pivot Zones"

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
input int    qm_ea_id                   = 39003;
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
input int    InpPPZLookback                         = 20;
input int    InpTrendEMA                            = 21;
input int    strategy_atr_period                    = 14;
input double strategy_ppz_zone_atr_fraction         = 0.50;
input double strategy_pinbar_wick_fraction          = 0.65;
input double strategy_pinbar_body_fraction          = 0.25;
input double strategy_spread_atr_multiplier         = 1.80;
input int    strategy_sl_buffer_pips                = 2;
input double strategy_reward_risk                   = 2.50;
input double strategy_slippage_tolerance_ticks      = 3.00;
input int    strategy_max_open_positions            = 1;
input double strategy_daily_entry_loss_limit_pct    = 2.00;
input double strategy_daily_drawdown_stop_pct       = 2.50;
input double strategy_total_drawdown_stop_pct       = 5.00;

// -----------------------------------------------------------------------------
// Card-specific state and bounded D1 structure helpers.
// -----------------------------------------------------------------------------

double g_initial_equity          = 0.0;
int    g_daily_loss_day_key      = -1;
double g_daily_loss_balance      = 0.0;
bool   g_daily_entry_loss_halted = true;

int StrategyDayKey(const datetime broker_time)
  {
   MqlDateTime parts;
   TimeToStruct(broker_time, parts);
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

void StrategyRefreshDailyEntryLossHalt(const bool force)
  {
   const int day_key = StrategyDayKey(TimeCurrent());
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   if(!force && day_key == g_daily_loss_day_key &&
      MathAbs(balance_now - g_daily_loss_balance) < 0.005)
      return;

   g_daily_loss_day_key = day_key;
   g_daily_loss_balance = balance_now;
   g_daily_entry_loss_halted = true;

   int closed_trades_today = 0;
   const double realized_today = QM_ChartUITodayPnL(0, closed_trades_today);
   const double day_start_balance = balance_now - realized_today;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return;

   g_daily_entry_loss_halted =
      (realized_today <= -(day_start_balance * strategy_daily_entry_loss_limit_pct / 100.0));
  }

bool StrategyTotalDrawdownBreached()
  {
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   return (g_initial_equity > 0.0 && equity_now > 0.0 &&
           equity_now <= g_initial_equity *
                         (1.0 - strategy_total_drawdown_stop_pct / 100.0));
  }

bool StrategyLoadClosedD1Rates(MqlRates &rates[])
  {
   const int required = InpPPZLookback + 2;
   if(required < 5)
      return false;

   ArrayResize(rates, required);
   ArraySetAsSeries(rates, true);
   // perf-allowed: one bounded D1 structure buffer, called only for an open
   // position's daily trail or after the framework's single new-bar entry gate.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required, rates);
   return (copied == required && ArraySize(rates) >= required);
  }

bool StrategyIsSwingLow(const MqlRates &rates[], const int index)
  {
   const int strength = 2;
   const int count = ArraySize(rates);
   if(index - strength < 0 || index + strength >= count)
      return false;

   const double level = rates[index].low;
   if(level <= 0.0)
      return false;
   for(int offset = 1; offset <= strength; ++offset)
     {
      if(rates[index - offset].low <= level || rates[index + offset].low <= level)
         return false;
     }
   return true;
  }

bool StrategyIsSwingHigh(const MqlRates &rates[], const int index)
  {
   const int strength = 2;
   const int count = ArraySize(rates);
   if(index - strength < 0 || index + strength >= count)
      return false;

   const double level = rates[index].high;
   if(level <= 0.0)
      return false;
   for(int offset = 1; offset <= strength; ++offset)
     {
      if(rates[index - offset].high >= level || rates[index + offset].high >= level)
         return false;
     }
   return true;
  }

bool StrategyFindPpzLevels(const MqlRates &rates[],
                           const double signal_low,
                           const double signal_high,
                           const double buy_price,
                           const double sell_price,
                           const double tolerance,
                           double &support,
                           double &resistance,
                           double &next_resistance,
                           double &next_support)
  {
   support = 0.0;
   resistance = 0.0;
   next_resistance = 0.0;
   next_support = 0.0;
   double support_distance = DBL_MAX;
   double resistance_distance = DBL_MAX;

   const int count = ArraySize(rates);
   if(count < InpPPZLookback + 2 || tolerance <= 0.0)
      return false;

   // Logical index 0 is shift 1. Indices 2..lookback-1 are shifts 3..lookback;
   // the two extra older bars provide the confirmation wing for a strength-2 pivot.
   for(int index = 2; index <= InpPPZLookback - 1; ++index)
     {
      if(index + 2 >= count)
         return false;

      if(StrategyIsSwingLow(rates, index))
        {
         const double level = rates[index].low;
         const double distance = MathAbs(signal_low - level);
         if(distance <= tolerance && distance < support_distance)
           {
            support = level;
            support_distance = distance;
           }
         if(level < sell_price && (next_support <= 0.0 || level > next_support))
            next_support = level;
        }

      if(StrategyIsSwingHigh(rates, index))
        {
         const double level = rates[index].high;
         const double distance = MathAbs(signal_high - level);
         if(distance <= tolerance && distance < resistance_distance)
           {
            resistance = level;
            resistance_distance = distance;
           }
         if(level > buy_price && (next_resistance <= 0.0 || level < next_resistance))
            next_resistance = level;
        }
     }

   return true;
  }

bool StrategyFindLatestSwing(const MqlRates &rates[],
                             const bool for_buy,
                             double &level)
  {
   level = 0.0;
   const int count = ArraySize(rates);
   if(count < InpPPZLookback + 2)
      return false;

   for(int index = 2; index <= InpPPZLookback - 1; ++index)
     {
      if(index + 2 >= count)
         return false;
      if(for_buy && StrategyIsSwingLow(rates, index))
        {
         level = rates[index].low;
         return (level > 0.0);
        }
      if(!for_buy && StrategyIsSwingHigh(rates, index))
        {
         level = rates[index].high;
         return (level > 0.0);
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   static int atr_day_key = 0;
   static double cached_atr = 0.0;
   const datetime broker_now = TimeCurrent();

   const int current_atr_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(current_atr_day_key > 0 &&
      (current_atr_day_key != atr_day_key || cached_atr <= 0.0))
     {
      atr_day_key = current_atr_day_key;
      cached_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
     }

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= strategy_max_open_positions)
      return true;

   StrategyRefreshDailyEntryLossHalt(false);
   if(g_daily_entry_loss_halted || StrategyTotalDrawdownBreached())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const datetime utc_now = QM_BrokerToUTC(broker_now);
   MqlDateTime utc_parts;
   TimeToStruct(utc_now, utc_parts);
   if((utc_parts.hour == 23 && utc_parts.min >= 55) ||
      (utc_parts.hour == 0 && utc_parts.min <= 5))
      return true;

   if(cached_atr <= 0.0)
      return true;
   // .DWX Model-4 spread can be exactly zero; only a genuinely positive,
   // overly wide spread blocks entry.
   if(ask > bid && (ask - bid) > strategy_spread_atr_multiplier * cached_atr)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) >= strategy_max_open_positions)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;
   const int deviation_points =
      (int)MathCeil(strategy_slippage_tolerance_ticks * tick_size / point);
   if(deviation_points < 1)
      return false;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     magic);

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_D1, InpTrendEMA, 1);
   if(atr <= 0.0 || ema <= 0.0)
      return false;

   MqlRates rates[];
   if(!StrategyLoadClosedD1Rates(rates))
      return false;
   const double open_1 = rates[0].open;
   const double high_1 = rates[0].high;
   const double low_1 = rates[0].low;
   const double close_1 = rates[0].close;
   if(open_1 <= 0.0 || high_1 <= low_1 || low_1 <= 0.0 || close_1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double ppz_support = 0.0;
   double ppz_resistance = 0.0;
   double next_resistance = 0.0;
   double next_support = 0.0;
   const double ppz_tolerance = strategy_ppz_zone_atr_fraction * atr;
   if(!StrategyFindPpzLevels(rates,
                             low_1,
                             high_1,
                             ask,
                             bid,
                             ppz_tolerance,
                             ppz_support,
                             ppz_resistance,
                             next_resistance,
                             next_support))
      return false;

   const double total_range = high_1 - low_1;
   const double body = MathAbs(close_1 - open_1);
   const double lower_wick = MathMin(open_1, close_1) - low_1;
   const double upper_wick = high_1 - MathMax(open_1, close_1);
   if(total_range <= 0.0 || body > strategy_pinbar_body_fraction * total_range)
      return false;

   const bool bullish_pinbar = (close_1 > open_1 &&
                                 lower_wick >= strategy_pinbar_wick_fraction * total_range);
   const bool bearish_pinbar = (close_1 < open_1 &&
                                upper_wick >= strategy_pinbar_wick_fraction * total_range);
   const bool at_support = (MathAbs(low_1 - ppz_support) <= ppz_tolerance);
   const bool at_resistance = (MathAbs(high_1 - ppz_resistance) <= ppz_tolerance);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(sl_buffer <= 0.0)
      return false;

   if(bullish_pinbar && at_support && close_1 > ema)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low_1 - sl_buffer);
      if(ask <= 0.0 || sl <= 0.0 || sl >= ask)
         return false;
      const double minimum_target = ask + strategy_reward_risk * (ask - sl);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, next_resistance);
      if(tp <= ask || tp < minimum_target)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "JAMES16_PPZ_PINBAR_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(bearish_pinbar && at_resistance && close_1 < ema)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high_1 + sl_buffer);
      if(bid <= 0.0 || sl <= bid)
         return false;
      const double minimum_target = bid - strategy_reward_risk * (sl - bid);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, next_support);
      if(tp <= 0.0 || tp >= bid || tp > minimum_target)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "JAMES16_PPZ_PINBAR_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   // A calendar key does not consume the framework's single-use new-bar gate.
   // This keeps the 20-bar structural trail out of the Model-4 per-tick path.
   static int last_trailing_day_key = 0;
   const int trailing_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(trailing_day_key <= 0 || trailing_day_key == last_trailing_day_key)
      return;
   last_trailing_day_key = trailing_day_key;

   MqlRates rates[];
   if(!StrategyLoadClosedD1Rates(rates))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(point <= 0.0 || sl_buffer <= 0.0)
      return;

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
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double current_sl = PositionGetDouble(POSITION_SL);
      double swing_level = 0.0;
      if(!StrategyFindLatestSwing(rates, is_buy, swing_level))
         continue;

      const double target_sl = QM_StopRulesNormalizePrice(
         _Symbol, is_buy ? swing_level - sl_buffer : swing_level + sl_buffer);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(target_sl <= 0.0 || market_price <= 0.0)
         continue;
      if(is_buy && target_sl >= market_price)
         continue;
      if(!is_buy && target_sl <= market_price)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? target_sl > current_sl + point * 0.5
                                    : target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "JAMES16_DYNAMIC_SWING_TRAIL");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // The framework kill switch owns the persistent 2.5% daily hard stop and
   // external 5% portfolio channel. This session-equity check makes the card's
   // 5% total-drawdown stop deterministic in the strategy tester as well.
   return StrategyTotalDrawdownBreached();
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
   if(InpPPZLookback < 10 || InpPPZLookback > 50 ||
      InpTrendEMA < 14 || InpTrendEMA > 34 ||
      strategy_atr_period < 1 ||
      strategy_ppz_zone_atr_fraction <= 0.0 ||
      strategy_pinbar_wick_fraction <= 0.0 || strategy_pinbar_wick_fraction > 1.0 ||
      strategy_pinbar_body_fraction < 0.0 || strategy_pinbar_body_fraction > 1.0 ||
      strategy_spread_atr_multiplier <= 0.0 ||
      strategy_sl_buffer_pips < 1 || strategy_reward_risk < 1.0 ||
      strategy_slippage_tolerance_ticks <= 0.0 ||
      strategy_max_open_positions < 1 ||
      strategy_daily_entry_loss_limit_pct <= 0.0 ||
      strategy_daily_drawdown_stop_pct <= strategy_daily_entry_loss_limit_pct ||
      strategy_total_drawdown_stop_pct <= strategy_daily_drawdown_stop_pct ||
      strategy_total_drawdown_stop_pct > 100.0)
      return INIT_PARAMETERS_INCORRECT;

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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   // Override the generic framework 3%/0% defaults with the approved card's
   // 2.5% daily hard stop and 5% portfolio/total-drawdown channel.
   if(!QM_KillSwitchInit(qm_ea_id,
                          QM_FrameworkMagic(),
                          strategy_daily_drawdown_stop_pct,
                          strategy_total_drawdown_stop_pct,
                          1.0))
      return INIT_FAILED;

   g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0)
      return INIT_FAILED;
   StrategyRefreshDailyEntryLossHalt(true);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_39003\",\"ea\":\"forexfactory-james16-price-action-ppz\"}");
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

   if(QM_FrameworkHandleFridayClose())
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())
      return;

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
