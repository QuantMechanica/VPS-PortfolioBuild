#property strict
#property version   "5.0"
#property description "QM5_12615 TSMOM 12M Cross-Asset Vol-Scaled Basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12615 - TSMOM 12M Cross-Asset Vol-Scaled Basket
// -----------------------------------------------------------------------------
// Monthly 12-month time-series momentum across EURUSD, NDX, XAUUSD, and XTIUSD.
// Each leg is sized from fixed per-slot risk multiplied by its realized-vol scalar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12615;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1_bars   = 252;
input int    strategy_vol_window_d1      = 63;
input double strategy_target_annual_vol  = 0.10;
input double strategy_max_vol_scale      = 2.0;
input double strategy_min_realized_vol   = 0.005;
input int    strategy_min_d1_bars        = 330;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input double strategy_vol_reopen_threshold = 0.25;
input double strategy_leg_risk_fraction  = 0.25;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;
input int    strategy_max_family_positions = 4;
input int    strategy_deviation_points   = 20;

#define QM12615_BASKET_SIZE 4

string g_qm12615_symbols[QM12615_BASKET_SIZE] =
  {
   "EURUSD.DWX",
   "NDX.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
  };

int g_qm12615_slots[QM12615_BASKET_SIZE] = {0, 1, 2, 3};
double g_qm12615_last_scalar[QM12615_BASKET_SIZE] = {0.0, 0.0, 0.0, 0.0};

int Strategy_SlotForSymbol(const string symbol)
  {
   for(int i = 0; i < QM12615_BASKET_SIZE; ++i)
      if(g_qm12615_symbols[i] == symbol)
         return g_qm12615_slots[i];
   return -1;
  }

int Strategy_IndexForSymbol(const string symbol)
  {
   for(int i = 0; i < QM12615_BASKET_SIZE; ++i)
      if(g_qm12615_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_qm12615_symbols[0] && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_IsMonthRebalanceBar()
  {
   if(!Strategy_IsHostChart())
      return false;

   const datetime closed_bar = iTime(g_qm12615_symbols[0], PERIOD_D1, 1); // perf-allowed: monthly D1 boundary detection
   const datetime current_bar = iTime(g_qm12615_symbols[0], PERIOD_D1, 0); // perf-allowed: monthly D1 boundary detection
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
  }

bool Strategy_HistoryReady(const string symbol)
  {
   const int min_bars = MathMax(strategy_min_d1_bars,
                                strategy_lookback_d1_bars + strategy_vol_window_d1 + strategy_atr_period + 5);
   return (Bars(symbol, PERIOD_D1) >= min_bars); // perf-allowed: monthly fixed-window history guard
  }

int Strategy_TsmomDirection(const string symbol)
  {
   if(strategy_lookback_d1_bars <= 0 || !Strategy_HistoryReady(symbol))
      return 0;

   const double recent_close = iClose(symbol, PERIOD_D1, 1); // perf-allowed: monthly 12m close-return sign
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars); // perf-allowed: monthly 12m close-return sign
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
  }

double Strategy_RealizedVolAnnual(const string symbol)
  {
   const int n = strategy_vol_window_d1;
   if(n < 2 || n > 512 || !Strategy_HistoryReady(symbol))
      return 0.0;

   double closes[];
   ArrayResize(closes, n + 1);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, n + 1, closes); // perf-allowed: monthly realized-vol window
   if(copied != n + 1)
      return 0.0;

   double returns[];
   ArrayResize(returns, n);
   double mean = 0.0;
   for(int i = 0; i < n; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return 0.0;
      returns[i] = MathLog(closes[i] / closes[i + 1]);
      mean += returns[i];
     }
   mean /= (double)n;

   double variance = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double diff = returns[i] - mean;
      variance += diff * diff;
     }
   variance /= (double)MathMax(1, n - 1);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance) * MathSqrt(252.0);
  }

double Strategy_VolScale(const string symbol)
  {
   if(strategy_target_annual_vol <= 0.0)
      return 0.0;

   const double realized_vol = MathMax(Strategy_RealizedVolAnnual(symbol),
                                       MathMax(0.000001, strategy_min_realized_vol));
   const double slot_target = strategy_target_annual_vol / (double)QM12615_BASKET_SIZE;
   double scale = slot_target / realized_vol;
   if(strategy_max_vol_scale > 0.0 && scale > strategy_max_vol_scale)
      scale = strategy_max_vol_scale;
   if(scale <= 0.0)
      return 0.0;
   return scale;
  }

double Strategy_MedianDailySpreadPoints(const string symbol)
  {
   const int n = strategy_spread_days;
   if(n <= 0 || n > 128)
      return 0.0;

   double values[128];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(symbol, PERIOD_D1, shift); // perf-allowed: monthly D1 spread guard
      if(spread > 0)
        {
         values[count] = (double)spread;
         ++count;
        }
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry(const string symbol)
  {
   const double median_spread = Strategy_MedianDailySpreadPoints(symbol);
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread > 0 && (double)current_spread > median_spread * strategy_spread_mult)
      return false;
   return true;
  }

bool Strategy_IsFamilyPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

