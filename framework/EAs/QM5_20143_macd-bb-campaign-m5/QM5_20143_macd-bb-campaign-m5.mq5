#property strict
#property version   "5.0"
#property description "QM5_20143 macd-bb-campaign-m5 (V5)"

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
input int    strategy_fast_ema          = 6;
input int    strategy_slow_ema          = 17;
input int    strategy_bb_period         = 10;
input int    strategy_bb_shift          = 1;
input double strategy_bb_dev            = 0.66;
input double strategy_entry_offset_pips = 1.0;
input double strategy_sl_offset_pips    = 1.0;
input double strategy_tp_r              = 1.0;

enum STR104_CAMPAIGN_STATE
  {
   STR104_IDLE = 0,
   STR104_WAIT_EXTENSION,
   STR104_WAIT_PULLBACK,
   STR104_WAIT_BREAKOUT,
   STR104_PENDING,
   STR104_CONSUMED
  };

int                   g_str104_fast_handle = INVALID_HANDLE;
int                   g_str104_slow_handle = INVALID_HANDLE;
int                   g_str104_bands_handle = INVALID_HANDLE;
STR104_CAMPAIGN_STATE g_str104_state = STR104_IDLE;
int                   g_str104_direction = 0;
double                g_str104_reference_extreme = 0.0;
datetime              g_str104_cross_bar = 0;
datetime              g_str104_last_state_bar = 0;
datetime              g_str104_last_place_attempt_bar = 0;
datetime              g_str104_last_cancel_attempt_bar = 0;
datetime              g_str104_last_data_log_bar = 0;
bool                  g_str104_cancel_required = false;

bool Strategy104_ConfigValid()
  {
   return (strategy_fast_ema > 1 &&
           strategy_slow_ema > strategy_fast_ema &&
           strategy_bb_period > 1 &&
           strategy_bb_shift == 1 &&
           MathIsValidNumber(strategy_bb_dev) &&
           strategy_bb_dev > 0.0 &&
           MathIsValidNumber(strategy_entry_offset_pips) &&
           strategy_entry_offset_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_offset_pips) &&
           strategy_sl_offset_pips > 0.0 &&
           MathIsValidNumber(strategy_tp_r) &&
           MathAbs(strategy_tp_r - 1.0) < 1e-9);
  }

bool Strategy104_EnsureHandles()
  {
   if(g_str104_fast_handle == INVALID_HANDLE)
      g_str104_fast_handle =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_fast_ema,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str104_slow_handle == INVALID_HANDLE)
      g_str104_slow_handle =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_slow_ema,
                  MODE_EMA,
                  PRICE_CLOSE);

   if(g_str104_bands_handle == INVALID_HANDLE)
     {
      const string key =
         StringFormat("STR104_BB_SHIFTED|%s|%d|%d|%d|%.8f",
                      _Symbol,
                      (int)PERIOD_M5,
                      strategy_bb_period,
                      strategy_bb_shift,
                      strategy_bb_dev);
      g_str104_bands_handle = QM_IndicatorsLookup(key);
      if(g_str104_bands_handle == INVALID_HANDLE)
        {
         const int raw_handle =
            iBands(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_shift, strategy_bb_dev, PRICE_CLOSE); // perf-allowed: plot-shift=1 is source material and unsupported by QM_IndBands; handle is registered in the framework pool, never lazy-created per tick
         g_str104_bands_handle =
            QM_IndicatorsRegister(key, raw_handle);
        }
     }
   return (g_str104_fast_handle != INVALID_HANDLE &&
           g_str104_slow_handle != INVALID_HANDLE &&
           g_str104_bands_handle != INVALID_HANDLE);
  }

int Strategy104_WarmupBars()
  {
   int required = 40;
   if(strategy_slow_ema + 5 > required)
      required = strategy_slow_ema + 5;
   if(strategy_bb_period + strategy_bb_shift + 5 > required)
      required = strategy_bb_period + strategy_bb_shift + 5;
   return required;
  }

