#property strict
#property version   "5.1"
#property description "QM5_12821 T-WIN Currency-Strength Cluster Basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>
#include <QM/QM_CurrencyStrength.mqh>
#include <QM/QM_MTFCoherence.mqh>
#include <QM/QM_PullbackGate.mqh>
#include <QM/QM_BasketBuilder.mqh>
#include <QM/QM_BasketEquityStop.mqh>
#include <QM/QM_TWINWarmupGuard.mqh>

#define QM12821_HOST_SYMBOL "EURUSD.DWX"
#define QM12821_HOST_TF PERIOD_H1

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12821;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_exhaustion_norm       = 95.0;
input int    strategy_prob_min_numerator    = 6;
input double strategy_basket_tp_pct         = 15.0;
input double strategy_basket_tp_units_per_lot = 0.0;
input double strategy_basket_stop_pct       = 1.0;
input double strategy_total_lots_per_1000   = 0.10;
input int    strategy_london_start_hhmm     = 630;
input int    strategy_london_end_hhmm       = 830;
input int    strategy_overlap_start_hhmm    = 930;
input int    strategy_overlap_end_hhmm      = 1000;
input int    strategy_flat_hhmm             = 2100;
input int    strategy_deviation_points      = 20;
input int    strategy_warmup_bars           = 360;
input int    strategy_pullback_ema_period   = 20;
input int    strategy_pullback_atr_period   = 14;
input double strategy_pullback_boundary_atr = 0.25;
input double strategy_pullback_max_chase_atr = 1.00;
input int    strategy_pullback_volume_lookback = 20;
input double strategy_pullback_volume_max_ratio = 1.00;
input int    strategy_pullback_min_legs     = 7;
input int    strategy_pending_expiration_minutes = 60; // <=0: cycle-scoped GTC (canceled on cycle teardown)
input bool   strategy_pending_reproject     = false;
input int    strategy_exit_signal_mode      = 0;  // 0=legacy full-stack decay, 1=D1 ranking-decay only
// false = exit only on a true strength FLIP, not when the momentary entry
// alignment expires. Full-run 20260702_094031: decay-close forced median
// 0.9h holds; measured edge is positive only >4h (4-12h +106/61%, 12-24h +42/94%).
input bool   strategy_close_on_signal_decay = true;

int  g_active_currency_idx = -1;
int  g_active_direction    = 0;
bool g_cycle_stopped       = false;
// D1 calendar key of the day the equity stop fired. The stop is per-CYCLE
// (DL-081 / card): it kills the current basket, not the EA. Without a re-arm
// the flag latched forever once flat (Strategy_NoTradeFilter short-circuits
// before QM12821_CheckBasketRisk's reset can ever run again).
int  g_cycle_stopped_daykey = 0;
datetime g_mtf_warmup_first_bar_time = 0;
datetime g_mtf_warmup_ready_time     = 0;
bool     g_mtf_warmup_logged         = false;
datetime g_pending_reproject_last_m30_bar = 0;
bool     g_pending_reproject_leg_stopped[QM_BASKET_BUILDER_MAX_LEGS];

int QM12821_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   return hh * 60 + mm;
  }

int QM12821_BrokerHhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 100 + dt.min;
  }

bool QM12821_InWindow(const int now_hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = QM12821_HhmmToMinutes(now_hhmm);
   const int start_m = QM12821_HhmmToMinutes(start_hhmm);
   const int end_m = QM12821_HhmmToMinutes(end_hhmm);
   if(start_m <= end_m)
      return (now_m >= start_m && now_m <= end_m);
   return (now_m >= start_m || now_m <= end_m);
  }

bool QM12821_InEntrySession(const datetime broker_time)
  {
   const int now_hhmm = QM12821_BrokerHhmm(broker_time);
   if(now_hhmm < 300)
      return false;
   if(QM12821_InWindow(now_hhmm, 0, 100))
      return false;
   if(QM12821_InWindow(now_hhmm, strategy_london_start_hhmm, strategy_london_end_hhmm))
      return true;
   if(QM12821_InWindow(now_hhmm, strategy_overlap_start_hhmm, strategy_overlap_end_hhmm))
      return true;
   return false;
  }