bool Strategy_CurrentPosition(const string symbol, ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;

   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
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

double Strategy_LotsForLeg(const string symbol,
                           const double entry_price,
                           const double sl_price,
                           const double vol_scale)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0 || vol_scale <= 0.0)
      return 0.0;

   const double sl_points = MathAbs(entry_price - sl_price) / point;
   if(sl_points <= 0.0)
      return 0.0;

   double lots = QM_LotsForRisk(symbol, sl_points) *
                 MathMax(0.0, strategy_leg_risk_fraction) *
                 vol_scale;
   return QM_BasketNormalizeLots(symbol, lots);
  }

bool Strategy_OpenSymbolLeg(const string symbol, const int direction, const double vol_scale)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   const int index = Strategy_IndexForSymbol(symbol);
   if(slot < 0 || index < 0 || direction == 0 || vol_scale <= 0.0)
      return false;
   if(!Strategy_SpreadAllowsEntry(symbol))
      return false;

   SymbolSelect(symbol, true);

   const QM_OrderType order_type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_OrderTypeIsBuy(order_type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                      : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(symbol, order_type, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(order_type == QM_BUY && sl >= entry)
      return false;
   if(order_type == QM_SELL && sl <= entry)
      return false;

   const double lots = Strategy_LotsForLeg(symbol, entry, sl, vol_scale);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = (direction > 0) ? "QM5_12615_TSMOM_XASSET_LONG" : "QM5_12615_TSMOM_XASSET_SHORT";
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong out_ticket = 0;
   const bool opened = QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, out_ticket);
   if(opened)
     {
      g_qm12615_last_scalar[index] = vol_scale;
      QM_LogEvent(QM_INFO,
                  "STRATEGY_REBALANCE_OPEN",
                  StringFormat("{\"symbol\":\"%s\",\"direction\":%d,\"vol_scale\":%.6f,\"lots\":%.8f}",
                               symbol,
                               direction,
                               vol_scale,
                               lots));
     }
   return opened;
  }

bool Strategy_VolResizeRequired(const string symbol, const double desired_scalar)
  {
   const int index = Strategy_IndexForSymbol(symbol);
   if(index < 0 || desired_scalar <= 0.0)
      return false;

   const double prior_scalar = g_qm12615_last_scalar[index];
   if(prior_scalar <= 0.0)
     {
      g_qm12615_last_scalar[index] = desired_scalar;
      return false;
     }

   const double drift = MathAbs(desired_scalar - prior_scalar) / MathMax(0.000001, prior_scalar);
   return (strategy_vol_reopen_threshold >= 0.0 && drift > strategy_vol_reopen_threshold);
  }

bool Strategy_RebalanceSymbol(const string symbol, int &open_count)
  {
   if(!Strategy_HistoryReady(symbol))
      return false;

   const int direction = Strategy_TsmomDirection(symbol);
   if(direction == 0)
      return false;

   const double vol_scale = Strategy_VolScale(symbol);
   if(vol_scale <= 0.0)
      return false;

   ulong existing_ticket = 0;
   int existing_direction = 0;
   const bool has_position = Strategy_CurrentPosition(symbol, existing_ticket, existing_direction);
   const bool needs_resize = has_position && existing_direction == direction &&
                             Strategy_VolResizeRequired(symbol, vol_scale);

   if(has_position)
     {
      if(existing_direction == direction && !needs_resize)
         return false;

      if(!QM_TM_ClosePosition(existing_ticket, QM_EXIT_STRATEGY))
         return false;
      open_count = MathMax(0, open_count - 1);
     }

   if(open_count >= strategy_max_family_positions)
      return false;

   if(Strategy_OpenSymbolLeg(symbol, direction, vol_scale))
     {
      ++open_count;
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_lookback_d1_bars <= 0 || strategy_vol_window_d1 < 2 || strategy_vol_window_d1 > 512)
      return true;
   if(strategy_target_annual_vol <= 0.0 || strategy_max_vol_scale <= 0.0)
      return true;
   if(strategy_min_realized_vol <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_leg_risk_fraction <= 0.0 || strategy_leg_risk_fraction > 1.0)
      return true;
   if(strategy_spread_days < 0 || strategy_spread_days > 128 || strategy_spread_mult < 0.0)
      return true;
   if(strategy_max_family_positions < 1 || strategy_max_family_positions > QM12615_BASKET_SIZE)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12615_TSMOM_XASSET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthRebalanceBar())
      return false;

   int open_count = Strategy_FamilyPositionCount();
   bool rebalanced_any = false;
   for(int i = 0; i < QM12615_BASKET_SIZE; ++i)
      if(Strategy_RebalanceSymbol(g_qm12615_symbols[i], open_count))
         rebalanced_any = true;

   if(rebalanced_any)
      QM_LogEvent(QM_INFO, "STRATEGY_REBALANCE_DONE", "{\"card\":\"QM5_12615\"}");

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance plus hard ATR SL only.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Monthly direction reversals and vol-resize exits are handled by Strategy_EntrySignal().
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_CloseFamilyPositions(QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   for(int i = 0; i < QM12615_BASKET_SIZE; ++i)
     {
      const string symbol = g_qm12615_symbols[i];
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

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   for(int i = 0; i < QM12615_BASKET_SIZE; ++i)
      SymbolSelect(g_qm12615_symbols[i], true);

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

   QM_SymbolGuardInit(g_qm12615_symbols);
   QM_BasketWarmupHistory(g_qm12615_symbols, PERIOD_D1, MathMax(360, strategy_min_d1_bars + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12615\",\"ea\":\"tsmom-12m-cross-asset-basket\"}");
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
      Strategy_CloseFamilyPositions(QM_EXIT_STRATEGY);
      return;
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
