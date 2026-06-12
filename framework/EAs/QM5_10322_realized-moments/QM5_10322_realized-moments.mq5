#property strict
#property version   "5.0"
#property description "QM5_10322 Weekly Realized Moments Cross-Section"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10322 realized-moments
// -----------------------------------------------------------------------------
// Mechanical build from approved card:
// D:\QM\strategy_farm\artifacts\cards_approved\QM5_10322_realized-moments.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10322;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_moment_tf       = PERIOD_H1;
input int    strategy_moment_bars              = 120;
input int    strategy_min_intraday_bars        = 40;
input double strategy_vol_z_coef               = 0.50;
input double strategy_median_score_buffer_sd   = 0.50;
input double strategy_quantile_frac            = 0.25;
input ENUM_TIMEFRAMES strategy_stop_tf         = PERIOD_D1;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 1.25;
input int    strategy_entry_day_of_week        = 1;
input int    strategy_entry_hour_broker        = 0;
input int    strategy_entry_window_hours       = 4;
input int    strategy_exit_day_of_week         = 5;
input int    strategy_exit_hour_broker         = 20;
input int    strategy_max_hold_days            = 7;
input int    strategy_spread_min_samples       = 20;
input double strategy_spread_percentile        = 80.0;

#define STRATEGY_SYMBOL_COUNT 11

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "WS30.DWX",
   "NDX.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "USDCHF.DWX",
   "USDCAD.DWX",
   "AUDUSD.DWX",
   "NZDUSD.DWX"
  };

struct StrategyMomentScore
  {
   string symbol;
   int    slot;
   bool   valid;
   double realized_vol;
   double realized_skew;
   double realized_kurt;
   double composite;
  };

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(g_strategy_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;

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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_InEntryWindow(const datetime now)
  {
   if(Strategy_DayOfWeek(now) != strategy_entry_day_of_week)
      return false;

   const int hour = Strategy_Hour(now);
   const int start_hour = MathMax(0, MathMin(23, strategy_entry_hour_broker));
   const int window = MathMax(1, strategy_entry_window_hours);
   return (hour >= start_hour && hour < start_hour + window);
  }

bool Strategy_IsWeeklyExitTime(const datetime now)
  {
   if(Strategy_DayOfWeek(now) != strategy_exit_day_of_week)
      return false;
   return (Strategy_Hour(now) >= strategy_exit_hour_broker);
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double Strategy_StdDev(const double &values[], const int count, const double mean)
  {
   if(count < 2)
      return 0.0;

   double sum_sq = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = values[i] - mean;
      sum_sq += d * d;
     }
   return MathSqrt(sum_sq / (double)(count - 1));
  }

bool Strategy_SpreadAllowedFromRates(const MqlRates &rates[], const int copied)
  {
   if(copied <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
         spreads[count++] = (double)rates[i].spread;
     }

   const int min_samples = MathMax(1, strategy_spread_min_samples);
   if(count < min_samples)
      return false;

   const double current_spread = (double)rates[0].spread;
   if(current_spread <= 0.0)
      return false;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double pct = MathMax(0.0, MathMin(100.0, strategy_spread_percentile));
   int idx = (int)MathFloor((pct / 100.0) * (double)(count - 1));
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;
   return (current_spread <= spreads[idx]);
  }

bool Strategy_ReadMoments(const string symbol,
                          const int slot,
                          StrategyMomentScore &out_score)
  {
   out_score.symbol = symbol;
   out_score.slot = slot;
   out_score.valid = false;
   out_score.realized_vol = 0.0;
   out_score.realized_skew = 0.0;
   out_score.realized_kurt = 0.0;
   out_score.composite = 0.0;

   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int bars_needed = MathMax(strategy_min_intraday_bars + 1, strategy_moment_bars + 1);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke realized-vol/skew/kurt math, called only from the framework closed-bar entry path and weekly entry window.
   const int copied = CopyRates(symbol, strategy_moment_tf, 1, bars_needed, rates);
   if(copied < strategy_min_intraday_bars + 1)
      return false;
   if(!Strategy_SpreadAllowedFromRates(rates, copied))
      return false;

   const int ret_count = copied - 1;
   if(ret_count < strategy_min_intraday_bars)
      return false;

   double returns[];
   ArrayResize(returns, ret_count);
   double mean = 0.0;
   int count = 0;
   for(int i = 0; i < ret_count; ++i)
     {
      if(rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         return false;
      const double r = MathLog(rates[i].close / rates[i + 1].close);
      returns[count++] = r;
      mean += r;
     }

   if(count < strategy_min_intraday_bars)
      return false;
   mean /= (double)count;

   double m2 = 0.0;
   double m3 = 0.0;
   double m4 = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = returns[i] - mean;
      const double d2 = d * d;
      m2 += d2;
      m3 += d2 * d;
      m4 += d2 * d2;
     }

   m2 /= (double)count;
   m3 /= (double)count;
   m4 /= (double)count;

   const double sd = MathSqrt(m2);
   if(sd <= 0.0 || m2 <= 0.0)
      return false;

   out_score.realized_vol = sd * MathSqrt((double)count);
   out_score.realized_skew = m3 / MathPow(sd, 3.0);
   out_score.realized_kurt = m4 / (m2 * m2);
   out_score.valid = true;
   return true;
  }

bool Strategy_BuildCrossSection(StrategyMomentScore &scores[], int &valid_count)
  {
   valid_count = 0;
   ArrayResize(scores, STRATEGY_SYMBOL_COUNT);

   double vols[];
   double skews[];
   double kurts[];
   ArrayResize(vols, STRATEGY_SYMBOL_COUNT);
   ArrayResize(skews, STRATEGY_SYMBOL_COUNT);
   ArrayResize(kurts, STRATEGY_SYMBOL_COUNT);

   double vol_sum = 0.0;
   double skew_sum = 0.0;
   double kurt_sum = 0.0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      StrategyMomentScore s;
      if(!Strategy_ReadMoments(g_strategy_symbols[i], i, s))
         continue;

      scores[valid_count] = s;
      vols[valid_count] = s.realized_vol;
      skews[valid_count] = s.realized_skew;
      kurts[valid_count] = s.realized_kurt;
      vol_sum += s.realized_vol;
      skew_sum += s.realized_skew;
      kurt_sum += s.realized_kurt;
      valid_count++;
     }

   const int min_valid = MathMax(4, (int)MathCeil((double)STRATEGY_SYMBOL_COUNT * 0.50));
   if(valid_count < min_valid)
      return false;

   ArrayResize(scores, valid_count);
   ArrayResize(vols, valid_count);
   ArrayResize(skews, valid_count);
   ArrayResize(kurts, valid_count);

   const double vol_mean = vol_sum / (double)valid_count;
   const double skew_mean = skew_sum / (double)valid_count;
   const double kurt_mean = kurt_sum / (double)valid_count;
   const double vol_sd = Strategy_StdDev(vols, valid_count, vol_mean);
   const double skew_sd = Strategy_StdDev(skews, valid_count, skew_mean);
   const double kurt_sd = Strategy_StdDev(kurts, valid_count, kurt_mean);
   if(vol_sd <= 0.0 || skew_sd <= 0.0 || kurt_sd <= 0.0)
      return false;

   for(int i = 0; i < valid_count; ++i)
     {
      const double z_vol = (scores[i].realized_vol - vol_mean) / vol_sd;
      const double z_skew = (scores[i].realized_skew - skew_mean) / skew_sd;
      const double z_kurt = (scores[i].realized_kurt - kurt_mean) / kurt_sd;
      scores[i].composite = z_skew + z_kurt + strategy_vol_z_coef * z_vol;
     }

   return true;
  }

