#property strict
#property version   "5.0"
#property description "QM5_21525 WTI XCU CADF-qualified OLS residual reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

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
input int    qm_ea_id                   = 21525;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ols_lookback_d1   = 252;
input double strategy_entry_z           = 1.0;
input double strategy_exit_z            = 0.5;
input double strategy_cadf_t_max        = -3.043;
input double strategy_beta_min          = 0.10;
input double strategy_beta_max          = 3.00;
input double strategy_half_life_min_d1  = 2.0;
input double strategy_half_life_max_d1  = 60.0;
input int    strategy_history_bars_d1   = 340;
input int    strategy_max_endpoint_gap_days = 10;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 3.5;
input int    strategy_max_hold_days     = 60;
input int    strategy_wti_max_spread_pts = 1500;
input int    strategy_xcu_max_spread_pts = 1200;
input int    strategy_deviation_points  = 20;

string   g_leg_wti = "XTIUSD.DWX";
string   g_leg_xcu = "XCUUSD.DWX";
bool     g_basket_scope_ready = false;
double   g_residual_z = 0.0;
double   g_previous_z = 0.0;
double   g_residual_sigma = 0.0;
double   g_rolling_beta = 0.0;
double   g_adf_rho = 0.0;
double   g_cadf_t = 0.0;
double   g_half_life_d1 = 0.0;
bool     g_state_ready = false;
datetime g_last_state_bar = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_wti)
      return 0;
   if(symbol == g_leg_xcu)
      return 1;
   return -1;
  }

bool Strategy_IsHostSymbol()
  {
   return (_Symbol == g_leg_wti);
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[2] = {"XTIUSD.DWX", "XCUUSD.DWX"};
   for(int i = 0; i < 2; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, strategy_history_bars_d1);
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_SpreadWithinCap(const string symbol, const int max_points)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid || max_points <= 0)
      return false;
   const double spread_points = (ask - bid) / point;
   return (MathIsValidNumber(spread_points) && spread_points <= (double)max_points);
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

