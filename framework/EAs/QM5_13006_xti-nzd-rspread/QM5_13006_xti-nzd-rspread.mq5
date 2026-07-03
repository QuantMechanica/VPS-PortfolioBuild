#property strict
#property version   "5.0"
#property description "QM5_13006 XTI/NZD Commodity-FX Residual Spread Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13006 - XTI/NZD commodity-FX residual spread reversion
// -----------------------------------------------------------------------------
// D1 two-leg basket:
//   spread = ln(XTIUSD.DWX) - beta_nzd * ln(NZDUSD.DWX)
//   rich spread: sell XTI, buy NZDUSD
//   cheap spread: buy XTI, sell NZDUSD
// Runtime uses MT5 OHLC only; no macro feed, futures curve, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 13006;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_z_lookback_d1         = 120;
input double strategy_beta_nzd              = 0.5;
input double strategy_entry_z               = 2.0;
input double strategy_exit_z                = 0.5;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_hold_days         = 45;
input int    strategy_xti_max_spread_pts    = 1000;
input int    strategy_nzdusd_max_spread_pts = 90;
input int    strategy_deviation_points      = 20;
input int    strategy_entry_hour_broker     = 0;
input int    strategy_entry_minute_broker   = 0;

string   g_leg_xti    = "XTIUSD.DWX";
string   g_leg_nzdusd = "NZDUSD.DWX";
double   g_spread_z = 0.0;
double   g_spread_mean = 0.0;
double   g_spread_sd = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_nzdusd)
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
   if(symbol == g_leg_nzdusd && strategy_nzdusd_max_spread_pts > 0)
      return (spread_points <= strategy_nzdusd_max_spread_pts);
   return true;
  }

int Strategy_SecondsOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 3600 + dt.min * 60 + dt.sec;
  }

bool Strategy_SymbolTradeSessionOpen(const string symbol, const datetime broker_time)
  {
   MqlDateTime now;
   TimeToStruct(broker_time, now);
   const int seconds_now = now.hour * 3600 + now.min * 60 + now.sec;

   bool has_schedule = false;
   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 16; ++session)
     {
      if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)now.day_of_week, session, session_from, session_to))
         break;

      has_schedule = true;
      int from_seconds = Strategy_SecondsOfDay(session_from);
      int to_seconds = Strategy_SecondsOfDay(session_to);
      if(from_seconds == to_seconds)
         continue;
      if(to_seconds == 0)
         to_seconds = 24 * 3600;

      if(from_seconds < to_seconds)
        {
         if(seconds_now >= from_seconds && seconds_now < to_seconds)
            return true;
        }
      else
        {
         if(seconds_now >= from_seconds || seconds_now < to_seconds)
            return true;
        }
     }

   return (!has_schedule && now.day_of_week >= 1 && now.day_of_week <= 5);
  }

bool Strategy_SymbolTradeReady(const string symbol, const datetime broker_time)
  {
   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   return Strategy_SymbolTradeSessionOpen(symbol, broker_time);
  }

bool Strategy_EntryTimeReady(const datetime broker_time)
  {
   if(strategy_entry_hour_broker < 0 || strategy_entry_hour_broker > 23)
      return false;
   if(strategy_entry_minute_broker < 0 || strategy_entry_minute_broker > 59)
      return false;

   MqlDateTime now;
   TimeToStruct(broker_time, now);
   const int now_minutes = now.hour * 60 + now.min;
   const int entry_minutes = strategy_entry_hour_broker * 60 + strategy_entry_minute_broker;
   if(now_minutes < entry_minutes)
      return false;
   if(!Strategy_SymbolTradeReady(g_leg_xti, broker_time))
      return false;
   if(!Strategy_SymbolTradeReady(g_leg_nzdusd, broker_time))
      return false;
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
  }

int Strategy_PairDirection()
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   if(xti_magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xti)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != xti_magic)
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
      if(opened <= 0)
         continue;
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

bool Strategy_RefreshSpreadState()
  {
   g_state_ready = false;
   const int lookback = MathMax(30, strategy_z_lookback_d1);

   double xti[];
   double nzdusd[];
   ArraySetAsSeries(xti, true);
   ArraySetAsSeries(nzdusd, true);
   if(CopyClose(g_leg_xti, PERIOD_D1, 1, lookback, xti) != lookback) // perf-allowed: called only behind D1 new-bar or close-state refresh.
      return false;
   if(CopyClose(g_leg_nzdusd, PERIOD_D1, 1, lookback, nzdusd) != lookback) // perf-allowed: called only behind D1 new-bar or close-state refresh.
      return false;

   double sum = 0.0;
   double spreads[];
   ArrayResize(spreads, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(xti[i] <= 0.0 || nzdusd[i] <= 0.0)
         return false;
      spreads[i] = MathLog(xti[i]) - strategy_beta_nzd * MathLog(nzdusd[i]);
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

bool Strategy_OpenPair(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) ||
      !Strategy_SpreadAllowed(g_leg_nzdusd))
      return false;

   const double xti_weight = 1.0;
   const double nzd_weight = MathMax(0.1, MathAbs(strategy_beta_nzd));
   const double weight_sum = xti_weight + nzd_weight;
   const bool long_spread = (spread_direction > 0);
   const QM_OrderType xti_type = long_spread ? QM_BUY : QM_SELL;
   const QM_OrderType nzd_type = long_spread ? QM_SELL : QM_BUY;
   const string reason = long_spread ? "QM5_13006_LONG_XTI_NZD_RSPREAD"
                                     : "QM5_13006_SHORT_XTI_NZD_RSPREAD";

   bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, xti_weight, weight_sum, reason);
   bool nzd_ok = Strategy_OpenLeg(g_leg_nzdusd, nzd_type, nzd_weight, weight_sum, reason);
   if(xti_ok && nzd_ok)
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
   if(strategy_z_lookback_d1 < 30 || strategy_beta_nzd <= 0.0)
      return true;
   if(strategy_entry_z <= 0.0 || strategy_exit_z < 0.0 || strategy_exit_z >= strategy_entry_z)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   if(strategy_entry_hour_broker < 0 || strategy_entry_hour_broker > 23)
      return true;
   if(strategy_entry_minute_broker < 0 || strategy_entry_minute_broker > 59)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13006_SPREAD_HOST";
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

   const datetime oldest_open = Strategy_OldestPairOpenTime();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   if(oldest_open > 0 && TimeCurrent() - oldest_open >= hold_seconds)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   if(!g_state_ready)
      return false;

   const int pair_direction = Strategy_PairDirection();
   const double exit_z = MathMax(0.0, strategy_exit_z);
   if(pair_direction > 0 && g_spread_z >= -exit_z)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   else if(pair_direction < 0 && g_spread_z <= exit_z)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   else if(pair_direction == 0)
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
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_nzdusd, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_nzdusd, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_nzdusd, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_nzdusd};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(180, strategy_z_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13006\",\"ea\":\"xti-nzd-rspread\"}");
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

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      if(Strategy_OpenPairLegCount() > 0)
         Strategy_RefreshSpreadState();
     }

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

   if(!new_bar)
      return;
   if(!Strategy_EntryTimeReady(broker_now))
      return;

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
