#property strict
#property version   "5.0"
#property description "QM5_12741 NNFX FX Basket Pooled Trend Sleeve"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12741 - NNFX FX Basket Pooled Trend Sleeve
// -----------------------------------------------------------------------------
// Single-host D1 basket that applies the faithful QM5_12534 NNFX stack to the
// four gross-positive FX majors named by the approved card.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12741;
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
input int    strategy_kijun_period        = 26;
input int    strategy_ssl_period          = 10;
input int    strategy_aroon_period        = 25;
input int    strategy_entry_window_bars   = 3;
input int    strategy_atr_period          = 14;
input double strategy_atr_proximity_mult  = 1.0;
input double strategy_sl_atr_mult         = 1.5;
input double strategy_tp_half_atr_mult    = 1.0;
input int    strategy_wae_fast            = 20;
input int    strategy_wae_slow            = 40;
input int    strategy_wae_signal          = 9;
input double strategy_wae_sensitivity     = 150.0;
input int    strategy_wae_bb_period       = 20;
input double strategy_wae_bb_deviation    = 2.0;
input int    strategy_wae_deadzone_pts    = 150;
input int    strategy_max_family_positions = 4;
input double strategy_leg_risk_fraction   = 0.25;
input int    strategy_max_spread_points   = 0;
input int    strategy_deviation_points    = 20;

#define QM12741_BASKET_SIZE 4

string g_qm12741_symbols[QM12741_BASKET_SIZE] =
  {
   "AUDUSD.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDCHF.DWX"
  };

int Strategy_SlotForSymbol(const string symbol)
  {
   for(int i = 0; i < QM12741_BASKET_SIZE; ++i)
      if(g_qm12741_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_qm12741_symbols[0] && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_LoadClosedBars(const string symbol, MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, count, rates); // perf-allowed: bounded D1 stack read, called behind QM_IsNewBar().
   return (copied == count);
  }

bool Strategy_BaselineRecentCross(const string symbol, const int direction)
  {
   const int window = MathMax(1, strategy_entry_window_bars);
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(symbol, rates, window + 1))
      return false;

   for(int shift = 1; shift <= window; ++shift)
     {
      const double close_now = rates[shift - 1].close;
      const double close_prev = rates[shift].close;
      const double kijun_now = QM_Ichimoku_KijunSen(symbol, PERIOD_D1, 9, strategy_kijun_period, 52, shift);
      const double kijun_prev = QM_Ichimoku_KijunSen(symbol, PERIOD_D1, 9, strategy_kijun_period, 52, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0 || kijun_now <= 0.0 || kijun_prev <= 0.0)
         continue;
      if(direction > 0 && close_now > kijun_now && close_prev <= kijun_prev)
         return true;
      if(direction < 0 && close_now < kijun_now && close_prev >= kijun_prev)
         return true;
     }

   return false;
  }

int Strategy_SSLSignal(const string symbol, const int shift)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(symbol, rates, shift))
      return 0;

   const double close_price = rates[shift - 1].close;
   const double high_ma = QM_SMA(symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_HIGH);
   const double low_ma = QM_SMA(symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_LOW);
   if(close_price <= 0.0 || high_ma <= 0.0 || low_ma <= 0.0)
      return 0;
   if(close_price > high_ma)
      return 1;
   if(close_price < low_ma)
      return -1;
   return 0;
  }

int Strategy_AroonSignal(const string symbol)
  {
   MqlRates rates[];
   const int period = MathMax(2, strategy_aroon_period);
   if(!Strategy_LoadClosedBars(symbol, rates, period))
      return 0;

   int highest_idx = 0;
   int lowest_idx = 0;
   double highest = rates[0].high;
   double lowest = rates[0].low;
   for(int i = 1; i < period; ++i)
     {
      if(rates[i].high > highest)
        {
         highest = rates[i].high;
         highest_idx = i;
        }
      if(rates[i].low < lowest)
        {
         lowest = rates[i].low;
         lowest_idx = i;
        }
     }

   const double aroon_up = 100.0 * (period - highest_idx) / period;
   const double aroon_down = 100.0 * (period - lowest_idx) / period;
   if(aroon_up > aroon_down)
      return 1;
   if(aroon_down > aroon_up)
      return -1;
   return 0;
  }

int Strategy_WAESignal(const string symbol)
  {
   const double macd_now = QM_MACD_Main(symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper = QM_BB_Upper(symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return 0;

   const double momentum = (macd_now - macd_prev) * strategy_wae_sensitivity;
   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);

   if(momentum > threshold)
      return 1;
   if(-momentum > threshold)
      return -1;
   return 0;
  }

bool Strategy_ProximityPass(const string symbol, const int direction)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(symbol, rates, 1))
      return false;

   const double close_price = rates[0].close;
   const double kijun = QM_Ichimoku_KijunSen(symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 1);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_price <= 0.0 || kijun <= 0.0 || atr <= 0.0)
      return false;
   if(direction > 0 && close_price <= kijun)
      return false;
   if(direction < 0 && close_price >= kijun)
      return false;
   return (MathAbs(close_price - kijun) < atr * strategy_atr_proximity_mult);
  }

int Strategy_NNFXDirection(const string symbol)
  {
   const int ssl = Strategy_SSLSignal(symbol, 1);
   const int aroon = Strategy_AroonSignal(symbol);
   const int wae = Strategy_WAESignal(symbol);

   if(Strategy_BaselineRecentCross(symbol, 1) && Strategy_ProximityPass(symbol, 1) &&
      ssl > 0 && aroon > 0 && wae > 0)
      return 1;
   if(Strategy_BaselineRecentCross(symbol, -1) && Strategy_ProximityPass(symbol, -1) &&
      ssl < 0 && aroon < 0 && wae < 0)
      return -1;
   return 0;
  }

