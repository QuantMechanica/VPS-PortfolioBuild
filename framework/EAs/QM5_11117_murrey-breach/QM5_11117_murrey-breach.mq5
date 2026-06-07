#property strict
#property version   "5.0"
#property description "QM5_11117 Murrey Math Line breach"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11117;
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
input int             strategy_murrey_period          = 64;
input ENUM_TIMEFRAMES strategy_upper_timeframe        = PERIOD_D1;
input int             strategy_step_back              = 0;
input int             strategy_atr_period             = 14;
input double          strategy_atr_stop_cap_mult      = 2.5;
input double          strategy_min_interval_atr_mult  = 0.5;
input int             strategy_max_hold_bars          = 12;

struct MurreyState
  {
   bool   ok;
   double lines[13];
   double interval;
  };

double g_last_entry_level = 0.0;
int    g_last_entry_line = -1;
int    g_last_entry_side = 0;

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int MurreyLookbackBars()
  {
   if(strategy_murrey_period <= 0)
      return 0;

   const int current_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   int upper_seconds = PeriodSeconds(strategy_upper_timeframe);
   if(upper_seconds <= 0)
      upper_seconds = current_seconds;

   int multiplier = 1;
   if(strategy_upper_timeframe != PERIOD_CURRENT &&
      strategy_upper_timeframe != (ENUM_TIMEFRAMES)_Period &&
      current_seconds > 0 &&
      upper_seconds > current_seconds)
      multiplier = (int)MathCeil((double)upper_seconds / (double)current_seconds);

   return strategy_murrey_period * multiplier;
  }

bool CalculateMurreyState(MurreyState &state)
  {
   state.ok = false;
   state.interval = 0.0;
   for(int i = 0; i < 13; ++i)
      state.lines[i] = 0.0;

   const int lookback = MurreyLookbackBars();
   if(lookback <= 0 || strategy_step_back < 0)
      return false;

   const int need = lookback + strategy_step_back + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need, rates) < need) // perf-allowed: Murrey structural window, called from framework new-bar path or bounded exit check.
      return false;

   double lowest = DBL_MAX;
   double highest = -DBL_MAX;
   for(int shift = strategy_step_back; shift < strategy_step_back + lookback; ++shift)
     {
      if(rates[shift].low > 0.0 && rates[shift].low < lowest)
         lowest = rates[shift].low;
      if(rates[shift].high > 0.0 && rates[shift].high > highest)
         highest = rates[shift].high;
     }

   if(lowest == DBL_MAX || highest == -DBL_MAX || highest <= lowest)
      return false;

   double fractal = 0.0;
   if((highest <= 250000.0) && (highest > 25000.0)) fractal = 100000.0;
   else if((highest <= 25000.0) && (highest > 2500.0)) fractal = 10000.0;
   else if((highest <= 2500.0) && (highest > 250.0)) fractal = 1000.0;
   else if((highest <= 250.0) && (highest > 25.0)) fractal = 100.0;
   else if((highest <= 25.0) && (highest > 12.5)) fractal = 12.5;
   else if((highest <= 12.5) && (highest > 6.25)) fractal = 12.5;
   else if((highest <= 6.25) && (highest > 3.125)) fractal = 6.25;
   else if((highest <= 3.125) && (highest > 1.5625)) fractal = 3.125;
   else if((highest <= 1.5625) && (highest > 0.390625)) fractal = 1.5625;
   else if((highest <= 0.390625) && (highest > 0.0)) fractal = 0.1953125;
   if(fractal <= 0.0)
      return false;

   const double range = highest - lowest;
   if(range <= 0.0)
      return false;

   const double octave_power = MathFloor(MathLog(fractal / range) / MathLog(2.0));
   const double octave = fractal * MathPow(0.5, octave_power);
   if(octave <= 0.0)
      return false;

   const double mn = MathFloor(lowest / octave) * octave;
   const double mx = (mn + octave > highest) ? (mn + octave) : (mn + 2.0 * octave);
   const double width = mx - mn;
   if(width <= 0.0)
      return false;

   double x1 = 0.0, x2 = 0.0, x3 = 0.0, x4 = 0.0, x5 = 0.0, x6 = 0.0;
   if((lowest >= (3.0 * width / 16.0 + mn)) && (highest <= (9.0 * width / 16.0 + mn)))
      x2 = mn + width / 2.0;
   if((lowest >= (mn - width / 8.0)) && (highest <= (5.0 * width / 8.0 + mn)) && (x2 == 0.0))
      x1 = mn + width / 2.0;
   if((lowest >= (mn + 7.0 * width / 16.0)) && (highest <= (13.0 * width / 16.0 + mn)))
      x4 = mn + 3.0 * width / 4.0;
   if((lowest >= (mn + 3.0 * width / 8.0)) && (highest <= (9.0 * width / 8.0 + mn)) && (x4 == 0.0))
      x5 = mx;
   if((lowest >= (mn + width / 8.0)) && (highest <= (7.0 * width / 8.0 + mn)) &&
      (x1 == 0.0) && (x2 == 0.0) && (x4 == 0.0) && (x5 == 0.0))
      x3 = mn + 3.0 * width / 4.0;
   if((x1 + x2 + x3 + x4 + x5) == 0.0)
      x6 = mx;

   const double final_high = x1 + x2 + x3 + x4 + x5 + x6;
   double y1 = 0.0, y2 = 0.0, y3 = 0.0, y4 = 0.0, y5 = 0.0, y6 = 0.0;
   if(x1 > 0.0) y1 = mn;
   if(x2 > 0.0) y2 = mn + width / 4.0;
   if(x3 > 0.0) y3 = mn + width / 4.0;
   if(x4 > 0.0) y4 = mn + width / 2.0;
   if(x5 > 0.0) y5 = mn + width / 2.0;
   if((final_high > 0.0) && ((y1 + y2 + y3 + y4 + y5) == 0.0))
      y6 = mn;

   const double final_low = y1 + y2 + y3 + y4 + y5 + y6;
   const double interval = (final_high - final_low) / 8.0;
   if(interval <= 0.0)
      return false;

   state.lines[0] = final_low - interval * 2.0;
   for(int i = 1; i < 13; ++i)
      state.lines[i] = state.lines[i - 1] + interval;

   state.interval = interval;
   state.ok = true;
   return true;
  }

