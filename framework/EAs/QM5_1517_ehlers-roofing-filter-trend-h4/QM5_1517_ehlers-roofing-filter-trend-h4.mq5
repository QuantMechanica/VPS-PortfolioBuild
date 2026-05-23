#property strict
#property version   "5.0"
#property description "QM5_1517 Ehlers Roofing Filter Trend H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1517;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_hp_period          = 48;
input int    strategy_ss_period          = 10;
input int    strategy_atr_period         = 14;
input int    strategy_atr_mean_bars      = 200;
input int    strategy_warmup_h4_bars     = 200;
input int    strategy_macro_sma_d1       = 50;
input int    strategy_macro_slope_bars   = 5;
input int    strategy_slope_bars         = 3;
input int    strategy_cooldown_h4_bars   = 16;
input double strategy_magnitude_atr_mult = 0.20;
input double strategy_atr_active_mult    = 0.60;
input double strategy_sl_atr_mult        = 2.00;
input double strategy_tp1_atr_mult       = 1.50;
input double strategy_tp1_close_fraction = 0.60;
input int    strategy_time_stop_h4_bars  = 24;
input int    strategy_spread_median_bars = 20;
input double strategy_spread_median_mult = 1.50;

#define QM1517_MAX_RECENT 64

double   g_roof_recent[QM1517_MAX_RECENT];
bool     g_roof_ready = false;
datetime g_roof_last_closed_bar = 0;

double   g_entry_tp1 = 0.0;
datetime g_entry_time = 0;

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

string Tp1GlobalKey(const ulong ticket)
  {
   return StringFormat("QM5_1517_TP1_%s_%I64u", _Symbol, ticket);
  }

int H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift > 0) ? shift : 0;
  }

double MedianSpreadPoints(const int bars)
  {
   const int n = MathMax(3, MathMin(100, bars));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, n, rates); // perf-allowed: Strategy_NoTradeFilter caches by closed H4 bar.
   if(copied <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
      spreads[i] = (double)rates[i].spread;
   ArraySort(spreads);

   const int mid = copied / 2;
   if((copied % 2) == 1)
      return spreads[mid];
   return 0.5 * (spreads[mid - 1] + spreads[mid]);
  }

bool SpreadAllowsEntry()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double current_spread_pts = (ask - bid) / point;
   const double median_spread_pts = MedianSpreadPoints(strategy_spread_median_bars);
   if(median_spread_pts <= 0.0)
      return true;

   return (current_spread_pts <= strategy_spread_median_mult * median_spread_pts);
  }

bool AdvanceRoofingState()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1);
   if(closed_bar <= 0)
      return false;
   if(g_roof_ready && g_roof_last_closed_bar == closed_bar)
      return true;

   const int hp_period = MathMax(3, strategy_hp_period);
   const int ss_period = MathMax(3, strategy_ss_period);
   const int keep = MathMin(QM1517_MAX_RECENT, MathMax(strategy_cooldown_h4_bars + 6, 24));
   const int count = MathMax(strategy_warmup_h4_bars, strategy_atr_mean_bars) + keep + hp_period + ss_period;
   if(Bars(_Symbol, PERIOD_H4) < count + 2)
      return false;

   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_H4, 1, count, close) != count) // perf-allowed: cached once per closed H4 bar by g_roof_last_closed_bar.
      return false;

   double hp[];
   double filt[];
   ArrayResize(hp, count);
   ArrayResize(filt, count);
   ArraySetAsSeries(hp, true);
   ArraySetAsSeries(filt, true);

   const double pi = 3.14159265358979323846;
   const double hp_angle = 0.707 * 2.0 * pi / (double)hp_period;
   const double alpha1 = (MathCos(hp_angle) + MathSin(hp_angle) - 1.0) / MathCos(hp_angle);
   const double hp_a = MathPow(1.0 - alpha1 / 2.0, 2.0);
   const double hp_b = 2.0 * (1.0 - alpha1);
   const double hp_c = -MathPow(1.0 - alpha1, 2.0);

   const double a1 = MathExp(-1.414 * pi / (double)ss_period);
   const double b1 = 2.0 * a1 * MathCos(1.414 * pi / (double)ss_period);
   const double c2 = b1;
   const double c3 = -a1 * a1;
   const double c1 = 1.0 - c2 - c3;

   hp[count - 1] = 0.0;
   hp[count - 2] = 0.0;
   filt[count - 1] = 0.0;
   filt[count - 2] = 0.0;

   for(int i = count - 3; i >= 0; --i)
     {
      hp[i] = hp_a * (close[i] - 2.0 * close[i + 1] + close[i + 2])
              + hp_b * hp[i + 1]
              + hp_c * hp[i + 2];
      filt[i] = c1 * (hp[i] + hp[i + 1]) / 2.0
                + c2 * filt[i + 1]
                + c3 * filt[i + 2];
     }

   for(int i = 0; i < QM1517_MAX_RECENT; ++i)
      g_roof_recent[i] = (i < keep) ? filt[i] : 0.0;

   g_roof_ready = true;
   g_roof_last_closed_bar = closed_bar;
   return true;
  }

