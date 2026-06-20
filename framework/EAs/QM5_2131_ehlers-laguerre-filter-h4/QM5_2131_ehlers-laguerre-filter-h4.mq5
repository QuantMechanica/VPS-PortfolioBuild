#property strict
#property version   "5.0"
#property description "QM5_2131 Ehlers Laguerre Filter H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2131;
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
input double strategy_gamma              = 0.80;
input bool   strategy_use_typical_price  = false;
input int    strategy_atr_period         = 20;
input double strategy_cross_atr_mult     = 0.30;
input int    strategy_d1_ema_period      = 50;
input int    strategy_warmup_h4_bars     = 200;
input double strategy_initial_stop_atr   = 0.50;
input double strategy_trail_trigger_atr  = 1.50;
input double strategy_trail_atr_mult     = 2.50;
input int    strategy_time_stop_h4_bars  = 80;
input int    strategy_cross_throttle_bars = 3;
input double strategy_spread_atr_mult    = 0.30;

#define QM2131_RECENT_BARS 12

double   g_laguerre_lf[QM2131_RECENT_BARS];
double   g_laguerre_close[QM2131_RECENT_BARS];
double   g_laguerre_high[QM2131_RECENT_BARS];
double   g_laguerre_low[QM2131_RECENT_BARS];
bool     g_laguerre_ready = false;
datetime g_laguerre_last_closed_bar = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &open_price,
                     datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
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

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift > 0) ? shift : 0;
  }

bool AdvanceLaguerreState()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1); // perf-allowed: bespoke Laguerre cache key, no per-EA new-bar gate.
   if(closed_bar <= 0)
      return false;
   if(g_laguerre_ready && g_laguerre_last_closed_bar == closed_bar)
      return true;

   const int gamma_warmup = MathMax(60, strategy_warmup_h4_bars);
   const int count = MathMax(gamma_warmup, strategy_atr_period + 60) + QM2131_RECENT_BARS + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, count, rates) != count) // perf-allowed: bounded reconstruction cached once per closed H4 bar.
      return false;

   const double gamma = MathMax(0.0, MathMin(0.99, strategy_gamma));
   double l0 = 0.0;
   double l1 = 0.0;
   double l2 = 0.0;
   double l3 = 0.0;

   for(int i = count - 1; i >= 0; --i)
     {
      const double price = strategy_use_typical_price
                           ? ((rates[i].high + rates[i].low + rates[i].close) / 3.0)
                           : rates[i].close;
      if(price <= 0.0)
         return false;

      if(i == count - 1)
        {
         l0 = price;
         l1 = price;
         l2 = price;
         l3 = price;
        }
      else
        {
         const double old_l0 = l0;
         const double old_l1 = l1;
         const double old_l2 = l2;
         const double old_l3 = l3;
         l0 = (1.0 - gamma) * price + gamma * old_l0;
         l1 = -gamma * l0 + old_l0 + gamma * old_l1;
         l2 = -gamma * l1 + old_l1 + gamma * old_l2;
         l3 = -gamma * l2 + old_l2 + gamma * old_l3;
        }

      if(i < QM2131_RECENT_BARS)
        {
         g_laguerre_lf[i] = (l0 + 2.0 * l1 + 2.0 * l2 + l3) / 6.0;
         g_laguerre_close[i] = rates[i].close;
         g_laguerre_high[i] = rates[i].high;
         g_laguerre_low[i] = rates[i].low;
        }
     }

   g_laguerre_ready = true;
   g_laguerre_last_closed_bar = closed_bar;
   return true;
  }

bool LaguerreSnapshot(double &close_0,
                      double &close_1,
                      double &lf_0,
                      double &lf_1,
                      double &lf_2,
                      double &lf_3)
  {
   close_0 = 0.0;
   close_1 = 0.0;
   lf_0 = 0.0;
   lf_1 = 0.0;
   lf_2 = 0.0;
   lf_3 = 0.0;

   if(!AdvanceLaguerreState())
      return false;

   close_0 = g_laguerre_close[0];
   close_1 = g_laguerre_close[1];
   lf_0 = g_laguerre_lf[0];
   lf_1 = g_laguerre_lf[1];
   lf_2 = g_laguerre_lf[2];
   lf_3 = g_laguerre_lf[3];
   return (close_0 > 0.0 && close_1 > 0.0 && lf_0 > 0.0 && lf_1 > 0.0 && lf_2 > 0.0 && lf_3 > 0.0);
  }

