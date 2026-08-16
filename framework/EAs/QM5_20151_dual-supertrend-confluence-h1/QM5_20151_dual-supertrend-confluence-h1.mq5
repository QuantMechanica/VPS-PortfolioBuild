#property strict
#property version   "5.0"
#property description "QM5_20151 dual-supertrend-confluence-h1 (V5)"

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
input int    qm_ea_id                   = 9999;
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
input int    strategy_st_atr_period = 7;
input double strategy_st_fast_mult  = 0.9;
input double strategy_st_slow_mult  = 1.8;
input int    strategy_ema_period    = 99;
input int    strategy_rsi_period    = 9;
input int    strategy_adx_period    = 9;
input double strategy_adx_min       = 25.0;

#define STR141_STATE_MAX 300

MqlRates g_str141_rates[STR141_STATE_MAX];
double   g_str141_atr[STR141_STATE_MAX];
double   g_str141_fast_upper[STR141_STATE_MAX];
double   g_str141_fast_lower[STR141_STATE_MAX];
double   g_str141_fast_line[STR141_STATE_MAX];
double   g_str141_slow_upper[STR141_STATE_MAX];
double   g_str141_slow_lower[STR141_STATE_MAX];
double   g_str141_slow_line[STR141_STATE_MAX];
int      g_str141_fast_dir[STR141_STATE_MAX];
int      g_str141_slow_dir[STR141_STATE_MAX];
int      g_str141_state_count = 0;
int      g_str141_ema_handle = INVALID_HANDLE;
int      g_str141_rsi_handle = INVALID_HANDLE;
int      g_str141_adx_handle = INVALID_HANDLE;
datetime g_str141_state_forming_bar = 0;
datetime g_str141_last_entry_eval_bar = 0;
datetime g_str141_last_manage_eval_bar = 0;
datetime g_str141_last_close_attempt_bar = 0;
datetime g_str141_last_modify_attempt_bar = 0;
datetime g_str141_last_data_log_bar = 0;
datetime g_str141_exit_reserved_bar = 0;
ulong    g_str141_position_id = 0;

bool Strategy141_SymbolSlotValid()
  {
   if(_Symbol == "EURUSD.DWX")
      return (qm_magic_slot_offset == 0);
   if(_Symbol == "GBPUSD.DWX")
      return (qm_magic_slot_offset == 1);
   if(_Symbol == "USDJPY.DWX")
      return (qm_magic_slot_offset == 2);
   if(_Symbol == "USDCAD.DWX")
      return (qm_magic_slot_offset == 3);
   if(_Symbol == "AUDUSD.DWX")
      return (qm_magic_slot_offset == 4);
   if(_Symbol == "USDCHF.DWX")
      return (qm_magic_slot_offset == 5);
   if(_Symbol == "NZDUSD.DWX")
      return (qm_magic_slot_offset == 6);
   return false;
  }

bool Strategy141_ConfigValid()
  {
   return (_Period == PERIOD_H1 &&
           Strategy141_SymbolSlotValid() &&
           strategy_st_atr_period == 7 &&
           MathAbs(strategy_st_fast_mult - 0.9) < 1e-9 &&
           MathAbs(strategy_st_slow_mult - 1.8) < 1e-9 &&
           strategy_ema_period == 99 &&
           strategy_rsi_period == 9 &&
           strategy_adx_period == 9 &&
           MathAbs(strategy_adx_min - 25.0) < 1e-9);
  }

bool Strategy141_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-H1 cadence
   return (bar_time > 0);
  }

void Strategy141_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str141_last_data_log_bar)
      return;
   g_str141_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-141\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy141_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value >= 0.0);
  }

double Strategy141_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy141_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy141_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

bool Strategy141_NewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol,
                             broker_time,
                             qm_news_mode_legacy);
  }

bool Strategy141_FindOwnPosition(
   ulong &ticket,
   ulong &position_id,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_tp)
  {
   ticket = 0;
   position_id = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl =
         PositionGetDouble(POSITION_SL);
      current_tp =
         PositionGetDouble(POSITION_TP);
      return true;
     }
   return false;
  }

bool Strategy141_HasOwnPosition()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   return Strategy141_FindOwnPosition(ticket,
                                      position_id,
                                      position_type,
                                      open_price,
                                      current_sl,
                                      current_tp);
  }

bool Strategy141_EnsureHandles()
  {
   if(g_str141_ema_handle == INVALID_HANDLE)
      g_str141_ema_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H1,
                  strategy_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str141_rsi_handle == INVALID_HANDLE)
      g_str141_rsi_handle =
         QM_IndRSI(_Symbol,
                   PERIOD_H1,
                   strategy_rsi_period,
                   PRICE_CLOSE);
   if(g_str141_adx_handle == INVALID_HANDLE)
      g_str141_adx_handle =
         QM_IndADX(_Symbol,
                   PERIOD_H1,
                   strategy_adx_period);
   return (g_str141_ema_handle != INVALID_HANDLE &&
           g_str141_rsi_handle != INVALID_HANDLE &&
           g_str141_adx_handle != INVALID_HANDLE);
  }