double RoofValue(const int shift)
  {
   if(shift < 1 || shift > QM1517_MAX_RECENT)
      return 0.0;
   if(!AdvanceRoofingState())
      return 0.0;
   return g_roof_recent[shift - 1];
  }

int RoofCrossDirection(const int shift)
  {
   const double now = RoofValue(shift);
   const double prev = RoofValue(shift + 1);
   if(now > 0.0 && prev <= 0.0)
      return 1;
   if(now < 0.0 && prev >= 0.0)
      return -1;
   return 0;
  }

bool HasRecentOppositeCross(const int direction)
  {
   const int bars = MathMin(strategy_cooldown_h4_bars, QM1517_MAX_RECENT - 2);
   for(int s = 2; s <= bars + 1; ++s)
     {
      if(RoofCrossDirection(s) == -direction)
         return true;
     }
   return false;
  }

double MeanATR(const int bars)
  {
   const int n = MathMax(1, bars);
   double sum = 0.0;
   int seen = 0;
   for(int s = 1; s <= n; ++s)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, s);
      if(atr <= 0.0)
         continue;
      sum += atr;
      ++seen;
     }
   return (seen > 0) ? (sum / (double)seen) : 0.0;
  }

bool MacroBiasPasses(const int direction)
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_d1, 1);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_d1, 1 + MathMax(1, strategy_macro_slope_bars));
   if(d1_close <= 0.0 || sma_now <= 0.0 || sma_prev <= 0.0)
      return false;

   if(direction > 0)
      return (d1_close > sma_now && sma_now > sma_prev);
   return (d1_close < sma_now && sma_now < sma_prev);
  }

bool EntryGatesPass(const int direction)
  {
   if(direction == 0)
      return false;
   if(Bars(_Symbol, PERIOD_H4) < strategy_warmup_h4_bars)
      return false;
   if(HasRecentOppositeCross(direction))
      return false;
   if(!MacroBiasPasses(direction))
      return false;

   const double f0 = RoofValue(1);
   const double f_slope = RoofValue(1 + MathMax(1, strategy_slope_bars));
   if(direction > 0 && f0 - f_slope <= 0.0)
      return false;
   if(direction < 0 && f0 - f_slope >= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double mean_atr = MeanATR(strategy_atr_mean_bars);
   if(atr <= 0.0 || mean_atr <= 0.0)
      return false;
   if(MathAbs(f0) <= strategy_magnitude_atr_mult * atr)
      return false;
   if(atr < strategy_atr_active_mult * mean_atr)
      return false;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   static datetime last_checked_bar = 0;
   static bool spread_blocks = false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1);
   if(closed_bar <= 0)
      return true;
   if(closed_bar != last_checked_bar)
     {
      last_checked_bar = closed_bar;
      spread_blocks = !SpreadAllowsEntry();
     }

   return spread_blocks;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H4)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(GetOurPosition(ticket, ptype, open_time))
      return false;

   const int direction = RoofCrossDirection(1);
   if(!EntryGatesPass(direction))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(direction > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - strategy_sl_atr_mult * atr;
      req.reason = "ROOFING_FILTER_BULL_ZERO_CROSS";
      g_entry_tp1 = ask + strategy_tp1_atr_mult * atr;
     }
   else
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + strategy_sl_atr_mult * atr;
      req.reason = "ROOFING_FILTER_BEAR_ZERO_CROSS";
      g_entry_tp1 = bid - strategy_tp1_atr_mult * atr;
     }

   req.tp = 0.0;
   g_entry_time = TimeCurrent();
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
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

      const string key = Tp1GlobalKey(ticket);
      if(GlobalVariableCheck(key))
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      if(entry <= 0.0 || sl <= 0.0 || lots <= 0.0)
         continue;

      double tp1 = g_entry_tp1;
      if(tp1 <= 0.0)
        {
         const double sl_dist = MathAbs(entry - sl);
         tp1 = (ptype == POSITION_TYPE_BUY) ? (entry + 0.75 * sl_dist)
                                            : (entry - 0.75 * sl_dist);
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool hit_tp1 = (ptype == POSITION_TYPE_BUY) ? (bid >= tp1) : (ask <= tp1);
      if(!hit_tp1)
         continue;

      const double partial_lots = lots * MathMax(0.0, MathMin(1.0, strategy_tp1_close_fraction));
      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
         GlobalVariableSet(key, (double)TimeCurrent());
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!GetOurPosition(ticket, ptype, open_time))
      return false;

   if(H4BarsHeld(open_time) >= strategy_time_stop_h4_bars)
      return true;

   const int cross = RoofCrossDirection(1);
   if(ptype == POSITION_TYPE_BUY && cross < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && cross > 0)
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
      Print("QM5_1517 expects H4 chart period.");

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1517\",\"strategy\":\"ehlers_roofing_filter_trend_h4\"}");
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