bool QM12821_TimeToFlat(const datetime broker_time)
  {
   if(strategy_flat_hhmm <= 0)
      return false;
   return (QM12821_HhmmToMinutes(QM12821_BrokerHhmm(broker_time)) >=
           QM12821_HhmmToMinutes(strategy_flat_hhmm));
  }

void QM12821_InitMtfWarmupGuard()
  {
   g_mtf_warmup_first_bar_time = iTime(QM12821_HOST_SYMBOL, QM12821_HOST_TF, 0);
   if(g_mtf_warmup_first_bar_time <= 0)
      g_mtf_warmup_first_bar_time = TimeCurrent();
   g_mtf_warmup_ready_time = QM_TWIN_MtfWarmupReadyTime(g_mtf_warmup_first_bar_time);
   g_mtf_warmup_logged = false;
  }

bool QM12821_MtfWarmupReady(const datetime broker_time)
  {
   return QM_TWIN_MtfWarmupReady(g_mtf_warmup_first_bar_time, broker_time);
  }

bool QM12821_BlockEntryForMtfWarmup(const datetime broker_time)
  {
   if(QM12821_MtfWarmupReady(broker_time))
      return false;
   if(!g_mtf_warmup_logged)
     {
      QM_LogEvent(QM_INFO, "BASKET_MTF_WARMUP_BLOCK",
                  StringFormat("{\"first_bar_time\":%I64d,\"ready_time\":%I64d,\"broker_time\":%I64d,\"w1_periods\":%d,\"mn_days\":%d}",
                               (long)g_mtf_warmup_first_bar_time,
                               (long)g_mtf_warmup_ready_time,
                               (long)broker_time,
                               QM_TWIN_MTF_WARMUP_W1_PERIODS,
                               QM_TWIN_MTF_WARMUP_MN_DAYS));
      g_mtf_warmup_logged = true;
     }
   return true;
  }

bool QM12821_HasOwnedPositions()
  {
   return QM_BasketEquityStop_HasOwnedPositions();
  }

bool QM12821_HasOwnedPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      const long magic = OrderGetInteger(ORDER_MAGIC);
      const string symbol = OrderGetString(ORDER_SYMBOL);
      if(QM_FrameworkOwnsMagicSymbol(magic, symbol))
         return true;
     }
   return false;
  }

bool QM12821_HasOwnedExposure()
  {
   return (QM12821_HasOwnedPositions() || QM12821_HasOwnedPendingOrders());
  }

void QM12821_ResetPendingReprojectState()
  {
   g_pending_reproject_last_m30_bar = 0;
   for(int i = 0; i < QM_BASKET_BUILDER_MAX_LEGS; ++i)
      g_pending_reproject_leg_stopped[i] = false;
  }

void QM12821_ResetActiveCycle()
  {
   g_active_currency_idx = -1;
   g_active_direction = 0;
   QM12821_ResetPendingReprojectState();
  }

int QM12821_CloseAllOwned(const QM_ExitReason reason)
  {
   const int closed = QM_BasketEquityStop_CloseAllOwned(reason);
   int canceled = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      const long magic = OrderGetInteger(ORDER_MAGIC);
      const string symbol = OrderGetString(ORDER_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, "twin_basket_cancel"))
         ++canceled;
     }
   if(closed > 0 || canceled > 0)
      QM12821_ResetActiveCycle();
   return closed + canceled;
  }

QM_OrderType QM12821_LegPendingOrderType(const QM_BasketLeg &leg)
  {
   return QM_OrderTypeIsBuy(leg.type) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
  }

bool QM12821_HasOwnedPositionForSymbol(const string symbol)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(position_symbol == symbol && QM_FrameworkOwnsMagicSymbol(magic, position_symbol))
         return true;
     }
   return false;
  }

bool QM12821_FindOwnedPendingForLeg(const QM_BasketLeg &leg,
                                    ulong &out_ticket,
                                    double &out_lots)
  {
   out_ticket = 0;
   out_lots = 0.0;
   const ENUM_ORDER_TYPE expected_type = QM_OrderTypeToMT5(QM12821_LegPendingOrderType(leg));
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      const long magic = OrderGetInteger(ORDER_MAGIC);
      const string symbol = OrderGetString(ORDER_SYMBOL);
      if(symbol != leg.symbol || !QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != expected_type)
         continue;

      out_ticket = ticket;
      out_lots = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(out_lots <= 0.0)
         out_lots = OrderGetDouble(ORDER_VOLUME_INITIAL);
      return true;
     }
   return false;
  }

