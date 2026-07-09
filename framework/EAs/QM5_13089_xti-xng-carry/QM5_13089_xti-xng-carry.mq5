#property strict
#property version   "5.0"
#property description "QM5_13089 XTI XNG Carry Spread"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13089 - XTI/XNG Carry Spread
// -----------------------------------------------------------------------------
// D1 two-leg energy carry basket:
//   carry_edge(symbol) = SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT
//   if XTI carry edge > XNG carry edge: buy XTI, sell XNG
//   if XNG carry edge > XTI carry edge: sell XTI, buy XNG
// A 12M return guard blocks packages that are already drifting strongly against
// the intended leg direction. Runtime uses MT5 swap/OHLC/spread/ATR only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13089;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rebalance_weekday  = 1;
input int    strategy_return_lookback_d1 = 252;
input double strategy_max_adverse_return_pct = 25.0;
input double strategy_min_pair_swap_edge = 0.0;
input int    strategy_zero_swap_fallback_direction = 1;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.5;
input int    strategy_max_hold_days      = 7;
input int    strategy_xti_max_spread_pts = 1000;
input int    strategy_xng_max_spread_pts = 2500;
input int    strategy_deviation_points   = 20;

string   g_leg_xti = "XTIUSD.DWX";
string   g_leg_xng = "XNGUSD.DWX";
int      g_cache_pair_direction = 0;
double   g_cache_xti_edge = 0.0;
double   g_cache_xng_edge = 0.0;
double   g_cache_xti_return_12m_pct = 0.0;
double   g_cache_xng_return_12m_pct = 0.0;
bool     g_cache_carry_valid = false;
datetime g_pair_entry_time = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
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

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
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
   g_pair_entry_time = 0;
  }

int Strategy_CurrentPairDirection()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xti)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_MagicChecked(qm_ea_id, 0, g_leg_xti))
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (position_type == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

bool Strategy_LoadReturnPct(const string symbol, double &return_pct)
  {
   return_pct = 0.0;
   const int lookback = MathMax(21, strategy_return_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 adverse-drift guard behind new-bar.
   if(copied < lookback + 1)
      return false;

   const double recent_close = closes[0];
   const double past_close = closes[lookback];
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   return_pct = 100.0 * MathLog(recent_close / past_close);
   return MathIsValidNumber(return_pct);
  }

bool Strategy_LoadCarryState(int &pair_direction,
                             double &xti_edge,
                             double &xng_edge,
                             double &xti_return_pct,
                             double &xng_return_pct)
  {
   pair_direction = 0;
   xti_edge = 0.0;
   xng_edge = 0.0;
   xti_return_pct = 0.0;
   xng_return_pct = 0.0;

   const double xti_swap_long = SymbolInfoDouble(g_leg_xti, SYMBOL_SWAP_LONG);
   const double xti_swap_short = SymbolInfoDouble(g_leg_xti, SYMBOL_SWAP_SHORT);
   const double xng_swap_long = SymbolInfoDouble(g_leg_xng, SYMBOL_SWAP_LONG);
   const double xng_swap_short = SymbolInfoDouble(g_leg_xng, SYMBOL_SWAP_SHORT);
   if(!MathIsValidNumber(xti_swap_long) || !MathIsValidNumber(xti_swap_short) ||
      !MathIsValidNumber(xng_swap_long) || !MathIsValidNumber(xng_swap_short))
      return false;

   xti_edge = xti_swap_long - xti_swap_short;
   xng_edge = xng_swap_long - xng_swap_short;
   const double pair_edge = xti_edge - xng_edge;
   const double min_edge = MathMax(0.0, strategy_min_pair_swap_edge);
   if(pair_edge > min_edge)
      pair_direction = 1;
   else if(-pair_edge > min_edge)
      pair_direction = -1;
   else
     {
      const bool zero_swap_tie = (MathAbs(xti_swap_long) <= 0.0000001 &&
                                  MathAbs(xti_swap_short) <= 0.0000001 &&
                                  MathAbs(xng_swap_long) <= 0.0000001 &&
                                  MathAbs(xng_swap_short) <= 0.0000001);
      if(!zero_swap_tie || (strategy_zero_swap_fallback_direction != 1 &&
                            strategy_zero_swap_fallback_direction != -1))
         return false;
      pair_direction = strategy_zero_swap_fallback_direction;
     }

   if(!Strategy_LoadReturnPct(g_leg_xti, xti_return_pct))
      return false;
   if(!Strategy_LoadReturnPct(g_leg_xng, xng_return_pct))
      return false;

   const double adverse_limit = MathMax(0.0, strategy_max_adverse_return_pct);
   if(pair_direction > 0)
     {
      if(xti_return_pct < -adverse_limit || xng_return_pct > adverse_limit)
         return false;
     }
   else if(pair_direction < 0)
     {
      if(xti_return_pct > adverse_limit || xng_return_pct < -adverse_limit)
         return false;
     }
   else
      return false;

   return true;
  }

// Called once per new closed D1 host bar. Per-tick management and entry read
// only this cached carry ranking, so CopyClose is not repeated every tick.
void Strategy_AdvanceCarryState_OnNewBar()
  {
   g_cache_carry_valid = Strategy_LoadCarryState(g_cache_pair_direction,
                                                 g_cache_xti_edge,
                                                 g_cache_xng_edge,
                                                 g_cache_xti_return_12m_pct,
                                                 g_cache_xng_return_12m_pct);
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;

   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
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
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
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
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const double xti_weight = 1.0;
   const double xng_weight = 1.0;
   const double weight_sum = xti_weight + xng_weight;
   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13089_LONG_XTI_SHORT_XNG_CARRY"
                                            : "QM5_13089_SHORT_XTI_LONG_XNG_CARRY";

   bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, xti_weight, weight_sum, reason);
   bool xng_ok = Strategy_OpenLeg(g_leg_xng, xng_type, xng_weight, weight_sum, reason);
   if(xti_ok && xng_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_rebalance_weekday < 1 || strategy_rebalance_weekday > 5)
      return true;
   if(strategy_return_lookback_d1 < 21)
      return true;
   if(strategy_max_adverse_return_pct < 0.0 || strategy_min_pair_swap_edge < 0.0)
      return true;
   if(strategy_zero_swap_fallback_direction != -1 && strategy_zero_swap_fallback_direction != 0 &&
      strategy_zero_swap_fallback_direction != 1)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_xti_max_spread_pts < 0 || strategy_xng_max_spread_pts < 0 ||
      strategy_deviation_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13089_CARRY_SPREAD_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   bool day_enabled[7];
   for(int d = 0; d < 7; ++d)
      day_enabled[d] = false;
   const int enabled_idx = strategy_rebalance_weekday - 1;
   if(enabled_idx >= 0 && enabled_idx < 7)
      day_enabled[enabled_idx] = true;
   if(QM_Sig_DayOfWeek(TimeCurrent(), day_enabled) == 0)
      return false;

   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_carry_valid || g_cache_pair_direction == 0)
      return false;

   Strategy_OpenPair(g_cache_pair_direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   const int current_pair_direction = Strategy_CurrentPairDirection();
   if(current_pair_direction == 0)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_cache_carry_valid && g_cache_pair_direction != 0 &&
      current_pair_direction != g_cache_pair_direction)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_STRATEGY);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xng, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(300, strategy_return_lookback_d1 + strategy_atr_period_d1 + 30));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13089\",\"ea\":\"xti-xng-carry\"}");
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
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      Strategy_ClosePair(QM_EXIT_FRIDAY_CLOSE);
      return;
     }
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      Strategy_AdvanceCarryState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(!new_bar)
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

