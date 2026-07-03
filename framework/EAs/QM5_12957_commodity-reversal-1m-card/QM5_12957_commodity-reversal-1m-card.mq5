#property strict
#property version   "5.0"
#property description "QM5_12957 monthly commodity reversal basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12957 - One-Month Market-Neutral Commodity Reversal Basket
// -----------------------------------------------------------------------------
// Monthly D1 basket:
//   - rank XTI, XNG, XAU, and XAG by prior N-day log return
//   - buy the worst prior-month performer and short the best
//   - require at least one selected leg to be energy when enabled
//   - close the package on the next monthly rebalance, max-hold expiry,
//     broken-package repair, Friday close, or per-leg ATR hard stop
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12957;
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
input int    strategy_lookback_d1          = 21;
input double strategy_min_return_diff_pct  = 4.0;
input bool   strategy_require_energy_leg   = true;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 35;
input int    strategy_xti_max_spread_pts   = 1000;
input int    strategy_xng_max_spread_pts   = 2500;
input int    strategy_xau_max_spread_pts   = 500;
input int    strategy_xag_max_spread_pts   = 200;
input int    strategy_deviation_points     = 20;

string   g_sym_xti = "XTIUSD.DWX";
string   g_sym_xng = "XNGUSD.DWX";
string   g_sym_xau = "XAUUSD.DWX";
string   g_sym_xag = "XAGUSD.DWX";
double   g_returns[4];
int      g_worst_slot = -1;
int      g_best_slot = -1;
double   g_return_diff = 0.0;
datetime g_pair_entry_time = 0;
int      g_last_entry_month_key = 0;

string Strategy_SymbolForSlot(const int slot)
  {
   if(slot == 0)
      return g_sym_xti;
   if(slot == 1)
      return g_sym_xng;
   if(slot == 2)
      return g_sym_xau;
   if(slot == 3)
      return g_sym_xag;
   return "";
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_sym_xti)
      return 0;
   if(symbol == g_sym_xng)
      return 1;
   if(symbol == g_sym_xau)
      return 2;
   if(symbol == g_sym_xag)
      return 3;
   return -1;
  }

bool Strategy_IsEnergySlot(const int slot)
  {
   return (slot == 0 || slot == 1);
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_sym_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
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

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(symbol == g_sym_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_sym_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
   if(symbol == g_sym_xau && strategy_xau_max_spread_pts > 0)
      return (spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_sym_xag && strategy_xag_max_spread_pts > 0)
      return (spread_points <= strategy_xag_max_spread_pts);
   return true;
  }

bool Strategy_IsBasketPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenBasketLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsBasketPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_OldestBasketOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsBasketPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0)
         continue;
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

void Strategy_CloseBasket(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsBasketPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_ReturnForSlot(const int slot, double &value)
  {
   value = 0.0;
   const string symbol = Strategy_SymbolForSlot(slot);
   const int lookback = MathMax(15, strategy_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_D1, 1, lookback + 1, closes) != lookback + 1) // perf-allowed: bounded D1 monthly ranking sample.
      return false;
   if(closes[0] <= 0.0 || closes[lookback] <= 0.0)
      return false;
   value = MathLog(closes[0] / closes[lookback]);
   return MathIsValidNumber(value);
  }

bool Strategy_LoadSignalState()
  {
   g_worst_slot = -1;
   g_best_slot = -1;
   g_return_diff = 0.0;

   for(int slot = 0; slot < 4; ++slot)
     {
      if(!Strategy_ReturnForSlot(slot, g_returns[slot]))
         return false;
      if(g_worst_slot < 0 || g_returns[slot] < g_returns[g_worst_slot])
         g_worst_slot = slot;
      if(g_best_slot < 0 || g_returns[slot] > g_returns[g_best_slot])
         g_best_slot = slot;
     }

   if(g_worst_slot < 0 || g_best_slot < 0 || g_worst_slot == g_best_slot)
      return false;

   g_return_diff = g_returns[g_best_slot] - g_returns[g_worst_slot];
   if(!MathIsValidNumber(g_return_diff))
      return false;

   const double threshold = MathMax(0.0, strategy_min_return_diff_pct) / 100.0;
   if(g_return_diff < threshold)
      return false;

   if(strategy_require_energy_leg && !Strategy_IsEnergySlot(g_worst_slot) && !Strategy_IsEnergySlot(g_best_slot))
      return false;

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

bool Strategy_OpenLeg(const int slot,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const string symbol = Strategy_SymbolForSlot(slot);
   if(symbol == "" || !Strategy_SpreadAllowed(symbol))
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

bool Strategy_OpenPackage()
  {
   if(g_worst_slot < 0 || g_best_slot < 0 || g_worst_slot == g_best_slot)
      return false;
   if(Strategy_OpenBasketLegCount() > 0)
      return false;

   const string worst_symbol = Strategy_SymbolForSlot(g_worst_slot);
   const string best_symbol = Strategy_SymbolForSlot(g_best_slot);
   if(!Strategy_SpreadAllowed(worst_symbol) || !Strategy_SpreadAllowed(best_symbol))
      return false;

   const string reason = "QM5_12957_LONG_LOSER_SHORT_WINNER";
   const double weight_sum = 2.0;
   const bool long_ok = Strategy_OpenLeg(g_worst_slot, QM_BUY, 1.0, weight_sum, reason);
   const bool short_ok = Strategy_OpenLeg(g_best_slot, QM_SELL, 1.0, weight_sum, reason);

   if(long_ok && short_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_CloseBasket(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_lookback_d1 < 15 || strategy_min_return_diff_pct < 0.0)
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
   req.reason = "QM5_12957_COMM_REV_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly de-dupe behind new-bar gate.
   const int month_key = Strategy_MonthKey(current_bar);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(Strategy_OpenBasketLegCount() > 0)
      return false;

   if(!Strategy_LoadSignalState())
      return false;

   if(Strategy_OpenPackage())
      g_last_entry_month_key = month_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenBasketLegCount();
   if(open_legs <= 0)
      return false;
   if(open_legs != 2)
     {
      Strategy_CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime oldest_open = Strategy_OldestBasketOpenTime();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   if(oldest_open > 0 && TimeCurrent() - oldest_open >= hold_seconds)
     {
      Strategy_CloseBasket(QM_EXIT_TIME_STOP);
      return false;
     }

   if(Strategy_IsMonthlyRebalanceBar())
     {
      const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly package lifecycle check.
      if(current_bar > 0 && oldest_open > 0 && Strategy_MonthKey(oldest_open) != Strategy_MonthKey(current_bar))
         Strategy_CloseBasket(QM_EXIT_STRATEGY);
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int slot = 0; slot < 4; ++slot)
     {
      const string symbol = Strategy_SymbolForSlot(slot);
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   SymbolSelect(g_sym_xti, true);
   SymbolSelect(g_sym_xng, true);
   SymbolSelect(g_sym_xau, true);
   SymbolSelect(g_sym_xag, true);

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

   string basket_symbols[4] = {g_sym_xti, g_sym_xng, g_sym_xau, g_sym_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(260, strategy_lookback_d1 + strategy_atr_period_d1 + 20));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12957\",\"ea\":\"commodity-reversal-1m-card\"}");
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
   if(qm_friday_close_enabled && QM_FrameworkFridayCloseNow(broker_now))
     {
      Strategy_CloseBasket(QM_EXIT_FRIDAY_CLOSE);
      return;
     }
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(Strategy_NewsFilterHook(broker_now))
      return;

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
