#property strict
#property version   "5.0"
#property description "QM5_1624 Ehlers Adaptive Center of Gravity H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1624;
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
input int    strategy_period_min        = 6;
input int    strategy_period_max        = 48;
input int    strategy_autocorr_lookback = 48;
input int    strategy_d1_ema_period     = 200;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 2.0;
input double strategy_spread_atr_mult   = 0.3;
input double strategy_time_stop_mult    = 2.0;

#define STRATEGY_PI                    3.14159265358979323846
#define STRATEGY_MAX_PERIOD            64
#define STRATEGY_MAX_RATE_BARS         512
#define STRATEGY_ACP_AVG_LENGTH        3
#define STRATEGY_ACP_FIRST_DFT_LAG     3
#define STRATEGY_ROOF_HP_PERIOD        48
#define STRATEGY_ROOF_SS_PERIOD        10

QM_ExitReason g_strategy_exit_reason = QM_EXIT_STRATEGY;

datetime g_signal_closed_bar = 0;
bool     g_signal_ready      = false;
int      g_signal_period     = 0;
double   g_signal_cg0        = 0.0;
double   g_signal_cg1        = 0.0;
double   g_signal_cg2        = 0.0;

// Accepted entry state is mirrored in the order comment. The broker-side
// provenance survives terminal/EA restarts and binds both adaptive state rules.
datetime g_last_entry_h4_bar = 0;
int      g_last_entry_dir    = 0;
int      g_last_entry_period = 0;

// Candidate state stays separate so a rejected order cannot consume cooldown.
datetime g_candidate_h4_bar = 0;
int      g_candidate_dir    = 0;
int      g_candidate_period = 0;

bool StrategyInputsValid()
{
   if(qm_ea_id != 1624 || qm_magic_slot_offset < 0)
      return false;
   if(strategy_period_min < 4 || strategy_period_min > STRATEGY_MAX_PERIOD)
      return false;
   if(strategy_period_max < strategy_period_min || strategy_period_max > STRATEGY_MAX_PERIOD)
      return false;
   if(strategy_autocorr_lookback < strategy_period_max ||
      strategy_autocorr_lookback > STRATEGY_MAX_PERIOD)
      return false;
   if(strategy_d1_ema_period < 2 || strategy_atr_period < 2)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_spread_atr_mult <= 0.0 ||
      strategy_time_stop_mult <= 0.0)
      return false;
   return true;
}

bool LoadClosedH4Rates(const int bars_needed, MqlRates &rates[])
{
   if(bars_needed <= 0 || bars_needed > STRATEGY_MAX_RATE_BARS)
      return false;
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates); // perf-allowed: one bounded ACP batch per completed H4 bar.
   ArraySetAsSeries(rates, false);
   return (copied == bars_needed && ArraySize(rates) >= bars_needed);
}

