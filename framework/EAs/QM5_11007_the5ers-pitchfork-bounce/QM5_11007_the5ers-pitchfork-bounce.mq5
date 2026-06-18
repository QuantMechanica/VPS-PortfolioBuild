#property strict
#property version   "5.0"
#property description "QM5_11007 The5ers Andrews Pitchfork Median Bounce"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11007;
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
input int    strategy_swing_width       = 3;
input int    strategy_atr_period        = 14;
input double strategy_touch_atr_mult    = 0.25;
input double strategy_reject_wick_ratio = 0.50;
input double strategy_rsi_long_max      = 35.0;
input double strategy_rsi_short_min     = 65.0;
input double strategy_stop_atr_mult     = 0.50;
input double strategy_min_spacing_atr   = 2.0;
input double strategy_min_target_rr     = 1.0;
input double strategy_max_target_rr     = 2.5;
input int    strategy_min_a_bars        = 30;
input int    strategy_pitchfork_expiry  = 120;
input int    strategy_time_stop_bars    = 24;
input int    strategy_scan_bars         = 180;
input int    strategy_max_spread_points = 0;

struct SwingPoint
  {
   int    type;
   int    shift;
   double price;
  };

struct PitchforkSetup
  {
   bool   valid;
   int    direction;
   int    a_shift;
   int    b_shift;
   int    c_shift;
   double slope;
   double median_intercept;
   double lower_intercept;
   double upper_intercept;
  };

int      g_active_direction = 0;
datetime g_active_entry_bar_time = 0;
double   g_active_outer_slope = 0.0;
double   g_active_outer_intercept = 0.0;

double PfLineAt(const double slope, const double intercept, const double x)
  {
   return slope * x + intercept;
  }

void ResetActivePitchfork()
  {
   g_active_direction = 0;
   g_active_entry_bar_time = 0;
   g_active_outer_slope = 0.0;
   g_active_outer_intercept = 0.0;
  }

bool IsSwingLow(const int shift, const int width)
  {
   const double candidate = iLow(_Symbol, _Period, shift); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
   if(candidate <= 0.0)
      return false;

   for(int i = 1; i <= width; ++i)
     {
      const double newer = iLow(_Symbol, _Period, shift - i); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
      const double older = iLow(_Symbol, _Period, shift + i); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(candidate >= newer || candidate >= older)
         return false;
     }

   return true;
  }

bool IsSwingHigh(const int shift, const int width)
  {
   const double candidate = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
   if(candidate <= 0.0)
      return false;

   for(int i = 1; i <= width; ++i)
     {
      const double newer = iHigh(_Symbol, _Period, shift - i); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
      const double older = iHigh(_Symbol, _Period, shift + i); // perf-allowed: bounded pitchfork fractal scan inside closed-bar strategy hook.
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(candidate <= newer || candidate <= older)
         return false;
     }

   return true;
  }

bool BuildPitchforkFromTriplet(const SwingPoint &a,
                               const SwingPoint &b,
                               const SwingPoint &c,
                               const int direction,
                               PitchforkSetup &setup)
  {
   setup.valid = false;
   setup.direction = direction;
   setup.a_shift = a.shift;
   setup.b_shift = b.shift;
   setup.c_shift = c.shift;

   if(a.shift < strategy_min_a_bars)
      return false;
   if(c.shift > strategy_pitchfork_expiry)
      return false;

   const double x_a = -(double)a.shift;
   const double x_b = -(double)b.shift;
   const double x_c = -(double)c.shift;
   const double mid_x = (x_b + x_c) * 0.5;
   const double mid_y = (b.price + c.price) * 0.5;
   const double denom = mid_x - x_a;
   if(MathAbs(denom) < 0.0000001)
      return false;

   setup.slope = (mid_y - a.price) / denom;
   setup.median_intercept = a.price - setup.slope * x_a;

   const double b_intercept = b.price - setup.slope * x_b;
   const double c_intercept = c.price - setup.slope * x_c;
   if(direction > 0)
     {
      setup.upper_intercept = b_intercept;
      setup.lower_intercept = c_intercept;
     }
   else
     {
      setup.lower_intercept = b_intercept;
      setup.upper_intercept = c_intercept;
     }

   setup.valid = true;
   return true;
  }

