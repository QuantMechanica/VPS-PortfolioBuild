#property strict
#property version   "5.0"
#property description "QM5_2078 Ehlers Sine-Wave / Lead-Line Cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2078;
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
input int    strategy_warmup_h4_bars       = 200;
input int    strategy_atr_period           = 20;
input double strategy_spread_atr_mult      = 0.30;
input int    strategy_d1_ema_period        = 50;
input double strategy_cycle_min_dphase_deg = 6.0;
input double strategy_cycle_max_dphase_deg = 60.0;
input int    strategy_trade_min_period     = 10;
input int    strategy_trade_max_period     = 40;
input double strategy_sine_lead_sep_min    = 0.05;
input int    strategy_cycle_stability_bars = 2;
input int    strategy_trend_exit_bars      = 3;
input double strategy_initial_stop_atr     = 0.50;
input double strategy_trail_trigger_atr    = 1.50;
input double strategy_trail_atr_mult       = 2.50;
input double strategy_time_stop_period_mult = 1.20;

#define QM2078_PI 3.14159265358979323846
#define QM2078_RECENT_BARS 16

double   g_sine[QM2078_RECENT_BARS];
double   g_lead[QM2078_RECENT_BARS];
double   g_period[QM2078_RECENT_BARS];
double   g_dphase_deg[QM2078_RECENT_BARS];
double   g_close_h4[QM2078_RECENT_BARS];
double   g_open_h4[QM2078_RECENT_BARS];
double   g_high_h4[QM2078_RECENT_BARS];
double   g_low_h4[QM2078_RECENT_BARS];
bool     g_cycle_mode[QM2078_RECENT_BARS];
bool     g_state_ready = false;
double   g_entry_period_h4 = 0.0;

double QM2078_Atan2(const double y, const double x)
  {
   if(x > 0.0)
      return MathArctan(y / x);
   if(x < 0.0 && y >= 0.0)
      return MathArctan(y / x) + QM2078_PI;
   if(x < 0.0 && y < 0.0)
      return MathArctan(y / x) - QM2078_PI;
   if(x == 0.0 && y > 0.0)
      return 0.5 * QM2078_PI;
   if(x == 0.0 && y < 0.0)
      return -0.5 * QM2078_PI;
   return 0.0;
  }

double QM2078_WrapRadians(double value)
  {
   while(value > QM2078_PI)
      value -= 2.0 * QM2078_PI;
   while(value < -QM2078_PI)
      value += 2.0 * QM2078_PI;
   return value;
  }

double QM2078_Clamp(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

bool QM2078_FindOurPosition(ulong &ticket,
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

int QM2078_H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift > 0) ? shift : 0;
  }

bool QM2078_UpdateState()
  {
   const int keep = QM2078_RECENT_BARS;
   const int count = MathMax(strategy_warmup_h4_bars + keep + 16, 240);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, count, rates) != count) // perf-allowed: bounded Hilbert reconstruction cached once per closed H4 bar.
      return false;

   double smooth[];
   double detrender[];
   double q1[];
   double i1[];
   double phase[];
   double period[];
   ArrayResize(smooth, count);
   ArrayResize(detrender, count);
   ArrayResize(q1, count);
   ArrayResize(i1, count);
   ArrayResize(phase, count);
   ArrayResize(period, count);

   for(int i = count - 1; i >= 0; --i)
     {
      const double close0 = rates[i].close;
      if(close0 <= 0.0)
         return false;

      if(i + 3 < count)
         smooth[i] = (4.0 * rates[i].close + 3.0 * rates[i + 1].close +
                      2.0 * rates[i + 2].close + rates[i + 3].close) / 10.0;
      else
         smooth[i] = close0;

      const double period_prev = (i + 1 < count && period[i + 1] > 0.0) ? period[i + 1] : 10.0;
      const double adj = 0.075 * period_prev + 0.54;

      if(i + 6 < count)
        {
         detrender[i] = (0.0962 * smooth[i] + 0.5769 * smooth[i + 2] -
                         0.5769 * smooth[i + 4] - 0.0962 * smooth[i + 6]) * adj;
         q1[i] = (0.0962 * detrender[i] + 0.5769 * detrender[i + 2] -
                  0.5769 * detrender[i + 4] - 0.0962 * detrender[i + 6]) * adj;
         i1[i] = detrender[i + 3];
        }
      else
        {
         detrender[i] = 0.0;
         q1[i] = 0.0;
         i1[i] = 0.0;
        }

      phase[i] = QM2078_Atan2(q1[i], i1[i]);

      if(i + 1 < count)
        {
         const double dphase = QM2078_WrapRadians(phase[i] - phase[i + 1]);
         const double abs_dphase = MathAbs(dphase);
         if(abs_dphase > 0.000001)
            period[i] = QM2078_Clamp((2.0 * QM2078_PI) / abs_dphase, 6.0, 50.0);
         else
            period[i] = period_prev;
        }
      else
         period[i] = 10.0;
     }

   for(int j = 0; j < keep; ++j)
     {
      const double dphase = (j + 1 < count) ? QM2078_WrapRadians(phase[j] - phase[j + 1]) : 0.0;
      const double dphase_deg = MathAbs(dphase) * 180.0 / QM2078_PI;
      g_sine[j] = MathSin(phase[j]);
      g_lead[j] = MathSin(phase[j] + 0.25 * QM2078_PI);
      g_period[j] = period[j];
      g_dphase_deg[j] = dphase_deg;
      g_cycle_mode[j] = (dphase_deg >= strategy_cycle_min_dphase_deg &&
                         dphase_deg <= strategy_cycle_max_dphase_deg);
      g_open_h4[j] = rates[j].open;
      g_close_h4[j] = rates[j].close;
      g_high_h4[j] = rates[j].high;
      g_low_h4[j] = rates[j].low;
     }

   g_state_ready = true;
   return true;
  }