bool Strategy141_HandlesReady()
  {
   return (Strategy141_EnsureHandles() &&
           BarsCalculated(g_str141_ema_handle) >= 220 &&
           BarsCalculated(g_str141_rsi_handle) >= 220 &&
           BarsCalculated(g_str141_adx_handle) >= 220);
  }

double Strategy141_TrueRange(const MqlRates &current,
                             const MqlRates &previous)
  {
   return MathMax(current.high - current.low,
                  MathMax(MathAbs(current.high - previous.close),
                          MathAbs(current.low - previous.close)));
  }

void Strategy141_SeedBands(const int index,
                           const double multiplier,
                           double &final_upper,
                           double &final_lower,
                           int &direction,
                           double &line)
  {
   const double mid =
      (g_str141_rates[index].high +
       g_str141_rates[index].low) * 0.5;
   final_upper = mid + multiplier * g_str141_atr[index];
   final_lower = mid - multiplier * g_str141_atr[index];
   if(g_str141_rates[index].close >= mid)
     {
      direction = 1;
      line = final_lower;
     }
   else
     {
      direction = -1;
      line = final_upper;
     }
  }

void Strategy141_RecurseBands(
   const int index,
   const double multiplier,
   const double prior_upper,
   const double prior_lower,
   const int prior_direction,
   double &final_upper,
   double &final_lower,
   int &direction,
   double &line)
  {
   const double mid =
      (g_str141_rates[index].high +
       g_str141_rates[index].low) * 0.5;
   const double basic_upper =
      mid + multiplier * g_str141_atr[index];
   const double basic_lower =
      mid - multiplier * g_str141_atr[index];
   const double prior_close =
      g_str141_rates[index - 1].close;
   final_upper =
      (basic_upper < prior_upper ||
       prior_close > prior_upper)
      ? basic_upper
      : prior_upper;
   final_lower =
      (basic_lower > prior_lower ||
       prior_close < prior_lower)
      ? basic_lower
      : prior_lower;

   if(prior_direction < 0)
     {
      if(g_str141_rates[index].close <= final_upper)
        {
         direction = -1;
         line = final_upper;
        }
      else
        {
         direction = 1;
         line = final_lower;
        }
     }
   else
     {
      if(g_str141_rates[index].close >= final_lower)
        {
         direction = 1;
         line = final_lower;
        }
      else
        {
         direction = -1;
         line = final_upper;
        }
     }
  }

bool Strategy141_BuildClosedState(const datetime forming_time)
  {
   if(forming_time > 0 &&
      forming_time == g_str141_state_forming_bar &&
      g_str141_state_count >= 220)
      return true;
   if(!Strategy141_HandlesReady())
      return false;

   const long available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: bounded state-array sizing
   int count = (int)MathMin((double)available - 1.0,
                            (double)STR141_STATE_MAX);
   if(count < 220)
      return false;

   ArrayInitialize(g_str141_atr, 0.0);
   ArrayInitialize(g_str141_fast_upper, 0.0);
   ArrayInitialize(g_str141_fast_lower, 0.0);
   ArrayInitialize(g_str141_fast_line, 0.0);
   ArrayInitialize(g_str141_slow_upper, 0.0);
   ArrayInitialize(g_str141_slow_lower, 0.0);
   ArrayInitialize(g_str141_slow_line, 0.0);
   ArrayInitialize(g_str141_fast_dir, 0);
   ArrayInitialize(g_str141_slow_dir, 0);

   for(int index = 0; index < count; ++index)
     {
      const int shift = count - index;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_H1,
                     shift,
                     g_str141_rates[index])) // perf-allowed: sanctioned bounded closed-H1 state-array rebuild
        {
         Strategy141_LogDataMissing("supertrend_rates",
                                    forming_time);
         return false;
        }
     }

   double tr_seed_sum = 0.0;
   for(int index = 1; index < count; ++index)
     {
      const double tr =
         Strategy141_TrueRange(g_str141_rates[index],
                               g_str141_rates[index - 1]);
      if(!MathIsValidNumber(tr) || tr <= 0.0)
         return false;
      if(index <= strategy_st_atr_period)
         tr_seed_sum += tr;
      if(index < strategy_st_atr_period)
         continue;
      if(index == strategy_st_atr_period)
        {
         g_str141_atr[index] =
            tr_seed_sum /
            (double)strategy_st_atr_period;
         Strategy141_SeedBands(
            index,
            strategy_st_fast_mult,
            g_str141_fast_upper[index],
            g_str141_fast_lower[index],
            g_str141_fast_dir[index],
            g_str141_fast_line[index]);
         Strategy141_SeedBands(
            index,
            strategy_st_slow_mult,
            g_str141_slow_upper[index],
            g_str141_slow_lower[index],
            g_str141_slow_dir[index],
            g_str141_slow_line[index]);
         continue;
        }

      g_str141_atr[index] =
         (((double)strategy_st_atr_period - 1.0) *
          g_str141_atr[index - 1] + tr) /
         (double)strategy_st_atr_period;
      Strategy141_RecurseBands(
         index,
         strategy_st_fast_mult,
         g_str141_fast_upper[index - 1],
         g_str141_fast_lower[index - 1],
         g_str141_fast_dir[index - 1],
         g_str141_fast_upper[index],
         g_str141_fast_lower[index],
         g_str141_fast_dir[index],
         g_str141_fast_line[index]);
      Strategy141_RecurseBands(
         index,
         strategy_st_slow_mult,
         g_str141_slow_upper[index - 1],
         g_str141_slow_lower[index - 1],
         g_str141_slow_dir[index - 1],
         g_str141_slow_upper[index],
         g_str141_slow_lower[index],
         g_str141_slow_dir[index],
         g_str141_slow_line[index]);
     }

   g_str141_state_count = count;
   g_str141_state_forming_bar = forming_time;
   return (g_str141_fast_dir[count - 1] != 0 &&
           g_str141_fast_dir[count - 2] != 0 &&
           g_str141_slow_dir[count - 1] != 0 &&
           g_str141_slow_dir[count - 2] != 0);
  }