int QM12821_CancelPendingForLeg(const QM_BasketLeg &leg, const string reason)
  {
   int canceled = 0;
   const ENUM_ORDER_TYPE expected_type = QM_OrderTypeToMT5(QM12821_LegPendingOrderType(leg));
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      const long magic = OrderGetInteger(ORDER_MAGIC);
      const string symbol = OrderGetString(ORDER_SYMBOL);
      if(symbol != leg.symbol || !QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != expected_type)
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         ++canceled;
     }
   return canceled;
  }

bool QM12821_EntryNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool QM12821_LegBeyondReprojectChase(const QM_BasketLeg &leg,
                                     const double boundary_price,
                                     double &out_chase_atr)
  {
   out_chase_atr = 0.0;
   if(boundary_price <= 0.0)
      return false;

   const double atr = QM_ATR(leg.symbol, PERIOD_M30, strategy_pullback_atr_period, 1);
   if(atr <= 0.0)
      return false;

   MqlRates rates[];
   if(CopyRates(leg.symbol, PERIOD_M30, 1, 1, rates) != 1 || rates[0].close <= 0.0)
      return false;

   const int dir = QM_OrderTypeIsBuy(leg.type) ? 1 : -1;
   out_chase_atr = ((rates[0].close - boundary_price) / atr) * (double)dir;
   return (out_chase_atr > MathMax(0.0, strategy_pullback_max_chase_atr));
  }

double QM12821_BaseRiskMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0 || RISK_PERCENT <= 0.0)
      return 0.0;
   return equity * RISK_PERCENT / 100.0;
  }

double QM12821_LotsPerLeg(const string symbol, const int leg_count)
  {
   if(leg_count <= 0 || strategy_total_lots_per_1000 <= 0.0)
      return 0.0;

   const double base_money = QM12821_BaseRiskMoney();
   if(base_money <= 0.0)
      return 0.0;

   const double raw_total_lots = (base_money / 1000.0) * strategy_total_lots_per_1000;
   const double raw_leg_lots = raw_total_lots / (double)leg_count;
   return QM_BasketNormalizeLots(symbol, raw_leg_lots);
  }

bool QM12821_EvaluateSignal(QM_CSMReading &d1,
                            QM_CSMReading &w1,
                            QM_CSMReading &mn,
                            QM_MTFCoherenceState &mtf,
                            QM_BasketPlan &plan,
                            double &out_probability)
  {
   out_probability = 0.0;
   QM_BasketBuilder_Reset(plan);

   if(!QM12821_MtfWarmupReady(TimeCurrent()))
      return false;

   if(!QM_CSM_LoadStrength(PERIOD_D1, d1, 0))
      return false;
   if(d1.extreme_idx < 0 || d1.extreme_sign == 0)
      return false;
   if(!QM_CSM_IsExhausted(d1, d1.extreme_idx, strategy_exhaustion_norm))
      return false;

   if(!QM_CSM_LoadStrength(PERIOD_W1, w1, 0))
      return false;
   if(!QM_CSM_LoadStrength(PERIOD_MN1, mn, 0))
      return false;
   if(!QM_MTFCoherence_Evaluate(d1, w1, mn, d1.extreme_idx, mtf))
      return false;

   out_probability = QM_CSM_ProbabilityRatio(d1, d1.extreme_idx);
   const double required_probability = (double)MathMax(1, strategy_prob_min_numerator) /
                                       (double)QM_CSM_CROSSES_PER_CURRENCY;
   if(out_probability < required_probability)
      return false;

   return QM_BasketBuilder_ModeC(d1.extreme_idx, d1.extreme_sign, plan);
  }

