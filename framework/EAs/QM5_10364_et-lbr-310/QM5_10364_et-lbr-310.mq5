#property strict
#property version   "5.0"
#property description "QM5_10364 Elite Trader LBR 3-10-16 First Cross Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10364;
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
input int    strategy_macd_fast             = 3;
input int    strategy_macd_slow             = 10;
input int    strategy_macd_signal           = 16;
input bool   strategy_ema_filter_enabled    = true;
input int    strategy_ema_fast              = 9;
input int    strategy_ema_slow              = 34;
input int    strategy_atr_period            = 14;
input double strategy_atr_target_mult       = 0.25;
input double strategy_breakeven_trigger_r   = 0.75;
input int    strategy_session_start_hhmm    = 1530;
input int    strategy_session_end_hhmm      = 2200;
input bool   strategy_spread_filter_enabled = true;
input int    strategy_spread_window         = 21;
input double strategy_spread_median_mult    = 2.5;

int  g_setup_direction = 0;
bool g_setup_consumed = false;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool IsInsideSession(const datetime t)
  {
   const int hhmm = Hhmm(t);
   const int start = MathMax(0, MathMin(2359, strategy_session_start_hhmm));
   const int finish = MathMax(0, MathMin(2359, strategy_session_end_hhmm));
   if(start == finish)
      return true;
   if(start < finish)
      return (hhmm >= start && hhmm < finish);
   return (hhmm >= start || hhmm < finish);
  }

bool HasOurOpenPosition()
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

bool SpreadFilterBlocks()
  {
   if(!strategy_spread_filter_enabled)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(spread_points <= 0.0)
      return false;

   static double samples[101];
   static int sample_count = 0;
   static int sample_next = 0;

   const int window = MathMax(3, MathMin(101, strategy_spread_window));
   samples[sample_next] = spread_points;
   sample_next = (sample_next + 1) % window;
   if(sample_count < window)
      sample_count++;
   if(sample_count < window)
      return false;

   double sorted[];
   ArrayResize(sorted, sample_count);
   for(int i = 0; i < sample_count; ++i)
      sorted[i] = samples[i];
   ArraySort(sorted);

   const double median = sorted[sample_count / 2];
   if(median <= 0.0)
      return false;
   return (spread_points > median * strategy_spread_median_mult);
  }

void FillRequest(QM_EntryRequest &req,
                 const QM_OrderType side,
                 const double entry,
                 const double stop,
                 const double take,
                 const string reason)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = take;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(SpreadFilterBlocks())
      return true;

   if(!IsInsideSession(TimeCurrent()) && !HasOurOpenPosition())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!IsInsideSession(TimeCurrent()))
      return false;
   if(HasOurOpenPosition())
      return false;

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_target_mult <= 0.0)
      return false;

   const double sig1 = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 1);
   const double sig2 = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 2);
   const double main1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double main2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);
   if(sig1 == EMPTY_VALUE || sig2 == EMPTY_VALUE ||
      main1 == EMPTY_VALUE || main2 == EMPTY_VALUE)
      return false;

   const double hist1 = main1 - sig1;
   const double hist2 = main2 - sig2;

   if(sig2 <= 0.0 && sig1 > 0.0)
     {
      g_setup_direction = 1;
      g_setup_consumed = false;
     }
   else if(sig2 >= 0.0 && sig1 < 0.0)
     {
      g_setup_direction = -1;
      g_setup_consumed = false;
     }

   if(g_setup_direction == 0 || g_setup_consumed)
      return false;

   if(strategy_ema_filter_enabled)
     {
      const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast, 1);
      const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow, 1);
      if(ema_fast == EMPTY_VALUE || ema_slow == EMPTY_VALUE)
         return false;
      if(g_setup_direction > 0 && ema_fast <= ema_slow)
         return false;
      if(g_setup_direction < 0 && ema_fast >= ema_slow)
         return false;
     }

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || atr == EMPTY_VALUE)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_setup_direction > 0 && sig1 > 0.0 && hist2 < 0.0 && hist1 > hist2)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_target_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_target_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      FillRequest(req, QM_BUY, ask, sl, tp, "LBR_31016_LONG_PULLBACK");
      g_setup_consumed = true;
      return true;
     }

   if(g_setup_direction < 0 && sig1 < 0.0 && hist2 > 0.0 && hist1 < hist2)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_target_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_target_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      FillRequest(req, QM_SELL, bid, sl, tp, "LBR_31016_SHORT_PULLBACK");
      g_setup_consumed = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_breakeven_trigger_r <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_risk = MathAbs(open_price - sl);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(initial_risk <= 0.0 || moved < initial_risk * strategy_breakeven_trigger_r)
         continue;

      const double target_sl = is_buy ? (open_price + point) : (open_price - point);
      const bool improves = is_buy ? (target_sl > sl + point * 0.5)
                                   : (target_sl < sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "LBR_31016_BREAKEVEN_075R");
     }
  }

bool Strategy_ExitSignal()
  {
   return !IsInsideSession(TimeCurrent()) && HasOurOpenPosition();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10364_et-lbr-310\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
