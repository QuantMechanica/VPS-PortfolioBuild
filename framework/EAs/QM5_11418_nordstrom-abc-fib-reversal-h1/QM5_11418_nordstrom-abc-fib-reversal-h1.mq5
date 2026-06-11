#property strict
#property version   "5.0"
#property description "QM5_11418 Nordstrom ABC Fib Reversal H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11418;
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
input int    strategy_d1_lookback_bars      = 20;
input double strategy_d1_majority_pct       = 60.0;
input int    strategy_swing_scan_bars       = 96;
input double strategy_min_swing_pips        = 5.0;
input double strategy_fib_zone_low_mult     = 1.279;
input double strategy_fib_zone_high_mult    = 1.618;
input double strategy_sl_buffer_pips        = 5.0;
input double strategy_max_sl_pips           = 80.0;
input double strategy_min_rr                = 2.0;
input double strategy_spread_cap_pips       = 20.0;
input int    strategy_pending_bars          = 1;
input int    strategy_c_max_age_bars        = 12;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double Strategy_RoundNearestStep(const double price, const double step)
  {
   if(step <= 0.0)
      return Strategy_NormalizePrice(price);
   return Strategy_NormalizePrice(MathRound(price / step) * step);
  }

double Strategy_RoundUpStep(const double price, const double step)
  {
   if(step <= 0.0)
      return Strategy_NormalizePrice(price);
   return Strategy_NormalizePrice(MathCeil((price - 1e-10) / step) * step);
  }

double Strategy_RoundDownStep(const double price, const double step)
  {
   if(step <= 0.0)
      return Strategy_NormalizePrice(price);
   return Strategy_NormalizePrice(MathFloor((price + 1e-10) / step) * step);
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

int Strategy_MacroTrend()
  {
   if(strategy_d1_lookback_bars <= 0)
      return 0;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_d1_lookback_bars, d1); // perf-allowed: fixed D1 body-count window, called only from framework closed-bar hooks.
   if(copied < strategy_d1_lookback_bars)
      return 0;

   int green = 0;
   int red = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(d1[i].close > d1[i].open)
         green++;
      else if(d1[i].close < d1[i].open)
         red++;
     }

   const int needed = (int)MathCeil((double)strategy_d1_lookback_bars * strategy_d1_majority_pct / 100.0);
   if(green >= needed && green > red)
      return 1;
   if(red >= needed && red > green)
      return -1;
   return 0;
  }

bool Strategy_IsHIP(MqlRates &rates[], const int shift, const double min_move)
  {
   const int n = ArraySize(rates);
   if(shift <= 1 || shift >= n - 1)
      return false;
   const double h = rates[shift].high;
   const double near_high = MathMax(rates[shift - 1].high, rates[shift + 1].high);
   return (h > rates[shift - 1].high && h > rates[shift + 1].high && (h - near_high) >= min_move);
  }

bool Strategy_IsLOP(MqlRates &rates[], const int shift, const double min_move)
  {
   const int n = ArraySize(rates);
   if(shift <= 1 || shift >= n - 1)
      return false;
   const double l = rates[shift].low;
   const double near_low = MathMin(rates[shift - 1].low, rates[shift + 1].low);
   return (l < rates[shift - 1].low && l < rates[shift + 1].low && (near_low - l) >= min_move);
  }

bool Strategy_FindShortABC(MqlRates &rates[],
                           int &a_shift,
                           double &a_price,
                           double &a_open,
                           double &b_price,
                           int &c_shift,
                           double &c_price)
  {
   const int n = ArraySize(rates);
   const double pip = Strategy_PipSize();
   const double min_move = pip * strategy_min_swing_pips;
   if(n < 12 || pip <= 0.0)
      return false;

   c_shift = -1;
   for(int s = 2; s < n - 1; ++s)
     {
      if(Strategy_IsHIP(rates, s, min_move))
        {
         c_shift = s;
         c_price = rates[s].high;
         break;
        }
     }
   if(c_shift < 0 || c_shift > strategy_c_max_age_bars)
      return false;

   int b_shift = -1;
   for(int s = c_shift + 1; s < n - 1; ++s)
     {
      if(Strategy_IsHIP(rates, s, min_move))
        {
         b_shift = s;
         b_price = rates[s].high;
         break;
        }
     }
   if(b_shift < 0 || c_price <= b_price)
      return false;

   a_shift = -1;
   for(int s = b_shift + 1; s < n - 1; ++s)
     {
      if(Strategy_IsLOP(rates, s, min_move))
        {
         a_shift = s;
         a_price = rates[s].low;
         a_open = rates[s].open;
         break;
        }
     }

   return (a_shift > 0 && b_price > a_price);
  }