// Faithful pullback mechanic (Giavon T-WIN / U.F.O., design-gap findings 2026-07-01 section 2):
// when the CSM signal fires the extreme currency's crosses have ALREADY run past their M30
// fair price (that is what makes the currency exhausted). We do NOT wait for the pullback to
// have happened on the current bar -- instead we place a PENDING LIMIT for every leg at its
// M30 fair-price boundary (lower dotted line for BUY legs, upper dotted line for SELL legs).
// The limit sitting at the boundary IS the "wait for the pullback / never chase" mechanism:
// it fills only if price retraces to the boundary, and expires otherwise. So this routine only
// computes each leg's boundary; it never vetoes on "already extended". tick-volume / distance
// are logged per leg for later fill-time calibration, but never block placement (that would
// break the symmetric 7-leg basket and defeat the limit mechanism).
bool QM12821_ComputeBasketBoundaries(const QM_BasketPlan &plan,
                                     double &pending_prices[],
                                     int &legs_ready,
                                     int &extended_count)
  {
   legs_ready = 0;
   extended_count = 0;
   ArrayResize(pending_prices, plan.leg_count);
   ArrayInitialize(pending_prices, 0.0);
   if(plan.leg_count <= 0)
      return false;

   for(int i = 0; i < plan.leg_count; ++i)
     {
      const string symbol = plan.legs[i].symbol;
      if(StringLen(symbol) <= 0)
         continue;
      if(!SymbolSelect(symbol, true))
         continue;

      const double fair_price = QM_EMA(symbol, PERIOD_M30, strategy_pullback_ema_period, 1, PRICE_CLOSE);
      const double atr = QM_ATR(symbol, PERIOD_M30, strategy_pullback_atr_period, 1);
      if(fair_price <= 0.0 || atr <= 0.0)
         continue;

      const double boundary_price = QM_PullbackGate_BoundaryPrice(fair_price, atr,
                                                                  plan.legs[i].type,
                                                                  strategy_pullback_boundary_atr);
      if(boundary_price <= 0.0)
         continue;

      pending_prices[i] = boundary_price;
      ++legs_ready;

      // Diagnostics only (never a placement veto): how far current price sits beyond fair
      // in the trade direction, plus tick-volume context for a future fill-time filter.
      MqlRates rates[];
      double distance_atr = 0.0;
      double tick_vol = 0.0;
      if(CopyRates(symbol, PERIOD_M30, 1, 1, rates) == 1 && rates[0].close > 0.0)
        {
         const int dir = QM_OrderTypeIsBuy(plan.legs[i].type) ? 1 : -1;
         distance_atr = ((rates[0].close - fair_price) / atr) * (double)dir;
         tick_vol = (double)rates[0].tick_volume;
         if(distance_atr > MathMax(0.0, strategy_pullback_max_chase_atr))
            ++extended_count;
        }
      double avg_vol = 0.0;
      if(strategy_pullback_volume_lookback > 0)
        {
         MqlRates hist[];
         const int got = CopyRates(symbol, PERIOD_M30, 2, strategy_pullback_volume_lookback, hist);
         if(got > 0)
           {
            double tot = 0.0;
            for(int h = 0; h < got; ++h)
               tot += (double)hist[h].tick_volume;
            avg_vol = tot / (double)got;
           }
        }
      QM_LogEvent(QM_INFO, "BASKET_LEG_LIMIT",
                  StringFormat("{\"symbol\":\"%s\",\"type\":\"%s\",\"boundary\":%.5f,\"fair\":%.5f,\"atr\":%.5f,\"distance_atr\":%.3f,\"tick_vol\":%.0f,\"avg_vol\":%.1f}",
                               symbol,
                               QM_OrderTypeIsBuy(plan.legs[i].type) ? "buy_limit" : "sell_limit",
                               boundary_price, fair_price, atr, distance_atr,
                               tick_vol, avg_vol));
     }

   // The symmetric basket needs a valid boundary for EVERY leg. If any leg's M30 data is not
   // ready (early warmup / missing history), skip this signal rather than open a partial basket.
   return (legs_ready == plan.leg_count);
  }

