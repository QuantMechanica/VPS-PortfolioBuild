#property strict
#property version   "5.0"
#property description "QM5_13033 Novo CRT H4 range sweep reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13033 - Novo CRT H4 Range-Sweep Reversal
// -----------------------------------------------------------------------------
// M5 execution around the 12:00 broker H4 anchor candle:
//   - record the 12:00-16:00 broker H4 range when it closes
//   - require an indecisive anchor and three prior indecisive H4 bodies
//   - wait for a 16:00-18:30 broker M5 liquidity sweep back inside the range
//   - enter on the codified CISD break in the opposite direction of the sweep
//   - use structural stop beyond the sweep/anchor extreme and TP at mid/full range
// Runtime uses MT5 OHLC/broker calendar only; no external feed, ML, grid, or add-on.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13033;
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
input double strategy_body_max_frac        = 0.50;
input double strategy_prior_body_max_frac  = 0.50;
input int    strategy_anchor_open_hour     = 12;
input int    strategy_sweep_start_minute   = 16 * 60;
input int    strategy_sweep_end_minute     = 18 * 60 + 30;
input int    strategy_trigger_window_min   = 120;
input int    strategy_atr_period_m5        = 14;
input double strategy_sl_buffer_atr        = 0.10;
input int    strategy_tp_mode              = 0;     // 0=opposite anchor side, 1=anchor midpoint
input int    strategy_flatten_minute       = 20 * 60;
input int    strategy_max_spread_points    = 2500;

const int STRATEGY_WAIT_ANCHOR  = 0;
const int STRATEGY_WAIT_SWEEP   = 1;
const int STRATEGY_WAIT_TRIGGER = 2;
const int STRATEGY_DONE         = 3;

int      g_day_key = 0;
int      g_state = STRATEGY_WAIT_ANCHOR;
int      g_sweep_dir = 0;              // +1 long after low sweep, -1 short after high sweep
int      g_last_trade_day_key = 0;
double   g_anchor_high = 0.0;
double   g_anchor_low = 0.0;
double   g_anchor_mid = 0.0;
double   g_sweep_extreme = 0.0;
double   g_cisd_level = 0.0;
datetime g_sweep_time = 0;
datetime g_trigger_expiry = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == "NDX.DWX")
      return 0;
   if(symbol == "XAUUSD.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsSupportedChart()
  {
   const int slot = Strategy_SlotForSymbol(_Symbol);
   return (slot >= 0 && slot == qm_magic_slot_offset && _Period == PERIOD_M5);
  }

int Strategy_DayKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

void Strategy_ResetState(const int day_key)
  {
   g_day_key = day_key;
   g_state = STRATEGY_WAIT_ANCHOR;
   g_sweep_dir = 0;
   g_anchor_high = 0.0;
   g_anchor_low = 0.0;
   g_anchor_mid = 0.0;
   g_sweep_extreme = 0.0;
   g_cisd_level = 0.0;
   g_sweep_time = 0;
   g_trigger_expiry = 0;
  }

void Strategy_ResetIfNewDay(const datetime now)
  {
   const int key = Strategy_DayKey(now);
   if(key > 0 && key != g_day_key)
      Strategy_ResetState(key);
  }

bool Strategy_LoadLastClosedM5(MqlRates &bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, bars) != 1) // perf-allowed: single closed M5 bar behind framework new-bar gate.
      return false;
   bar = bars[0];
   return (bar.time > 0);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(ask < bid)
      return false;

   const double spread_points = (ask - bid) / point;
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_LoadAnchor()
  {
   MqlRates h4[];
   ArraySetAsSeries(h4, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, 4, h4) != 4) // perf-allowed: four H4 bars once per candidate day.
      return false;

   MqlDateTime anchor_dt;
   TimeToStruct(h4[0].time, anchor_dt);
   if(anchor_dt.hour != strategy_anchor_open_hour)
      return false;

   const double range = h4[0].high - h4[0].low;
   if(range <= 0.0)
      return false;

   const double body_frac = MathAbs(h4[0].close - h4[0].open) / range;
   if(body_frac >= strategy_body_max_frac)
     {
      g_state = STRATEGY_DONE;
      return false;
     }

   double prior_sum = 0.0;
   int prior_count = 0;
   for(int i = 1; i <= 3; ++i)
     {
      const double prior_range = h4[i].high - h4[i].low;
      if(prior_range <= 0.0)
         return false;
      prior_sum += MathAbs(h4[i].close - h4[i].open) / prior_range;
      ++prior_count;
     }
   if(prior_count <= 0 || (prior_sum / (double)prior_count) >= strategy_prior_body_max_frac)
     {
      g_state = STRATEGY_DONE;
      return false;
     }

   g_anchor_high = h4[0].high;
   g_anchor_low = h4[0].low;
   g_anchor_mid = 0.5 * (g_anchor_high + g_anchor_low);
   g_state = STRATEGY_WAIT_SWEEP;
   return true;
  }

double Strategy_BearishCISDLevel(const MqlRates &sweep_bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, 36, bars); // perf-allowed: bounded run-open scan after a sweep.
   if(copied <= 0)
      return sweep_bar.low;

   int run_count = 0;
   double min_open = 1.0e100;
   for(int i = 0; i < copied; ++i)
     {
      if(bars[i].close <= bars[i].open)
         break;
      min_open = MathMin(min_open, bars[i].open);
      ++run_count;
     }

   if(run_count <= 1 || min_open >= 1.0e99)
      return sweep_bar.low;
   return min_open;
  }