// Ehlers 2013 Autocorrelation-Periodogram, replayed oldest-to-newest:
// 48-bar two-pole high-pass + 10-bar SuperSmoother roofing filter; centered
// Pearson lag correlations; DFT with 0.2 power smoothing and 0.995 AGC decay;
// dominant-cycle center of gravity over normalized power >= 0.5.
int ComputeDominantPeriod(MqlRates &rates[], const int rate_count)
{
   const int min_p = strategy_period_min;
   const int max_p = strategy_period_max;
   const int max_lag = strategy_autocorr_lookback;
   const int first_valid = max_lag + STRATEGY_ACP_AVG_LENGTH - 1;
   if(rate_count <= first_valid || rate_count > STRATEGY_MAX_RATE_BARS ||
      ArraySize(rates) < rate_count)
      return 0;

   double hp[STRATEGY_MAX_RATE_BARS];
   double filt[STRATEGY_MAX_RATE_BARS];
   ArrayInitialize(hp, 0.0);
   ArrayInitialize(filt, 0.0);

   const double hp_angle = 0.707 * 2.0 * STRATEGY_PI / (double)STRATEGY_ROOF_HP_PERIOD;
   const double hp_cos = MathCos(hp_angle);
   if(MathAbs(hp_cos) <= DBL_EPSILON)
      return 0;
   const double alpha1 = (hp_cos + MathSin(hp_angle) - 1.0) / hp_cos;
   const double hp_a = MathPow(1.0 - alpha1 / 2.0, 2.0);
   const double hp_b = 2.0 * (1.0 - alpha1);
   const double hp_c = -MathPow(1.0 - alpha1, 2.0);

   const double ss_a1 = MathExp(-1.414 * STRATEGY_PI / (double)STRATEGY_ROOF_SS_PERIOD);
   const double ss_b1 = 2.0 * ss_a1 * MathCos(1.414 * STRATEGY_PI / (double)STRATEGY_ROOF_SS_PERIOD);
   const double ss_c2 = ss_b1;
   const double ss_c3 = -ss_a1 * ss_a1;
   const double ss_c1 = 1.0 - ss_c2 - ss_c3;

   for(int i = 2; i < rate_count; ++i)
   {
      const double close0 = rates[i].close;
      const double close1 = rates[i - 1].close;
      const double close2 = rates[i - 2].close;
      if(close0 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
         return 0;
      hp[i] = hp_a * (close0 - 2.0 * close1 + close2)
              + hp_b * hp[i - 1] + hp_c * hp[i - 2];
      filt[i] = ss_c1 * (hp[i] + hp[i - 1]) / 2.0
                + ss_c2 * filt[i - 1] + ss_c3 * filt[i - 2];
   }

   double smoothed_power[STRATEGY_MAX_PERIOD + 1];
   ArrayInitialize(smoothed_power, 0.0);
   double max_power = 0.0;
   int last_period = 0;

   for(int end = first_valid; end < rate_count; ++end)
   {
      double corr[STRATEGY_MAX_PERIOD + 1];
      ArrayInitialize(corr, 0.0);
      for(int lag = 0; lag <= max_lag; ++lag)
      {
         double sx = 0.0;
         double sy = 0.0;
         double sxx = 0.0;
         double syy = 0.0;
         double sxy = 0.0;
         for(int count = 0; count < STRATEGY_ACP_AVG_LENGTH; ++count)
         {
            const double x = filt[end - count];
            const double y = filt[end - lag - count];
            sx += x;
            sy += y;
            sxx += x * x;
            syy += y * y;
            sxy += x * y;
         }
         const double m = (double)STRATEGY_ACP_AVG_LENGTH;
         const double var_x = m * sxx - sx * sx;
         const double var_y = m * syy - sy * sy;
         const double denom_sq = var_x * var_y;
         if(denom_sq > DBL_EPSILON)
            corr[lag] = (m * sxy - sx * sy) / MathSqrt(denom_sq);
      }

      for(int period = min_p; period <= max_p; ++period)
      {
         double cosine_part = 0.0;
         double sine_part = 0.0;
         for(int lag = STRATEGY_ACP_FIRST_DFT_LAG; lag <= max_lag; ++lag)
         {
            const double angle = 2.0 * STRATEGY_PI * (double)lag / (double)period;
            cosine_part += corr[lag] * MathCos(angle);
            sine_part += corr[lag] * MathSin(angle);
         }
         const double sq_sum = cosine_part * cosine_part + sine_part * sine_part;
         smoothed_power[period] = 0.2 * sq_sum * sq_sum
                                  + 0.8 * smoothed_power[period];
      }

      max_power *= 0.995;
      for(int period = min_p; period <= max_p; ++period)
         max_power = MathMax(max_power, smoothed_power[period]);
      if(max_power <= DBL_EPSILON)
         continue;

      double weighted_period = 0.0;
      double weight_sum = 0.0;
      for(int period = min_p; period <= max_p; ++period)
      {
         const double normalized_power = smoothed_power[period] / max_power;
         if(normalized_power >= 0.5)
         {
            weighted_period += (double)period * normalized_power;
            weight_sum += normalized_power;
         }
      }
      if(weight_sum > DBL_EPSILON)
         last_period = (int)MathRound(weighted_period / weight_sum);
   }
   return (last_period >= min_p && last_period <= max_p) ? last_period : 0;
}

double ComputeCG(MqlRates &rates[], const int end_index, const int length)
{
   if(length < 2 || end_index < length - 1 || end_index >= ArraySize(rates))
      return 0.0;
   double numerator = 0.0;
   double denominator = 0.0;
   for(int i = 0; i < length; ++i)
   {
      const double price = rates[end_index - i].close;
      numerator += (double)(1 + i) * price;
      denominator += price;
   }
   return (MathAbs(denominator) > DBL_EPSILON) ? numerator / denominator : 0.0;
}

bool RefreshSignalState()
{
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1); // perf-allowed: cached once per completed H4 bar.
   if(closed_bar <= 0)
      return false;
   if(closed_bar == g_signal_closed_bar)
      return g_signal_ready;

   g_signal_closed_bar = closed_bar;
   g_signal_ready = false;
   const int bars_needed = MathMin(STRATEGY_MAX_RATE_BARS,
                                   MathMax(192, 4 * strategy_autocorr_lookback + 32));
   MqlRates h4[];
   if(!LoadClosedH4Rates(bars_needed, h4) || ArraySize(h4) < bars_needed)
      return false;

   const int p = ComputeDominantPeriod(h4, bars_needed);
   const int n = MathMax(3, (int)MathRound((double)p / 2.0));
   if(p <= 0 || n + 2 > bars_needed)
      return false;
   const int last = bars_needed - 1;
   g_signal_cg0 = ComputeCG(h4, last, n);
   g_signal_cg1 = ComputeCG(h4, last - 1, n);
   g_signal_cg2 = ComputeCG(h4, last - 2, n);
   if(g_signal_cg0 <= 0.0 || g_signal_cg1 <= 0.0 || g_signal_cg2 <= 0.0)
      return false;
   g_signal_period = p;
   g_signal_ready = true;
   return true;
}