bool FindMurreyBreach(const MurreyState &state, int &side, int &line_index, double &level)
  {
   side = 0;
   line_index = -1;
   level = 0.0;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, 3, bars) < 3) // perf-allowed: source alert rule needs only the last completed candle and prior close.
      return false;

   const double close_last = bars[1].close;
   const double open_last = bars[1].open;
   const double close_prev = bars[2].close;
   if(close_last <= 0.0 || open_last <= 0.0 || close_prev <= 0.0)
      return false;

   for(int i = 2; i <= 10; ++i)
     {
      const double candidate = state.lines[i];
      if(candidate <= 0.0)
         continue;

      if(close_last > candidate && (open_last <= candidate || close_prev <= candidate))
        {
         side = 1;
         line_index = i - 2;
         level = candidate;
         return true;
        }
      if(close_last < candidate && (open_last >= candidate || close_prev >= candidate))
        {
         side = -1;
         line_index = i - 2;
         level = candidate;
         return true;
        }
     }

   return false;
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                       datetime &open_time,
                       string &comment)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      comment = PositionGetString(POSITION_COMMENT);
      return true;
     }

   return false;
  }

double LevelFromPositionComment(const string comment)
  {
   const int at_pos = StringFind(comment, "@");
   if(at_pos < 0)
      return 0.0;
   return StringToDouble(StringSubstr(comment, at_pos + 1));
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   MurreyState state;
   if(!CalculateMurreyState(state))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if(state.interval < atr * strategy_min_interval_atr_mult)
      return false;

   int side = 0;
   int line_index = -1;
   double level = 0.0;
   if(!FindMurreyBreach(state, side, line_index, level))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double stop_distance = MathMin(state.interval, atr * strategy_atr_stop_cap_mult);
   if(stop_distance <= 0.0)
      return false;

   req.type = (side > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = StringFormat("MUR%s%d@%s",
                             (side > 0) ? "UP" : "DN",
                             line_index,
                             DoubleToString(level, _Digits));

   if(req.sl <= 0.0)
      return false;

   g_last_entry_level = level;
   g_last_entry_line = line_index;
   g_last_entry_side = side;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   string comment = "";
   if(!SelectOurPosition(position_type, open_time, comment))
      return false;

   const bool is_long = (position_type == POSITION_TYPE_BUY);
   double entry_level = g_last_entry_level;
   if(entry_level <= 0.0)
      entry_level = LevelFromPositionComment(comment);

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, 3, bars) < 3) // perf-allowed: closed-bar exit checks are O(1) while framework calls this hook per tick.
      return false;

   const double close_last = bars[1].close;
   if(close_last <= 0.0)
      return false;

   if(strategy_max_hold_bars > 0 && open_time > 0)
     {
      const int sec = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(sec > 0 && (bars[1].time - open_time) >= (datetime)(strategy_max_hold_bars * sec))
         return true;
     }

   if(entry_level > 0.0)
     {
      if(is_long && close_last < entry_level)
         return true;
      if(!is_long && close_last > entry_level)
         return true;
     }

   MurreyState state;
   if(!CalculateMurreyState(state))
      return false;

   int side = 0;
   int line_index = -1;
   double level = 0.0;
   if(!FindMurreyBreach(state, side, line_index, level))
      return false;

   if(is_long && side < 0)
      return true;
   if(!is_long && side > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11117_murrey-breach\"}");
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

