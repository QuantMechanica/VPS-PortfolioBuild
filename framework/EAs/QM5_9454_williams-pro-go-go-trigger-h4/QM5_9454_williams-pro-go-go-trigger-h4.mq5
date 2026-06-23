#property strict
#property version   "5.0"
#property description "QM5_9454 Williams Pro-Go Go-trigger H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9454;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                 = PERIOD_H4;
input int    strategy_pro_go_period               = 14;
input int    strategy_sma_period                  = 50;
input int    strategy_atr_period                  = 14;
input double strategy_extension_atr_mult          = 2.0;
input double strategy_stop_atr_mult               = 1.0;
input double strategy_gap_clip_atr_mult           = 0.5;
input double strategy_spread_atr_mult             = 0.20;
input int    strategy_time_stop_bars              = 18;

double g_signal_pro_now = 0.0;
double g_signal_pro_prev = 0.0;
bool   g_signal_cache_ready = false;

bool SelectOurPosition(ENUM_POSITION_TYPE &pos_type, ulong &ticket, datetime &open_time)
  {
   pos_type = POSITION_TYPE_BUY;
   ticket = 0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool IsWeeklyGapTerm(const MqlRates &bar, const MqlRates &prev_bar)
  {
   const int sec = PeriodSeconds(strategy_tf);
   if(sec > 0 && (bar.time - prev_bar.time) > sec * 2)
      return true;
   return false;
  }

bool ReadClosedBar(const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, shift, 1, rates); // perf-allowed: one closed-bar OHLC read for Williams Pro/Go structural math.
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
  }

bool WilliamsProGo(const int shift, double &pro_value, double &go_value)
  {
   pro_value = 0.0;
   go_value = 0.0;
   if(strategy_pro_go_period < 2 || shift < 1)
      return false;

   MqlRates rates[];
   const int need = strategy_pro_go_period + 1;
   const int copied = CopyRates(_Symbol, strategy_tf, shift, need, rates); // perf-allowed: bounded 14-bar Williams Pro/Go window, called from closed-bar strategy hooks.
   if(copied < need)
      return false;

   // CopyRates stores the oldest physical element at index 0. Index 1..N is
   // the card window, with index-1 as the prior close for each Go term.
   for(int i = 1; i <= strategy_pro_go_period; ++i)
     {
      if(rates[i].open <= 0.0 || rates[i].close <= 0.0 || rates[i - 1].close <= 0.0)
         return false;

      pro_value += rates[i].close - rates[i].open;

      double gap = rates[i].open - rates[i - 1].close;
      if(IsWeeklyGapTerm(rates[i], rates[i - 1]))
        {
         const int bar_shift = shift + (strategy_pro_go_period - i);
         const double atr_prev = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, bar_shift + 1);
         const double cap = atr_prev * strategy_gap_clip_atr_mult;
         if(cap > 0.0)
           {
            if(gap > cap)
               gap = cap;
            else if(gap < -cap)
               gap = -cap;
           }
        }
      go_value += gap;
     }

   return true;
  }

bool RefreshSignalCache(double &go_now, double &go_prev)
  {
   double pro_now = 0.0;
   double pro_prev = 0.0;
   go_now = 0.0;
   go_prev = 0.0;
   g_signal_cache_ready = false;

   if(!WilliamsProGo(1, pro_now, go_now) || !WilliamsProGo(2, pro_prev, go_prev))
      return false;

   g_signal_pro_now = pro_now;
   g_signal_pro_prev = pro_prev;
   g_signal_cache_ready = true;
   return true;
  }

bool SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask < bid)
      return true;
   if(ask == bid)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;
   return ((ask - bid) > atr * strategy_spread_atr_mult);
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_tf)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 6)
      return true;
   if(dt.day_of_week == 0)
      return true;
   if(dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker)
      return true;

   return SpreadTooWide();
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
   g_signal_cache_ready = false;

   if(strategy_pro_go_period < 2 || strategy_sma_period < 2 ||
      strategy_atr_period < 1 || strategy_stop_atr_mult <= 0.0 ||
      strategy_extension_atr_mult <= 0.0)
      return false;

   double go_now = 0.0;
   double go_prev = 0.0;
   if(!RefreshSignalCache(go_now, go_prev))
      return false;

   MqlRates closed_bar;
   if(!ReadClosedBar(1, closed_bar))
      return false;

   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(closed_bar.close <= 0.0 || sma <= 0.0 || atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(go_prev < 0.0 && go_now >= 0.0 && g_signal_pro_now > 0.0 &&
      closed_bar.close > sma && (closed_bar.close - sma) <= strategy_extension_atr_mult * atr)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_stop_atr_mult);
      req.tp = 0.0;
      req.reason = "GO_ZERO_UP_PRO_CONFIRM";
      return (req.sl > 0.0);
     }

   if(go_prev > 0.0 && go_now <= 0.0 && g_signal_pro_now < 0.0 &&
      closed_bar.close < sma && (sma - closed_bar.close) <= strategy_extension_atr_mult * atr)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_stop_atr_mult);
      req.tp = 0.0;
      req.reason = "GO_ZERO_DOWN_PRO_CONFIRM";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in logic.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   ulong ticket;
   datetime open_time;
   if(!SelectOurPosition(pos_type, ticket, open_time))
      return false;

   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int sec = PeriodSeconds(strategy_tf);
      if(sec > 0 && TimeCurrent() >= open_time + (strategy_time_stop_bars + 1) * sec)
         return true;
     }

   if(!g_signal_cache_ready)
      return false;

   if(pos_type == POSITION_TYPE_BUY && g_signal_pro_prev > 0.0 && g_signal_pro_now <= 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && g_signal_pro_prev < 0.0 && g_signal_pro_now >= 0.0)
      return true;

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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9454\",\"ea\":\"QM5_9454_williams-pro-go-go-trigger-h4\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   QM_EntryRequest req;
   bool has_entry_signal = false;

   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      has_entry_signal = Strategy_EntrySignal(req);
     }

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

   if(!is_new_bar)
      return;

   if(has_entry_signal)
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
