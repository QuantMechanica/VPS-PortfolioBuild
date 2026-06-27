#property strict
#property version   "5.0"
#property description "QM5_12605 CME Oil Gold Ratio Breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12605 - CME Oil/Gold Ratio Breakout
// -----------------------------------------------------------------------------
// D1 two-leg commodity basket:
//   spread = ln(XTIUSD.DWX) - beta * ln(XAUUSD.DWX)
//   break above entry channel: long ratio = buy WTI, sell gold
//   break below entry channel: short ratio = sell WTI, buy gold
// The EA runs from the XTIUSD.DWX host chart and trades both registered legs
// through QM_BasketOrder. Runtime uses MT5 OHLC only; no external CME data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12605;
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
input int    strategy_entry_lookback_d1 = 120;
input int    strategy_exit_lookback_d1  = 40;
input double strategy_beta              = 1.0;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_xti_max_spread_pts = 1000;
input int    strategy_xau_max_spread_pts = 500;
input int    strategy_deviation_points   = 20;

string   g_leg_xti = "XTIUSD.DWX";
string   g_leg_xau = "XAUUSD.DWX";
double   g_spread_value = 0.0;
double   g_entry_high = 0.0;
double   g_entry_low = 0.0;
double   g_exit_high = 0.0;
double   g_exit_low = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;
datetime g_last_state_bar = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xau)
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
   if(symbol == g_leg_xau && strategy_xau_max_spread_pts > 0)
      return (spread_points <= strategy_xau_max_spread_pts);
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

bool Strategy_RefreshSpreadState()
  {
   g_state_ready = false;
   const int entry_lookback = MathMax(20, strategy_entry_lookback_d1);
   const int exit_lookback = MathMax(5, strategy_exit_lookback_d1);
   const int lookback = MathMax(entry_lookback, exit_lookback) + 1;

   double xti[];
   double xau[];
   ArraySetAsSeries(xti, true);
   ArraySetAsSeries(xau, true);
   if(CopyClose(g_leg_xti, PERIOD_D1, 1, lookback, xti) != lookback) // perf-allowed: called only behind the D1 new-bar gate or close-state refresh.
      return false;
   if(CopyClose(g_leg_xau, PERIOD_D1, 1, lookback, xau) != lookback) // perf-allowed: called only behind the D1 new-bar gate or close-state refresh.
      return false;

   double spreads[];
   ArrayResize(spreads, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(xti[i] <= 0.0 || xau[i] <= 0.0)
         return false;
      spreads[i] = MathLog(xti[i]) - strategy_beta * MathLog(xau[i]);
      if(!MathIsValidNumber(spreads[i]))
         return false;
     }

   g_spread_value = spreads[0];
   g_entry_high = spreads[1];
   g_entry_low = spreads[1];
   for(int i = 1; i <= entry_lookback; ++i)
     {
      g_entry_high = MathMax(g_entry_high, spreads[i]);
      g_entry_low = MathMin(g_entry_low, spreads[i]);
     }

   g_exit_high = spreads[1];
   g_exit_low = spreads[1];
   for(int i = 1; i <= exit_lookback; ++i)
     {
      g_exit_high = MathMax(g_exit_high, spreads[i]);
      g_exit_low = MathMin(g_exit_low, spreads[i]);
     }

   g_state_ready = (
      MathIsValidNumber(g_spread_value) &&
      MathIsValidNumber(g_entry_high) &&
      MathIsValidNumber(g_entry_low) &&
      MathIsValidNumber(g_exit_high) &&
      MathIsValidNumber(g_exit_low) &&
      g_entry_high > g_entry_low &&
      g_exit_high > g_exit_low
   );
   if(g_state_ready)
      g_last_state_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap cached D1 timestamp.
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

bool Strategy_OpenPair(const int ratio_direction)
  {
   if(ratio_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xau))
      return false;

   const double xti_weight = 1.0;
   const double xau_weight = MathMax(0.1, MathAbs(strategy_beta));
   const double weight_sum = xti_weight + xau_weight;
   const bool long_ratio = (ratio_direction > 0);
   const QM_OrderType xti_type = long_ratio ? QM_BUY : QM_SELL;
   const QM_OrderType xau_type = long_ratio ? QM_SELL : QM_BUY;
   const string reason = long_ratio ? "QM5_12605_LONG_XTI_XAU_BRK"
                                    : "QM5_12605_SHORT_XTI_XAU_BRK";

   bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, xti_weight, weight_sum, reason);
   bool xau_ok = Strategy_OpenLeg(g_leg_xau, xau_type, xau_weight, weight_sum, reason);
   if(xti_ok && xau_ok)
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
   if(strategy_entry_lookback_d1 < 20 || strategy_exit_lookback_d1 < 5)
      return true;
   if(strategy_exit_lookback_d1 >= strategy_entry_lookback_d1 || strategy_beta <= 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12605_BRK_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshSpreadState())
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   if(g_spread_value > g_entry_high)
      Strategy_OpenPair(1);
   else if(g_spread_value < g_entry_low)
      Strategy_OpenPair(-1);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

int Strategy_PairDirection()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xti)
         continue;
      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
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

   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp guard before optional spread refresh.
   if(current_d1_bar > 0 && current_d1_bar != g_last_state_bar)
      Strategy_RefreshSpreadState();
   const int direction = Strategy_PairDirection();
   if(g_state_ready && direction > 0 && g_spread_value < g_exit_low)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
   if(g_state_ready && direction < 0 && g_spread_value > g_exit_high)
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
      if(!QM_NewsAllowsTrade2(g_leg_xau, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xau, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xau};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(160, strategy_entry_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12605\",\"ea\":\"cme-oilgold-brk\"}");
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