int CrossDirectionAtOffset(const int offset)
  {
   if(offset < 0 || offset + 1 >= QM2131_RECENT_BARS)
      return 0;
   if(!AdvanceLaguerreState())
      return 0;

   const double close_now = g_laguerre_close[offset];
   const double close_prev = g_laguerre_close[offset + 1];
   const double lf_now = g_laguerre_lf[offset];
   const double lf_prev = g_laguerre_lf[offset + 1];
   if(close_prev <= lf_prev && close_now > lf_now)
      return 1;
   if(close_prev >= lf_prev && close_now < lf_now)
      return -1;
   return 0;
  }

bool RecentCrossThrottleBlocks()
  {
   const int bars = MathMin(MathMax(0, strategy_cross_throttle_bars), QM2131_RECENT_BARS - 2);
   for(int offset = 1; offset <= bars; ++offset)
      if(CrossDirectionAtOffset(offset) != 0)
         return true;
   return false;
  }

double ExtremeSinceEntry(const ENUM_POSITION_TYPE position_type, const datetime open_time)
  {
   double extreme = 0.0;
   const int max_scan = MathMax(2, strategy_time_stop_h4_bars + 4);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop scan over H4 bars since entry.
      if(bar_time <= 0)
         break;
      if(open_time > 0 && bar_time < open_time)
         break;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double high = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop highest-high since entry.
         if(high > 0.0 && (extreme <= 0.0 || high > extreme))
            extreme = high;
        }
      else
        {
         const double low = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop lowest-low since entry.
         if(low > 0.0 && (extreme <= 0.0 || low < extreme))
            extreme = low;
        }
     }

   return extreme;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

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

   if(_Period != PERIOD_H4)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(RecentCrossThrottleBlocks())
      return false;

   double close_0, close_1, lf_0, lf_1, lf_2, lf_3;
   if(!LaguerreSnapshot(close_0, close_1, lf_0, lf_1, lf_2, lf_3))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || d1_ema <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const bool cross_up = (close_1 <= lf_1 && close_0 > lf_0);
   const bool cross_down = (close_1 >= lf_1 && close_0 < lf_0);

   if(cross_up &&
      close_0 - lf_0 >= strategy_cross_atr_mult * atr &&
      lf_0 > lf_2 &&
      close_0 > d1_ema)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(g_laguerre_low[0] - strategy_initial_stop_atr * atr);
      req.tp = 0.0;
      req.reason = "LAGUERRE_PRICE_UP_CROSS";
      return (req.sl > 0.0);
     }

   if(cross_down &&
      lf_0 - close_0 >= strategy_cross_atr_mult * atr &&
      lf_0 < lf_2 &&
      close_0 < d1_ema)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeStrategyPrice(g_laguerre_high[0] + strategy_initial_stop_atr * atr);
      req.tp = 0.0;
      req.reason = "LAGUERRE_PRICE_DOWN_CROSS";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double favorable_move = is_buy ? (market - open_price) : (open_price - market);
   if(favorable_move < strategy_trail_trigger_atr * atr)
      return;

   const double extreme = ExtremeSinceEntry(position_type, open_time);
   if(extreme <= 0.0)
      return;

   const double target_sl = NormalizeStrategyPrice(is_buy ? (extreme - strategy_trail_atr_mult * atr)
                                                          : (extreme + strategy_trail_atr_mult * atr));
   if(target_sl <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "laguerre_high_low_atr_trail");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return false;

   if(H4BarsHeld(open_time) >= strategy_time_stop_h4_bars)
      return true;

   double close_0, close_1, lf_0, lf_1, lf_2, lf_3;
   if(!LaguerreSnapshot(close_0, close_1, lf_0, lf_1, lf_2, lf_3))
      return false;

   const bool cross_up = (close_1 <= lf_1 && close_0 > lf_0);
   const bool cross_down = (close_1 >= lf_1 && close_0 < lf_0);
   if(position_type == POSITION_TYPE_BUY && cross_down)
      return true;
   if(position_type == POSITION_TYPE_SELL && cross_up)
      return true;

   if(position_type == POSITION_TYPE_BUY && lf_0 < lf_3 && lf_1 < lf_2)
      return true;
   if(position_type == POSITION_TYPE_SELL && lf_0 > lf_3 && lf_1 > lf_2)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(_Period != PERIOD_H4 && MQLInfoInteger(MQL_TESTER) == 0)
      Print("QM5_2131 expects H4 chart period.");

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2131\",\"strategy\":\"ehlers_laguerre_filter_h4\"}");
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