double Strategy_BullishCISDLevel(const MqlRates &sweep_bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, 36, bars); // perf-allowed: bounded run-open scan after a sweep.
   if(copied <= 0)
      return sweep_bar.high;

   int run_count = 0;
   double max_open = -1.0e100;
   for(int i = 0; i < copied; ++i)
     {
      if(bars[i].close >= bars[i].open)
         break;
      max_open = MathMax(max_open, bars[i].open);
      ++run_count;
     }

   if(run_count <= 1 || max_open <= -1.0e99)
      return sweep_bar.high;
   return max_open;
  }

bool Strategy_DetectSweep(const MqlRates &bar)
  {
   if(g_state != STRATEGY_WAIT_SWEEP)
      return false;

   const int minute = Strategy_MinuteOfDay(bar.time);
   if(minute < strategy_sweep_start_minute)
      return false;
   if(minute > strategy_sweep_end_minute)
     {
      g_state = STRATEGY_DONE;
      return false;
     }

   const bool close_inside = (bar.close >= g_anchor_low && bar.close <= g_anchor_high);
   if(!close_inside)
      return false;

   const bool high_sweep = (bar.high > g_anchor_high);
   const bool low_sweep = (bar.low < g_anchor_low);
   if(high_sweep == low_sweep)
      return false;

   if(high_sweep)
     {
      g_sweep_dir = -1;
      g_sweep_extreme = MathMax(bar.high, g_anchor_high);
      g_cisd_level = Strategy_BearishCISDLevel(bar);
     }
   else
     {
      g_sweep_dir = 1;
      g_sweep_extreme = MathMin(bar.low, g_anchor_low);
      g_cisd_level = Strategy_BullishCISDLevel(bar);
     }

   g_sweep_time = bar.time;
   g_trigger_expiry = g_sweep_time + (datetime)(MathMax(1, strategy_trigger_window_min) * 60);
   g_state = STRATEGY_WAIT_TRIGGER;
   return true;
  }

void Strategy_AdvanceState(const datetime now, const MqlRates &last_bar)
  {
   Strategy_ResetIfNewDay(now);

   const int minute_now = Strategy_MinuteOfDay(now);
   const int anchor_close_minute = strategy_anchor_open_hour * 60 + 240;
   if(g_state == STRATEGY_WAIT_ANCHOR && minute_now >= anchor_close_minute)
      Strategy_LoadAnchor();

   if(g_state == STRATEGY_WAIT_SWEEP)
      Strategy_DetectSweep(last_bar);

   if(g_state == STRATEGY_WAIT_TRIGGER)
     {
      if(last_bar.time > g_trigger_expiry || minute_now >= strategy_flatten_minute)
         g_state = STRATEGY_DONE;
     }
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   if(!Strategy_IsSupportedChart())
      return;

   const int minute_now = Strategy_MinuteOfDay(TimeCurrent());
   if(minute_now < strategy_flatten_minute)
      return;

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
      QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsSupportedChart())
      return true;
   if(strategy_body_max_frac <= 0.0 || strategy_body_max_frac >= 1.0)
      return true;
   if(strategy_prior_body_max_frac <= 0.0 || strategy_prior_body_max_frac >= 1.0)
      return true;
   if(strategy_anchor_open_hour < 0 || strategy_anchor_open_hour > 20)
      return true;
   if(strategy_sweep_start_minute < 0 || strategy_sweep_end_minute <= strategy_sweep_start_minute)
      return true;
   if(strategy_sweep_end_minute > 23 * 60 + 59)
      return true;
   if(strategy_trigger_window_min <= 0)
      return true;
   if(strategy_atr_period_m5 <= 0 || strategy_sl_buffer_atr < 0.0)
      return true;
   if(strategy_tp_mode < 0 || strategy_tp_mode > 1)
      return true;
   if(strategy_flatten_minute <= strategy_sweep_end_minute || strategy_flatten_minute > 23 * 60 + 59)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13033_CRT_SWEEP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   MqlRates last_bar;
   if(!Strategy_LoadLastClosedM5(last_bar))
      return false;

   const datetime now = TimeCurrent();
   Strategy_AdvanceState(now, last_bar);
   const int day_key = Strategy_DayKey(now);
   if(day_key <= 0 || day_key == g_last_trade_day_key)
      return false;
   if(g_state != STRATEGY_WAIT_TRIGGER)
      return false;
   if(last_bar.time <= g_sweep_time)
      return false;
   if(last_bar.time > g_trigger_expiry)
     {
      g_state = STRATEGY_DONE;
      return false;
     }

   if(g_sweep_dir < 0)
     {
      if(last_bar.close >= g_cisd_level)
         return false;
      req.type = QM_SELL;
     }
   else if(g_sweep_dir > 0)
     {
      if(last_bar.close <= g_cisd_level)
         return false;
      req.type = QM_BUY;
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(req.type);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period_m5, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(req.type == QM_SELL)
     {
      req.sl = NormalizeDouble(MathMax(g_sweep_extreme, g_anchor_high) + strategy_sl_buffer_atr * atr, digits);
      req.tp = NormalizeDouble((strategy_tp_mode == 1) ? g_anchor_mid : g_anchor_low, digits);
      if(req.sl <= entry || req.tp >= entry)
         return false;
      req.reason = "CRT_HIGH_SWEEP_CISD_SHORT";
     }
   else
     {
      req.sl = NormalizeDouble(MathMin(g_sweep_extreme, g_anchor_low) - strategy_sl_buffer_atr * atr, digits);
      req.tp = NormalizeDouble((strategy_tp_mode == 1) ? g_anchor_mid : g_anchor_high, digits);
      if(req.sl >= entry || req.tp <= entry)
         return false;
      req.reason = "CRT_LOW_SWEEP_CISD_LONG";
     }

   g_last_trade_day_key = day_key;
   g_state = STRATEGY_DONE;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13033\",\"ea\":\"novo-crt-h4-sweep-reversal\"}");
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
