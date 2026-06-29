#property strict
#property version   "5.0"
#property description "QM5_12774 Williams 8-Week WTI Box Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12774 - Williams 8-Week WTI Box Breakout
// -----------------------------------------------------------------------------
// D1 structural commodity breakout sleeve:
//   - detect a compressed 40-bar WTI box
//   - require the pre-box trend to point in the breakout direction
//   - enter on the next D1 bar after a close-confirmed box break
// Runtime uses MT5 OHLC/broker spread only; no external energy data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12774;
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
input int    strategy_box_bars             = 40;
input int    strategy_trend_lookback       = 20;
input int    strategy_atr_period           = 20;
input double strategy_box_atr_mult         = 8.0;
input double strategy_min_trend_return_pct = 1.0;
input int    strategy_break_buffer_points  = 0;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 20;
input int    strategy_max_spread_points    = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_LoadBoxState(double &box_high,
                           double &box_low,
                           double &signal_close,
                           double &prebox_close,
                           double &trend_ref_close,
                           double &atr_value)
  {
   const int warmup_bars = strategy_box_bars + strategy_trend_lookback + strategy_atr_period + 5;
   const int bars = Bars(_Symbol, PERIOD_D1); // perf-allowed: bounded D1 warmup check behind new-bar gate.
   if(bars < warmup_bars)
      return false;

   box_high = -DBL_MAX;
   box_low = DBL_MAX;

   const int last_box_shift = strategy_box_bars + 1;
   for(int shift = 2; shift <= last_box_shift; ++shift)
     {
      const double high_value = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded 40-bar D1 box scan behind new-bar gate.
      const double low_value = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded 40-bar D1 box scan behind new-bar gate.
      if(high_value <= 0.0 || low_value <= 0.0 || high_value < low_value)
         return false;
      if(high_value > box_high)
         box_high = high_value;
      if(low_value < box_low)
         box_low = low_value;
     }

   signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior D1 close for breakout confirmation behind new-bar gate.
   prebox_close = iClose(_Symbol, PERIOD_D1, last_box_shift); // perf-allowed: pre-box trend anchor behind new-bar gate.
   trend_ref_close = iClose(_Symbol, PERIOD_D1, strategy_box_bars + strategy_trend_lookback + 1); // perf-allowed: pre-box trend reference behind new-bar gate.
   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   return (box_high > box_low &&
           signal_close > 0.0 &&
           prebox_close > 0.0 &&
           trend_ref_close > 0.0 &&
           atr_value > 0.0);
  }

void Strategy_CloseTimeExpiredPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   int hold_days = strategy_max_hold_days;
   if(hold_days < 1)
      hold_days = 1;
   const long hold_seconds = (long)hold_days * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0)
         continue;

      const long elapsed = (long)(now - opened);
      if(elapsed >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_box_bars < 20 || strategy_box_bars > 120)
      return true;
   if(strategy_trend_lookback < 5 || strategy_trend_lookback > 120)
      return true;
   if(strategy_atr_period < 5 || strategy_atr_period > 120)
      return true;
   if(strategy_box_atr_mult <= 0.0 || strategy_min_trend_return_pct < 0.0)
      return true;
   if(strategy_break_buffer_points < 0 || strategy_atr_sl_mult <= 0.0)
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
   req.reason = "QM5_12774_WILLIAMS_8WK_XTI";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   double signal_close = 0.0;
   double prebox_close = 0.0;
   double trend_ref_close = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadBoxState(box_high,
                             box_low,
                             signal_close,
                             prebox_close,
                             trend_ref_close,
                             atr_value))
      return false;

   const double box_range = box_high - box_low;
   if(box_range <= 0.0 || box_range > strategy_box_atr_mult * atr_value)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double buffer = (double)strategy_break_buffer_points * point;
   const double trend_return_pct = 100.0 * (prebox_close - trend_ref_close) / trend_ref_close;

   QM_OrderType side = QM_BUY;
   if(signal_close > box_high + buffer && trend_return_pct >= strategy_min_trend_return_pct)
      side = QM_BUY;
   else if(signal_close < box_low - buffer && trend_return_pct <= -strategy_min_trend_return_pct)
      side = QM_SELL;
   else
      return false;

   req.type = side;
   req.reason = (side == QM_BUY) ? "WILLIAMS_8WK_BOX_XTI_LONG" : "WILLIAMS_8WK_BOX_XTI_SHORT";

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_value, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseTimeExpiredPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12774\",\"ea\":\"williams-8wk-xti\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
