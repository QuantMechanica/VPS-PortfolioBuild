#property strict
#property version   "5.0"
#property description "QM5_12857 XBR XNG Ratio VCB"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12857 - XBR/XNG Ratio Volatility-Contraction Breakout
// -----------------------------------------------------------------------------
// D1 two-leg energy basket:
//   spread = ln(XBRUSD.DWX) - beta * ln(XNGUSD.DWX)
//   low Bollinger BandWidth rank on the spread identifies compression
//   upper envelope break: buy ratio  = buy XBR, sell XNG
//   lower envelope break: sell ratio = sell XBR, buy XNG
// Runtime uses MT5 OHLC only; no external feed, futures curve, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12857;
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
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input int    strategy_bandwidth_lookback_d1 = 126;
input double strategy_bandwidth_rank_max    = 0.20;
input double strategy_break_buffer_sd       = 0.10;
input int    strategy_slope_shift           = 10;
input bool   strategy_require_slope         = true;
input double strategy_beta                  = 1.0;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_hold_days         = 20;
input int    strategy_xbr_max_spread_pts    = 1000;
input int    strategy_xng_max_spread_pts    = 2500;
input int    strategy_deviation_points      = 20;

string   g_leg_xbr = "XBRUSD.DWX";
string   g_leg_xng = "XNGUSD.DWX";
double   g_ratio_spread = 0.0;
double   g_ratio_middle = 0.0;
double   g_ratio_sd = 0.0;
double   g_ratio_upper = 0.0;
double   g_ratio_lower = 0.0;
double   g_bandwidth_rank = 1.0;
double   g_middle_slope = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;
datetime g_last_state_bar = 0;
datetime g_signal_bar_time = 0;
datetime g_last_entry_bar_time = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xbr)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xbr && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(symbol == g_leg_xbr && strategy_xbr_max_spread_pts > 0)
      return (spread_points <= strategy_xbr_max_spread_pts);
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

int Strategy_PairDirection()
  {
   const int xbr_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xbr);
   if(xbr_magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xbr)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != xbr_magic)
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

datetime Strategy_OldestPairOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (oldest == 0 || opened < oldest))
         oldest = opened;
     }
   return oldest;
  }

bool Strategy_LoadSpreadSeries(const int count_raw, double &spreads[])
  {
   const int count = MathMax(40, count_raw);
   double xbr[];
   double xng[];
   ArraySetAsSeries(xbr, true);
   ArraySetAsSeries(xng, true);
   if(CopyClose(g_leg_xbr, PERIOD_D1, 1, count, xbr) != count) // perf-allowed: called behind the D1 new-bar gate or close-state refresh.
      return false;
   if(CopyClose(g_leg_xng, PERIOD_D1, 1, count, xng) != count) // perf-allowed: called behind the D1 new-bar gate or close-state refresh.
      return false;

   ArrayResize(spreads, count);
   for(int i = 0; i < count; ++i)
     {
      if(xbr[i] <= 0.0 || xng[i] <= 0.0)
         return false;
      spreads[i] = MathLog(xbr[i]) - strategy_beta * MathLog(xng[i]);
      if(!MathIsValidNumber(spreads[i]))
         return false;
     }
   return true;
  }

bool Strategy_BandStateAtIndex(double &spreads[],
                               const int index,
                               double &middle,
                               double &sd,
                               double &upper,
                               double &lower,
                               double &bandwidth)
  {
   middle = 0.0;
   sd = 0.0;
   upper = 0.0;
   lower = 0.0;
   bandwidth = 0.0;

   const int period = MathMax(10, strategy_bb_period);
   if(index < 0 || index + period >= ArraySize(spreads))
      return false;

   double sum = 0.0;
   for(int i = index + 1; i <= index + period; ++i)
      sum += spreads[i];
   middle = sum / (double)period;

   double var_sum = 0.0;
   for(int i = index + 1; i <= index + period; ++i)
     {
      const double d = spreads[i] - middle;
      var_sum += d * d;
     }

   sd = MathSqrt(var_sum / (double)MathMax(1, period - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd) || !MathIsValidNumber(middle))
      return false;

   const double band = strategy_bb_deviation * sd;
   upper = middle + band;
   lower = middle - band;
   const double denom = MathMax(0.000001, MathAbs(middle));
   bandwidth = (upper - lower) / denom;
   return (bandwidth > 0.0 && MathIsValidNumber(bandwidth));
  }