int SignalCrossDirection()
{
   if(!RefreshSignalState())
      return 0;
   if(g_signal_cg1 <= g_signal_cg2 && g_signal_cg0 > g_signal_cg1)
      return 1;
   if(g_signal_cg1 >= g_signal_cg2 && g_signal_cg0 < g_signal_cg1)
      return -1;
   return 0;
}

bool SpreadAllows(const double atr_value)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid || atr_value <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_atr_mult * atr_value);
}

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

string EntryProvenanceComment(const int direction, const int period, const datetime h4_bar)
{
   return StringFormat("ACG%c:P=%d:B=%I64d", (direction > 0 ? 'L' : 'S'),
                       period, (long)h4_bar);
}

bool ParseEntryProvenance(const string comment, int &direction, int &period, datetime &h4_bar)
{
   direction = 0;
   period = 0;
   h4_bar = 0;
   if(StringLen(comment) < 14 || StringSubstr(comment, 0, 3) != "ACG")
      return false;
   const string side = StringSubstr(comment, 3, 1);
   direction = (side == "L") ? 1 : ((side == "S") ? -1 : 0);
   const int period_pos = StringFind(comment, ":P=");
   const int bar_pos = StringFind(comment, ":B=");
   if(direction == 0 || period_pos < 0 || bar_pos <= period_pos + 3)
      return false;
   period = (int)StringToInteger(StringSubstr(comment, period_pos + 3,
                                              bar_pos - period_pos - 3));
   h4_bar = (datetime)StringToInteger(StringSubstr(comment, bar_pos + 3));
   return (period >= strategy_period_min && period <= strategy_period_max && h4_bar > 0);
}

void CommitAcceptedEntryState()
{
   g_last_entry_h4_bar = g_candidate_h4_bar;
   g_last_entry_dir = g_candidate_dir;
   g_last_entry_period = g_candidate_period;
}

bool RestoreAcceptedEntryState()
{
   g_last_entry_h4_bar = 0;
   g_last_entry_dir = 0;
   g_last_entry_period = 0;

   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(SelectOurPosition(position_ticket, position_type))
   {
      int direction = 0;
      int period = 0;
      datetime h4_bar = 0;
      if(!ParseEntryProvenance(PositionGetString(POSITION_COMMENT), direction, period, h4_bar))
      {
         QM_LogEvent(QM_ERROR, "ENTRY_PROVENANCE_MISSING",
                     StringFormat("{\"ticket\":%I64u}", position_ticket));
         return false;
      }
      if(direction != ((position_type == POSITION_TYPE_BUY) ? 1 : -1))
         return false;
      g_last_entry_h4_bar = h4_bar;
      g_last_entry_dir = direction;
      g_last_entry_period = period;
      return true;
   }

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 30 * 24 * 60 * 60, now))
      return false;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      int direction = 0;
      int period = 0;
      datetime h4_bar = 0;
      if(ParseEntryProvenance(HistoryDealGetString(deal, DEAL_COMMENT),
                              direction, period, h4_bar))
      {
         g_last_entry_h4_bar = h4_bar;
         g_last_entry_dir = direction;
         g_last_entry_period = period;
      }
      break; // newest accepted entry is authoritative, including a legacy untagged one
   }
   return true;
}