bool FindPitchfork(const int direction, PitchforkSetup &setup)
  {
   setup.valid = false;
   const int width = MathMax(1, strategy_swing_width);
   const int min_shift = width + 1;
   const int max_shift = MathMax(strategy_scan_bars, strategy_min_a_bars + width + 5);

   SwingPoint swings[128];
   int swing_count = 0;

   for(int shift = max_shift; shift >= min_shift && swing_count < 128; --shift)
     {
      const bool is_low = IsSwingLow(shift, width);
      const bool is_high = IsSwingHigh(shift, width);
      if(is_low == is_high)
         continue;

      swings[swing_count].type = is_low ? -1 : 1;
      swings[swing_count].shift = shift;
      swings[swing_count].price = is_low
                                  ? iLow(_Symbol, _Period, shift)   // perf-allowed: structural pitchfork anchor price.
                                  : iHigh(_Symbol, _Period, shift); // perf-allowed: structural pitchfork anchor price.
      swing_count++;
     }

   bool found = false;
   PitchforkSetup latest;
   latest.valid = false;

   for(int i = 0; i <= swing_count - 3; ++i)
     {
      const SwingPoint a = swings[i];
      const SwingPoint b = swings[i + 1];
      const SwingPoint c = swings[i + 2];

      if(direction > 0)
        {
         if(a.type != -1 || b.type != 1 || c.type != -1)
            continue;
         if(c.price <= a.price)
            continue;
        }
      else
        {
         if(a.type != 1 || b.type != -1 || c.type != 1)
            continue;
         if(c.price >= a.price)
            continue;
        }

      PitchforkSetup candidate;
      if(BuildPitchforkFromTriplet(a, b, c, direction, candidate))
        {
         latest = candidate;
         found = true;
        }
     }

   if(!found)
      return false;

   setup = latest;
   return true;
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &position_type,
                       datetime &position_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, 14, 1, PRICE_CLOSE);
   if(atr <= 0.0 || rsi <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: candle rejection geometry for pitchfork entry.
   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: candle rejection geometry for pitchfork entry.
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: candle rejection geometry for pitchfork entry.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: candle rejection geometry for pitchfork entry.
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high1 <= low1)
      return false;

   const double range = high1 - low1;
   const double lower_wick = MathMin(open1, close1) - low1;
   const double upper_wick = high1 - MathMax(open1, close1);
   const double touch_tolerance = strategy_touch_atr_mult * atr;
   const double spacing_min = strategy_min_spacing_atr * atr;

   PitchforkSetup bullish;
   if(FindPitchfork(1, bullish))
     {
      const double lower_line1 = PfLineAt(bullish.slope, bullish.lower_intercept, -1.0);
      const double upper_line1 = PfLineAt(bullish.slope, bullish.upper_intercept, -1.0);
      const double median_now = PfLineAt(bullish.slope, bullish.median_intercept, 0.0);
      const double spacing = MathAbs(upper_line1 - lower_line1);

      if(spacing >= spacing_min &&
         low1 <= lower_line1 + touch_tolerance &&
         close1 > lower_line1 &&
         lower_wick >= range * strategy_reject_wick_ratio &&
         rsi < strategy_rsi_long_max)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double entry = (ask > 0.0) ? ask : close1;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, low1 - strategy_stop_atr_mult * atr);
         const double risk = entry - sl;
         const double median_distance = median_now - entry;
         if(sl > 0.0 && risk > 0.0 && median_distance >= risk * strategy_min_target_rr)
           {
            const double max_tp = entry + risk * strategy_max_target_rr;
            const double tp = QM_StopRulesNormalizePrice(_Symbol, MathMin(median_now, max_tp));
            if(tp > entry)
              {
               req.type = QM_BUY;
               req.price = 0.0;
               req.sl = sl;
               req.tp = tp;
               req.reason = "PITCHFORK_LOWER_BOUNCE_LONG";
               req.symbol_slot = qm_magic_slot_offset;
               g_active_direction = 1;
               g_active_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: store entry bar for fixed pitchfork exit projection.
               g_active_outer_slope = bullish.slope;
               g_active_outer_intercept = bullish.lower_intercept;
               return true;
              }
           }
        }
     }

   PitchforkSetup bearish;
   if(FindPitchfork(-1, bearish))
     {
      const double lower_line1 = PfLineAt(bearish.slope, bearish.lower_intercept, -1.0);
      const double upper_line1 = PfLineAt(bearish.slope, bearish.upper_intercept, -1.0);
      const double median_now = PfLineAt(bearish.slope, bearish.median_intercept, 0.0);
      const double spacing = MathAbs(upper_line1 - lower_line1);

      if(spacing >= spacing_min &&
         high1 >= upper_line1 - touch_tolerance &&
         close1 < upper_line1 &&
         upper_wick >= range * strategy_reject_wick_ratio &&
         rsi > strategy_rsi_short_min)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double entry = (bid > 0.0) ? bid : close1;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, high1 + strategy_stop_atr_mult * atr);
         const double risk = sl - entry;
         const double median_distance = entry - median_now;
         if(sl > 0.0 && risk > 0.0 && median_distance >= risk * strategy_min_target_rr)
           {
            const double min_tp = entry - risk * strategy_max_target_rr;
            const double tp = QM_StopRulesNormalizePrice(_Symbol, MathMax(median_now, min_tp));
            if(tp > 0.0 && tp < entry)
              {
               req.type = QM_SELL;
               req.price = 0.0;
               req.sl = sl;
               req.tp = tp;
               req.reason = "PITCHFORK_UPPER_BOUNCE_SHORT";
               req.symbol_slot = qm_magic_slot_offset;
               g_active_direction = -1;
               g_active_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: store entry bar for fixed pitchfork exit projection.
               g_active_outer_slope = bearish.slope;
               g_active_outer_intercept = bearish.upper_intercept;
               return true;
              }
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      ResetActivePitchfork();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime position_time = 0;
   if(!SelectOurPosition(ticket, position_type, position_time))
      return false;

   int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      period_seconds = 14400;

   if(strategy_time_stop_bars > 0 && position_time > 0)
     {
      const int held_seconds = (int)(TimeCurrent() - position_time);
      if(held_seconds >= strategy_time_stop_bars * period_seconds)
         return true;
     }

   if(g_active_direction == 0 || g_active_entry_bar_time <= 0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const datetime closed_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: O(1) closed-bar exit projection, no custom new-bar gate.
   const double close1 = iClose(_Symbol, _Period, 1);           // perf-allowed: O(1) closed-bar exit signal from card.
   if(atr <= 0.0 || closed_bar_time <= 0 || close1 <= 0.0)
      return false;

   const double bars_from_entry = (double)(closed_bar_time - g_active_entry_bar_time) / (double)period_seconds;
   const double outer_line = PfLineAt(g_active_outer_slope, g_active_outer_intercept, bars_from_entry);
   const double tolerance = strategy_touch_atr_mult * atr;

   if(position_type == POSITION_TYPE_BUY && close1 < outer_line - tolerance)
      return true;
   if(position_type == POSITION_TYPE_SELL && close1 > outer_line + tolerance)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11007\",\"strategy\":\"the5ers-pitchfork-bounce\"}");
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
