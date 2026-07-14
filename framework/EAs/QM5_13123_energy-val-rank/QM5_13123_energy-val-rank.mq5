#property strict
#property version   "5.0"
#property description "QM5_13123 XTI XNG Long-Horizon Value Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13123 - XTI/XNG long-horizon cross-sectional value
// -----------------------------------------------------------------------------
// Monthly market-neutral energy package:
//   - value = log(mean spot proxy at 54..66 month boundaries / latest spot proxy)
//   - buy the higher-value energy leg and sell the lower-value leg
//   - split fixed package risk equally between the two ATR-stopped legs
// Runtime is Darwinex-native completed D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13123;
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
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_anchor_near_months      = 54;
input int    strategy_anchor_far_months       = 66;
input int    strategy_history_bars            = 1900;
input int    strategy_max_boundary_gap_days   = 10;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 35;
input int    strategy_xti_max_spread_pts       = 1500;
input int    strategy_xng_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_attempt_month_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_value = 0.0;
double   g_cache_xng_value = 0.0;
double   g_cache_xti_latest = 0.0;
double   g_cache_xng_latest = 0.0;
double   g_cache_xti_anchor_mean = 0.0;
double   g_cache_xng_anchor_mean = 0.0;

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
   if(spread_points < 0)
      return false;
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
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int xti_direction = 0;
   int xng_direction = 0;
   int xti_count = 0;
   int xng_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(symbol == g_leg_xti)
        {
         xti_direction = direction;
         ++xti_count;
        }
      else if(symbol == g_leg_xng)
        {
         xng_direction = direction;
         ++xng_count;
        }
     }
   return (xti_count == 1 && xng_count == 1 && xti_direction == -xng_direction);
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

void Strategy_ShiftMonths(const MqlDateTime &base,
                          const int months_back,
                          MqlDateTime &shifted)
  {
   shifted = base;
   const int absolute_month = base.year * 12 + (base.mon - 1) - months_back;
   shifted.year = absolute_month / 12;
   shifted.mon = absolute_month % 12 + 1;
   shifted.day = 1;
   shifted.hour = 0;
   shifted.min = 0;
   shifted.sec = 0;
  }