bool Strategy141_ReadConfluence(double &ema_1,
                                double &ema_2,
                                double &rsi_1,
                                double &adx_1)
  {
   ema_1 =
      QM_IndicatorReadBuffer(
         g_str141_ema_handle,
         0,
         1); // perf-allowed: pooled closed-H1 EMA shift 1
   ema_2 =
      QM_IndicatorReadBuffer(
         g_str141_ema_handle,
         0,
         2); // perf-allowed: pooled closed-H1 EMA shift 2
   rsi_1 =
      QM_IndicatorReadBuffer(
         g_str141_rsi_handle,
         0,
         1); // perf-allowed: pooled closed-H1 RSI shift 1
   adx_1 =
      QM_IndicatorReadBuffer(
         g_str141_adx_handle,
         0,
         1); // perf-allowed: pooled closed-H1 ADX main shift 1
   return (Strategy141_IndicatorValid(ema_1) &&
           Strategy141_IndicatorValid(ema_2) &&
           Strategy141_IndicatorValid(rsi_1) &&
           Strategy141_IndicatorValid(adx_1) &&
           ema_1 > 0.0 &&
           ema_2 > 0.0);
  }

bool Strategy141_EntryStopLegal(const bool buy_side,
                                const double entry,
                                const double sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy141_TradeTick();
   if(entry <= 0.0 || sl <= 0.0 ||
      point <= 0.0 || tick <= 0.0)
      return false;
   const long broker_level =
      MathMax(SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_STOPS_LEVEL),
              SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_FREEZE_LEVEL));
   const double minimum =
      MathMax(tick,
              (double)broker_level * point);
   if(buy_side)
      return (sl < entry &&
              entry - sl + tick * 0.1 >= minimum);
   return (sl > entry &&
           sl - entry + tick * 0.1 >= minimum);
  }