bool Strategy104_HandlesReady()
  {
   if(!Strategy104_EnsureHandles())
      return false;
   const int required = Strategy104_WarmupBars();
   return (BarsCalculated(g_str104_fast_handle) >= required &&
           BarsCalculated(g_str104_slow_handle) >= required &&
           BarsCalculated(g_str104_bands_handle) >= required);
  }

bool Strategy104_CurrentM5Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_M5,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-M5 clock for strategy-owned state, place, cancel, and retry guards
   return (bar_time > 0);
  }

void Strategy104_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str104_last_data_log_bar)
      return;
   g_str104_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-104\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy104_BandSelfTest()
  {
   if(!Strategy104_HandlesReady())
      return false;

   double closes[];
   ArrayResize(closes, strategy_bb_period);
   const int copied =
      CopyClose(_Symbol, PERIOD_M5, 1 + strategy_bb_shift, strategy_bb_period, closes); // perf-allowed: one bounded OnInit-only BB plot-shift causal self-test
   if(copied != strategy_bb_period)
      return false;

   double mean = 0.0;
   for(int i = 0; i < copied; ++i)
      mean += closes[i];
   mean /= (double)copied;

   double variance = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      const double delta = closes[i] - mean;
      variance += delta * delta;
     }
   variance /= (double)copied;
   const double sigma = MathSqrt(MathMax(0.0, variance));
   const double manual_upper = mean + strategy_bb_dev * sigma;
   const double manual_lower = mean - strategy_bb_dev * sigma;

   const int source_shift =
      1 + strategy_bb_shift;
   double upper[1];
   double lower[1];
   upper[0] = QM_IndicatorReadBuffer(g_str104_bands_handle, 1, source_shift);
   lower[0] = QM_IndicatorReadBuffer(g_str104_bands_handle, 2, source_shift);
   if(upper[0] <= 0.0 || lower[0] <= 0.0)
      return false;

   const double tick =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
              SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   const double tolerance =
      MathMax(tick * 2.0,
              MathMax(MathAbs(manual_upper),
                      MathAbs(manual_lower)) * 1e-8);
   const bool pass =
      MathIsValidNumber(upper[0]) &&
      MathIsValidNumber(lower[0]) &&
      upper[0] != EMPTY_VALUE &&
      lower[0] != EMPTY_VALUE &&
      MathAbs(upper[0] - manual_upper) <= tolerance &&
      MathAbs(lower[0] - manual_lower) <= tolerance;
   if(!pass)
      QM_LogEvent(
         QM_ERROR,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-104\",\"reason\":\"bb_shift_self_test\",\"native_upper\":%.10f,\"manual_upper\":%.10f,\"native_lower\":%.10f,\"manual_lower\":%.10f,\"tolerance\":%.10f}",
            upper[0],
            manual_upper,
            lower[0],
            manual_lower,
            tolerance));
   return pass;
  }

bool Strategy104_Init()
  {
   if(_Period != PERIOD_M5 ||
      !Strategy104_ConfigValid() ||
      !Strategy104_HandlesReady())
      return false;
   return Strategy104_BandSelfTest();
  }

bool Strategy104_ReadClosedBar(const int shift,
                               MqlRates &bar)
  {
   if(shift < 1)
      return false;
   return QM_ReadBar(_Symbol,
                     PERIOD_M5,
                     shift,
                     bar); // perf-allowed: one closed M5 record, bounded once per forming M5 bar
  }

bool Strategy104_ReadMACD(const int shift,
                          double &value)
  {
   value = 0.0;
   if(shift < 1 ||
      !Strategy104_HandlesReady())
      return false;
   const double fast =
      QM_IndicatorReadBuffer(
         g_str104_fast_handle,
         0,
         shift); // perf-allowed: pooled one-value closed-bar EMA6 read
   const double slow =
      QM_IndicatorReadBuffer(
         g_str104_slow_handle,
         0,
         shift); // perf-allowed: pooled one-value closed-bar EMA17 read
   if(!MathIsValidNumber(fast) ||
      !MathIsValidNumber(slow) ||
      fast == EMPTY_VALUE ||
      slow == EMPTY_VALUE ||
      fast <= 0.0 ||
      slow <= 0.0)
      return false;
   value = fast - slow;
   return MathIsValidNumber(value);
  }

