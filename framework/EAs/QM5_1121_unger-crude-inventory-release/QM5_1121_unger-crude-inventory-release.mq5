#property strict
#property version   "5.0"
#property description "QM5_1121 Unger Crude Inventory Release"

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1121;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_release_hhmm_ny   = 1030;
input int    strategy_pre_news_minutes  = 30;
input int    strategy_release_window_minutes = 90;
input int    strategy_session_flat_hhmm_ny = 1555;
input int    strategy_atr_period        = 14;
input double strategy_buffer_atr_mult   = 0.05;
input double strategy_sl_atr_mult       = 2.0;
input double strategy_fixed_r_distance  = 0.90;
input double strategy_take_profit_rr    = 1.78;
input int    strategy_spread_samples    = 20;

bool     g_orders_armed_today = false;
bool     g_trade_taken_today = false;
datetime g_trade_day = 0;
datetime g_last_spread_bar = 0;
int      g_spread_ring[256];
int      g_spread_count = 0;
int      g_spread_pos = 0;
CTrade   g_trade;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

datetime NYToBroker(const datetime ny_time)
  {
   datetime utc_dst = ny_time + 4 * 3600;
   if(QM_IsUSDSTUTC(utc_dst))
      return QM_UTCToBroker(utc_dst);
   return QM_UTCToBroker(ny_time + 5 * 3600);
  }

datetime TodayNYAtHhmmBroker(const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNY(TimeCurrent()), dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return NYToBroker(StructToTime(dt));
  }

void ResetNewTradeDayIfNeeded()
  {
   const datetime today = DateKey(TimeCurrent());
   if(today == g_trade_day)
      return;
   g_trade_day = today;
   g_orders_armed_today = false;
   g_trade_taken_today = false;
  }

bool IsWednesday()
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNY(TimeCurrent()), dt);
   return (dt.day_of_week == 3);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   g_trade.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;
      g_trade.OrderDelete(ticket);
     }
  }

void UpdateSpreadSample()
  {
   const datetime bt = iTime(_Symbol, PERIOD_M5, 0);
   if(bt <= 0 || bt == g_last_spread_bar)
      return;
   g_last_spread_bar = bt;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return;

   const int cap = MathMax(1, MathMin(strategy_spread_samples, 256));
   g_spread_ring[g_spread_pos % cap] = spread;
   g_spread_pos = (g_spread_pos + 1) % cap;
   if(g_spread_count < cap)
      ++g_spread_count;
  }

int MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0;
   int tmp[256];
   for(int i = 0; i < g_spread_count; ++i)
      tmp[i] = g_spread_ring[i];
   for(int i = 1; i < g_spread_count; ++i)
     {
      const int key = tmp[i];
      int j = i - 1;
      while(j >= 0 && tmp[j] > key)
        {
         tmp[j + 1] = tmp[j];
         --j;
        }
      tmp[j + 1] = key;
     }
   return tmp[g_spread_count / 2];
  }

bool SpreadAllowsEntry()
  {
   const int current = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const int median = MedianSpread();
   if(current <= 0 || median <= 0)
      return true;
   return (current <= 2 * median);
  }

bool BuildPreNewsRange(double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const datetime release_time = TodayNYAtHhmmBroker(strategy_release_hhmm_ny);
   const datetime range_start = release_time - strategy_pre_news_minutes * 60;
   int samples = 0;

   for(int shift = 1; shift <= 24; ++shift)
     {
      const datetime bt = iTime(_Symbol, strategy_signal_tf, shift);
      if(bt <= 0)
         break;
      if(bt < range_start)
         break;
      if(bt >= release_time)
         continue;

      const double h = iHigh(_Symbol, strategy_signal_tf, shift);
      const double l = iLow(_Symbol, strategy_signal_tf, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;
      range_high = MathMax(range_high, h);
      range_low = MathMin(range_low, l);
      ++samples;
     }

   return (samples > 0 && range_high > range_low && range_high != -DBL_MAX && range_low != DBL_MAX);
  }

double FixedRiskDistanceEquivalent()
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(RISK_FIXED <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0 || strategy_fixed_r_distance <= 0.0)
      return 0.0;
   return (RISK_FIXED * strategy_fixed_r_distance * tick_size / tick_value);
  }

double NormalizedStopDistance(const double atr)
  {
   const double atr_dist = strategy_sl_atr_mult * atr;
   const double fixed_dist = FixedRiskDistanceEquivalent();
   if(atr_dist <= 0.0)
      return fixed_dist;
   if(fixed_dist <= 0.0)
      return atr_dist;
   return MathMin(atr_dist, fixed_dist);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   ResetNewTradeDayIfNeeded();
   UpdateSpreadSample();

   if(_Symbol != "XTIUSD.DWX" && !HasOurOpenPosition() && !HasOurPendingOrder())
      return true;

   const datetime now = TimeCurrent();
   const datetime release_time = TodayNYAtHhmmBroker(strategy_release_hhmm_ny);
   const datetime release_end = release_time + strategy_release_window_minutes * 60;
   if(now >= release_end && HasOurPendingOrder())
      CancelOurPendingOrders();

   if(!HasOurOpenPosition() && !HasOurPendingOrder())
     {
      if(!IsWednesday())
         return true;
      if(now < release_time || now >= release_end)
         return true;
      if(!SpreadAllowsEntry())
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ResetNewTradeDayIfNeeded();
   if(g_trade_taken_today || g_orders_armed_today || HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   const datetime now = TimeCurrent();
   const datetime release_time = TodayNYAtHhmmBroker(strategy_release_hhmm_ny);
   const datetime release_end = release_time + strategy_release_window_minutes * 60;
   if(!IsWednesday() || now < release_time || now >= release_end)
      return false;

   double pre_high = 0.0;
   double pre_low = 0.0;
   if(!BuildPreNewsRange(pre_high, pre_low))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double stop_dist = NormalizedStopDistance(atr);
   if(point <= 0.0 || atr <= 0.0 || stop_dist <= 0.0)
      return false;

   const double buffer = strategy_buffer_atr_mult * atr;
   const double buy_price = NormalizeDouble(pre_high + buffer, _Digits);
   const double sell_price = NormalizeDouble(pre_low - buffer, _Digits);
   const double buy_sl = NormalizeDouble(buy_price - stop_dist, _Digits);
   const double sell_sl = NormalizeDouble(sell_price + stop_dist, _Digits);
   if(buy_price <= 0.0 || sell_price <= 0.0 || buy_sl <= 0.0 || sell_sl <= 0.0)
      return false;
   if((buy_price - buy_sl) / point <= 0.0 || (sell_sl - sell_price) / point <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = QM_TakeRR(_Symbol, buy_req.type, buy_price, buy_sl, strategy_take_profit_rr);
   buy_req.reason = "UNGER_EIA_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = (int)MathMax(60, release_end - now);

   ulong ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, ticket))
      return false;

   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = QM_TakeRR(_Symbol, req.type, sell_price, sell_sl, strategy_take_profit_rr);
   req.reason = "UNGER_EIA_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (int)MathMax(60, release_end - now);
   g_orders_armed_today = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      CancelOurPendingOrders();
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   return (TimeCurrent() >= TodayNYAtHhmmBroker(strategy_session_flat_hhmm_ny));
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_NO_NEWS)
      return true;
   if(qm_news_mode == QM_NEWS_NEWS_ONLY && !IsWednesday())
      return true;
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
