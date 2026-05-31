#property strict
#property version   "5.0"
#property description "QM5_10524 MQL5 MA590 pending breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10524;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ma_period         = 590;
input int    strategy_slope_bars        = 3;
input int    strategy_breakout_lookback = 5;
input int    strategy_atr_period        = 14;
input double strategy_atr_indent_mult   = 0.25;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_atr_sl_cap_mult   = 2.5;
input double strategy_tp_r_mult         = 1.5;
input int    strategy_pending_bars      = 6;

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: closed H1 MA590 directional state with pending stop breakout.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_pending_bars) * PeriodSeconds(_Period);

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int ma_period = MathMax(2, strategy_ma_period);
   const int slope_bars = MathMax(1, strategy_slope_bars);
   const int lookback = MathMax(1, strategy_breakout_lookback);
   const int atr_period = MathMax(1, strategy_atr_period);

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double ma_1 = QM_SMA(_Symbol, _Period, ma_period, 1);
   const double ma_slope_ref = QM_SMA(_Symbol, _Period, ma_period, 1 + slope_bars);
   const double atr = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(close_1 <= 0.0 || ma_1 <= 0.0 || ma_slope_ref <= 0.0 || atr <= 0.0)
      return false;

   const int lifetime_seconds = MathMax(1, strategy_pending_bars) * PeriodSeconds(_Period);
   const datetime now = TimeCurrent();
   bool has_pending = false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      const bool stale = (setup_time > 0 && now - setup_time >= lifetime_seconds);
      const bool side_flipped = (order_type == ORDER_TYPE_BUY_STOP && close_1 < ma_1) ||
                                (order_type == ORDER_TYPE_SELL_STOP && close_1 > ma_1);
      if(stale || side_flipped)
         QM_TM_RemovePendingOrder(ticket, stale ? "MA590_PENDING_STALE" : "MA590_SIDE_FLIP");
      else
         has_pending = true;
     }
   if(has_pending)
      return false;

   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double high = iHigh(_Symbol, _Period, shift);
      const double low = iLow(_Symbol, _Period, shift);
      if(high <= 0.0 || low <= 0.0)
         return false;
      range_high = MathMax(range_high, high);
      range_low = MathMin(range_low, low);
     }
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double indent = MathMax(0.0, strategy_atr_indent_mult) * atr;
   const double atr_floor = MathMax(0.0, strategy_atr_sl_mult) * atr;
   const double atr_cap = MathMax(atr_floor, strategy_atr_sl_cap_mult * atr);
   const double tp_mult = MathMax(0.1, strategy_tp_r_mult);
   const double min_stop_dist = MathMax((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point, point);
   if(atr_floor <= 0.0 || atr_cap <= 0.0)
      return false;

   if(close_1 > ma_1 && ma_1 > ma_slope_ref)
     {
      const double entry = MathMax(range_high + indent, ask + min_stop_dist);
      const double structure_dist = entry - range_low;
      const double risk_dist = MathMin(MathMax(structure_dist, atr_floor), atr_cap);
      if(risk_dist <= min_stop_dist)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = entry - risk_dist;
      req.tp = entry + risk_dist * tp_mult;
      req.reason = "MA590_BUY_STOP";
      return true;
     }

   if(close_1 < ma_1 && ma_1 < ma_slope_ref)
     {
      const double entry = MathMin(range_low - indent, bid - min_stop_dist);
      const double structure_dist = range_high - entry;
      const double risk_dist = MathMin(MathMax(structure_dist, atr_floor), atr_cap);
      if(risk_dist <= min_stop_dist)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = entry + risk_dist;
      req.tp = entry - risk_dist * tp_mult;
      req.reason = "MA590_SELL_STOP";
      return true;
     }

   return false;
  }

// Trade Management: triggered positions are left at fixed SL/TP.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close on opposite MA side after bar close.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double ma_1 = QM_SMA(_Symbol, _Period, MathMax(2, strategy_ma_period), 1);
   if(close_1 <= 0.0 || ma_1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && close_1 < ma_1)
         return true;
      if(type == POSITION_TYPE_SELL && close_1 > ma_1)
         return true;
     }

   return false;
  }

// News Filter Hook: central FW1 news filter handles high-impact blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10524\",\"ea\":\"mql5-ma590-pend\"}");
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