int QM2078_SineLeadCross(const int shift)
  {
   if(shift < 0 || shift + 1 >= QM2078_RECENT_BARS)
      return 0;
   if(!g_state_ready)
      return 0;

   if(g_sine[shift + 1] <= g_lead[shift + 1] && g_sine[shift] > g_lead[shift])
      return 1;
   if(g_sine[shift + 1] >= g_lead[shift + 1] && g_sine[shift] < g_lead[shift])
      return -1;
   return 0;
  }

bool QM2078_CycleStable()
  {
   if(!g_state_ready)
      return false;

   const int bars = MathMax(1, MathMin(strategy_cycle_stability_bars, QM2078_RECENT_BARS));
   for(int i = 0; i < bars; ++i)
      if(!g_cycle_mode[i])
         return false;
   return true;
  }

bool QM2078_TrendExitCondition(const ENUM_POSITION_TYPE position_type)
  {
   if(!g_state_ready)
      return false;

   const int bars = MathMax(1, MathMin(strategy_trend_exit_bars, QM2078_RECENT_BARS));
   for(int i = 0; i < bars; ++i)
      if(g_cycle_mode[i])
         return false;

   if(position_type == POSITION_TYPE_BUY)
      return (g_close_h4[0] > g_open_h4[0]);
   return (g_close_h4[0] < g_open_h4[0]);
  }

double QM2078_ExtremeSinceEntry(const ENUM_POSITION_TYPE position_type, const datetime open_time)
  {
   double extreme = 0.0;
   const int max_scan = MathMax(12, MathMin(160, (int)MathCeil(strategy_trade_max_period * strategy_time_stop_period_mult) + 16));

   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded H4 scan for card-required highest-high/lowest-low trail.
      if(bar_time <= 0)
         break;
      if(open_time > 0 && bar_time < open_time)
         break;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double high = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trail extreme since entry.
         if(high > 0.0 && (extreme <= 0.0 || high > extreme))
            extreme = high;
        }
      else
        {
         const double low = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trail extreme since entry.
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
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_ready)
      return false;
   if(!QM2078_CycleStable())
      return false;
   if(g_period[0] < strategy_trade_min_period || g_period[0] > strategy_trade_max_period)
      return false;
   if(MathAbs(g_sine[0] - g_lead[0]) < strategy_sine_lead_sep_min)
      return false;

   const int cross = QM2078_SineLeadCross(0);
   if(cross == 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
   if(d1_ema <= 0.0)
      return false;

   if(cross > 0)
     {
      if(g_sine[0] <= 0.0)
         return false;
      if(g_close_h4[0] <= d1_ema)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_low_h4[0] - strategy_initial_stop_atr * atr);
      req.reason = "EHLERS_SINE_LEAD_UP_CROSS";
     }
   else
     {
      if(g_sine[0] >= 0.0)
         return false;
      if(g_close_h4[0] >= d1_ema)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_high_h4[0] + strategy_initial_stop_atr * atr);
      req.reason = "EHLERS_SINE_LEAD_DOWN_CROSS";
     }

   if(req.sl <= 0.0)
      return false;

   g_entry_period_h4 = g_period[0];
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!QM2078_FindOurPosition(ticket, position_type, open_price, open_time))
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

   const double extreme = QM2078_ExtremeSinceEntry(position_type, open_time);
   if(extreme <= 0.0)
      return;

   const double raw_sl = is_buy ? (extreme - strategy_trail_atr_mult * atr)
                                : (extreme + strategy_trail_atr_mult * atr);
   const double target_sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(target_sl <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "ehlers_sine_high_low_atr_trail");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!QM2078_FindOurPosition(ticket, position_type, open_price, open_time))
      return false;

   if(!g_state_ready)
      return false;

   const int cross = QM2078_SineLeadCross(0);
   if(position_type == POSITION_TYPE_BUY && cross < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && cross > 0)
      return true;

   if(QM2078_TrendExitCondition(position_type))
      return true;

   const double period_for_stop = (g_entry_period_h4 > 0.0) ? g_entry_period_h4 : g_period[0];
   const int max_hold_bars = (int)MathCeil(strategy_time_stop_period_mult * period_for_stop);
   if(max_hold_bars > 0 && QM2078_H4BarsHeld(open_time) >= max_hold_bars)
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
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2078\",\"strategy\":\"ehlers_sine_wave_h4\"}");
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

   if(!QM2078_UpdateState())
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
