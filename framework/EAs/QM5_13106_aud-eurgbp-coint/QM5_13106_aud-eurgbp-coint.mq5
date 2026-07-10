#property strict
#property version   "5.0"
#property description "QM5_13106 AUDUSD EURGBP Cointegration"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 two-leg basket EA.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13106;
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
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_z_lookback_d1     = 60;
input double strategy_beta              = -0.0545763736541407;
input double strategy_entry_z           = 2.0;
input double strategy_exit_z            = 0.5;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_deviation_points  = 20;

string   g_leg_audusd = "AUDUSD.DWX";
string   g_leg_eurgbp = "EURGBP.DWX";
bool     g_basket_scope_ready = false;
double   g_spread_z = 0.0;
double   g_spread_mean = 0.0;
double   g_spread_sd = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;
datetime g_last_state_bar = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_audusd)
      return 0;
   if(symbol == g_leg_eurgbp)
      return 1;
   return -1;
  }

bool Strategy_IsHostSymbol()
  {
   return (_Symbol == g_leg_audusd || _Symbol == g_leg_eurgbp);
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

   string allowed[2] = {"AUDUSD.DWX", "EURGBP.DWX"};
   for(int i = 0; i < 2; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed,
                          PERIOD_D1,
                          MathMax(300, strategy_z_lookback_d1 + strategy_atr_period_d1 + 10));
   g_basket_scope_ready = true;
   return true;
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

bool Strategy_RefreshSpreadState()
  {
   g_state_ready = false;
   const int lookback = MathMax(20, strategy_z_lookback_d1);

   if(!Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_leg_audusd) || !QM_SymbolAssertOrLog(g_leg_eurgbp))
      return false;

   double audusd[];
   double eurgbp[];
   ArraySetAsSeries(audusd, true);
   ArraySetAsSeries(eurgbp, true);
   if(CopyClose(g_leg_audusd, PERIOD_D1, 1, lookback, audusd) != lookback) // perf-allowed: new-bar gated.
      return false;
   if(CopyClose(g_leg_eurgbp, PERIOD_D1, 1, lookback, eurgbp) != lookback) // perf-allowed: new-bar gated.
      return false;

   double sum = 0.0;
   double spreads[];
   ArrayResize(spreads, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(audusd[i] <= 0.0 || eurgbp[i] <= 0.0)
         return false;
      spreads[i] = MathLog(audusd[i]) - strategy_beta * MathLog(eurgbp[i]);
      if(!MathIsValidNumber(spreads[i]))
         return false;
      sum += spreads[i];
     }

   g_spread_mean = sum / (double)lookback;
   double var_sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = spreads[i] - g_spread_mean;
      var_sum += d * d;
     }

   g_spread_sd = MathSqrt(var_sum / (double)MathMax(1, lookback - 1));
   if(g_spread_sd <= 0.0 || !MathIsValidNumber(g_spread_sd))
      return false;

   g_spread_z = (spreads[0] - g_spread_mean) / g_spread_sd;
   g_state_ready = MathIsValidNumber(g_spread_z);
   if(g_state_ready)
      g_last_state_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached D1 timestamp.
   return g_state_ready;
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
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
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_OpenPair(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;

   const double audusd_weight = 1.0;
   const double eurgbp_weight = MathAbs(strategy_beta);
   const double weight_sum = audusd_weight + eurgbp_weight;
   if(weight_sum <= 0.0)
      return false;

   const bool long_spread = (spread_direction > 0);
   const QM_OrderType audusd_type = long_spread ? QM_BUY : QM_SELL;
   const QM_OrderType eurgbp_type = long_spread
                                    ? (strategy_beta >= 0.0 ? QM_SELL : QM_BUY)
                                    : (strategy_beta >= 0.0 ? QM_BUY : QM_SELL);
   const string reason = long_spread ? "QM5_13106_LONG_SPREAD_Z_LT_NEG_ENTRY"
                                     : "QM5_13106_SHORT_SPREAD_Z_GT_POS_ENTRY";

   const bool audusd_ok = Strategy_OpenLeg(g_leg_audusd,
                                            audusd_type,
                                            audusd_weight,
                                            weight_sum,
                                            reason);
   const bool eurgbp_ok = Strategy_OpenLeg(g_leg_eurgbp,
                                            eurgbp_type,
                                            eurgbp_weight,
                                            weight_sum,
                                            reason);
   if(audusd_ok && eurgbp_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if(!Strategy_IsHostSymbol())
      return true;
   if(Strategy_SlotForSymbol(_Symbol) != qm_magic_slot_offset)
      return true;
   const ENUM_TIMEFRAMES chart_tf = (ENUM_TIMEFRAMES)_Period;
   if(chart_tf != PERIOD_H1 && chart_tf != PERIOD_D1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13106_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshSpreadState())
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   if(g_spread_z > strategy_entry_z)
      Strategy_OpenPair(-1);
   else if(g_spread_z < -strategy_entry_z)
      Strategy_OpenPair(1);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing, break-even, partial close, grid, or averaging.
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return false;
   if(open_legs != 2)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: timestamp guard.
   if(current_d1_bar > 0 && current_d1_bar != g_last_state_bar)
      Strategy_RefreshSpreadState();
   if(g_state_ready && MathAbs(g_spread_z) < strategy_exit_z)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_audusd,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_eurgbp,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_audusd, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_eurgbp, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_leg_audusd, true);
   SymbolSelect(g_leg_eurgbp, true);

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }

