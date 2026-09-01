#property strict
#property version   "5.0"
#property description "QM5_41276 EURCHF extreme franc-strength reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: strategy-seeds/cards/approved/QM5_41276_eurchf-franc-rev_card.md
// Source: AI-CODEX-EURCHF-FRANC-REVERSAL-20260901
// =============================================================================

#define STRATEGY_EA_ID          41276
#define STRATEGY_SYMBOL         "EURCHF.DWX"
#define STRATEGY_REQUIRED_BARS  251

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = STRATEGY_EA_ID;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf   = PERIOD_H4;
input int    strategy_z_lookback            = 40;
input double strategy_z_entry               = -2.0;
input double strategy_z_exit                = -0.5;
input int    strategy_range_lookback        = 250;
input double strategy_lower_decile          = 0.10;
input int    strategy_atr_period            = 14;
input double strategy_swing_buffer_atr      = 0.25;
input double strategy_min_stop_atr          = 1.25;
input double strategy_max_stop_atr          = 2.50;
input double strategy_target_atr            = 1.50;
input int    strategy_max_hold_bars         = 18;
input int    strategy_max_spread_points     = 50;
input int    strategy_deviation_points      = 20;

bool     g_strategy_state_ready = false;
bool     g_strategy_entry_ready = false;
bool     g_strategy_exit_ready = false;
bool     g_strategy_closed_this_tick = false;
double   g_strategy_signal_atr = 0.0;
double   g_strategy_signal_low = 0.0;
double   g_strategy_signal_z = 0.0;
datetime g_strategy_signal_time = 0;

bool Strategy_DoubleEquals(const double lhs, const double rhs)
  {
   return (MathAbs(lhs - rhs) <= 1e-10);
  }

bool Strategy_ParametersValid()
  {
   return (qm_ea_id == STRATEGY_EA_ID &&
           qm_magic_slot_offset == 0 &&
           strategy_signal_tf == PERIOD_H4 &&
           strategy_z_lookback == 40 &&
           Strategy_DoubleEquals(strategy_z_entry, -2.0) &&
           Strategy_DoubleEquals(strategy_z_exit, -0.5) &&
           strategy_range_lookback == 250 &&
           Strategy_DoubleEquals(strategy_lower_decile, 0.10) &&
           strategy_atr_period == 14 &&
           Strategy_DoubleEquals(strategy_swing_buffer_atr, 0.25) &&
           Strategy_DoubleEquals(strategy_min_stop_atr, 1.25) &&
           Strategy_DoubleEquals(strategy_max_stop_atr, 2.50) &&
           Strategy_DoubleEquals(strategy_target_atr, 1.50) &&
           strategy_max_hold_bars == 18 &&
           strategy_max_spread_points == 50 &&
           strategy_deviation_points == 20 &&
           Strategy_DoubleEquals(RISK_PERCENT, 0.0) &&
           Strategy_DoubleEquals(RISK_FIXED, 1000.0) &&
           Strategy_DoubleEquals(PORTFOLIO_WEIGHT, 1.0) &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21 &&
           qm_stress_reject_probability >= 0.0 &&
           qm_stress_reject_probability <= 1.0);
  }

bool Strategy_HasOwnedPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_ResetClosedBarState()
  {
   g_strategy_state_ready = false;
   g_strategy_entry_ready = false;
   g_strategy_exit_ready = false;
   g_strategy_signal_atr = 0.0;
   g_strategy_signal_low = 0.0;
   g_strategy_signal_z = 0.0;
   g_strategy_signal_time = 0;
  }

