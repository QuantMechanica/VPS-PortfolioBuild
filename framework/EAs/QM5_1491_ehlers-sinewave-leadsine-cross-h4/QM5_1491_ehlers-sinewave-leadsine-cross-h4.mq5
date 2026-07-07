#property strict
#property version   "5.0"
#property description "QM5_1491 Ehlers Sinewave / LeadSine cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1491;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_warmup_bars          = 200;
input int    strategy_atr_period           = 14;
input int    strategy_atr_sma_period       = 200;
input double strategy_atr_floor_ratio      = 0.6;
input int    strategy_macro_sma_period     = 50;
input int    strategy_macro_sma_slope_bars = 5;
input int    strategy_recent_opp_bars      = 12;
input double strategy_cycle_extreme_level  = 0.5;
input double strategy_sl_atr_mult          = 2.0;
input double strategy_tp1_atr_mult         = 1.5;
input double strategy_tp1_close_pct        = 60.0;
input int    strategy_time_stop_bars       = 24;
input int    strategy_spread_median_bars   = 20;
input double strategy_spread_mult          = 1.5;

const double QM1491_PI                 = 3.1415926535897932384626433832795;
const double QM1491_HP_ALPHA           = 0.07;
const double QM1491_LEAD_OFFSET_RADIANS = 0.78539816339744830961566084581988;

int    g_qm1491_last_cross_direction = 0;
double g_qm1491_pending_entry_atr    = 0.0;

ulong  g_qm1491_position_ticket       = 0;
double g_qm1491_position_initial_lots = 0.0;
double g_qm1491_position_entry_atr    = 0.0;
bool   g_qm1491_tp1_done              = false;

double QM1491_Atan2(const double y, const double x)
  {
   if(x > 0.0)
      return MathArctan(y / x);
   if(x < 0.0 && y >= 0.0)
      return MathArctan(y / x) + QM1491_PI;
   if(x < 0.0 && y < 0.0)
      return MathArctan(y / x) - QM1491_PI;
   if(x == 0.0 && y > 0.0)
      return 0.5 * QM1491_PI;
   if(x == 0.0 && y < 0.0)
      return -0.5 * QM1491_PI;
   return 0.0;
  }

double QM1491_NormalizeAngle(double value)
  {
   const double two_pi = 2.0 * QM1491_PI;
   while(value > QM1491_PI)
      value -= two_pi;
   while(value < -QM1491_PI)
      value += two_pi;
   return value;
  }

bool QM1491_HasOpenPosition(ENUM_POSITION_TYPE &ptype,
                            ulong &ticket,
                            double &open_price,
                            double &volume,
                            datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;
   open_price = 0.0;
   volume = 0.0;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void QM1491_ResetPositionCache()
  {
   g_qm1491_position_ticket = 0;
   g_qm1491_position_initial_lots = 0.0;
   g_qm1491_position_entry_atr = 0.0;
   g_qm1491_tp1_done = false;
  }

double QM1491_ATRAverage(const int period_value, const int samples)
  {
   if(period_value <= 0 || samples <= 0)
      return 0.0;

   double sum = 0.0;
   for(int shift = 1; shift <= samples; ++shift)
     {
      const double value = QM_ATR(_Symbol, PERIOD_H4, period_value, shift);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }

   return sum / (double)samples;
  }

bool QM1491_MacroBiasAllows(const int direction)
  {
   if(strategy_macro_sma_period <= 1 || strategy_macro_sma_slope_bars <= 0)
      return false;

   double d1_close[];
   ArraySetAsSeries(d1_close, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, 1, d1_close); // perf-allowed: one closed D1 close for card macro-bias gate.
   if(copied < 1 || d1_close[0] <= 0.0)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_sma_slope_bars, PRICE_CLOSE);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return false;

   if(direction > 0)
      return (d1_close[0] > sma_now && sma_now > sma_prev);
   return (d1_close[0] < sma_now && sma_now < sma_prev);
  }

bool QM1491_SpreadBlocksEntry()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if(!(ask > bid))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_spread_median_bars <= 0 || strategy_spread_mult <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, strategy_spread_median_bars, rates); // perf-allowed: EntrySignal is called only after the framework new-bar gate.
   if(copied <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   for(int i = 0; i < copied; ++i)
      spreads[i] = (double)rates[i].spread;

   ArraySort(spreads);
   double median_points = 0.0;
   if((copied % 2) == 1)
      median_points = spreads[copied / 2];
   else
      median_points = 0.5 * (spreads[(copied / 2) - 1] + spreads[copied / 2]);

   if(median_points <= 0.0)
      return false;

   const double current_spread_price = ask - bid;
   const double cap_price = median_points * point * strategy_spread_mult;
   return (current_spread_price > cap_price);
  }