bool Strategy_IsFamilyPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

bool Strategy_HasFamilyPosition(const string symbol)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   const int resolved_magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(resolved_magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == resolved_magic)
         return true;
     }
   return false;
  }

int Strategy_FamilyPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsFamilyPosition())
         ++count;
     }
   return count;
  }

void Strategy_CloseFamilyPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsFamilyPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   return (spread <= strategy_max_spread_points);
  }

double Strategy_LotsForLeg(const string symbol, const double entry_price, const double sl_price)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0)
      return 0.0;

   const double sl_points = MathAbs(entry_price - sl_price) / point;
   if(sl_points <= 0.0)
      return 0.0;

   double lots = QM_LotsForRisk(symbol, sl_points) * MathMax(0.0, strategy_leg_risk_fraction);
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

bool Strategy_OpenSymbolLeg(const string symbol, const int direction)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || direction == 0)
      return false;
   if(Strategy_HasFamilyPosition(symbol) || !Strategy_SpreadAllowed(symbol))
      return false;

   SymbolSelect(symbol, true);

   const QM_OrderType order_type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_OrderTypeIsBuy(order_type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                      : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(symbol, order_type, entry, atr, strategy_sl_atr_mult);
   const double lots = Strategy_LotsForLeg(symbol, entry, sl);
   if(sl <= 0.0 || lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = (direction > 0) ? "QM5_12741_NNFX_BASKET_LONG" : "QM5_12741_NNFX_BASKET_SHORT";
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong out_ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, out_ticket);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_kijun_period < 2 || strategy_ssl_period < 2 || strategy_aroon_period < 2)
      return true;
   if(strategy_entry_window_bars < 1 || strategy_atr_period < 1)
      return true;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_half_atr_mult <= 0.0)
      return true;
   if(strategy_leg_risk_fraction <= 0.0 || strategy_leg_risk_fraction > 1.0)
      return true;
   if(strategy_max_family_positions < 1 || strategy_max_family_positions > QM12741_BASKET_SIZE)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12741_NNFX_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int open_count = Strategy_FamilyPositionCount();
   if(open_count >= strategy_max_family_positions)
      return false;

   bool opened_any = false;
   for(int i = 0; i < QM12741_BASKET_SIZE; ++i)
     {
      if(open_count >= strategy_max_family_positions)
         break;

      const string symbol = g_qm12741_symbols[i];
      if(Strategy_HasFamilyPosition(symbol))
         continue;

      const int direction = Strategy_NNFXDirection(symbol);
      if(direction == 0)
         continue;

      if(Strategy_OpenSymbolLeg(symbol, direction))
        {
         opened_any = true;
         open_count++;
         QM_LogEvent(QM_INFO,
                     "STRATEGY_ENTRY",
                     StringFormat("{\"symbol\":\"%s\",\"direction\":%d}", symbol, direction));
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsFamilyPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || price <= 0.0 || volume <= 0.0)
         continue;

      const double trigger = is_buy ? (open_price + atr * strategy_tp_half_atr_mult)
                                    : (open_price - atr * strategy_tp_half_atr_mult);
      const bool hit_trigger = is_buy ? (price >= trigger) : (price <= trigger);
      const bool sl_not_breakeven = (current_sl <= 0.0) ||
                                    (is_buy ? (current_sl < open_price) : (current_sl > open_price));
      if(!hit_trigger || !sl_not_breakeven)
         continue;

      const double half_lots = QM_TM_NormalizeVolume(symbol, volume * 0.5);
      if(half_lots > 0.0 && half_lots < volume && QM_TM_PartialClose(ticket, half_lots, QM_EXIT_PARTIAL))
        {
         const double be = QM_TM_NormalizePrice(symbol, open_price);
         QM_TM_MoveSL(ticket, be, "nnfx_basket_half_tp_runner_be");
        }
     }
  }

bool Strategy_ExitBySignal(const string symbol, const ENUM_POSITION_TYPE ptype)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(symbol, rates, 2))
      return false;

   const double close_now = rates[0].close;
   const double close_prev = rates[1].close;
   const double kijun_now = QM_Ichimoku_KijunSen(symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 1);
   const double kijun_prev = QM_Ichimoku_KijunSen(symbol, PERIOD_D1, 9, strategy_kijun_period, 52, 2);
   const int ssl = Strategy_SSLSignal(symbol, 1);
   if(close_now <= 0.0 || close_prev <= 0.0 || kijun_now <= 0.0 || kijun_prev <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return ((close_now < kijun_now && close_prev >= kijun_prev) || ssl < 0);
   if(ptype == POSITION_TYPE_SELL)
      return ((close_now > kijun_now && close_prev <= kijun_prev) || ssl > 0);
   return false;
  }

bool Strategy_ExitSignal()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsFamilyPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(Strategy_ExitBySignal(symbol, ptype))
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_CloseFamilyPositions(QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   for(int i = 0; i < QM12741_BASKET_SIZE; ++i)
     {
      const string symbol = g_qm12741_symbols[i];
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else
        {
         if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
            return true;
        }
     }
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < QM12741_BASKET_SIZE; ++i)
      SymbolSelect(g_qm12741_symbols[i], true);

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

   QM_SymbolGuardInit(g_qm12741_symbols);
   QM_BasketWarmupHistory(g_qm12741_symbols, PERIOD_D1, MathMax(180, strategy_entry_window_bars + strategy_aroon_period + strategy_kijun_period + 60));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12741\",\"ea\":\"nnfx-fx-basket-pooled\"}");
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