// One bounded bespoke OHLC read advances every closed-bar strategy value.
// CopyRates writes the oldest requested bar at physical index zero, so with
// shifts 1..251 the signal bar C0 is index 250 and C1 is index 249.
bool Strategy_AdvanceClosedBarState()
  {
   Strategy_ResetClosedBarState();

   MqlRates rates[STRATEGY_REQUIRED_BARS];
   const int capacity = ArraySize(rates);
   if(STRATEGY_REQUIRED_BARS > capacity)
      return false;

   const int copied = CopyRates(_Symbol,
                                strategy_signal_tf,
                                1,
                                STRATEGY_REQUIRED_BARS,
                                rates); // perf-allowed: one bounded bespoke H4 close-range scan behind the sole QM_IsNewBar gate.
   if(copied != STRATEGY_REQUIRED_BARS || copied > capacity)
      return false;

   const int signal_index = copied - 1;
   if(signal_index < 0 || signal_index >= ArraySize(rates))
      return false;

   const MqlRates signal_bar = rates[signal_index];
   if(signal_bar.time <= 0 ||
      !MathIsValidNumber(signal_bar.open) || signal_bar.open <= 0.0 ||
      !MathIsValidNumber(signal_bar.low) || signal_bar.low <= 0.0 ||
      !MathIsValidNumber(signal_bar.close) || signal_bar.close <= 0.0)
      return false;

   double reference_sum = 0.0;
   for(int offset = 1; offset <= strategy_z_lookback; ++offset)
     {
      const int index = signal_index - offset;
      if(index < 0 || index >= ArraySize(rates))
         return false;
      const double close_value = rates[index].close;
      if(!MathIsValidNumber(close_value) || close_value <= 0.0)
         return false;
      reference_sum += close_value;
     }

   const double mean = reference_sum / (double)strategy_z_lookback;
   double squared_deviation_sum = 0.0;
   for(int offset = 1; offset <= strategy_z_lookback; ++offset)
     {
      const int index = signal_index - offset;
      if(index < 0 || index >= ArraySize(rates))
         return false;
      const double delta = rates[index].close - mean;
      squared_deviation_sum += delta * delta;
     }

   const double population_sd = MathSqrt(squared_deviation_sum /
                                         (double)strategy_z_lookback);
   if(!MathIsValidNumber(population_sd) || population_sd <= 0.0)
      return false;

   double prior_low = DBL_MAX;
   double prior_high = -DBL_MAX;
   for(int offset = 1; offset <= strategy_range_lookback; ++offset)
     {
      const int index = signal_index - offset;
      if(index < 0 || index >= ArraySize(rates))
         return false;
      const double close_value = rates[index].close;
      if(!MathIsValidNumber(close_value) || close_value <= 0.0)
         return false;
      prior_low = MathMin(prior_low, close_value);
      prior_high = MathMax(prior_high, close_value);
     }
   if(!MathIsValidNumber(prior_low) || !MathIsValidNumber(prior_high) ||
      prior_low <= 0.0 || prior_high <= prior_low)
      return false;

   const int prior_index = signal_index - 1;
   if(prior_index < 0 || prior_index >= ArraySize(rates))
      return false;
   const double prior_close = rates[prior_index].close;
   if(!MathIsValidNumber(prior_close) || prior_close <= 0.0)
      return false;

   const double z_score = (signal_bar.close - mean) / population_sd;
   const double lower_decile = prior_low +
                               strategy_lower_decile * (prior_high - prior_low);
   const double atr = QM_ATR(_Symbol,
                             strategy_signal_tf,
                             strategy_atr_period,
                             1);
   if(!MathIsValidNumber(z_score) ||
      !MathIsValidNumber(lower_decile) || lower_decile <= 0.0 ||
      !MathIsValidNumber(atr) || atr <= 0.0)
      return false;

   const bool bullish_reversal = (signal_bar.close > signal_bar.open &&
                                  signal_bar.close > prior_close);

   g_strategy_signal_atr = atr;
   g_strategy_signal_low = signal_bar.low;
   g_strategy_signal_z = z_score;
   g_strategy_signal_time = signal_bar.time;
   g_strategy_exit_ready = (z_score > strategy_z_exit);
   g_strategy_entry_ready = (z_score < strategy_z_entry &&
                             signal_bar.close <= lower_decile &&
                             bullish_reversal);
   g_strategy_state_ready = true;
   return true;
  }