bool Strategy_PackageValid(const int expected_residual_direction = 0)
  {
   int wti_count = 0;
   int xcu_count = 0;
   ENUM_POSITION_TYPE wti_type = POSITION_TYPE_BUY;
   ENUM_POSITION_TYPE xcu_type = POSITION_TYPE_BUY;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0 || !MathIsValidNumber(sl))
         return false;

      if(symbol == g_leg_wti)
        {
         ++wti_count;
         wti_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        }
      else if(symbol == g_leg_xcu)
        {
         ++xcu_count;
         xcu_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        }
     }

   if(wti_count != 1 || xcu_count != 1 || wti_type == xcu_type)
      return false;
   if(expected_residual_direction > 0)
      return (wti_type == POSITION_TYPE_SELL && xcu_type == POSITION_TYPE_BUY);
   if(expected_residual_direction < 0)
      return (wti_type == POSITION_TYPE_BUY && xcu_type == POSITION_TYPE_SELL);
   return true;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_RefreshResidualState()
  {
   g_state_ready = false;
   g_residual_z = 0.0;
   g_previous_z = 0.0;
   g_residual_sigma = 0.0;
   g_rolling_beta = 0.0;
   g_adf_rho = 0.0;
   g_cadf_t = 0.0;
   g_half_life_d1 = 0.0;
   const int lookback = strategy_ols_lookback_d1;

   if(lookback != 252 || !Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_leg_wti) || !QM_SymbolAssertOrLog(g_leg_xcu))
      return false;

   double wti[];
   double xcu[];
   datetime wti_time[];
   datetime xcu_time[];
   ArraySetAsSeries(wti, true);
   ArraySetAsSeries(xcu, true);
   ArraySetAsSeries(wti_time, true);
   ArraySetAsSeries(xcu_time, true);

   // perf-allowed: this function is reached once per new host D1 bar, plus
   // one guarded refresh while managing an existing package.
   if(CopyClose(g_leg_wti, PERIOD_D1, 1, lookback, wti) != lookback) // perf-allowed: caller is gated to a new host D1 bar or a changed cached D1 timestamp.
      return false;
   if(CopyClose(g_leg_xcu, PERIOD_D1, 1, lookback, xcu) != lookback) // perf-allowed: caller is gated to a new host D1 bar or a changed cached D1 timestamp.
      return false;
   if(CopyTime(g_leg_wti, PERIOD_D1, 1, lookback, wti_time) != lookback) // perf-allowed: timestamp synchronization is structural and D1-gated.
      return false;
   if(CopyTime(g_leg_xcu, PERIOD_D1, 1, lookback, xcu_time) != lookback) // perf-allowed: timestamp synchronization is structural and D1-gated.
      return false;

   const datetime current_host_bar = iTime(g_leg_wti, PERIOD_D1, 0); // perf-allowed: cached host D1 timestamp for endpoint freshness and refresh gating.
   if(current_host_bar <= 0 || wti_time[0] <= 0 || wti_time[0] >= current_host_bar)
      return false;
   if(current_host_bar - wti_time[0] > (long)strategy_max_endpoint_gap_days * 86400)
      return false;

   double log_wti[];
   double log_xcu[];
   ArrayResize(log_wti, lookback);
   ArrayResize(log_xcu, lookback);
   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      if(wti_time[i] <= 0 || wti_time[i] != xcu_time[i])
         return false;
      if(i > 0 && wti_time[i] >= wti_time[i - 1])
         return false;
      if(wti[i] <= 0.0 || xcu[i] <= 0.0)
         return false;

      log_wti[i] = MathLog(wti[i]);
      log_xcu[i] = MathLog(xcu[i]);
      if(!MathIsValidNumber(log_wti[i]) || !MathIsValidNumber(log_xcu[i]))
         return false;
      sum_x += log_xcu[i];
      sum_y += log_wti[i];
     }

   const double mean_x = sum_x / (double)lookback;
   const double mean_y = sum_y / (double)lookback;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double dx = log_xcu[i] - mean_x;
      const double dy = log_wti[i] - mean_y;
      sxx += dx * dx;
      sxy += dx * dy;
     }

   if(sxx <= 1.0e-20 || !MathIsValidNumber(sxx) || !MathIsValidNumber(sxy))
      return false;

   g_rolling_beta = sxy / sxx;
   const double alpha = mean_y - g_rolling_beta * mean_x;
   if(!MathIsValidNumber(g_rolling_beta) || !MathIsValidNumber(alpha) ||
      g_rolling_beta < strategy_beta_min || g_rolling_beta > strategy_beta_max)
      return false;

   double residuals[];
   ArrayResize(residuals, lookback);
   double sum_squared_residuals = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      residuals[i] = log_wti[i] - alpha - g_rolling_beta * log_xcu[i];
      if(!MathIsValidNumber(residuals[i]))
         return false;
      sum_squared_residuals += residuals[i] * residuals[i];
     }

   g_residual_sigma = MathSqrt(sum_squared_residuals / (double)(lookback - 2));
   if(g_residual_sigma <= 1.0e-10 || !MathIsValidNumber(g_residual_sigma))
      return false;

   // Simple residual CADF proxy: delta(e_t) = c + rho*e_(t-1) + error.
   // Arrays are series, so residuals[i+1] is the chronological lag of
   // residuals[i]. With 252 residuals there are 251 regression observations.
   const int adf_count = lookback - 1;
   double sum_lag = 0.0;
   double sum_delta = 0.0;
   for(int i = 0; i < adf_count; ++i)
     {
      const double lag = residuals[i + 1];
      const double delta = residuals[i] - lag;
      sum_lag += lag;
      sum_delta += delta;
     }

   const double mean_lag = sum_lag / (double)adf_count;
   const double mean_delta = sum_delta / (double)adf_count;
   double adf_sxx = 0.0;
   double adf_sxy = 0.0;
   for(int i = 0; i < adf_count; ++i)
     {
      const double lag = residuals[i + 1];
      const double delta = residuals[i] - lag;
      const double dx = lag - mean_lag;
      adf_sxx += dx * dx;
      adf_sxy += dx * (delta - mean_delta);
     }
   if(adf_sxx <= 1.0e-20 || !MathIsValidNumber(adf_sxx) ||
      !MathIsValidNumber(adf_sxy))
      return false;

   g_adf_rho = adf_sxy / adf_sxx;
   const double adf_intercept = mean_delta - g_adf_rho * mean_lag;
   double adf_sse = 0.0;
   for(int i = 0; i < adf_count; ++i)
     {
      const double lag = residuals[i + 1];
      const double delta = residuals[i] - lag;
      const double error = delta - adf_intercept - g_adf_rho * lag;
      adf_sse += error * error;
     }

   const double adf_error_variance = adf_sse / (double)(adf_count - 2);
   const double rho_standard_error = MathSqrt(adf_error_variance / adf_sxx);
   if(g_adf_rho >= 0.0 || !MathIsValidNumber(g_adf_rho) ||
      rho_standard_error <= 0.0 || !MathIsValidNumber(rho_standard_error))
      return false;

   g_cadf_t = g_adf_rho / rho_standard_error;
   const double phi = 1.0 + g_adf_rho;
   if(!MathIsValidNumber(g_cadf_t) || g_cadf_t > strategy_cadf_t_max ||
      phi <= 0.0 || phi >= 1.0)
      return false;

   g_half_life_d1 = -MathLog(2.0) / MathLog(phi);
   if(!MathIsValidNumber(g_half_life_d1) ||
      g_half_life_d1 < strategy_half_life_min_d1 ||
      g_half_life_d1 > strategy_half_life_max_d1)
      return false;

   g_residual_z = residuals[0] / g_residual_sigma;
   g_previous_z = residuals[1] / g_residual_sigma;
   g_state_ready = (MathIsValidNumber(g_residual_z) && MathIsValidNumber(g_previous_z));
   if(g_state_ready)
      g_last_state_bar = current_host_bar;
   return g_state_ready;
  }