bool Strategy104_ReadAlignedBands(const int display_shift,
                                  double &upper,
                                  double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   if(display_shift < 1 ||
      !Strategy104_HandlesReady())
      return false;
   const int source_shift =
      display_shift + strategy_bb_shift;
   upper =
      QM_IndicatorReadBuffer(
         g_str104_bands_handle,
         1,
         source_shift); // perf-allowed: pooled raw-BB one-value read from the source bar plotted on the requested closed display bar; OnInit proves shift-1 causality
   lower =
      QM_IndicatorReadBuffer(
         g_str104_bands_handle,
         2,
         source_shift); // perf-allowed: pooled raw-BB one-value read from the source bar plotted on the requested closed display bar; OnInit proves shift-1 causality
   return (MathIsValidNumber(upper) &&
           MathIsValidNumber(lower) &&
           upper != EMPTY_VALUE &&
           lower != EMPTY_VALUE &&
           upper > lower &&
           lower > 0.0);
  }

bool Strategy104_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

int Strategy104_OwnPendingCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 ||
         !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

bool Strategy104_CancelOwnPending(const string reason,
                                  const datetime forming_time,
                                  const bool paced)
  {
   if(paced &&
      forming_time > 0 &&
      forming_time == g_str104_last_cancel_attempt_bar)
      return (Strategy104_OwnPendingCount() == 0);
   if(paced && forming_time > 0)
      g_str104_last_cancel_attempt_bar = forming_time;

   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 ||
         !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return (all_ok &&
           Strategy104_OwnPendingCount() == 0);
  }

double Strategy104_PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy104_TradeTick()
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

double Strategy104_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy104_TradeTick();
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

