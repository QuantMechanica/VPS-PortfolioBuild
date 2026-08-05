#property strict
#property version   "5.0"
#property description "QM5_10025 Robot Wealth FX Broad Pairs"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10025;
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
input int    strategy_formation_bars     = 252;
input int    strategy_zscore_bars        = 120;
input double strategy_min_corr           = 0.70;
input double strategy_adf_t_max          = -1.30;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 0.0;
input double strategy_spread_stop_z      = 3.0;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input int    strategy_time_stop_bars     = 15;
input double strategy_min_improve_frac   = 0.25;
input int    strategy_max_spread_points  = 50;

#define STRATEGY_SYMBOL_COUNT 7
string g_symbols[STRATEGY_SYMBOL_COUNT] = {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDCHF.DWX", "USDCAD.DWX", "USDJPY.DWX"
};
int g_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

int     g_selected_partner = -1;
double  g_selected_beta = 1.0;
int     g_selected_month_key = -1;
double  g_current_z = 0.0;
double  g_current_sigma = 0.0;
double  g_entry_abs_z = 0.0;
datetime g_entry_bar_time = 0;
bool    g_state_ready = false;

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(symbol == g_symbols[i])
         return i;
     }
   return -1;
  }

bool Strategy_FinalH4BeforeWeekend(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= 17);
  }

bool Strategy_SpreadsNormal()
  {
   const int host_index = Strategy_SymbolIndex(_Symbol);
   if(host_index < 0 || g_selected_partner < 0)
      return false;

   const long host_spread = SymbolInfoInteger(g_symbols[host_index], SYMBOL_SPREAD);
   const long partner_spread = SymbolInfoInteger(g_symbols[g_selected_partner], SYMBOL_SPREAD);
   if(strategy_max_spread_points <= 0)
      return true;
   return (host_spread <= strategy_max_spread_points &&
           partner_spread <= strategy_max_spread_points);
  }

bool Strategy_ReadLogs(const string sym_a,
                        const string sym_b,
                       const int bars,
                       double &log_a[],
                       double &log_b[])
  {
   if(bars < 3)
      return false;
   if(!QM_SymbolAssertOrLog(sym_a) || !QM_SymbolAssertOrLog(sym_b))
      return false;

   double closes_a[];
   double closes_b[];
   ArraySetAsSeries(closes_a, true);
   ArraySetAsSeries(closes_b, true);
   ArraySetAsSeries(log_a, true);
   ArraySetAsSeries(log_b, true);

   if(CopyClose(sym_a, PERIOD_H4, 1, bars, closes_a) != bars) // perf-allowed: bespoke pair window, H4-gated in OnTick
      return false;
   if(CopyClose(sym_b, PERIOD_H4, 1, bars, closes_b) != bars) // perf-allowed: bespoke pair window, H4-gated in OnTick
      return false;

   ArrayResize(log_a, bars);
   ArrayResize(log_b, bars);
   for(int i = 0; i < bars; ++i)
     {
      if(closes_a[i] <= 0.0 || closes_b[i] <= 0.0)
         return false;
      log_a[i] = MathLog(closes_a[i]);
      log_b[i] = MathLog(closes_b[i]);
      if(!MathIsValidNumber(log_a[i]) || !MathIsValidNumber(log_b[i]))
         return false;
     }
   return true;
  }

bool Strategy_EstimateOLS(const double &y[],
                          const double &x[],
                          const int bars,
                          double &beta)
  {
   beta = 1.0;
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
     }

   const double n = (double)bars;
   const double denom = n * sxx - sx * sx;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   beta = (n * sxy - sx * sy) / denom;
   return (MathIsValidNumber(beta) && MathAbs(beta) > 0.01 && MathAbs(beta) < 20.0);
  }

bool Strategy_Correlation(const double &a[],
                          const double &b[],
                          const int bars,
                          double &corr)
  {
   corr = 0.0;
   double sa = 0.0, sb = 0.0, saa = 0.0, sbb = 0.0, sab = 0.0;
   int n = 0;
   for(int i = 0; i < bars - 1; ++i)
     {
      const double ra = a[i] - a[i + 1];
      const double rb = b[i] - b[i + 1];
      sa += ra;
      sb += rb;
      saa += ra * ra;
      sbb += rb * rb;
      sab += ra * rb;
      ++n;
     }

   const double denom = MathSqrt(((double)n * saa - sa * sa) * ((double)n * sbb - sb * sb));
   if(denom <= DBL_EPSILON)
      return false;

   corr = ((double)n * sab - sa * sb) / denom;
   return MathIsValidNumber(corr);
  }