double Strategy_LotsForLeg(const string symbol, const double risk_weight, const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0 || !MathIsValidNumber(entry) ||
      !MathIsValidNumber(atr))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double stop = QM_OrderTypeIsBuy(type) ? entry - stop_dist
                                               : entry + stop_dist;
   if(stop_dist <= 0.0 || stop <= 0.0 || !MathIsValidNumber(stop))
      return false;

   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = NormalizeDouble(stop, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int residual_direction)
  {
   if(residual_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadWithinCap(g_leg_wti, strategy_wti_max_spread_pts) ||
      !Strategy_SpreadWithinCap(g_leg_xcu, strategy_xcu_max_spread_pts))
      return false;

   // For residual = log(WTI) - alpha - beta*log(XCU), WTI receives unit
   // aggregate stop-risk weight and copper receives abs(beta).
   const double wti_weight = 1.0;
   const double xcu_weight = MathAbs(g_rolling_beta);
   const double weight_sum = wti_weight + xcu_weight;
   if(weight_sum <= 0.0)
      return false;

   const bool positive_residual = (residual_direction > 0);
   const QM_OrderType wti_type = positive_residual ? QM_SELL : QM_BUY;
   const QM_OrderType xcu_type = positive_residual ? QM_BUY : QM_SELL;
   const string reason = positive_residual ? "QM5_21525_POS_RESIDUAL_SELL_WTI_BUY_XCU"
                                           : "QM5_21525_NEG_RESIDUAL_BUY_WTI_SELL_XCU";

   const bool wti_ok = Strategy_OpenLeg(g_leg_wti, wti_type, wti_weight, weight_sum, reason);
   if(!wti_ok)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   const bool xcu_ok = Strategy_OpenLeg(g_leg_xcu, xcu_type, xcu_weight, weight_sum, reason);
   if(xcu_ok && Strategy_PackageValid(residual_direction))
      return true;

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_ValueIs(const double value, const double expected)
  {
   return (MathAbs(value - expected) <= 1.0e-9);
  }

bool Strategy_ConfigurationAuthorized()
  {
   return (qm_ea_id == 21525 && qm_magic_slot_offset == 0 &&
           qm_rng_seed == 42 && RISK_PERCENT == 0.0 &&
           Strategy_ValueIs(RISK_FIXED, 1000.0) &&
           Strategy_ValueIs(PORTFOLIO_WEIGHT, 1.0) &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_news_stale_max_hours == 336 && qm_news_min_impact == "high" &&
           !qm_friday_close_enabled && qm_friday_close_hour_broker == 21 &&
           strategy_ols_lookback_d1 == 252 &&
           Strategy_ValueIs(qm_stress_reject_probability, 0.0) &&
           Strategy_ValueIs(strategy_entry_z, 1.0) &&
           Strategy_ValueIs(strategy_exit_z, 0.5) &&
           Strategy_ValueIs(strategy_cadf_t_max, -3.043) &&
           Strategy_ValueIs(strategy_beta_min, 0.10) &&
           Strategy_ValueIs(strategy_beta_max, 3.00) &&
           Strategy_ValueIs(strategy_half_life_min_d1, 2.0) &&
           Strategy_ValueIs(strategy_half_life_max_d1, 60.0) &&
           strategy_history_bars_d1 == 340 &&
           strategy_max_endpoint_gap_days == 10 &&
           strategy_atr_period_d1 == 20 &&
           Strategy_ValueIs(strategy_atr_sl_mult, 3.5) &&
           strategy_max_hold_days == 60 &&
           strategy_wti_max_spread_pts == 1500 &&
           strategy_xcu_max_spread_pts == 1200 &&
           strategy_deviation_points == 20);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if(!Strategy_IsHostSymbol())
      return true;
   if(!Strategy_ConfigurationAuthorized())
     {
      if(Strategy_OpenPairLegCount() > 0)
         Strategy_ClosePair(QM_EXIT_STRATEGY);
      return true;
     }
   if(Strategy_SlotForSymbol(_Symbol) != qm_magic_slot_offset)
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21525_CADF_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_RefreshResidualState())
      return false;

   if(g_residual_z > strategy_entry_z && g_previous_z <= strategy_entry_z)
      Strategy_OpenPair(1);
   else if(g_residual_z < -strategy_entry_z && g_previous_z >= -strategy_entry_z)
      Strategy_OpenPair(-1);

   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, grid, or averaging.
  }

datetime Strategy_PairOldestOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return false;
   if(open_legs != 2 || !Strategy_PackageValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   const datetime current_d1_bar = iTime(g_leg_wti, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp guard before optional residual refresh.
   if(current_d1_bar > 0 && current_d1_bar != g_last_state_bar)
      Strategy_RefreshResidualState();
   const datetime opened = Strategy_PairOldestOpenTime();
   if(opened > 0 && TimeCurrent() - opened >= (long)strategy_max_hold_days * 86400)
     {
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
      return false;
     }
   if(!g_state_ready)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   if(MathAbs(g_residual_z) <= strategy_exit_z)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_wti, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_xcu, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_wti, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xcu, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   SymbolSelect(g_leg_wti, true);
   SymbolSelect(g_leg_xcu, true);

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

   Strategy_EnsureBasketScope();

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