int CompletedH4BarsSince(const datetime h4_bar)
{
   if(h4_bar <= 0)
      return -1;
   return iBarShift(_Symbol, PERIOD_H4, h4_bar, false); // perf-allowed: once per completed H4 decision bar.
}

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);
   req.type = QM_BUY;
   req.symbol_slot = qm_magic_slot_offset;
   g_candidate_h4_bar = 0;
   g_candidate_dir = 0;
   g_candidate_period = 0;

   ulong open_ticket = 0;
   ENUM_POSITION_TYPE open_type = POSITION_TYPE_BUY;
   if(SelectOurPosition(open_ticket, open_type))
      return false;

   const int direction = SignalCrossDirection();
   if(direction == 0)
      return false;
   const double d1_ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double d1_ema_prev = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 2, PRICE_CLOSE);
   if(d1_ema_now <= 0.0 || d1_ema_prev <= 0.0)
      return false;
   const double ema_slope = d1_ema_now - d1_ema_prev;
   if((direction > 0 && ema_slope <= 0.0) || (direction < 0 && ema_slope >= 0.0))
      return false;

   const int cooldown_period = (g_last_entry_period > 0)
                               ? g_last_entry_period
                               : g_signal_period;
   const int cooldown_bars = MathMax(3, (int)MathRound((double)cooldown_period / 2.0));
   if(g_last_entry_dir == direction && g_last_entry_h4_bar > 0)
   {
      const int elapsed_bars = CompletedH4BarsSince(g_last_entry_h4_bar);
      if(elapsed_bars >= 0 && elapsed_bars < cooldown_bars)
         return false;
   }

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(!SpreadAllows(atr_value))
      return false;
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.price = 0.0;
   req.expiration_seconds = 0;
   if(req.sl <= 0.0)
      return false;

   g_candidate_h4_bar = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: one candidate provenance tag per completed H4 bar.
   g_candidate_dir = direction;
   g_candidate_period = g_signal_period;
   if(g_candidate_h4_bar <= 0)
      return false;
   req.reason = EntryProvenanceComment(g_candidate_dir, g_candidate_period,
                                       g_candidate_h4_bar);
   return true;
}

void Strategy_ManageOpenPosition()
{
   // Card specifies no break-even, trailing, partial close, or pyramiding.
}

bool Strategy_ExitSignal()
{
   g_strategy_exit_reason = QM_EXIT_STRATEGY;
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
      return false;

   int entry_direction = 0;
   int entry_period = 0;
   datetime entry_h4_bar = 0;
   if(!ParseEntryProvenance(PositionGetString(POSITION_COMMENT), entry_direction,
                            entry_period, entry_h4_bar))
   {
      QM_LogEvent(QM_ERROR, "ENTRY_PROVENANCE_MISSING",
                  StringFormat("{\"ticket\":%I64u}", ticket));
      return false;
   }
   if(entry_direction != ((position_type == POSITION_TYPE_BUY) ? 1 : -1))
      return false;
   const int time_stop_bars = (int)MathCeil(strategy_time_stop_mult * (double)entry_period);
   const int bars_held = CompletedH4BarsSince(entry_h4_bar);
   if(bars_held >= time_stop_bars)
   {
      g_strategy_exit_reason = QM_EXIT_TIME_STOP;
      return true;
   }

   const double d1_ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double d1_ema_prev = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 2, PRICE_CLOSE);
   if(d1_ema_now > 0.0 && d1_ema_prev > 0.0)
   {
      const double ema_slope = d1_ema_now - d1_ema_prev;
      if(position_type == POSITION_TYPE_BUY && ema_slope < 0.0)
         return true;
      if(position_type == POSITION_TYPE_SELL && ema_slope > 0.0)
         return true;
   }

   const int cross_direction = SignalCrossDirection();
   if(position_type == POSITION_TYPE_BUY && cross_direction < 0)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }
   if(position_type == POSITION_TYPE_SELL && cross_direction > 0)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

int OnInit()
{
   if(!StrategyInputsValid())
      return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4, QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_1624 Ehlers Adaptive CG H4"))
      return INIT_FAILED;
   if(!RestoreAcceptedEntryState())
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1624_ehlers-adaptive-cg-h4\"}");
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
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();
   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;
   QM_EquityStreamOnNewBar();

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
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
      }
   }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now) || Strategy_NoTradeFilter())
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         CommitAcceptedEntryState();
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
