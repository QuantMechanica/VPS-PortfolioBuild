#property strict
#property version   "5.0"
#property description "QM5_12511 bt weekly inverse-vol target volatility"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12511;
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
input double strategy_target_annual_vol      = 0.10;
input int    strategy_vol_lookback_d1        = 252;
input int    strategy_short_vol_lookback_d1  = 20;
input int    strategy_spread_median_days     = 60;
input double strategy_spread_median_mult     = 2.0;
input double strategy_single_symbol_cap      = 0.40;
input double strategy_entry_weight_threshold = 0.05;
input double strategy_exit_weight_threshold  = 0.02;
input double strategy_rebalance_tolerance    = 0.10;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 4.0;

#define QM5_12511_SYMBOL_COUNT 5
#define QM5_12511_MAX_LOOKBACK 512

string g_symbols[QM5_12511_SYMBOL_COUNT] =
  {
   "GDAXI.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
  };

double g_target_weights[QM5_12511_SYMBOL_COUNT];
bool   g_valid_symbols[QM5_12511_SYMBOL_COUNT];
bool   g_high_short_vol[QM5_12511_SYMBOL_COUNT];
bool   g_basket_state_ok      = false;
bool   g_portfolio_stop       = false;
int    g_valid_symbol_count   = 0;
int    g_last_entry_week      = 0;
int    g_last_exit_week       = 0;
double g_open_target_weight   = 0.0;

int Strategy_CurrentSlot()
  {
   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
      if(_Symbol == g_symbols[i])
         return i;
   return -1;
  }

int Strategy_WeekKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_HasOpenPosition(ulong &ticket)
  {
   ticket = 0;
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
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = pos_ticket;
      return true;
     }

   return false;
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowedFromRates(const MqlRates &rates[])
  {
   if(strategy_spread_median_mult <= 0.0 || strategy_spread_median_days <= 0)
      return true;

   const int n = MathMin(strategy_spread_median_days, ArraySize(rates));
   double spreads[QM5_12511_MAX_LOOKBACK];
   int count = 0;
   for(int i = 0; i < n && i < QM5_12511_MAX_LOOKBACK; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      ++count;
     }

   if(count < 5)
      return true;

   const double median = Strategy_Median(spreads, count);
   const long current = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median <= 0.0 || current <= 0)
      return true;

   return ((double)current <= strategy_spread_median_mult * median);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level <= 0)
      return true;

   return ((entry - sl) / point > (double)stops_level);
  }

bool Strategy_ConfigureRiskForTarget(const double target_weight)
  {
   if(target_weight <= 0.0 || target_weight > strategy_single_symbol_cap + 1e-8)
      return false;

   if(RISK_PERCENT > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT * target_weight, 0.0, PORTFOLIO_WEIGHT);

   if(RISK_FIXED > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, RISK_FIXED * target_weight, PORTFOLIO_WEIGHT);

   return false;
  }