bool Strategy_CloseBeforeBoundary(const MqlRates &rates[],
                                  const int count,
                                  const datetime boundary,
                                  double &close_price,
                                  datetime &close_time)
  {
   close_price = 0.0;
   close_time = 0;
   for(int i = 0; i < count; ++i)
     {
      if(rates[i].time >= boundary || rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         continue;
      close_price = rates[i].close;
      close_time = rates[i].time;
      break;
     }
   if(close_time <= 0 || close_price <= 0.0)
      return false;
   const long gap_seconds = (long)(boundary - close_time);
   const long max_gap_seconds = (long)strategy_max_boundary_gap_days * 86400;
   return (gap_seconds > 0 && gap_seconds <= max_gap_seconds);
  }

bool Strategy_LegValueScore(const string symbol,
                            const datetime decision_bar_time,
                            double &value_score,
                            double &latest_close,
                            double &anchor_mean)
  {
   value_score = 0.0;
   latest_close = 0.0;
   anchor_mean = 0.0;

   MqlDateTime decision_dt;
   TimeToStruct(decision_bar_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlDateTime current_dt;
   Strategy_ShiftMonths(decision_dt, 0, current_dt);
   const datetime current_boundary = StructToTime(current_dt);
   if(current_boundary <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded monthly value copy.
   if(count < 1200)
      return false;

   datetime latest_time = 0;
   if(!Strategy_CloseBeforeBoundary(rates, count, current_boundary, latest_close, latest_time))
      return false;

   double anchor_sum = 0.0;
   int anchor_count = 0;
   datetime previous_endpoint_time = 0;
   for(int months_back = strategy_anchor_near_months;
       months_back <= strategy_anchor_far_months;
       ++months_back)
     {
      MqlDateTime anchor_dt;
      Strategy_ShiftMonths(current_dt, months_back, anchor_dt);
      const datetime anchor_boundary = StructToTime(anchor_dt);
      double endpoint_close = 0.0;
      datetime endpoint_time = 0;
      if(anchor_boundary <= 0 ||
         !Strategy_CloseBeforeBoundary(rates, count, anchor_boundary, endpoint_close, endpoint_time))
         return false;
      if(endpoint_time >= latest_time ||
         (anchor_count > 0 && endpoint_time >= previous_endpoint_time))
         return false;
      previous_endpoint_time = endpoint_time;
      anchor_sum += endpoint_close;
      ++anchor_count;
     }

   const int required_anchors = strategy_anchor_far_months - strategy_anchor_near_months + 1;
   if(anchor_count != required_anchors || required_anchors <= 0)
      return false;
   anchor_mean = anchor_sum / (double)anchor_count;
   if(anchor_mean <= 0.0 || latest_close <= 0.0)
      return false;

   value_score = MathLog(anchor_mean / latest_close);
   return MathIsValidNumber(value_score) && MathIsValidNumber(anchor_mean);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   if(!Strategy_LegValueScore(g_leg_xti, decision_bar_time,
                              g_cache_xti_value,
                              g_cache_xti_latest,
                              g_cache_xti_anchor_mean))
      return false;
   if(!Strategy_LegValueScore(g_leg_xng, decision_bar_time,
                              g_cache_xng_value,
                              g_cache_xng_latest,
                              g_cache_xng_anchor_mean))
      return false;

   const double value_difference = g_cache_xti_value - g_cache_xng_value;
   const double rank_epsilon = 1.0e-12;
   if(value_difference > rank_epsilon)
      pair_direction = 1;
   else if(value_difference < -rank_epsilon)
      pair_direction = -1;
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one timestamp on the D1 new-bar path.
   if(decision_bar_time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time, g_cache_pair_direction);
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

// Resolves the current package's per-leg half-risk override from whichever
// framework risk input is active (ENV validated once at OnInit). Both legs
// use the SAME half-value so the fixed package risk splits equally per the
// card, regardless of which risk mode the setfile ENV selects.
bool Strategy_HalfRiskMode(QM_RiskMode &mode, double &value)
  {
   mode = QM_RISK_MODE_UNSET;
   value = 0.0;
   if(RISK_FIXED > 0.0 && RISK_PERCENT <= 0.0)
     {
      mode = QM_RISK_MODE_FIXED;
      value = RISK_FIXED * 0.5;
      return true;
     }
   if(RISK_PERCENT > 0.0 && RISK_FIXED <= 0.0)
     {
      mode = QM_RISK_MODE_PERCENT;
      value = RISK_PERCENT * 0.5;
      return true;
     }
   return false;
  }

double Strategy_LotsForLeg(const string symbol,
                           const QM_RiskMode risk_mode,
                           const double risk_value)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_value <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points, risk_mode, risk_value);
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

// Off-host leg only (XNG when host is XTI). The host leg never goes through
// QM_BasketOpenPosition — it is opened by the framework's own QM_TM_OpenPosition
// path from the QM_EntryRequest that Strategy_OpenPair populates (see below).
bool Strategy_OpenOffHostLeg(const string symbol,
                             const QM_OrderType type,
                             const QM_RiskMode risk_mode,
                             const double risk_value,
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
   const double lots = Strategy_LotsForLeg(symbol, risk_mode, risk_value);
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

// Opens the off-host leg (XNG) first, then populates host_req for the XTI
// host leg. Returns true only when host_req is ready for the framework's own
// QM_TM_OpenPosition call in OnTick. If the off-host leg opens but the host
// leg is subsequently rejected by the broker, Strategy_ManageOpenPosition's
// composition check closes the orphaned off-host leg on the next tick.
bool Strategy_OpenPair(const int pair_direction, QM_EntryRequest &host_req)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   QM_RiskMode half_mode;
   double half_value;
   if(!Strategy_HalfRiskMode(half_mode, half_value))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13123_LONG_XTI_SHORT_XNG_VALUE"
                                            : "QM5_13123_SHORT_XTI_LONG_XNG_VALUE";

   if(!Strategy_OpenOffHostLeg(g_leg_xng, xng_type, half_mode, half_value, reason))
      return false;

   const double entry = QM_OrderTypeIsBuy(xti_type) ? SymbolInfoDouble(g_leg_xti, SYMBOL_ASK)
                                                    : SymbolInfoDouble(g_leg_xti, SYMBOL_BID);
   const double atr = QM_ATR(g_leg_xti, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false; // off-host leg already open; ManageOpenPosition repairs the orphan.

   const int digits = (int)SymbolInfoInteger(g_leg_xti, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   host_req.type = xti_type;
   host_req.price = 0.0;
   host_req.sl = QM_OrderTypeIsBuy(xti_type) ? NormalizeDouble(entry - stop_dist, digits)
                                             : NormalizeDouble(entry + stop_dist, digits);
   host_req.tp = 0.0;
   host_req.reason = reason;
   host_req.symbol_slot = 0;
   host_req.expiration_seconds = 0;

   g_pair_entry_time = TimeCurrent();
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_anchor_near_months != 54 || strategy_anchor_far_months != 66)
      return true;
   if(strategy_history_bars < 1800 || strategy_history_bars > 2100 ||
      strategy_max_boundary_gap_days < 7 || strategy_max_boundary_gap_days > 10)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days <= 0)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return false;
   if(g_cache_month_key == g_last_attempt_month_key)
      return false;
   g_last_attempt_month_key = g_cache_month_key;

   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   // Populates req for the XTI host leg; caller (OnTick) fires it through
   // QM_TM_OpenPosition with the same half-risk override used for the XNG
   // off-host leg above.
   return Strategy_OpenPair(g_cache_pair_direction, req);
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_monthly_rebalance_bar)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
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
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(1800, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13123\",\"ea\":\"energy-val-rank\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_AdvanceSignal_OnNewBar();

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
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      QM_RiskMode half_mode;
      double half_value;
      if(Strategy_HalfRiskMode(half_mode, half_value))
        {
         ulong out_ticket = 0;
         QM_TM_OpenPosition(req, out_ticket, 0, half_mode, half_value);
        }
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