bool QM12821_OpenPlan(const QM_BasketPlan &plan,
                      const double probability,
                      const double &pending_prices[])
  {
   if(plan.leg_count != QM_BASKET_BUILDER_MAX_LEGS)
      return false;
   if(ArraySize(pending_prices) < plan.leg_count)
      return false;

   int opened = 0;
   for(int i = 0; i < plan.leg_count; ++i)
     {
      const string symbol = plan.legs[i].symbol;
      if(!SymbolSelect(symbol, true))
         continue;

      const double lots = QM12821_LotsPerLeg(symbol, plan.leg_count);
      if(lots <= 0.0)
         continue;
      if(pending_prices[i] <= 0.0)
         continue;

      QM_BasketOrderRequest req;
      req.symbol = symbol;
      req.type = QM_OrderTypeIsBuy(plan.legs[i].type) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
      req.price = pending_prices[i];
      req.sl = 0.0;
      req.tp = 0.0;
      req.lots = lots;
      req.reason = StringFormat("TWIN_MODE_C_%s_%s",
                                QM_CSM_CCY[plan.currency_idx],
                               plan.direction > 0 ? "STRONG" : "WEAK");
      req.symbol_slot = plan.legs[i].symbol_slot;
      req.expiration_seconds = (strategy_pending_expiration_minutes <= 0)
                               ? 0
                               : strategy_pending_expiration_minutes * 60;

      ulong ticket = 0;
      if(QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket))
         ++opened;
     }

   if(opened != plan.leg_count)
     {
      const int closed = QM12821_CloseAllOwned(QM_EXIT_STRATEGY);
      QM_LogEvent(QM_WARN, "BASKET_PARTIAL_ABORT",
                  StringFormat("{\"attempted\":%d,\"opened\":%d,\"closed\":%d}",
                               plan.leg_count, opened, closed));
      return false;
     }

   g_active_currency_idx = plan.currency_idx;
   g_active_direction = plan.direction;
   g_cycle_stopped = false;
   QM12821_ResetPendingReprojectState();
   g_pending_reproject_last_m30_bar = iTime(QM12821_HOST_SYMBOL, PERIOD_M30, 1);
   QM_LogEvent(QM_INFO, "BASKET_CYCLE_OPEN",
               StringFormat("{\"currency\":\"%s\",\"direction\":%d,\"legs\":%d,\"probability\":%.4f,\"order_type\":\"limit_at_m30_boundary\"}",
                            QM_CSM_CCY[plan.currency_idx],
                            plan.direction,
                            plan.leg_count,
                            probability));
   return true;
  }

void QM12821_CheckBasketRisk()
  {
   if(!QM12821_HasOwnedExposure())
     {
      QM12821_ResetActiveCycle();
      g_cycle_stopped = false;
      return;
     }

   if(QM12821_TimeToFlat(TimeCurrent()))
     {
      const int closed = QM12821_CloseAllOwned(QM_EXIT_TIME_STOP);
      if(closed > 0)
         QM_LogEvent(QM_INFO, "BASKET_FLAT_TIME", StringFormat("{\"closed_or_canceled\":%d}", closed));
      return;
     }

   if(!QM12821_HasOwnedPositions())
      return;

   QM_ExitReason reason = QM_EXIT_STRATEGY;
   double pnl = 0.0;
   double threshold = 0.0;
   double open_lots = 0.0;
   int closed_by_equity = 0;
   if(strategy_basket_tp_units_per_lot > 0.0)
      closed_by_equity = QM_BasketEquityStop_EnforceUnitsPerLot(strategy_basket_stop_pct,
                                                                strategy_basket_tp_units_per_lot,
                                                                reason,
                                                                pnl,
                                                                threshold,
                                                                open_lots);
   else
      closed_by_equity = QM_BasketEquityStop_Enforce(strategy_basket_stop_pct,
                                                     strategy_basket_tp_pct,
                                                     reason,
                                                     pnl,
                                                     threshold);
   if(closed_by_equity > 0)
     {
      if(reason == QM_EXIT_KILLSWITCH)
        {
         g_cycle_stopped = true;
         g_cycle_stopped_daykey = QM_CalendarPeriodKey(PERIOD_D1, _Symbol);
        }
      // The equity-stop module closes POSITIONS only. The cycle's pending leg
      // limits must die with the cycle, or late fills re-open exposure past
      // the 1% cap with the cycle already reset.
      QM12821_CloseAllOwned(reason);
      QM12821_ResetActiveCycle();
      QM_LogEvent(reason == QM_EXIT_KILLSWITCH ? QM_WARN : QM_INFO,
                  reason == QM_EXIT_KILLSWITCH ? "BASKET_EQUITY_STOP" : "BASKET_TAKE_PROFIT",
                  StringFormat("{\"pnl\":%.2f,\"threshold\":%.2f,\"open_lots\":%.2f,\"closed\":%d}",
                               pnl, threshold, open_lots, closed_by_equity));
     }
  }