bool Strategy_RefreshBasketState()
  {
   ArrayInitialize(g_target_weights, 0.0);
   ArrayInitialize(g_valid_symbols, false);
   ArrayInitialize(g_high_short_vol, false);
   g_basket_state_ok = false;
   g_portfolio_stop = false;
   g_valid_symbol_count = 0;

   const int lookback = MathMax(strategy_vol_lookback_d1, strategy_short_vol_lookback_d1);
   if(strategy_target_annual_vol <= 0.0 ||
      strategy_vol_lookback_d1 < 20 ||
      lookback + 2 > QM5_12511_MAX_LOOKBACK)
      return false;

   double returns[QM5_12511_SYMBOL_COUNT][QM5_12511_MAX_LOOKBACK];
   double means[QM5_12511_SYMBOL_COUNT];
   double annual_vols[QM5_12511_SYMBOL_COUNT];
   double inv_vols[QM5_12511_SYMBOL_COUNT];
   double raw_weights[QM5_12511_SYMBOL_COUNT];
   double close_recent[QM5_12511_SYMBOL_COUNT];
   double close_20[QM5_12511_SYMBOL_COUNT];

   ArrayInitialize(means, 0.0);
   ArrayInitialize(annual_vols, 0.0);
   ArrayInitialize(inv_vols, 0.0);
   ArrayInitialize(raw_weights, 0.0);
   ArrayInitialize(close_recent, 0.0);
   ArrayInitialize(close_20, 0.0);

   for(int sym_idx = 0; sym_idx < QM5_12511_SYMBOL_COUNT; ++sym_idx)
     {
      const string sym = g_symbols[sym_idx];
      if(!SymbolSelect(sym, true))
         continue;

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      const int copied = CopyRates(sym, PERIOD_D1, 1, lookback + 2, rates); // perf-allowed: D1 new-bar basket refresh only, bounded by QM5_12511_MAX_LOOKBACK
      if(copied < lookback + 1)
         continue;

      if(sym == _Symbol && !Strategy_SpreadAllowedFromRates(rates))
         continue;

      double sum = 0.0;
      double sumsq = 0.0;
      bool ok = true;
      for(int bar = 0; bar < strategy_vol_lookback_d1; ++bar)
        {
         const double c0 = rates[bar].close;
         const double c1 = rates[bar + 1].close;
         if(c0 <= 0.0 || c1 <= 0.0)
           {
            ok = false;
            break;
           }
         const double r = MathLog(c0 / c1);
         returns[sym_idx][bar] = r;
         sum += r;
         sumsq += r * r;
        }
      if(!ok)
         continue;

      const double mean = sum / (double)strategy_vol_lookback_d1;
      const double var = (sumsq / (double)strategy_vol_lookback_d1) - mean * mean;
      if(var <= 0.0)
         continue;

      means[sym_idx] = mean;
      annual_vols[sym_idx] = MathSqrt(var) * MathSqrt(252.0);
      if(annual_vols[sym_idx] <= 0.0)
         continue;

      if(copied > strategy_short_vol_lookback_d1 && rates[0].close > 0.0 && rates[strategy_short_vol_lookback_d1].close > 0.0)
        {
         double short_sum = 0.0;
         double short_sumsq = 0.0;
         for(int bar = 0; bar < strategy_short_vol_lookback_d1; ++bar)
           {
            const double c0 = rates[bar].close;
            const double c1 = rates[bar + 1].close;
            if(c0 <= 0.0 || c1 <= 0.0)
              {
               ok = false;
               break;
              }
            const double r = MathLog(c0 / c1);
            short_sum += r;
            short_sumsq += r * r;
           }
         if(!ok)
            continue;
         const double short_mean = short_sum / (double)strategy_short_vol_lookback_d1;
         const double short_var = (short_sumsq / (double)strategy_short_vol_lookback_d1) - short_mean * short_mean;
         const double short_annual_vol = (short_var > 0.0) ? MathSqrt(short_var) * MathSqrt(252.0) : 0.0;
         g_high_short_vol[sym_idx] = (short_annual_vol > 2.0 * annual_vols[sym_idx]);

         close_recent[sym_idx] = rates[0].close;
         close_20[sym_idx] = rates[strategy_short_vol_lookback_d1].close;
        }

      inv_vols[sym_idx] = 1.0 / annual_vols[sym_idx];
      g_valid_symbols[sym_idx] = true;
      ++g_valid_symbol_count;
     }

   if(g_valid_symbol_count < 2)
      return false;

   double inv_total = 0.0;
   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
      if(g_valid_symbols[i])
         inv_total += inv_vols[i];
   if(inv_total <= 0.0)
      return false;

   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
      if(g_valid_symbols[i])
         raw_weights[i] = inv_vols[i] / inv_total;

   double basket_var_daily = 0.0;
   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
     {
      if(!g_valid_symbols[i])
         continue;
      for(int j = 0; j < QM5_12511_SYMBOL_COUNT; ++j)
        {
         if(!g_valid_symbols[j])
            continue;

         double cov = 0.0;
         for(int bar = 0; bar < strategy_vol_lookback_d1; ++bar)
            cov += (returns[i][bar] - means[i]) * (returns[j][bar] - means[j]);
         cov /= (double)strategy_vol_lookback_d1;
         basket_var_daily += raw_weights[i] * raw_weights[j] * cov;
        }
     }

   if(basket_var_daily <= 0.0)
      return false;

   const double basket_vol = MathSqrt(basket_var_daily) * MathSqrt(252.0);
   if(basket_vol <= 0.0)
      return false;

   const double scale = strategy_target_annual_vol / basket_vol;
   const double cap = MathMax(0.01, MathMin(strategy_single_symbol_cap, 1.0));
   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
      if(g_valid_symbols[i])
         g_target_weights[i] = MathMin(raw_weights[i] * scale, cap);

   double basket_return_20 = 0.0;
   for(int i = 0; i < QM5_12511_SYMBOL_COUNT; ++i)
     {
      if(!g_valid_symbols[i] || close_recent[i] <= 0.0 || close_20[i] <= 0.0)
         continue;
      basket_return_20 += raw_weights[i] * ((close_recent[i] / close_20[i]) - 1.0);
     }

   const double target_monthly_vol = strategy_target_annual_vol / MathSqrt(12.0);
   g_portfolio_stop = (basket_return_20 < -2.0 * target_monthly_vol);
   g_basket_state_ok = true;
   return true;
  }