bool Strategy141_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy141_TradeTick();
   if(candidate <= 0.0 || point <= 0.0 || tick <= 0.0)
      return false;
   const long broker_level =
      MathMax(SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_STOPS_LEVEL),
              SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_FREEZE_LEVEL));
   const double minimum =
      MathMax(tick,
              (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy141_HasOwnPosition())
      return false;
   if(!Strategy141_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) 220-bar warmup gate
   return (bars_available < 220 ||
           !Strategy141_HandlesReady());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy141_CurrentBar(forming_time))
     {
      Strategy141_LogDataMissing("forming_h1_bar", 0);
      return false;
     }
   if(forming_time == g_str141_last_entry_eval_bar)
      return false;
   g_str141_last_entry_eval_bar = forming_time;

   if(!Strategy141_ConfigValid() ||
      forming_time == g_str141_exit_reserved_bar ||
      Strategy141_HasOwnPosition() ||
      !Strategy141_BuildClosedState(forming_time))
      return false;

   double ema_1 = 0.0;
   double ema_2 = 0.0;
   double rsi_1 = 0.0;
   double adx_1 = 0.0;
   if(!Strategy141_ReadConfluence(ema_1,
                                  ema_2,
                                  rsi_1,
                                  adx_1))
     {
      Strategy141_LogDataMissing("closed_h1_confluence",
                                 forming_time);
      return false;
     }

   const int newest = g_str141_state_count - 1;
   const int previous = newest - 1;
   const bool long_signal =
      (g_str141_fast_dir[previous] < 0 &&
       g_str141_fast_dir[newest] > 0 &&
       g_str141_slow_dir[previous] > 0 &&
       g_str141_slow_dir[newest] > 0 &&
       ema_1 > ema_2 &&
       rsi_1 > 50.0 &&
       adx_1 > strategy_adx_min);
   const bool short_signal =
      (g_str141_slow_dir[previous] > 0 &&
       g_str141_slow_dir[newest] < 0 &&
       g_str141_fast_dir[previous] < 0 &&
       g_str141_fast_dir[newest] < 0 &&
       ema_1 < ema_2 &&
       rsi_1 < 50.0 &&
       adx_1 > strategy_adx_min);
   if(long_signal == short_signal)
      return false;

   const bool buy_side = long_signal;
   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double raw_sl =
      buy_side
      ? g_str141_fast_line[newest]
      : g_str141_slow_line[newest];
   const double sl =
      Strategy141_AlignPrice(raw_sl,
                             buy_side ? -1 : 1);
   if(!Strategy141_EntryStopLegal(buy_side,
                                  entry,
                                  sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-141\",\"reason\":\"supertrend_stop_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f}",
            (long)forming_time,
            entry,
            sl));
      return false;
     }

   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      buy_side
      ? "STR141_FAST_FLIP_LONG"
      : "STR141_SLOW_FLIP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   if(!Strategy141_FindOwnPosition(ticket,
                                   position_id,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp))
     {
      g_str141_position_id = 0;
      g_str141_last_manage_eval_bar = 0;
      g_str141_last_close_attempt_bar = 0;
      g_str141_last_modify_attempt_bar = 0;
      return;
     }

   datetime forming_time = 0;
   if(!Strategy141_CurrentBar(forming_time) ||
      forming_time == g_str141_last_manage_eval_bar)
      return;
   if(position_id != g_str141_position_id)
     {
      g_str141_position_id = position_id;
      g_str141_last_close_attempt_bar = 0;
      g_str141_last_modify_attempt_bar = 0;
     }
   if(!Strategy141_BuildClosedState(forming_time))
     {
      Strategy141_LogDataMissing("manage_supertrend_state",
                                 forming_time);
      return;
     }

   double ema_1 = 0.0;
   double ema_2 = 0.0;
   double rsi_1 = 0.0;
   double adx_1 = 0.0;
   if(!Strategy141_ReadConfluence(ema_1,
                                  ema_2,
                                  rsi_1,
                                  adx_1))
      return;
   g_str141_last_manage_eval_bar = forming_time;

   const int newest = g_str141_state_count - 1;
   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const bool exit_signal =
      buy_side
      ? (g_str141_fast_dir[newest] < 0 ||
         g_str141_slow_dir[newest] < 0 ||
         ema_1 < ema_2)
      : (g_str141_fast_dir[newest] > 0 ||
         g_str141_slow_dir[newest] > 0 ||
         ema_1 > ema_2);
   if(exit_signal)
     {
      g_str141_exit_reserved_bar = forming_time;
      if(forming_time != g_str141_last_close_attempt_bar)
        {
         g_str141_last_close_attempt_bar = forming_time;
         QM_TM_ClosePosition(ticket,
                             QM_EXIT_STRATEGY);
        }
      return;
     }

   const double raw_candidate =
      buy_side
      ? g_str141_fast_line[newest]
      : g_str141_slow_line[newest];
   const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy141_AlignPrice(raw_candidate,
                             buy_side ? -1 : 1));
   const double tick = Strategy141_TradeTick();
   const bool tightens =
      (candidate > 0.0 && tick > 0.0 &&
       (buy_side
        ? candidate > current_sl + tick * 0.5
        : (current_sl <= 0.0 ||
           candidate < current_sl - tick * 0.5)));
   if(!tightens ||
      forming_time == g_str141_last_modify_attempt_bar ||
      !Strategy141_PositionStopLegal(position_type,
                                     candidate))
      return;
   g_str141_last_modify_attempt_bar = forming_time;
   QM_TM_MoveSL(ticket,
                candidate,
                buy_side
                ? "STR141_FAST_ST_RATCHET"
                : "STR141_SLOW_ST_RATCHET");
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy141_NewsAllows(broker_time))
      return false;
   return !Strategy141_HasOwnPosition();
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