void QM12821_ReprojectPendingOrders()
  {
   if(!strategy_pending_reproject)
      return;
   if(!QM12821_HasOwnedExposure())
      return;
   if(g_active_currency_idx < 0 || g_active_direction == 0)
      return;

   const datetime broker_now = TimeCurrent();
   if(QM12821_TimeToFlat(broker_now))
      return;
   if(!QM12821_InEntrySession(broker_now))
      return;
   if(!QM12821_EntryNewsAllows(broker_now))
      return;

   const datetime closed_m30 = iTime(QM12821_HOST_SYMBOL, PERIOD_M30, 1);
   if(closed_m30 <= 0 || closed_m30 == g_pending_reproject_last_m30_bar)
      return;
   g_pending_reproject_last_m30_bar = closed_m30;

   QM_BasketPlan plan;
   if(!QM_BasketBuilder_ModeC(g_active_currency_idx, g_active_direction, plan))
      return;

   int legs_ready = 0;
   int extended = 0;
   double pending_prices[];
   if(!QM12821_ComputeBasketBoundaries(plan, pending_prices, legs_ready, extended))
     {
      QM_LogEvent(QM_INFO, "BASKET_REPROJECT_BOUNDARY_UNREADY",
                  StringFormat("{\"currency\":\"%s\",\"direction\":%d,\"legs_ready\":%d,\"required\":%d}",
                               QM_CSM_CCY[g_active_currency_idx],
                               g_active_direction,
                               legs_ready,
                               plan.leg_count));
      return;
     }

   int canceled = 0;
   int replaced = 0;
   int stopped = 0;
   int filled = 0;
   for(int i = 0; i < plan.leg_count; ++i)
     {
      const QM_BasketLeg leg = plan.legs[i];
      if(QM12821_HasOwnedPositionForSymbol(leg.symbol))
        {
         ++filled;
         continue;
        }

      ulong pending_ticket = 0;
      double pending_lots = 0.0;
      const bool has_pending = QM12821_FindOwnedPendingForLeg(leg, pending_ticket, pending_lots);

      if(g_pending_reproject_leg_stopped[i])
        {
         if(has_pending)
            canceled += QM12821_CancelPendingForLeg(leg, "twin_basket_reproject_stopped");
         continue;
        }

      double chase_atr = 0.0;
      if(QM12821_LegBeyondReprojectChase(leg, pending_prices[i], chase_atr))
        {
         if(has_pending)
            canceled += QM12821_CancelPendingForLeg(leg, "twin_basket_reproject_chase_stop");
         g_pending_reproject_leg_stopped[i] = true;
         ++stopped;
         QM_LogEvent(QM_INFO, "BASKET_REPROJECT_LEG_STOP",
                     StringFormat("{\"symbol\":\"%s\",\"boundary\":%.5f,\"chase_atr\":%.3f,\"max_chase_atr\":%.3f}",
                                  leg.symbol,
                                  pending_prices[i],
                                  chase_atr,
                                  strategy_pullback_max_chase_atr));
         continue;
        }

      double lots = pending_lots;
      if(lots <= 0.0)
         lots = QM12821_LotsPerLeg(leg.symbol, plan.leg_count);
      if(lots <= 0.0)
         continue;

      if(has_pending)
        {
         const int removed = QM12821_CancelPendingForLeg(leg, "twin_basket_reproject");
         if(removed <= 0)
            continue;
         canceled += removed;
        }

      QM_BasketOrderRequest req;
      req.symbol = leg.symbol;
      req.type = QM12821_LegPendingOrderType(leg);
      req.price = pending_prices[i];
      req.sl = 0.0;
      req.tp = 0.0;
      req.lots = lots;
      req.reason = StringFormat("TWIN_REPROJECT_%s_%s",
                                QM_CSM_CCY[plan.currency_idx],
                                plan.direction > 0 ? "STRONG" : "WEAK");
      req.symbol_slot = leg.symbol_slot;
      req.expiration_seconds = (strategy_pending_expiration_minutes <= 0)
                               ? 0
                               : strategy_pending_expiration_minutes * 60;

      ulong new_ticket = 0;
      if(QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, new_ticket))
         ++replaced;
     }

   if(canceled > 0 || replaced > 0 || stopped > 0)
      QM_LogEvent(QM_INFO, "BASKET_PENDING_REPROJECT",
                  StringFormat("{\"bar_time\":%I64d,\"currency\":\"%s\",\"direction\":%d,\"canceled\":%d,\"replaced\":%d,\"stopped\":%d,\"filled\":%d}",
                               (long)closed_m30,
                               QM_CSM_CCY[g_active_currency_idx],
                               g_active_direction,
                               canceled,
                               replaced,
                               stopped,
                               filled));
  }

