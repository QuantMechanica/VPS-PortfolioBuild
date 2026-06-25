#property strict
#property version   "5.0"
#property description "QM5_11501 Langer engulfing D1 swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11501;
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
input int    strategy_sma_period         = 200;
input double strategy_entry_buffer_pips  = 5.0;
input double strategy_sl_cap_pips        = 100.0;
input int    strategy_trail_bars         = 3;
input int    strategy_max_hold_bars      = 10;
input double strategy_spread_cap_pips    = 30.0;
input bool   strategy_no_friday_entry    = true;

// Return TRUE to BLOCK trading this tick. This hook carries the cheap
// no-trade spread guard; news is handled by Strategy_NewsFilterHook and the
// framework, while the card's no-Friday-entry rule is entry-only.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0 || strategy_spread_cap_pips <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = strategy_spread_cap_pips * pip;
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Trade Entry: D1 engulfing candle in the direction of D1 SMA trend. The caller
// invokes this only after the framework closed-bar gate has fired.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return false;
     }

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, bars) != 2) // perf-allowed: two closed D1 bars for candle-pattern math after framework new-bar gate.
      return false;

   const double o1 = bars[0].open;
   const double h1 = bars[0].high;
   const double l1 = bars[0].low;
   const double c1 = bars[0].close;
   const double o2 = bars[1].open;
   const double h2 = bars[1].high;
   const double l2 = bars[1].low;
   const double c2 = bars[1].close;
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 ||
      o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || c2 <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(sma <= 0.0 || pip <= 0.0)
      return false;

   const bool bullish_engulfing = (h1 > h2) && (l1 < l2) &&
                                  (c1 > o1) && (c2 < o2) &&
                                  (o1 <= c2) && (c1 >= o2);
   const bool bearish_engulfing = (h1 > h2) && (l1 < l2) &&
                                  (c1 < o1) && (c2 > o2) &&
                                  (o1 >= c2) && (c1 <= o2);

   if(bullish_engulfing && c1 > sma)
     {
      double entry = h1 + strategy_entry_buffer_pips * pip;
      double sl = l1;
      const double cap = strategy_sl_cap_pips * pip;
      if(cap > 0.0 && (entry - sl) > cap)
         sl = entry - cap;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || sl <= 0.0 || entry <= sl || (ask > 0.0 && entry <= ask))
         return false;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = 0.0;
      req.reason = "langer_engulfing_d1_long";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   if(bearish_engulfing && c1 < sma)
     {
      double entry = l1 - strategy_entry_buffer_pips * pip;
      double sl = h1;
      const double cap = strategy_sl_cap_pips * pip;
      if(cap > 0.0 && (sl - entry) > cap)
         sl = entry + cap;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry || (bid > 0.0 && entry >= bid))
         return false;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = 0.0;
      req.reason = "langer_engulfing_d1_short";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

// Trade Management: break-even after the first profitable D1 close, then trail
// to the most recent N-bar D1 low/high per the card's "trail every three bars".
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

      MqlRates last_closed[];
      ArraySetAsSeries(last_closed, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, last_closed) == 1) // perf-allowed: one closed D1 bar for break-even state.
        {
         if(last_closed[0].time > open_time)
           {
            if(position_type == POSITION_TYPE_BUY && last_closed[0].close > open_price &&
               (current_sl <= 0.0 || current_sl < open_price))
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "langer_be_after_profitable_d1_close");
            else if(position_type == POSITION_TYPE_SELL && last_closed[0].close < open_price &&
                    (current_sl <= 0.0 || current_sl > open_price))
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "langer_be_after_profitable_d1_close");
           }
        }

      if(strategy_trail_bars <= 0)
         continue;

      MqlRates trail_bars[];
      ArraySetAsSeries(trail_bars, true);
      if(CopyRates(_Symbol, PERIOD_D1, 1, strategy_trail_bars, trail_bars) != strategy_trail_bars) // perf-allowed: bounded D1 trailing-extreme scan, max default 3 bars.
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         double trail = DBL_MAX;
         for(int j = 0; j < strategy_trail_bars; ++j)
            trail = MathMin(trail, trail_bars[j].low);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(trail > 0.0 && trail < DBL_MAX && (current_sl <= 0.0 || trail > current_sl) &&
            (bid <= 0.0 || trail < bid))
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, trail), "langer_trail_d1_lows");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         double trail = 0.0;
         for(int j = 0; j < strategy_trail_bars; ++j)
            trail = MathMax(trail, trail_bars[j].high);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(trail > 0.0 && (current_sl <= 0.0 || trail < current_sl) &&
            (ask <= 0.0 || trail > ask))
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, trail), "langer_trail_d1_highs");
        }
     }
  }

// Trade Close: max-hold fallback after ten D1 bars.
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;
      const long seconds_held = (long)(TimeCurrent() - open_time);
      if(seconds_held >= (long)strategy_max_hold_bars * (long)PeriodSeconds(PERIOD_D1))
         return true;
     }

   return false;
  }

// News Filter Hook: no custom override; central framework news filter decides.
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
