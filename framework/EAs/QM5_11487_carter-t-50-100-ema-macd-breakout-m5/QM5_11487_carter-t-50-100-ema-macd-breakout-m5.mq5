#property strict
#property version   "5.0"
#property description "QM5_11487 Carter-T 50/100 EMA MACD breakout M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11487;
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
input int    strategy_ema_fast_period     = 50;
input int    strategy_ema_slow_period     = 100;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_macd_lookback       = 5;
input int    strategy_breakout_pips       = 10;
input int    strategy_sl_lookback_bars    = 5;
input int    strategy_sl_max_pips         = 25;
input double strategy_tp1_rr              = 2.0;
input int    strategy_spread_cap_pips     = 15;
input bool   strategy_no_friday_entry     = true;

ulong g_partial_done_ticket = 0;

double ClosedBarClose(const int shift)
  {
   if(shift < 1)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, shift, 1, rates); // perf-allowed: one closed bar only
   if(copied != 1)
      return 0.0;

   return rates[0].close;
  }

bool IsFridayNow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool SpreadWithinCap()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > cap)
      return false;

   return true;
  }

bool MacdZeroCrossedWithin(const int dir)
  {
   if(strategy_macd_lookback <= 0)
      return false;

   for(int k = 1; k <= strategy_macd_lookback; ++k)
     {
      const double macd_now = QM_MACD_Main(_Symbol,
                                           _Period,
                                           strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal,
                                           k);
      const double macd_prev = QM_MACD_Main(_Symbol,
                                            _Period,
                                            strategy_macd_fast,
                                            strategy_macd_slow,
                                            strategy_macd_signal,
                                            k + 1);
      if(dir > 0 && macd_prev <= 0.0 && macd_now > 0.0)
         return true;
      if(dir < 0 && macd_prev >= 0.0 && macd_now < 0.0)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_no_friday_entry && IsFridayNow())
      return false;

   if(!SpreadWithinCap())
      return false;

   const double close1 = ClosedBarClose(1);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 || buffer <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool signal = false;

   if(close1 > ema_fast &&
      close1 > ema_slow &&
      (close1 - ema_fast) >= buffer &&
      MacdZeroCrossedWithin(+1))
     {
      side = QM_BUY;
      signal = true;
     }

   if(!signal &&
      close1 < ema_fast &&
      close1 < ema_slow &&
      (ema_fast - close1) >= buffer &&
      MacdZeroCrossedWithin(-1))
     {
      side = QM_SELL;
      signal = true;
     }

   if(!signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback_bars);
   if(sl <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   const double max_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(risk <= 0.0 || (max_stop > 0.0 && risk > max_stop))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "ema50_100_macd_breakout_long" : "ema50_100_macd_breakout_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(ticket == g_partial_done_ticket)
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(entry <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_risk = MathAbs(entry - current_sl);
      if(initial_risk <= 0.0)
         continue;

      const bool stop_already_be = is_buy ? (current_sl >= entry) : (current_sl <= entry);
      if(stop_already_be)
        {
         g_partial_done_ticket = ticket;
         continue;
        }

      const double moved = is_buy ? (market - entry) : (entry - market);
      if(moved < initial_risk * strategy_tp1_rr)
         continue;

      const double partial_lots = QM_TM_NormalizeVolume(symbol, volume * 0.5);
      bool partial_done = false;
      if(partial_lots > 0.0 && partial_lots < volume)
         partial_done = QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);

      const double be_sl = QM_TM_NormalizePrice(symbol, entry);
      if(be_sl > 0.0)
         QM_TM_MoveSL(ticket, be_sl, "tp1_breakeven");

      if(partial_done || partial_lots <= 0.0 || partial_lots >= volume)
         g_partial_done_ticket = ticket;
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = ClosedBarClose(1);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || buffer <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && close1 < (ema_fast - buffer))
         return true;
      if(position_type == POSITION_TYPE_SELL && close1 > (ema_fast + buffer))
         return true;
     }

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
