#property strict
#property version   "5.0"
#property description "QM5_1405 Allocate Smartly Risk Premium Value Best Value"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1405
// Allocate Smartly Risk Premium Value (Best Value variant)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1405;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_D1;
input int    strategy_min_history_months             = 24;
input int    strategy_rebalance_hour                 = 1;
input int    strategy_earnings_lag_months            = 4;
input double strategy_equity_threshold_z             = 0.00;
input int    strategy_atr_period                     = 20;
input double strategy_emergency_sl_atr               = 5.00;
input int    strategy_spread_median_days             = 20;
input double strategy_spread_cap_mult                = 3.00;

bool     g_new_bar = false;
bool     g_target_long = false;
datetime g_last_rebalance_month = 0;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

int MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

int YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

bool IsMonthlyRebalanceBar()
  {
   const datetime current_bar = iTime(_Symbol, strategy_tf, 0);
   const datetime just_closed = iTime(_Symbol, strategy_tf, 1);
   if(current_bar <= 0 || just_closed <= 0)
      return false;

   return (MonthOf(current_bar) != MonthOf(just_closed) ||
           YearOf(current_bar) != YearOf(just_closed));
  }

bool Strategy_SelectOurPosition(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_cap_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spread_sum = 0.0;
   int spread_count = 0;
   for(int shift = 1; shift <= strategy_spread_median_days; ++shift)
     {
      const long sample = (long)iSpread(_Symbol, strategy_tf, shift);
      if(sample <= 0)
         continue;
      spread_sum += (double)sample;
      ++spread_count;
     }
   if(spread_count == 0)
      return true;

   const double avg_spread = spread_sum / (double)spread_count;
   return ((double)current_spread <= strategy_spread_cap_mult * avg_spread);
  }

bool Strategy_EvaluateBestValueAllocation(bool &allocate_equity)
  {
   allocate_equity = false;
   const int total_bars = iBars(_Symbol, strategy_tf);
   const int min_bars_needed = strategy_min_history_months * 21;
   if(total_bars < min_bars_needed)
      return false;

   const int sample_count = MathMin(total_bars / 21, 120);
   if(sample_count < strategy_min_history_months)
      return false;

   double equity_values[];
   double treasury_values[];
   double corporate_values[];
   ArrayResize(equity_values, sample_count);
   ArrayResize(treasury_values, sample_count);
   ArrayResize(corporate_values, sample_count);

   for(int m = 0; m < sample_count; ++m)
     {
      const int shift_now = (m * 21) + 1;
      const int shift_past = shift_now + 252;
      const int shift_short = shift_now + 63;

      const double p_now = iClose(_Symbol, strategy_tf, shift_now);
      const double p_past = iClose(_Symbol, strategy_tf, MathMin(shift_past, total_bars - 1));
      const double p_short = iClose(_Symbol, strategy_tf, MathMin(shift_short, total_bars - 1));

      if(p_now <= 0.0 || p_past <= 0.0 || p_short <= 0.0)
         return false;

      const double sma_10m = QM_SMA(_Symbol, strategy_tf, 200, shift_now);
      const double earnings_yield_proxy = (sma_10m > 0.0) ? (sma_10m / p_now) * 0.05 : 0.04;
      const double ret_12m = (p_now / p_past) - 1.0;
      const double ret_3m = (p_now / p_short) - 1.0;

      const double t_yield_proxy = 0.035 - (ret_12m * 0.05);
      const double corp_yield_proxy = t_yield_proxy + 0.015 - (ret_3m * 0.03);

      equity_values[m] = earnings_yield_proxy - t_yield_proxy;
      treasury_values[m] = t_yield_proxy - 0.025;
      corporate_values[m] = corp_yield_proxy - t_yield_proxy;
     }

   double sum_e = 0.0, sum_t = 0.0, sum_c = 0.0;
   for(int i = 0; i < sample_count; ++i)
     {
      sum_e += equity_values[i];
      sum_t += treasury_values[i];
      sum_c += corporate_values[i];
     }
   const double mean_e = sum_e / (double)sample_count;
   const double mean_t = sum_t / (double)sample_count;
   const double mean_c = sum_c / (double)sample_count;

   double sq_e = 0.0, sq_t = 0.0, sq_c = 0.0;
   for(int i = 0; i < sample_count; ++i)
     {
      sq_e += (equity_values[i] - mean_e) * (equity_values[i] - mean_e);
      sq_t += (treasury_values[i] - mean_t) * (treasury_values[i] - mean_t);
      sq_c += (corporate_values[i] - mean_c) * (corporate_values[i] - mean_c);
     }
   const double std_e = MathSqrt(sq_e / (double)sample_count);
   const double std_t = MathSqrt(sq_t / (double)sample_count);
   const double std_c = MathSqrt(sq_c / (double)sample_count);

   if(std_e <= 1e-6 || std_t <= 1e-6 || std_c <= 1e-6)
      return false;

   const double z_equity = (equity_values[0] - mean_e) / std_e;
   const double z_treasury = (treasury_values[0] - mean_t) / std_t;
   const double z_corporate = (corporate_values[0] - mean_c) / std_c;

   const double max_z = MathMax(z_equity, MathMax(z_treasury, z_corporate));
   if(max_z > strategy_equity_threshold_z && z_equity >= max_z)
      allocate_equity = true;
   else
      allocate_equity = false;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_tf || strategy_tf != PERIOD_D1)
      return true;
   if(strategy_min_history_months < 6 || strategy_atr_period < 2)
      return true;
   return false;
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 || !Strategy_SpreadAllowsEntry())
      return false;

   if(!g_target_long)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || ask <= 0.0)
      return false;

   const double sl = ask - strategy_emergency_sl_atr * atr;
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = "ALLOCATE_SMARTLY_RPV_BESTVALUE_LONG_D1";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Monthly rotation managed via Strategy_ExitSignal and Strategy_EntrySignal
  }

bool Strategy_ExitSignal()
  {
   if(!g_new_bar)
      return false;

   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   // Exit if monthly model rotated away from equity (cash or alternative asset)
   if(!g_target_long)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1405\",\"ea\":\"as-rpv-bestvalue\"}");
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   g_new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   if(g_new_bar)
     {
      const datetime bar_time = iTime(_Symbol, strategy_tf, 0);
      const datetime month_key = (datetime)(YearOf(bar_time) * 100 + MonthOf(bar_time));
      if(month_key != g_last_rebalance_month)
        {
         bool alloc_eq = false;
         if(Strategy_EvaluateBestValueAllocation(alloc_eq))
           {
            g_target_long = alloc_eq;
            g_last_rebalance_month = month_key;
           }
        }
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !g_new_bar)
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