bool Strategy_FindLongABC(MqlRates &rates[],
                          int &a_shift,
                          double &a_price,
                          double &a_open,
                          double &b_price,
                          int &c_shift,
                          double &c_price)
  {
   const int n = ArraySize(rates);
   const double pip = Strategy_PipSize();
   const double min_move = pip * strategy_min_swing_pips;
   if(n < 12 || pip <= 0.0)
      return false;

   c_shift = -1;
   for(int s = 2; s < n - 1; ++s)
     {
      if(Strategy_IsLOP(rates, s, min_move))
        {
         c_shift = s;
         c_price = rates[s].low;
         break;
        }
     }
   if(c_shift < 0 || c_shift > strategy_c_max_age_bars)
      return false;

   int b_shift = -1;
   for(int s = c_shift + 1; s < n - 1; ++s)
     {
      if(Strategy_IsLOP(rates, s, min_move))
        {
         b_shift = s;
         b_price = rates[s].low;
         break;
        }
     }
   if(b_shift < 0 || c_price >= b_price)
      return false;

   a_shift = -1;
   for(int s = b_shift + 1; s < n - 1; ++s)
     {
      if(Strategy_IsHIP(rates, s, min_move))
        {
         a_shift = s;
         a_price = rates[s].high;
         a_open = rates[s].open;
         break;
        }
     }

   return (a_shift > 0 && a_price > b_price);
  }

bool Strategy_NoTradeFilter()
  {
   const double pip = Strategy_PipSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if(strategy_spread_cap_pips > 0.0 && ((ask - bid) / pip) > strategy_spread_cap_pips)
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
   const int pending_bars = (strategy_pending_bars > 1) ? strategy_pending_bars : 1;
   req.expiration_seconds = pending_bars * PeriodSeconds(PERIOD_H1);

   if(Strategy_HasOurPendingOrder())
      return false;

   const int macro_trend = Strategy_MacroTrend();
   if(macro_trend == 0)
      return false;

   const int requested_bars = strategy_swing_scan_bars + 4;
   const int need = (requested_bars > 24) ? requested_bars : 24;
   MqlRates h1[];
   ArraySetAsSeries(h1, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, need, h1); // perf-allowed: bounded ABC swing scan, called only after framework QM_IsNewBar gate.
   if(copied < need)
      return false;

   const double pip = Strategy_PipSize();
   const double round_step = pip * 10.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || round_step <= 0.0 || point <= 0.0)
      return false;

   int a_shift = -1;
   int c_shift = -1;
   double a_price = 0.0;
   double a_open = 0.0;
   double b_price = 0.0;
   double c_price = 0.0;

   if(macro_trend < 0 && Strategy_FindShortABC(h1, a_shift, a_price, a_open, b_price, c_shift, c_price))
     {
      const double ab = b_price - a_price;
      const double zone_low = a_price + strategy_fib_zone_low_mult * ab;
      const double zone_high = a_price + strategy_fib_zone_high_mult * ab;
      if(ab <= 0.0 || c_price < zone_low)
         return false;

      if(h1[1].close <= h1[1].open || h1[1].open < zone_low)
         return false;

      const double entry = Strategy_NormalizePrice(h1[1].open + point);
      const double sl_base = MathMax(c_price, Strategy_RoundUpStep(zone_high, round_step));
      const double sl = Strategy_NormalizePrice(sl_base + strategy_sl_buffer_pips * pip);
      const double tp = Strategy_RoundNearestStep(a_open, round_step);
      const double risk = sl - entry;
      const double reward = entry - tp;
      if(entry <= 0.0 || sl <= entry || tp >= entry)
         return false;
      if(risk > strategy_max_sl_pips * pip || reward < risk * strategy_min_rr)
         return false;
      if(entry >= SymbolInfoDouble(_Symbol, SYMBOL_BID))
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "NORDSTROM_ABC_FIB_SHORT";
      return true;
     }

   if(macro_trend > 0 && Strategy_FindLongABC(h1, a_shift, a_price, a_open, b_price, c_shift, c_price))
     {
      const double ab = a_price - b_price;
      const double zone_high = a_price - strategy_fib_zone_low_mult * ab;
      const double zone_low = a_price - strategy_fib_zone_high_mult * ab;
      if(ab <= 0.0 || c_price > zone_high)
         return false;

      if(h1[1].close >= h1[1].open || h1[1].open > zone_high)
         return false;

      const double entry = Strategy_NormalizePrice(h1[1].open - point);
      const double sl_base = MathMin(c_price, Strategy_RoundDownStep(zone_low, round_step));
      const double sl = Strategy_NormalizePrice(sl_base - strategy_sl_buffer_pips * pip);
      const double tp = Strategy_RoundNearestStep(a_open, round_step);
      const double risk = entry - sl;
      const double reward = tp - entry;
      if(entry <= 0.0 || sl >= entry || tp <= entry)
         return false;
      if(risk > strategy_max_sl_pips * pip || reward < risk * strategy_min_rr)
         return false;
      if(entry <= SymbolInfoDouble(_Symbol, SYMBOL_ASK))
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "NORDSTROM_ABC_FIB_LONG";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   const int trend = Strategy_MacroTrend();
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_SELL_STOP && trend >= 0)
         QM_TM_RemovePendingOrder(ticket, "D1_TREND_FLIP_CANCEL_SHORT");
      else if(type == ORDER_TYPE_BUY_STOP && trend <= 0)
         QM_TM_RemovePendingOrder(ticket, "D1_TREND_FLIP_CANCEL_LONG");
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11418\",\"strategy\":\"nordstrom_abc_fib_reversal_h1\"}");
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