// No Trade Filter (time, spread, news) — block unsupported symbols, non-D1 charts,
// invalid magic slot, and malformed parameters. Spread is enforced in basket state.
bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_CurrentSlot();
   if(slot < 0)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;
   if(strategy_target_annual_vol <= 0.0 ||
      strategy_vol_lookback_d1 < 20 ||
      strategy_vol_lookback_d1 > QM5_12511_MAX_LOOKBACK - 2 ||
      strategy_short_vol_lookback_d1 < 2 ||
      strategy_short_vol_lookback_d1 >= strategy_vol_lookback_d1)
      return true;
   if(strategy_entry_weight_threshold <= strategy_exit_weight_threshold ||
      strategy_single_symbol_cap <= 0.0 ||
      strategy_atr_period_d1 <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return true;

   return false;
  }

// Trade Entry — weekly long-only target-vol rebalance. Lots are sized by the
// framework from the 4x ATR emergency stop and the target weight risk scale.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12511_BT_TARGET_VOL_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int week = Strategy_WeekKey(TimeCurrent());
   if(week <= 0 || week == g_last_entry_week)
      return false;
   g_last_entry_week = week;

   if(!g_basket_state_ok || g_portfolio_stop)
      return false;

   const int slot = Strategy_CurrentSlot();
   if(slot < 0 || !g_valid_symbols[slot] || g_high_short_vol[slot])
      return false;

   const double target_weight = g_target_weights[slot];
   if(target_weight <= strategy_entry_weight_threshold)
      return false;

   ulong ticket = 0;
   if(Strategy_HasOpenPosition(ticket))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   if(!Strategy_ConfigureRiskForTarget(target_weight))
      return false;

   req.price = entry;
   req.sl = sl;
   g_open_target_weight = target_weight;
   return true;
  }

// Trade Management — no trailing, partial, or break-even rules in the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — daily emergency flatten on invalid basket/loss stop, and weekly
// close/reopen when target weight falls below exit threshold or needs rebalance.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_HasOpenPosition(ticket))
      return false;

   if(!g_basket_state_ok || g_portfolio_stop || g_valid_symbol_count < 2)
     {
      g_open_target_weight = 0.0;
      return true;
     }

   const int slot = Strategy_CurrentSlot();
   if(slot < 0 || !g_valid_symbols[slot])
     {
      g_open_target_weight = 0.0;
      return true;
     }

   const double target_weight = g_target_weights[slot];
   if(target_weight < strategy_exit_weight_threshold)
     {
      g_open_target_weight = 0.0;
      return true;
     }

   const int week = Strategy_WeekKey(TimeCurrent());
   if(week <= 0 || week == g_last_exit_week)
      return false;

   if(g_open_target_weight <= 0.0)
     {
      g_open_target_weight = target_weight;
      return false;
     }

   const double diff = MathAbs(target_weight - g_open_target_weight) / g_open_target_weight;
   if(diff >= strategy_rebalance_tolerance)
     {
      g_last_exit_week = week;
      g_open_target_weight = 0.0;
      return true;
     }

   return false;
  }

// News Filter Hook — defer to the framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — standard skeleton, with basket guard and D1 state refresh.
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_vol_lookback_d1 + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12511\",\"ea\":\"QM5_12511_bt-target-vol\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_RefreshBasketState();

   if(Strategy_ExitSignal())
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