int Strategy_RankAbove(const StrategyMomentScore &scores[], const int count, const double score)
  {
   int above = 0;
   for(int i = 0; i < count; ++i)
      if(scores[i].composite > score)
         above++;
   return above;
  }

int Strategy_RankBelow(const StrategyMomentScore &scores[], const int count, const double score)
  {
   int below = 0;
   for(int i = 0; i < count; ++i)
      if(scores[i].composite < score)
         below++;
   return below;
  }

bool Strategy_CurrentSymbolSignal(int &side, double &symbol_score, double &median_score, double &score_sd)
  {
   side = 0;
   symbol_score = 0.0;
   median_score = 0.0;
   score_sd = 0.0;

   const int slot = Strategy_SymbolSlot(_Symbol);
   if(slot < 0 || qm_magic_slot_offset != slot)
      return false;

   StrategyMomentScore scores[];
   int valid_count = 0;
   if(!Strategy_BuildCrossSection(scores, valid_count))
      return false;

   int current_idx = -1;
   double composites[];
   ArrayResize(composites, valid_count);
   double score_sum = 0.0;
   for(int i = 0; i < valid_count; ++i)
     {
      composites[i] = scores[i].composite;
      score_sum += scores[i].composite;
      if(scores[i].symbol == _Symbol)
         current_idx = i;
     }

   if(current_idx < 0)
      return false;

   median_score = Strategy_Median(composites, valid_count);
   score_sd = Strategy_StdDev(composites, valid_count, score_sum / (double)valid_count);
   if(score_sd <= 0.0)
      return false;

   symbol_score = scores[current_idx].composite;
   const int bucket = MathMax(1, MathMin(valid_count / 2, (int)MathCeil((double)valid_count * strategy_quantile_frac)));
   const double upper_trigger = median_score + strategy_median_score_buffer_sd * score_sd;
   const double lower_trigger = median_score - strategy_median_score_buffer_sd * score_sd;

   if(Strategy_RankAbove(scores, valid_count, symbol_score) < bucket && symbol_score >= upper_trigger)
     {
      side = 1;
      return true;
     }
   if(Strategy_RankBelow(scores, valid_count, symbol_score) < bucket && symbol_score <= lower_trigger)
     {
      side = -1;
      return true;
     }

   return false;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_SymbolSlot(_Symbol) < 0)
      return true;

   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_HasOpenPosition(ticket, open_time))
      return false;

   return !Strategy_InEntryWindow(TimeCurrent());
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_moment_tf)
      return false;

   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_HasOpenPosition(ticket, open_time))
      return false;

   int side = 0;
   double symbol_score = 0.0;
   double median_score = 0.0;
   double score_sd = 0.0;
   if(!Strategy_CurrentSymbolSignal(side, symbol_score, median_score, score_sd))
      return false;

   const QM_OrderType order_type = (side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_stop_tf, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.reason = StringFormat("realized_moments_%s score=%.4f median=%.4f sd=%.4f",
                             (side > 0) ? "long" : "short",
                             symbol_score,
                             median_score,
                             score_sd);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies one position per magic per symbol, with no trailing,
   // break-even, partial close, averaging, or grid logic.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime open_time = 0;
   if(!Strategy_HasOpenPosition(ticket, open_time))
      return false;

   const datetime now = TimeCurrent();
   if(Strategy_IsWeeklyExitTime(now))
      return true;

   if(open_time > 0 && strategy_max_hold_days > 0)
     {
      const int max_hold_seconds = strategy_max_hold_days * 86400;
      if((int)(now - open_time) >= max_hold_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, strategy_moment_tf, MathMax(200, strategy_moment_bars + 50));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10322_realized-moments\"}");
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