bool Strategy_ADFProxy(const double &spread[],
                       const int bars,
                       double &t_stat)
  {
   t_stat = 0.0;
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   int n = 0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = spread[i + 1];
      const double delta = spread[i] - spread[i + 1];
      sx += lagged;
      sy += delta;
      sxx += lagged * lagged;
      sxy += lagged * delta;
      ++n;
     }

   const double denom = sxx - sx * sx / (double)n;
   if(denom <= DBL_EPSILON)
      return false;

   const double beta = (sxy - sx * sy / (double)n) / denom;
   double rss = 0.0;
   const double alpha = (sy - beta * sx) / (double)n;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = spread[i + 1];
      const double delta = spread[i] - spread[i + 1];
      const double err = delta - alpha - beta * lagged;
      rss += err * err;
     }

   const double se = MathSqrt((rss / MathMax(1, n - 2)) / denom);
   if(se <= 0.0)
      return false;

   t_stat = beta / se;
   return MathIsValidNumber(t_stat);
  }

bool Strategy_SpreadStats(const int host_index,
                          const int partner_index,
                          const bool full_formation,
                          double &beta,
                          double &corr,
                          double &adf_t,
                          double &z,
                          double &sigma)
  {
   beta = 1.0;
   corr = 0.0;
   adf_t = 0.0;
   z = 0.0;
   sigma = 0.0;

   const int formation = MathMax(60, strategy_formation_bars);
   const int zbars = MathMax(20, strategy_zscore_bars);
   const int bars = MathMax(formation + 1, zbars + 1);

   double y[];
   double x[];
   if(!Strategy_ReadLogs(g_symbols[host_index], g_symbols[partner_index], bars, y, x))
      return false;

   if(!Strategy_EstimateOLS(y, x, formation, beta))
      return false;
   if(!Strategy_Correlation(y, x, formation + 1, corr))
      return false;

   double spread[];
   ArrayResize(spread, bars);
   for(int i = 0; i < bars; ++i)
      spread[i] = y[i] - beta * x[i];

   if(full_formation && !Strategy_ADFProxy(spread, formation, adf_t))
      return false;

   double sum = 0.0;
   for(int i = 0; i < zbars; ++i)
      sum += spread[i];
   const double mean = sum / (double)zbars;

   double var = 0.0;
   for(int i = 0; i < zbars; ++i)
     {
      const double d = spread[i] - mean;
      var += d * d;
     }

   sigma = MathSqrt(var / MathMax(1, zbars - 1));
   if(sigma <= 0.0 || !MathIsValidNumber(sigma))
      return false;

   z = (spread[0] - mean) / sigma;
   return MathIsValidNumber(z);
  }

bool Strategy_SelectMonthlyPair(const int host_index)
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0)
      return false;

   // Pair selection is monthly. A month with no qualifying partner is also a
   // completed selection result; do not rescan six 252-bar relationships on
   // every H4 bar until the calendar month changes.
   if(month_key == g_selected_month_key)
      return (g_selected_partner >= 0);

   int best_partner = -1;
   double best_corr = -DBL_MAX;
   double best_beta = 1.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == host_index)
         continue;

      double beta = 1.0, corr = 0.0, adf_t = 0.0, z = 0.0, sigma = 0.0;
      if(!Strategy_SpreadStats(host_index, i, true, beta, corr, adf_t, z, sigma))
         continue;
      if(corr < strategy_min_corr)
         continue;
      if(adf_t > strategy_adf_t_max)
         continue;
      if(corr > best_corr)
        {
         best_corr = corr;
         best_partner = i;
         best_beta = beta;
        }
     }

   g_selected_partner = best_partner;
   g_selected_beta = best_beta;
   g_selected_month_key = month_key;
   return (g_selected_partner >= 0);
  }

bool Strategy_RefreshState()
  {
   // OnTick calls this exactly once after the framework's H4 new-bar gate.
   // Exit and entry hooks consume the resulting closed-bar snapshot.
   g_state_ready = false;

   const int host_index = Strategy_SymbolIndex(_Symbol);
   if(host_index < 0)
      return false;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   if(!Strategy_SelectMonthlyPair(host_index))
     {
      g_state_ready = false;
      return false;
     }

   double beta = 1.0, corr = 0.0, adf_t = 0.0, z = 0.0, sigma = 0.0;
   if(!Strategy_SpreadStats(host_index, g_selected_partner, false, beta, corr, adf_t, z, sigma))
     {
      g_state_ready = false;
      return false;
     }

   g_selected_beta = beta;
   g_current_z = z;
   g_current_sigma = sigma;
   g_state_ready = (corr >= 0.50);
   return g_state_ready;
  }