void QM12821_CloseOnRankingDecay()
  {
   if(g_active_currency_idx < 0 || g_active_direction == 0)
      return;

   QM_CSMReading d1;
   if(!QM_CSM_LoadStrength(PERIOD_D1, d1, 1))
      return;

   const int ranked_idx = (g_active_direction > 0) ? d1.strong_idx : d1.weak_idx;
   if(ranked_idx < 0 || ranked_idx >= QM_CSM_CURRENCY_COUNT)
      return;
   if(ranked_idx == g_active_currency_idx)
      return;

   const int old_idx = g_active_currency_idx;
   const int old_direction = g_active_direction;
   const double old_strength = (old_idx >= 0 && old_idx < QM_CSM_CURRENCY_COUNT)
                               ? d1.strength[old_idx]
                               : 0.0;
   const double ranked_strength = d1.strength[ranked_idx];
   const int closed = QM12821_CloseAllOwned(QM_EXIT_OPPOSITE_SIGNAL);
   QM_LogEvent(QM_INFO, "BASKET_STRENGTH_SHIFT_EXIT",
               StringFormat("{\"closed\":%d,\"reason\":\"ranking_decay\",\"old_currency\":\"%s\",\"old_direction\":%d,\"ranked_currency\":\"%s\",\"ranked_direction\":%d,\"old_strength\":%.6f,\"ranked_strength\":%.6f,\"d1_shift\":1}",
                            closed,
                            old_idx >= 0 ? QM_CSM_CCY[old_idx] : "",
                            old_direction,
                            QM_CSM_CCY[ranked_idx],
                            old_direction,
                            old_strength,
                            ranked_strength));
  }