bool QM1491_RecentOppositeCross(const int direction,
                                const double &sine[],
                                const double &lead[],
                                const int bars_available)
  {
   if(strategy_recent_opp_bars <= 0)
      return false;

   const int max_shift = MathMin(strategy_recent_opp_bars, bars_available - 2);
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const bool bullish = (lead[shift] > sine[shift] && lead[shift + 1] <= sine[shift + 1]);
      const bool bearish = (lead[shift] < sine[shift] && lead[shift + 1] >= sine[shift + 1]);
      if(direction > 0 && bearish)
         return true;
      if(direction < 0 && bullish)
         return true;
     }

   return false;
  }

bool QM1491_CalculateClosedBarSignal(int &entry_direction,
                                     int &cross_direction,
                                     double &atr_value)
  {
   entry_direction = 0;
   cross_direction = 0;
   atr_value = 0.0;

   if(strategy_warmup_bars < 80 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sma_period <= 0 ||
      strategy_atr_floor_ratio <= 0.0 ||
      strategy_cycle_extreme_level <= 0.0)
      return false;

   double close_values[];
   ArraySetAsSeries(close_values, true);
   const int copied = CopyClose(_Symbol, PERIOD_H4, 1, strategy_warmup_bars, close_values); // perf-allowed: custom Ehlers Hilbert transform runs only after QM_IsNewBar.
   if(copied < strategy_warmup_bars)
      return false;

   double highpass[];
   double smooth[];
   double inphase[];
   double quadrature[];
   double phase[];
   double dcperiod[];
   double sine[];
   double lead[];
   bool trend_mode[];

   ArrayResize(highpass, copied);
   ArrayResize(smooth, copied);
   ArrayResize(inphase, copied);
   ArrayResize(quadrature, copied);
   ArrayResize(phase, copied);
   ArrayResize(dcperiod, copied);
   ArrayResize(sine, copied);
   ArrayResize(lead, copied);
   ArrayResize(trend_mode, copied);

   for(int i = copied - 1; i >= 0; --i)
     {
      highpass[i] = 0.0;
      smooth[i] = 0.0;
      inphase[i] = 0.0;
      quadrature[i] = 0.0;
      phase[i] = 0.0;
      dcperiod[i] = 20.0;
      sine[i] = 0.0;
      lead[i] = 0.0;
      trend_mode[i] = true;

      if(i + 2 < copied)
        {
         const double one_minus = 1.0 - QM1491_HP_ALPHA;
         const double hp_gain = MathPow(1.0 - 0.5 * QM1491_HP_ALPHA, 2.0);
         highpass[i] = hp_gain * (close_values[i] - 2.0 * close_values[i + 1] + close_values[i + 2])
                       + 2.0 * one_minus * highpass[i + 1]
                       - MathPow(one_minus, 2.0) * highpass[i + 2];
        }

      if(i + 3 < copied)
         smooth[i] = (highpass[i] + 2.0 * highpass[i + 1] + 2.0 * highpass[i + 2] + highpass[i + 3]) / 6.0;

      if(i + 6 < copied)
         quadrature[i] = 0.0962 * smooth[i]
                         + 0.5769 * smooth[i + 2]
                         - 0.5769 * smooth[i + 4]
                         - 0.0962 * smooth[i + 6];

      if(i + 3 < copied)
         inphase[i] = smooth[i + 3];

      phase[i] = QM1491_Atan2(quadrature[i], inphase[i]);

      if(i + 1 < copied)
        {
         const double delta = MathAbs(QM1491_NormalizeAngle(phase[i] - phase[i + 1]));
         double raw_period = dcperiod[i + 1];
         if(delta > 0.000001)
            raw_period = (2.0 * QM1491_PI) / delta;
         if(raw_period < 8.0)
            raw_period = 8.0;
         if(raw_period > 100.0)
            raw_period = 100.0;
         dcperiod[i] = 0.2 * raw_period + 0.8 * dcperiod[i + 1];
        }

      const int half_period = (int)MathRound(0.5 * dcperiod[i]);
      double phase_delta = 0.0;
      if(half_period > 0 && i + half_period < copied)
         phase_delta = MathAbs(QM1491_NormalizeAngle(phase[i] - phase[i + half_period]));
      else
         phase_delta = 0.0;

      trend_mode[i] = (dcperiod[i] > 50.0 || phase_delta < QM1491_LEAD_OFFSET_RADIANS);
      sine[i] = MathSin(phase[i]);
      lead[i] = MathSin(phase[i] + QM1491_LEAD_OFFSET_RADIANS);
     }

   if(copied < 14)
      return false;

   const bool bullish_cross = (lead[0] > sine[0] && lead[1] <= sine[1]);
   const bool bearish_cross = (lead[0] < sine[0] && lead[1] >= sine[1]);
   if(bullish_cross)
      cross_direction = 1;
   else if(bearish_cross)
      cross_direction = -1;

   if(cross_direction == 0)
      return true;

   if(trend_mode[0] || trend_mode[1] || trend_mode[2])
      return true;

   if(cross_direction > 0 && sine[0] >= -strategy_cycle_extreme_level)
      return true;
   if(cross_direction < 0 && sine[0] <= strategy_cycle_extreme_level)
      return true;

   if(!QM1491_MacroBiasAllows(cross_direction))
      return true;

   atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_avg = QM1491_ATRAverage(strategy_atr_period, strategy_atr_sma_period);
   if(atr_value <= 0.0 || atr_avg <= 0.0 || atr_value <= strategy_atr_floor_ratio * atr_avg)
      return true;

   if(QM1491_RecentOppositeCross(cross_direction, sine, lead, copied))
      return true;

   if(QM1491_SpreadBlocksEntry())
      return true;

   entry_direction = cross_direction;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (bid <= 0.0 || ask <= 0.0);
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

   int entry_direction = 0;
   int cross_direction = 0;
   double atr_value = 0.0;
   if(!QM1491_CalculateClosedBarSignal(entry_direction, cross_direction, atr_value))
      return false;

   g_qm1491_last_cross_direction = cross_direction;

   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price;
   double volume;
   datetime open_time;
   if(QM1491_HasOpenPosition(ptype, ticket, open_price, volume, open_time))
      return false;

   if(entry_direction == 0 || atr_value <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   req.type = (entry_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (req.type == QM_BUY) ? ask : bid;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_value, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (entry_direction > 0) ? "LEADSINE_SINE_BULL_CROSS" : "LEADSINE_SINE_BEAR_CROSS";
   g_qm1491_pending_entry_atr = atr_value;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price;
   double volume;
   datetime open_time;
   if(!QM1491_HasOpenPosition(ptype, ticket, open_price, volume, open_time))
     {
      QM1491_ResetPositionCache();
      return;
     }

   if(g_qm1491_position_ticket != ticket)
     {
      g_qm1491_position_ticket = ticket;
      g_qm1491_position_initial_lots = volume;
      g_qm1491_position_entry_atr = (g_qm1491_pending_entry_atr > 0.0)
                                    ? g_qm1491_pending_entry_atr
                                    : QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      g_qm1491_tp1_done = false;
      g_qm1491_pending_entry_atr = 0.0;
     }

   if(g_qm1491_tp1_done || g_qm1491_position_entry_atr <= 0.0 || g_qm1491_position_initial_lots <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double tp1_distance = strategy_tp1_atr_mult * g_qm1491_position_entry_atr;
   const double tp1_price = (ptype == POSITION_TYPE_BUY) ? open_price + tp1_distance : open_price - tp1_distance;
   const bool tp1_hit = (ptype == POSITION_TYPE_BUY) ? (bid >= tp1_price) : (ask <= tp1_price);
   if(!tp1_hit)
      return;

   double close_lots = g_qm1491_position_initial_lots * strategy_tp1_close_pct / 100.0;
   close_lots = QM_TM_NormalizeVolume(_Symbol, close_lots);
   if(close_lots <= 0.0 || close_lots >= volume)
      return;

   if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
      g_qm1491_tp1_done = true;
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price;
   double volume;
   datetime open_time;
   if(!QM1491_HasOpenPosition(ptype, ticket, open_price, volume, open_time))
      return false;

   if(!g_qm1491_tp1_done && strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int seconds_per_bar = PeriodSeconds(PERIOD_H4);
      if(seconds_per_bar > 0 && (TimeCurrent() - open_time) >= strategy_time_stop_bars * seconds_per_bar)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && g_qm1491_last_cross_direction < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_qm1491_last_cross_direction > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1491\",\"slug\":\"ehlers-sinewave-leadsine-cross-h4\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