bool Strategy_IsPairPosition(const int host_index, const int partner_index)
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   if(symbol == g_symbols[host_index] && magic == QM_MagicChecked(qm_ea_id, g_slots[host_index], symbol))
      return true;
   if(symbol == g_symbols[partner_index] && magic == QM_MagicChecked(qm_ea_id, g_slots[partner_index], symbol))
      return true;
   return false;
  }

bool Strategy_HasPairPosition(const int host_index, const int partner_index)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition(host_index, partner_index))
         return true;
     }
   return false;
  }

int Strategy_ClosePair(const int host_index, const int partner_index, const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition(host_index, partner_index))
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

double Strategy_StopDistance(const string symbol)
  {
   const double atr = QM_ATR(symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return 0.0;
   return atr * strategy_atr_sl_mult;
  }

bool Strategy_RiskForWeight(const double weight,
                            const double weight_sum,
                            QM_RiskMode &mode,
                            double &value)
  {
   mode = QM_RISK_MODE_UNSET;
   value = 0.0;
   if(weight_sum <= 0.0 || MathAbs(weight) <= 0.0)
      return false;

   const double fraction = MathAbs(weight) / weight_sum;
   if(RISK_FIXED > 0.0 && RISK_PERCENT <= 0.0)
     {
      mode = QM_RISK_MODE_FIXED;
      value = RISK_FIXED * fraction;
      return (value > 0.0);
     }
   if(RISK_PERCENT > 0.0 && RISK_FIXED <= 0.0)
     {
      mode = QM_RISK_MODE_PERCENT;
      value = RISK_PERCENT * fraction;
      return (value > 0.0);
     }
   return false;
  }

// Foreign partner leg only. The host leg is returned as QM_EntryRequest and
// opened by QM_TM_OpenPosition in OnTick.
bool Strategy_OpenPartnerLeg(const int symbol_index,
                             const bool buy_leg,
                             const double weight,
                             const double weight_sum,
                             const string reason)
  {
   const string symbol = g_symbols[symbol_index];
   if(symbol == _Symbol || !QM_SymbolAssertOrLog(symbol))
      return false;

   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double stop_dist = Strategy_StopDistance(symbol);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || stop_dist <= 0.0 || point <= 0.0 || weight_sum <= 0.0)
      return false;

   QM_BasketOrderRequest breq;
   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = buy_leg ? entry - stop_dist : entry + stop_dist;
   breq.tp = 0.0;
   breq.symbol_slot = g_slots[symbol_index];
   breq.expiration_seconds = 0;
   breq.reason = reason;

   QM_RiskMode risk_mode;
   double risk_value;
   if(!Strategy_RiskForWeight(weight, weight_sum, risk_mode, risk_value))
      return false;

   const double sl_points = stop_dist / point;
   breq.lots = QM_LotsForRisk(symbol, sl_points, risk_mode, risk_value);
   if(breq.lots <= 0.0)
      return false;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket);
  }

bool Strategy_PreparePair(const int spread_direction, QM_EntryRequest &host_req)
  {
   const int host_index = Strategy_SymbolIndex(_Symbol);
   const int partner_index = g_selected_partner;
   if(host_index < 0 || partner_index < 0 || Strategy_HasPairPosition(host_index, partner_index))
      return false;

   const double host_weight = 1.0;
   const double partner_weight = -g_selected_beta;
   const double weight_sum = MathAbs(host_weight) + MathAbs(partner_weight);
   if(weight_sum <= 0.0)
      return false;

   const bool buy_host = (spread_direction * host_weight > 0.0);
   const bool buy_partner = (spread_direction * partner_weight > 0.0);
   const string reason = (spread_direction > 0) ? "QM5_10025_LONG_SPREAD_Z_LT_NEG2"
                                                : "QM5_10025_SHORT_SPREAD_Z_GT_POS2";

   const double host_entry = buy_host ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double host_stop_dist = Strategy_StopDistance(_Symbol);
   const int host_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(host_entry <= 0.0 || host_stop_dist <= 0.0)
      return false;

   // Prepare the host before opening the partner so a local data defect cannot
   // leave an orphan. The partner is sent first; a failed partner aborts.
   host_req.type = buy_host ? QM_BUY : QM_SELL;
   host_req.price = 0.0;
   host_req.sl = buy_host ? NormalizeDouble(host_entry - host_stop_dist, host_digits)
                          : NormalizeDouble(host_entry + host_stop_dist, host_digits);
   host_req.tp = 0.0;
   host_req.reason = reason;
   host_req.symbol_slot = g_slots[host_index];
   host_req.expiration_seconds = 0;

   return Strategy_OpenPartnerLeg(partner_index,
                                  buy_partner,
                                  partner_weight,
                                  weight_sum,
                                  reason);
  }