bool Strategy_RefreshRatioState()
  {
   g_state_ready = false;
   g_ratio_spread = 0.0;
   g_ratio_middle = 0.0;
   g_ratio_sd = 0.0;
   g_ratio_upper = 0.0;
   g_ratio_lower = 0.0;
   g_bandwidth_rank = 1.0;
   g_middle_slope = 0.0;
   g_signal_bar_time = 0;

   const int period = MathMax(10, strategy_bb_period);
   const int lookback = MathMax(40, strategy_bandwidth_lookback_d1);
   const int slope_shift = MathMax(1, strategy_slope_shift);
   const int count = MathMax(lookback + period + 2, slope_shift + period + 2);

   double spreads[];
   if(!Strategy_LoadSpreadSeries(count, spreads))
      return false;

   g_signal_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 timestamp cached only after framework state gates.
   g_ratio_spread = spreads[0];

   double current_bw = 0.0;
   if(!Strategy_BandStateAtIndex(spreads,
                                 0,
                                 g_ratio_middle,
                                 g_ratio_sd,
                                 g_ratio_upper,
                                 g_ratio_lower,
                                 current_bw))
      return false;

   double prior_middle = 0.0;
   double prior_sd = 0.0;
   double prior_upper = 0.0;
   double prior_lower = 0.0;
   double prior_bw = 0.0;
   if(Strategy_BandStateAtIndex(spreads,
                                slope_shift,
                                prior_middle,
                                prior_sd,
                                prior_upper,
                                prior_lower,
                                prior_bw))
      g_middle_slope = g_ratio_middle - prior_middle;

   int samples = 0;
   int less_or_equal = 0;
   for(int idx = 1; idx <= lookback; ++idx)
     {
      double bw_middle = 0.0;
      double bw_sd = 0.0;
      double bw_upper = 0.0;
      double bw_lower = 0.0;
      double bw_value = 0.0;
      if(!Strategy_BandStateAtIndex(spreads, idx, bw_middle, bw_sd, bw_upper, bw_lower, bw_value))
         continue;

      ++samples;
      if(bw_value <= current_bw)
         ++less_or_equal;
     }

   if(samples < MathMax(20, lookback / 2))
      return false;

   g_bandwidth_rank = (double)less_or_equal / (double)samples;
   if(g_bandwidth_rank < 0.0 || g_bandwidth_rank > 1.0 || !MathIsValidNumber(g_bandwidth_rank))
      return false;

   g_last_state_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp cache for open-position refresh.
   g_state_ready = true;
   return true;
  }

int Strategy_BreakoutDirection()
  {
   if(!g_state_ready)
      return 0;
   if(g_bandwidth_rank > strategy_bandwidth_rank_max)
      return 0;

   const double buffer = MathMax(0.0, strategy_break_buffer_sd) * g_ratio_sd;
   if(g_ratio_spread > g_ratio_upper + buffer)
     {
      if(strategy_require_slope && g_middle_slope <= 0.0)
         return 0;
      return 1;
     }

   if(g_ratio_spread < g_ratio_lower - buffer)
     {
      if(strategy_require_slope && g_middle_slope >= 0.0)
         return 0;
      return -1;
     }

   return 0;
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

bool Strategy_OpenPair(const int ratio_direction)
  {
   if(ratio_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xbr) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const double xbr_weight = 1.0;
   const double xng_weight = MathMax(0.1, MathAbs(strategy_beta));
   const double weight_sum = xbr_weight + xng_weight;
   const bool long_ratio = (ratio_direction > 0);
   const QM_OrderType xbr_type = long_ratio ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_ratio ? QM_SELL : QM_BUY;
   const string reason = long_ratio ? "QM5_12857_LONG_XBR_XNG_VCB"
                                    : "QM5_12857_SHORT_XBR_XNG_VCB";

   bool xbr_ok = Strategy_OpenLeg(g_leg_xbr, xbr_type, xbr_weight, weight_sum, reason);
   bool xng_ok = Strategy_OpenLeg(g_leg_xng, xng_type, xng_weight, weight_sum, reason);
   if(xbr_ok && xng_ok)
     {
      g_pair_entry_time = TimeCurrent();
      g_last_entry_bar_time = g_signal_bar_time;
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_bb_period < 10 || strategy_bb_period > 80)
      return true;
   if(strategy_bb_deviation <= 0.0 || strategy_bb_deviation > 5.0)
      return true;
   if(strategy_bandwidth_lookback_d1 < MathMax(40, strategy_bb_period + 10) || strategy_bandwidth_lookback_d1 > 320)
      return true;
   if(strategy_bandwidth_rank_max <= 0.0 || strategy_bandwidth_rank_max >= 0.60)
      return true;
   if(strategy_break_buffer_sd < 0.0 || strategy_break_buffer_sd > 2.0)
      return true;
   if(strategy_slope_shift <= 0 || strategy_slope_shift > 80)
      return true;
   if(strategy_beta <= 0.0 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12857_VCB_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshRatioState())
      return false;
   if(g_signal_bar_time > 0 && g_signal_bar_time == g_last_entry_bar_time)
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   const int direction = Strategy_BreakoutDirection();
   if(direction == 0)
      return false;

   Strategy_OpenPair(direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_OldestPairOpenTime();
   if(entry_time <= 0)
      return false;

   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
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

   if(Strategy_MaxHoldExceeded())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp guard before optional spread refresh.
   if(current_d1_bar > 0 && current_d1_bar != g_last_state_bar)
      Strategy_RefreshRatioState();
   if(!g_state_ready)
      return false;

   const int pair_direction = Strategy_PairDirection();
   if(pair_direction > 0 && g_ratio_spread < g_ratio_middle)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   else if(pair_direction < 0 && g_ratio_spread > g_ratio_middle)
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

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xbr, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xbr, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_leg_xbr, true);
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

   string basket_symbols[2] = {g_leg_xbr, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(260, strategy_bandwidth_lookback_d1 + strategy_bb_period + strategy_slope_shift + strategy_atr_period_d1 + 20));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12857\",\"ea\":\"xbr-xng-vcb\"}");
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