// Cheap identity guard only. Quote and spread admission belongs to entry so
// it cannot suppress time, strategy, Friday, or kill-switch exits.
bool Strategy_NoTradeFilter()
  {
   return (_Symbol != STRATEGY_SYMBOL ||
           (ENUM_TIMEFRAMES)_Period != strategy_signal_tf);
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

   if(!g_strategy_state_ready || !g_strategy_entry_ready ||
      g_strategy_closed_this_tick || Strategy_HasOwnedPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(!MathIsValidNumber(ask) || !MathIsValidNumber(bid) ||
      !MathIsValidNumber(point) || ask <= 0.0 || bid <= 0.0 ||
      point <= 0.0 || ask < bid)
      return false;

   const double spread_points = (ask - bid) / point;
   if(!MathIsValidNumber(spread_points) || spread_points < 0.0 ||
      (spread_points > 0.0 && spread_points > strategy_max_spread_points))
      return false;

   const double structural_stop = g_strategy_signal_low -
                                  strategy_swing_buffer_atr * g_strategy_signal_atr;
   const double structural_distance = ask - structural_stop;
   const double minimum_distance = strategy_min_stop_atr * g_strategy_signal_atr;
   const double stop_distance = MathMax(structural_distance, minimum_distance);
   const double maximum_distance = strategy_max_stop_atr * g_strategy_signal_atr;
   if(!MathIsValidNumber(structural_stop) || structural_stop <= 0.0 ||
      !MathIsValidNumber(stop_distance) || stop_distance <= 0.0 ||
      !MathIsValidNumber(maximum_distance) || maximum_distance <= 0.0 ||
      stop_distance > maximum_distance)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, ask - stop_distance);
   const double tp = QM_StopRulesNormalizePrice(_Symbol,
                                                ask + strategy_target_atr *
                                                      g_strategy_signal_atr);
   if(!MathIsValidNumber(sl) || !MathIsValidNumber(tp) ||
      sl <= 0.0 || sl >= ask || tp <= ask)
      return false;

   const double sl_points = (ask - sl) / point;
   const double tp_points = (tp - ask) / point;
   const int broker_stops_level =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(!MathIsValidNumber(sl_points) || !MathIsValidNumber(tp_points) ||
      sl_points <= 0.0 || tp_points <= 0.0 ||
      (broker_stops_level > 0 &&
       (sl_points < broker_stops_level || tp_points < broker_stops_level)))
      return false;

   const double risk_lots = QM_LotsForRisk(_Symbol, sl_points);
   if(!MathIsValidNumber(risk_lots) || risk_lots <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "EURCHF_FRANC_STRENGTH_REVERSAL_LONG";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

// The only active per-tick management rule is the elapsed eighteen-H4-bar
// time stop. No trail, break-even, partial close, or scale-in is permitted.
void Strategy_ManageOpenPosition()
  {
   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   const int magic = QM_FrameworkMagic();
   if(seconds_per_bar <= 0 || strategy_max_hold_bars <= 0 || magic <= 0)
      return;

   const long max_hold_seconds = (long)strategy_max_hold_bars * seconds_per_bar;
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0 || now < opened || (long)(now - opened) < max_hold_seconds)
         continue;
      if(QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP))
         g_strategy_closed_this_tick = true;
     }
  }

bool Strategy_ExitSignal()
  {
   return (g_strategy_state_ready &&
           g_strategy_exit_ready &&
           Strategy_HasOwnedPosition());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(_Symbol != STRATEGY_SYMBOL ||
      (ENUM_TIMEFRAMES)_Period != PERIOD_H4 ||
      !Strategy_ParametersValid())
      return INIT_PARAMETERS_INCORRECT;

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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     strategy_deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"strategy\":\"eurchf_franc_strength_reversal\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   g_strategy_closed_this_tick = false;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // This is the sole strategy new-bar gate. It advances cached entry and exit
   // state before open-position management, while all exits remain news-agnostic.
   const bool strategy_new_bar = QM_IsNewBar(_Symbol, strategy_signal_tf);
   if(strategy_new_bar)
      Strategy_AdvanceClosedBarState();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            g_strategy_closed_this_tick = true;
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !strategy_new_bar)
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