int Strategy_BarsHeld()
  {
   if(g_entry_bar_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, g_entry_bar_time, false);
   return (shift < 0) ? 0 : shift;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;
   if(Strategy_SymbolIndex(_Symbol) < 0)
      return true;
   if(!Strategy_SpreadsNormal())
      return true;
   if(Strategy_FinalH4BeforeWeekend(TimeCurrent()))
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10025_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;
   if(Strategy_NoTradeFilter())
      return false;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return false;

   int spread_direction = 0;
   if(g_current_z > strategy_entry_z)
      spread_direction = -1;
   else if(g_current_z < -strategy_entry_z)
      spread_direction = 1;
   else
      return false;

   return Strategy_PreparePair(spread_direction, req);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int host_index = Strategy_SymbolIndex(_Symbol);
   const int partner_index = g_selected_partner;
   if(host_index < 0 || partner_index < 0 || !Strategy_HasPairPosition(host_index, partner_index))
      return false;

   if(!g_state_ready)
      return false;

   bool should_close = false;
   if(MathAbs(g_current_z) <= strategy_exit_z)
      should_close = true;
   if(MathAbs(g_current_z) >= strategy_spread_stop_z)
      should_close = true;

   if(strategy_time_stop_bars > 0 && Strategy_BarsHeld() >= strategy_time_stop_bars && g_entry_abs_z > 0.0)
     {
      const double improvement = (g_entry_abs_z - MathAbs(g_current_z)) / g_entry_abs_z;
      if(improvement < strategy_min_improve_frac)
         should_close = true;
     }

   if(should_close)
      Strategy_ClosePair(host_index, partner_index, QM_EXIT_STRATEGY);
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int host_index = Strategy_SymbolIndex(_Symbol);
   if(host_index < 0 || g_selected_partner < 0)
      return true;

   const string host_symbol = g_symbols[host_index];
   const string partner_symbol = g_symbols[g_selected_partner];
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(host_symbol,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(partner_symbol,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(host_symbol, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(partner_symbol, broker_time, qm_news_mode_legacy))
         return true;
     }
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols,
                          PERIOD_H4,
                          MathMax(strategy_formation_bars + 1,
                                  strategy_zscore_bars + 1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10025\",\"ea\":\"rw-fx-broad-pairs\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 lifecycle sampling must precede every early-return guard.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   // Reject stale broad-fanout tester jobs before any cross-symbol or news
   // work. The approved card permits only the seven registered FX hosts.
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4 ||
      Strategy_SymbolIndex(_Symbol) < 0)
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      const int host_index = Strategy_SymbolIndex(_Symbol);
      if(host_index >= 0 && g_selected_partner >= 0)
         Strategy_ClosePair(host_index, g_selected_partner, QM_EXIT_FRIDAY_CLOSE);
      QM_FrameworkHandleFridayClose();
      return;
     }
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   // All multi-symbol history, spread and news work now executes at most once
   // per closed H4 bar. Exits remain available through news blackouts; the
   // entry hook applies the two-leg news gate after selecting the partner.
   Strategy_RefreshState();
   QM_EquityStreamOnNewBar();
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      const int host_index = Strategy_SymbolIndex(_Symbol);
      const int partner_index = g_selected_partner;
      const double weight_sum = 1.0 + MathAbs(g_selected_beta);
      QM_RiskMode host_risk_mode;
      double host_risk_value;
      ulong out_ticket = 0;
      const bool risk_ok = Strategy_RiskForWeight(1.0,
                                                  weight_sum,
                                                  host_risk_mode,
                                                  host_risk_value);
      const bool host_opened = risk_ok &&
         QM_TM_OpenPosition(req,
                            out_ticket,
                            0,
                            host_risk_mode,
                            host_risk_value);
      if(!host_opened)
        {
         // Partner was opened first. Roll it back immediately when the
         // framework rejects the host leg so directional exposure is bounded.
         if(host_index >= 0 && partner_index >= 0)
            Strategy_ClosePair(host_index, partner_index, QM_EXIT_STRATEGY);
        }
      else
        {
         g_entry_abs_z = MathAbs(g_current_z);
         g_entry_bar_time = iTime(_Symbol, PERIOD_H4, 1); // perf-allowed: closed H4 entry timestamp after new-bar gate
        }
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
