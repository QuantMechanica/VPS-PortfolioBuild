#property strict
#property version   "5.0"
#property description "QM5_13083 XBR CADJPY Return Spread Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13083 - Brent/CADJPY Return-Spread Reversion
// -----------------------------------------------------------------------------
// D1 two-leg energy/FX basket:
//   rspread = log(XBR[t] / XBR[t-L]) - beta_cadjpy * log(CADJPY[t] / CADJPY[t-L])
//   z > entry: short return spread = sell Brent, buy CADJPY
//   z < -entry: long return spread = buy Brent, sell CADJPY
// The EA runs from the XBRUSD.DWX host chart and trades both registered legs
// through QM_BasketOrder. Runtime uses MT5 OHLC only; no external feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13083;
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
input int    strategy_return_lookback_d1  = 20;
input int    strategy_z_lookback_d1       = 120;
input double strategy_beta_cadjpy         = 0.65;
input double strategy_entry_z             = 1.9;
input double strategy_exit_z              = 0.4;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 30;
input int    strategy_xbr_max_spread_pts  = 1000;
input int    strategy_cadjpy_max_spread_pts = 120;
input int    strategy_deviation_points    = 20;

string   g_leg_xbr    = "XBRUSD.DWX";
string   g_leg_cadjpy = "CADJPY.DWX";
double   g_spread_z = 0.0;
double   g_spread_mean = 0.0;
double   g_spread_sd = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xbr)
      return 0;
   if(symbol == g_leg_cadjpy)
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
   if(symbol == g_leg_cadjpy && strategy_cadjpy_max_spread_pts > 0)
      return (spread_points <= strategy_cadjpy_max_spread_pts);
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

bool Strategy_RefreshSpreadState()
  {
   g_state_ready = false;
   const int return_lookback = MathMax(5, strategy_return_lookback_d1);
   const int z_lookback = MathMax(40, strategy_z_lookback_d1);
   const int history_needed = z_lookback + return_lookback + 1;

   double xbr[];
   double cadjpy[];
   ArraySetAsSeries(xbr, true);
   ArraySetAsSeries(cadjpy, true);
   if(CopyClose(g_leg_xbr, PERIOD_D1, 1, history_needed, xbr) != history_needed) // perf-allowed: called only behind the D1 new-bar gate or close-state refresh.
      return false;
   if(CopyClose(g_leg_cadjpy, PERIOD_D1, 1, history_needed, cadjpy) != history_needed) // perf-allowed: called only behind the D1 new-bar gate or close-state refresh.
      return false;

   double sum = 0.0;
   double spreads[];
   ArrayResize(spreads, z_lookback);
   for(int i = 0; i < z_lookback; ++i)
     {
      const int past_idx = i + return_lookback;
      if(xbr[i] <= 0.0 || cadjpy[i] <= 0.0 || xbr[past_idx] <= 0.0 || cadjpy[past_idx] <= 0.0)
         return false;

      const double xbr_ret = MathLog(xbr[i] / xbr[past_idx]);
      const double cadjpy_ret = MathLog(cadjpy[i] / cadjpy[past_idx]);
      spreads[i] = xbr_ret - strategy_beta_cadjpy * cadjpy_ret;
      if(!MathIsValidNumber(spreads[i]))
         return false;
      sum += spreads[i];
     }

   g_spread_mean = sum / (double)z_lookback;
   double var_sum = 0.0;
   for(int i = 0; i < z_lookback; ++i)
     {
      const double d = spreads[i] - g_spread_mean;
      var_sum += d * d;
     }

   g_spread_sd = MathSqrt(var_sum / (double)MathMax(1, z_lookback - 1));
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
   if(!Strategy_SpreadAllowed(g_leg_xbr) || !Strategy_SpreadAllowed(g_leg_cadjpy))
      return false;

   const double xbr_weight = 1.0;
   const double cadjpy_weight = MathMax(0.1, MathAbs(strategy_beta_cadjpy));
   const double weight_sum = xbr_weight + cadjpy_weight;
   const bool long_spread = (spread_direction > 0);
   const QM_OrderType xbr_type = long_spread ? QM_BUY : QM_SELL;
   const QM_OrderType cadjpy_type = long_spread ? QM_SELL : QM_BUY;
   const string reason = long_spread ? "QM5_13083_LONG_XBR_CADJPY_RSPREAD"
                                     : "QM5_13083_SHORT_XBR_CADJPY_RSPREAD";

   bool xbr_ok = Strategy_OpenLeg(g_leg_xbr, xbr_type, xbr_weight, weight_sum, reason);
   bool cadjpy_ok = Strategy_OpenLeg(g_leg_cadjpy, cadjpy_type, cadjpy_weight, weight_sum, reason);
   if(xbr_ok && cadjpy_ok)
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
   if(strategy_return_lookback_d1 < 5 || strategy_z_lookback_d1 < 40 || strategy_beta_cadjpy <= 0.0)
      return true;
   if(strategy_entry_z <= 0.0 || strategy_exit_z < 0.0 || strategy_exit_z >= strategy_entry_z)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13083_RSPREAD_HOST";
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

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;

   const long hold_seconds = (long)strategy_max_hold_days * 86400;
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

   if(g_state_ready && MathAbs(g_spread_z) < strategy_exit_z)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   else if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xbr, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_cadjpy, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xbr, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_cadjpy, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_leg_xbr, true);
   SymbolSelect(g_leg_cadjpy, true);

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

   string basket_symbols[2] = {g_leg_xbr, g_leg_cadjpy};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(220, strategy_z_lookback_d1 + strategy_return_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13083\",\"ea\":\"xbr-cadjpy-rspr\"}");
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
   if(Strategy_NewsFilterHook(broker_now))
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
