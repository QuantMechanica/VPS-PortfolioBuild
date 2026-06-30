#property strict
#property version   "5.0"
#property description "QM5_12813 XTI XNG Seasonal Energy Switch"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12813 - XTI/XNG Seasonal Energy Switch
// -----------------------------------------------------------------------------
// D1 two-leg energy basket:
//   - trade only during fixed EIA-supported energy demand windows
//   - summer window: long XTIUSD.DWX and short XNGUSD.DWX
//   - winter window: short XTIUSD.DWX and long XNGUSD.DWX
//   - require both legs to confirm the seasonal direction versus D1 SMA
// This is calendar-season structural relative value, not ratio reversion,
// cross-sectional momentum, channel breakout, inventory news, or external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12813;
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
input int    strategy_trend_period_d1        = 84;
input bool   strategy_require_relative_trend = true;
input int    strategy_xti_start_month        = 5;
input int    strategy_xti_start_day          = 15;
input int    strategy_xti_end_month          = 8;
input int    strategy_xti_end_day            = 31;
input int    strategy_xng_start_month        = 11;
input int    strategy_xng_start_day          = 1;
input int    strategy_xng_end_month          = 3;
input int    strategy_xng_end_day            = 31;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_max_hold_days          = 35;
input int    strategy_xti_max_spread_pts     = 1000;
input int    strategy_xng_max_spread_pts     = 2500;
input int    strategy_deviation_points       = 20;

string   g_leg_xti = "XTIUSD.DWX";
string   g_leg_xng = "XNGUSD.DWX";
datetime g_pair_entry_time = 0;
int      g_last_entry_month_key = 0;
int      g_current_direction = 0;

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

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework tick loop.
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 calendar gate behind framework tick loop.
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_MonthKey(current_bar) != Strategy_MonthKey(prior_bar);
  }

int Strategy_MonthDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon * 100 + dt.day;
  }

bool Strategy_ValidMonthDay(const int month, const int day)
  {
   return (month >= 1 && month <= 12 && day >= 1 && day <= 31);
  }

bool Strategy_DateInWindow(const datetime t,
                           const int start_month,
                           const int start_day,
                           const int end_month,
                           const int end_day)
  {
   if(t <= 0)
      return false;

   const int md = Strategy_MonthDay(t);
   const int start_md = start_month * 100 + start_day;
   const int end_md = end_month * 100 + end_day;
   if(start_md <= end_md)
      return (md >= start_md && md <= end_md);
   return (md >= start_md || md <= end_md);
  }

int Strategy_SeasonDirection(const datetime t)
  {
   const bool xti_window = Strategy_DateInWindow(t,
                                                 strategy_xti_start_month,
                                                 strategy_xti_start_day,
                                                 strategy_xti_end_month,
                                                 strategy_xti_end_day);
   const bool xng_window = Strategy_DateInWindow(t,
                                                 strategy_xng_start_month,
                                                 strategy_xng_start_day,
                                                 strategy_xng_end_month,
                                                 strategy_xng_end_day);
   if(xti_window == xng_window)
      return 0;
   return xti_window ? 1 : -1;
  }

bool Strategy_PriceAboveSma(const string symbol, bool &above_sma)
  {
   above_sma = false;
   const int period = MathMax(20, strategy_trend_period_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_D1, 1, 1, closes) != 1) // perf-allowed: one closed D1 bar for season confirmation.
      return false;

   const double sma = QM_SMA(symbol, PERIOD_D1, period, 1, PRICE_CLOSE);
   if(closes[0] <= 0.0 || sma <= 0.0 || !MathIsValidNumber(closes[0]) || !MathIsValidNumber(sma))
      return false;

   above_sma = (closes[0] > sma);
   return true;
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
      if(opened <= 0)
         continue;
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
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

int Strategy_CurrentPairDirection()
  {
   int direction = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xti)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         direction = 1;
      else if(pos_type == POSITION_TYPE_SELL)
         direction = -1;
      break;
     }
   return direction;
  }

bool Strategy_LoadSignalState(int &direction)
  {
   direction = 0;
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar season gate behind new-bar loop.
   direction = Strategy_SeasonDirection(current_bar);
   g_current_direction = direction;
   if(direction == 0)
      return true;

   if(!strategy_require_relative_trend)
      return true;

   bool xti_above = false;
   bool xng_above = false;
   if(!Strategy_PriceAboveSma(g_leg_xti, xti_above))
      return false;
   if(!Strategy_PriceAboveSma(g_leg_xng, xng_above))
      return false;

   if(direction > 0 && (!xti_above || xng_above))
      direction = 0;
   else if(direction < 0 && (!xng_above || xti_above))
      direction = 0;

   g_current_direction = direction;
   return true;
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

bool Strategy_OpenPair(const int seasonal_direction)
  {
   if(seasonal_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool xti_season = (seasonal_direction > 0);
   const QM_OrderType xti_type = xti_season ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = xti_season ? QM_SELL : QM_BUY;
   const string reason = xti_season ? "QM5_12813_LONG_XTI_SHORT_XNG_SEASON"
                                    : "QM5_12813_SHORT_XTI_LONG_XNG_SEASON";
   const double weight_sum = 2.0;

   const bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, 1.0, weight_sum, reason);
   const bool xng_ok = Strategy_OpenLeg(g_leg_xng, xng_type, 1.0, weight_sum, reason);
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
   if(strategy_trend_period_d1 < 20)
      return true;
   if(!Strategy_ValidMonthDay(strategy_xti_start_month, strategy_xti_start_day))
      return true;
   if(!Strategy_ValidMonthDay(strategy_xti_end_month, strategy_xti_end_day))
      return true;
   if(!Strategy_ValidMonthDay(strategy_xng_start_month, strategy_xng_start_day))
      return true;
   if(!Strategy_ValidMonthDay(strategy_xng_end_month, strategy_xng_end_day))
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
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
   req.reason = "QM5_12813_XTI_XNG_SEASON_SWITCH_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly de-dupe behind new-bar gate.
   const int month_key = Strategy_MonthKey(current_bar);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   int direction = 0;
   if(!Strategy_LoadSignalState(direction))
      return false;
   if(direction == 0)
      return false;

   if(Strategy_OpenPair(direction))
     {
      g_last_entry_month_key = month_key;
      g_current_direction = direction;
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
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

   const int current_pair_direction = Strategy_CurrentPairDirection();
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 season lifecycle check.
   if(current_pair_direction != 0 && Strategy_SeasonDirection(current_bar) != current_pair_direction)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime oldest_open = Strategy_OldestPairOpenTime();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   if(oldest_open > 0 && TimeCurrent() - oldest_open >= hold_seconds)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   if(Strategy_IsMonthlyRebalanceBar())
     {
      if(current_bar > 0 && oldest_open > 0 && Strategy_MonthKey(oldest_open) != Strategy_MonthKey(current_bar))
         Strategy_ClosePair(QM_EXIT_STRATEGY);
     }
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
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
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
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(160, strategy_trend_period_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12813\",\"ea\":\"eia-energy-switch\"}");
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