bool Strategy104_PendingGeometryLegal(const bool buy_side,
                                      const double entry,
                                      const double sl,
                                      const double tp)
  {
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy104_TradeTick();
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const double minimum =
      MathMax(tick,
              (double)MathMax(stops_level,
                              freeze_level) * point);
   if(buy_side)
      return (entry > ask &&
              sl < entry &&
              tp > entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (entry < bid &&
           sl > entry &&
           tp < entry &&
           bid - entry + tick * 0.1 >= minimum &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

void Strategy104_Reset(const STR104_CAMPAIGN_STATE state)
  {
   g_str104_state = state;
   g_str104_direction = 0;
   g_str104_reference_extreme = 0.0;
   g_str104_cross_bar = 0;
   g_str104_last_place_attempt_bar = 0;
  }

void Strategy104_StartCampaign(const int direction,
                               const MqlRates &cross_bar)
  {
   g_str104_direction = direction;
   g_str104_state = STR104_WAIT_EXTENSION;
   g_str104_cross_bar = cross_bar.time;
   g_str104_reference_extreme =
      (direction > 0)
      ? cross_bar.high
      : cross_bar.low;
   g_str104_last_place_attempt_bar = 0;
  }

bool Strategy104_PlaceBreakout(const MqlRates &signal_bar,
                               const datetime forming_time)
  {
   if(forming_time <= 0 ||
      forming_time == g_str104_last_place_attempt_bar ||
      (g_str104_direction != 1 &&
       g_str104_direction != -1))
      return false;
   g_str104_last_place_attempt_bar = forming_time;

   const bool buy_side =
      (g_str104_direction > 0);
   const double pip = Strategy104_PipSize();
   if(pip <= 0.0 ||
      signal_bar.high <= signal_bar.low)
     {
      Strategy104_Reset(STR104_CONSUMED);
      return false;
     }

   const double entry =
      Strategy104_AlignPrice(
         buy_side
         ? signal_bar.high +
           strategy_entry_offset_pips * pip
         : signal_bar.low -
           strategy_entry_offset_pips * pip,
         buy_side ? 1 : -1);
   const double sl =
      Strategy104_AlignPrice(
         buy_side
         ? signal_bar.low -
           strategy_sl_offset_pips * pip
         : signal_bar.high +
           strategy_sl_offset_pips * pip,
         buy_side ? -1 : 1);
   const double risk =
      buy_side ? entry - sl : sl - entry;
   const double tp =
      Strategy104_AlignPrice(
         buy_side
         ? entry + strategy_tp_r * risk
         : entry - strategy_tp_r * risk,
         buy_side ? 1 : -1);

   if(!MathIsValidNumber(risk) ||
      risk <= 0.0 ||
      !Strategy104_PendingGeometryLegal(
         buy_side,
         entry,
         sl,
         tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-104\",\"reason\":\"pending_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            (long)signal_bar.time,
            entry,
            sl,
            tp));
      Strategy104_Reset(STR104_CONSUMED);
      return false;
     }

   QM_EntryRequest req;
   ZeroMemory(req);
   req.type = buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR104_CAMPAIGN_BUY_STOP"
      : "STR104_CAMPAIGN_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong out_ticket = 0;
   if(QM_TM_OpenPosition(req, out_ticket))
     {
      g_str104_state = STR104_PENDING;
      return true;
     }
   if(g_str104_direction > 0)
      g_str104_reference_extreme =
         MathMax(g_str104_reference_extreme,
                 signal_bar.high);
   else
      g_str104_reference_extreme =
         MathMin(g_str104_reference_extreme,
                 signal_bar.low);
   return false; // a later qualifying close may retry, never more than once/bar
  }

void Strategy104_ProcessClosedBar(const datetime forming_time)
  {
   if(!Strategy104_HandlesReady())
      return;

   if(g_str104_cancel_required)
     {
      if(Strategy104_OwnPendingCount() > 0 &&
         !Strategy104_CancelOwnPending(
            "deferred_cancel",
            forming_time,
            true))
         return;
      g_str104_cancel_required = false;
      Strategy104_Reset(STR104_CONSUMED);
      return;
     }

   MqlRates bar;
   if(!Strategy104_ReadClosedBar(1, bar))
     {
      Strategy104_LogDataMissing("closed_m5_bar",
                                 forming_time);
      return;
     }

   double macd_now = 0.0;
   double macd_previous = 0.0;
   if(!Strategy104_ReadMACD(1, macd_now) ||
      !Strategy104_ReadMACD(2, macd_previous))
     {
      Strategy104_LogDataMissing("ema_cross_values",
                                 forming_time);
      return;
     }

   int cross_direction = 0;
   if(macd_previous <= 0.0 &&
      macd_now > 0.0)
      cross_direction = 1;
   else if(macd_previous >= 0.0 &&
           macd_now < 0.0)
      cross_direction = -1;

   if(cross_direction != 0)
     {
      if(Strategy104_OwnPendingCount() > 0)
        {
         g_str104_cancel_required = true;
         if(!Strategy104_CancelOwnPending(
               "opposite_zero_cross",
               forming_time,
               true))
            return; // deferred-cancel latch retries once on each later bar
         g_str104_cancel_required = false;
        }
      if(Strategy104_HasOwnPosition())
        {
         // A zero cross never closes a fill. This new campaign cannot arm
         // while the older campaign's position occupies the one-position slot.
         Strategy104_Reset(STR104_CONSUMED);
         return;
        }
      Strategy104_StartCampaign(cross_direction,
                                bar);
      return; // extension must be on a later closed bar
     }

   if(Strategy104_HasOwnPosition())
     {
      Strategy104_Reset(STR104_CONSUMED);
      return;
     }
   const int pending_count =
      Strategy104_OwnPendingCount();
   if(pending_count > 0)
     {
      g_str104_state = STR104_PENDING;
      return;
     }
   if(g_str104_state == STR104_PENDING)
     {
      // The GTC order filled or disappeared. Either outcome consumes the
      // campaign; a new zero cross is required.
      Strategy104_Reset(STR104_CONSUMED);
      return;
     }
   if(g_str104_state == STR104_IDLE ||
      g_str104_state == STR104_CONSUMED ||
      (g_str104_direction != 1 &&
       g_str104_direction != -1))
      return;

   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy104_ReadAlignedBands(1,
                                    upper,
                                    lower))
     {
      Strategy104_LogDataMissing("aligned_bb_values",
                                 forming_time);
      return;
     }

   if(g_str104_state == STR104_WAIT_EXTENSION)
     {
      const bool extended =
         (g_str104_direction > 0)
         ? bar.close > upper
         : bar.close < lower;
      if(!extended)
         return;
      if(g_str104_direction > 0)
         g_str104_reference_extreme =
            MathMax(g_str104_reference_extreme,
                    bar.high);
      else
         g_str104_reference_extreme =
            MathMin(g_str104_reference_extreme,
                    bar.low);
      g_str104_state = STR104_WAIT_PULLBACK;
      return;
     }

   if(g_str104_state == STR104_WAIT_PULLBACK)
     {
      const bool contacted =
         (g_str104_direction > 0)
         ? bar.low <= upper
         : bar.high >= lower;
      if(contacted)
        {
         g_str104_state = STR104_WAIT_BREAKOUT;
         return; // pullback bar cannot also confirm the later breakout
        }
      if(g_str104_direction > 0)
         g_str104_reference_extreme =
            MathMax(g_str104_reference_extreme,
                    bar.high);
      else
         g_str104_reference_extreme =
            MathMin(g_str104_reference_extreme,
                    bar.low);
      return;
     }

   if(g_str104_state == STR104_WAIT_BREAKOUT)
     {
      const bool confirmed =
         (g_str104_direction > 0)
         ? bar.close > g_str104_reference_extreme
         : bar.close < g_str104_reference_extreme;
      if(confirmed)
        {
         Strategy104_PlaceBreakout(bar,
                                   forming_time);
         return;
        }

      // Wick-only violations replace the tracked reference extreme.
      if(g_str104_direction > 0 &&
         bar.high > g_str104_reference_extreme)
         g_str104_reference_extreme = bar.high;
      else if(g_str104_direction < 0 &&
              bar.low < g_str104_reference_extreme)
         g_str104_reference_extreme = bar.low;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy104_HasOwnPosition() ||
      Strategy104_OwnPendingCount() > 0)
      return false;
   if(_Period != PERIOD_M5 ||
      !Strategy104_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M5,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) M5 warmup gate
   if(bars_available < Strategy104_WarmupBars())
      return true;
   return !Strategy104_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return false; // Manage owns all campaign and pending-order transitions
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy104_CurrentM5Bar(forming_time))
     {
      Strategy104_LogDataMissing("forming_m5_bar", 0);
      return;
     }

   if(Strategy104_HasOwnPosition())
     {
      if(Strategy104_OwnPendingCount() > 0)
        {
         g_str104_cancel_required = true;
         if(Strategy104_CancelOwnPending(
               "filled_position_cleanup",
               forming_time,
               true))
            g_str104_cancel_required = false;
        }
      g_str104_state = STR104_CONSUMED;
     }
   if(forming_time == g_str104_last_state_bar)
      return;
   g_str104_last_state_bar = forming_time;
   Strategy104_ProcessClosedBar(forming_time);
  }

bool Strategy_ExitSignal()
  {
   return false; // fixed Method-1 SL/TP; zero crosses never close fills
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_time,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol,
                            broker_time,
                            qm_news_mode_legacy);
   if(news_allows)
      return false;

   datetime forming_time = 0;
   Strategy104_CurrentM5Bar(forming_time);
   if(Strategy104_OwnPendingCount() > 0)
     {
      g_str104_cancel_required = true;
      if(Strategy104_CancelOwnPending(
            "news_blackout",
            forming_time,
            true))
         g_str104_cancel_required = false;
     }
   Strategy104_Reset(STR104_CONSUMED);
   // A filled position has fixed Method-1 SL/TP and no campaign management.
   // Let the canonical Friday/management path continue; the later framework
   // news gate still blocks new entries. Flat/pending-only state must return
   // true here because Manage itself owns pending placement.
   return !Strategy104_HasOwnPosition();
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

   if(!Strategy104_Init())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

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