void QM12821_CloseOnSignalShift()
  {
   if(!QM12821_HasOwnedExposure())
      return;
   if(strategy_exit_signal_mode == 1)
     {
      QM12821_CloseOnRankingDecay();
      return;
     }
   if(!QM12821_MtfWarmupReady(TimeCurrent()))
      return;

   QM_CSMReading d1;
   QM_CSMReading w1;
   QM_CSMReading mn;
   QM_MTFCoherenceState mtf;
   QM_BasketPlan plan;
   double probability = 0.0;
   if(!QM12821_EvaluateSignal(d1, w1, mn, mtf, plan, probability))
     {
      if(!strategy_close_on_signal_decay)
         return;
      const int closed = QM12821_CloseAllOwned(QM_EXIT_OPPOSITE_SIGNAL);
      QM_LogEvent(QM_INFO, "BASKET_STRENGTH_SHIFT_EXIT",
                  StringFormat("{\"closed\":%d,\"reason\":\"signal_invalid\"}", closed));
      return;
     }

   if(g_active_currency_idx < 0 || g_active_direction == 0)
     {
      g_active_currency_idx = plan.currency_idx;
      g_active_direction = plan.direction;
      return;
     }

   if(plan.currency_idx == g_active_currency_idx && plan.direction == g_active_direction)
      return;

   const int old_idx = g_active_currency_idx;
   const int old_direction = g_active_direction;
   const int closed = QM12821_CloseAllOwned(QM_EXIT_OPPOSITE_SIGNAL);
   QM_LogEvent(QM_INFO, "BASKET_STRENGTH_SHIFT_EXIT",
               StringFormat("{\"closed\":%d,\"old_currency\":\"%s\",\"old_direction\":%d,\"new_currency\":\"%s\",\"new_direction\":%d}",
                            closed,
                            old_idx >= 0 ? QM_CSM_CCY[old_idx] : "",
                            old_direction,
                            QM_CSM_CCY[plan.currency_idx],
                            plan.direction));
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != QM12821_HOST_SYMBOL)
      return true;
   if((ENUM_TIMEFRAMES)_Period != QM12821_HOST_TF)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(QM12821_HasOwnedExposure())
      return false;
   // Per-cycle stop re-arm: a new D1 calendar day = a new cycle evaluation.
   // (The card's 1% stop ends the CYCLE; it must not end the backtest.)
   if(g_cycle_stopped && QM_CalendarPeriodKey(PERIOD_D1, _Symbol) != g_cycle_stopped_daykey)
      g_cycle_stopped = false;
   if(g_cycle_stopped)
      return true;
   const datetime broker_now = TimeCurrent();
   if(QM12821_BlockEntryForMtfWarmup(broker_now))
      return true;
   if(!QM12821_InEntrySession(broker_now))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM12821_HasOwnedExposure())
     {
      QM12821_CloseOnSignalShift();
      return false;
     }
   if(QM12821_BlockEntryForMtfWarmup(TimeCurrent()))
      return false;

   QM_CSMReading d1;
   QM_CSMReading w1;
   QM_CSMReading mn;
   QM_MTFCoherenceState mtf;
   QM_BasketPlan plan;
   double probability = 0.0;
   if(!QM12821_EvaluateSignal(d1, w1, mn, mtf, plan, probability))
      return false;

   int legs_ready = 0;
   int extended = 0;
   double pending_prices[];
   if(!QM12821_ComputeBasketBoundaries(plan, pending_prices, legs_ready, extended))
     {
      QM_LogEvent(QM_INFO, "BASKET_BOUNDARY_UNREADY",
                  StringFormat("{\"currency\":\"%s\",\"direction\":%d,\"legs_ready\":%d,\"required\":%d}",
                               QM_CSM_CCY[plan.currency_idx],
                               plan.direction,
                               legs_ready,
                               plan.leg_count));
      return false;
     }

   QM_LogEvent(QM_INFO, "BASKET_LIMITS_PLACED",
               StringFormat("{\"currency\":\"%s\",\"direction\":%d,\"legs\":%d,\"extended\":%d,\"probability\":%.4f}",
                            QM_CSM_CCY[plan.currency_idx],
                            plan.direction,
                            plan.leg_count,
                            extended,
                            probability));
   QM12821_OpenPlan(plan, probability, pending_prices);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   QM12821_CheckBasketRisk();
   QM12821_ReprojectPendingOrders();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   string basket_symbols[QM_CSM_PAIR_COUNT];
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
      basket_symbols[i] = QM_CSM_PAIRS[i];
   QM_SymbolGuardInit(basket_symbols);
   QM12821_InitMtfWarmupGuard();
   QM_BasketWarmupHistory(basket_symbols, PERIOD_M30, strategy_warmup_bars);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_H1, strategy_warmup_bars);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(40, strategy_warmup_bars / 24));
   QM_BasketWarmupHistory(basket_symbols, PERIOD_W1, 80);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_MN1, 80);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_12821_twin-csm-basket\",\"scope\":\"fx8_csm_basket\",\"version\":\"modular_5_1\",\"mtf_warmup_first_bar_time\":%I64d,\"mtf_warmup_ready_time\":%I64d}",
                            (long)g_mtf_warmup_first_bar_time,
                            (long)g_mtf_warmup_ready_time));
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

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

   // News blackout gates NEW entries only (below). It must not sit above the
   // management path: the 7 legs carry no server-side SL (req.sl=0.0), so the
   // DL-081 1% equity stop is the ONLY protection and has to keep enforcing
   // through news windows. Fail-closed init in OnInit is unchanged.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
