#property strict
#property version   "5.0"
#property description "QM5_1116 Hopwood ASCTrend H1 Trend-Follower"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1116;
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
input ENUM_TIMEFRAMES strategy_tf       = PERIOD_H1;
input int    strategy_asctrend_risk     = 3;
input int    strategy_ema_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_rr_target         = 2.0;
input int    strategy_structure_lookback = 10;
input bool   strategy_use_structure_sl  = false;
input int    strategy_max_spread_points = 25;
input int    strategy_warmup_bars       = 260;

datetime g_last_exit_bar = 0;
bool     g_last_exit_signal = false;

double NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool OurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

double WilderRange(const int shift)
  {
   const int period = MathMax(2, strategy_asctrend_risk * 10);
   const int warmup = MathMax(strategy_warmup_bars, period + 20);
   double rma = 0.0;
   bool seeded = false;

   for(int s = shift + warmup; s >= shift; --s)
     {
      const double high = iHigh(_Symbol, strategy_tf, s);
      const double low = iLow(_Symbol, strategy_tf, s);
      const double prev_close = iClose(_Symbol, strategy_tf, s + 1);
      if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
         continue;

      const double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
      if(!seeded)
        {
         rma = tr;
         seeded = true;
        }
      else
         rma = (rma * (period - 1) + tr) / period;
     }

   return seeded ? rma : 0.0;
  }

int ASCTrendState(const int shift)
  {
   const int warmup = MathMax(strategy_warmup_bars, strategy_ema_period + 20);
   int trend = 0;
   double trail_up = 0.0;
   double trail_dn = 0.0;

   for(int s = shift + warmup; s >= shift; --s)
     {
      const double high = iHigh(_Symbol, strategy_tf, s);
      const double low = iLow(_Symbol, strategy_tf, s);
      const double close = iClose(_Symbol, strategy_tf, s);
      const double range = WilderRange(s);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || range <= 0.0)
         continue;

      const double mid = (high + low) * 0.5;
      const double candidate_up = mid - strategy_asctrend_risk * range;
      const double candidate_dn = mid + strategy_asctrend_risk * range;

      if(trend == 0)
        {
         trend = (close >= mid) ? 1 : -1;
         trail_up = candidate_up;
         trail_dn = candidate_dn;
         continue;
        }

      if(trend > 0)
        {
         trail_up = MathMax(trail_up, candidate_up);
         if(close < trail_up)
           {
            trend = -1;
            trail_dn = candidate_dn;
           }
        }
      else
        {
         trail_dn = MathMin(trail_dn, candidate_dn);
         if(close > trail_dn)
           {
            trend = 1;
            trail_up = candidate_up;
           }
        }
     }

   return trend;
  }

bool ASCTrendFlip(const int shift, int &state)
  {
   state = ASCTrendState(shift);
   const int prev = ASCTrendState(shift + 1);
   return (state != 0 && prev != 0 && state != prev);
  }

double StructureStop(const bool bullish)
  {
   const int lookback = MathMax(2, strategy_structure_lookback);
   double stop = bullish ? DBL_MAX : -DBL_MAX;

   for(int s = 1; s <= lookback; ++s)
     {
      if(bullish)
         stop = MathMin(stop, iLow(_Symbol, strategy_tf, s));
      else
         stop = MathMax(stop, iHigh(_Symbol, strategy_tf, s));
     }

   if(bullish && stop != DBL_MAX)
      return NormalizePrice(stop);
   if(!bullish && stop != -DBL_MAX)
      return NormalizePrice(stop);
   return 0.0;
  }

double ATRStop(const bool bullish, const double entry_price)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0.0;
   return NormalizePrice(bullish ? entry_price - strategy_atr_sl_mult * atr
                                 : entry_price + strategy_atr_sl_mult * atr);
  }

bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, strategy_tf) < strategy_warmup_bars)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(strategy_asctrend_risk <= 0 || strategy_ema_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(OurPosition(ticket, ptype))
      return false;

   int state = 0;
   if(!ASCTrendFlip(1, state))
      return false;

   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double ema1 = QM_EMA(_Symbol, strategy_tf, strategy_ema_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close1 <= 0.0 || ema1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const bool bullish = (state > 0 && close1 > ema1);
   const bool bearish = (state < 0 && close1 < ema1);
   if(!bullish && !bearish)
      return false;

   const double entry = bullish ? ask : bid;
   double sl = strategy_use_structure_sl ? StructureStop(bullish) : ATRStop(bullish, entry);
   if(sl <= 0.0)
      return false;

   if(bullish && sl >= entry)
      sl = ATRStop(true, entry);
   if(bearish && sl <= entry)
      sl = ATRStop(false, entry);
   if(sl <= 0.0 || (bullish && sl >= entry) || (bearish && sl <= entry))
      return false;

   const double risk = MathAbs(entry - sl);
   const double tp = NormalizePrice(bullish ? entry + strategy_rr_target * risk
                                            : entry - strategy_rr_target * risk);
   if(tp <= 0.0)
      return false;

   req.type = bullish ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = bullish ? "ASCTREND_EMA_LONG" : "ASCTREND_EMA_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, grid, or scale-in.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!OurPosition(ticket, ptype))
      return false;

   const datetime bar0 = iTime(_Symbol, strategy_tf, 0);
   if(bar0 <= 0)
      return false;
   if(bar0 == g_last_exit_bar)
      return g_last_exit_signal;

   g_last_exit_bar = bar0;
   g_last_exit_signal = false;

   int state = 0;
   if(!ASCTrendFlip(1, state))
      return false;

   if(ptype == POSITION_TYPE_BUY && state < 0)
      g_last_exit_signal = true;
   if(ptype == POSITION_TYPE_SELL && state > 0)
      g_last_exit_signal = true;

   return g_last_exit_signal;
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1116\",\"ea\":\"hopwood-asctrend-h1-tf\"}");
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

