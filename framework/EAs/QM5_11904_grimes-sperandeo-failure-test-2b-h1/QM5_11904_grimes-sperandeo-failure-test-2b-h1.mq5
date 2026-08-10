#property strict
#property version   "5.0"
#property description "QM5_11904 Grimes/Sperandeo Failure Test 2B H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11904
// Card: Grimes/Sperandeo failure test (2B reversal at a swing pivot)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11904;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_pivot_lookback_bars = 10;
input int    strategy_pivot_min_age_bars        = 5;
input int    strategy_pivot_max_age_bars        = 100;
input int    strategy_breach_min_pips           = 3;
input double strategy_breach_max_pips_atr_mult  = 1.5;
input int    strategy_atr_period                 = 14;
input bool   strategy_close_back_inside_required = true;
input string strategy_target_method             = "prior_swing_or_rr";
input double strategy_target_rr                 = 2.0;
input int    strategy_stop_buffer_pips          = 2;
input int    strategy_time_exit_bars            = 48;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
  }

bool Strategy_FindRecentPivots(const MqlRates &rates[],
                               const int copied,
                               double &pivot_low,
                               int &pivot_low_age,
                               double &pivot_high,
                               int &pivot_high_age)
  {
   pivot_low = 0.0;
   pivot_low_age = -1;
   pivot_high = 0.0;
   pivot_high_age = -1;

   const int half_window = strategy_swing_pivot_lookback_bars / 2;
   for(int age = strategy_pivot_min_age_bars; age <= strategy_pivot_max_age_bars; ++age)
     {
      const int candidate = age;
      if(candidate - half_window < 0 || candidate + half_window >= copied)
         continue;

      bool is_low = true;
      bool is_high = true;
      for(int offset = 1; offset <= half_window; ++offset)
        {
         if(rates[candidate].low >= rates[candidate - offset].low ||
            rates[candidate].low >= rates[candidate + offset].low)
            is_low = false;
         if(rates[candidate].high <= rates[candidate - offset].high ||
            rates[candidate].high <= rates[candidate + offset].high)
            is_high = false;
        }

      if(is_low && pivot_low_age < 0)
        {
         pivot_low = rates[candidate].low;
         pivot_low_age = age;
        }
      if(is_high && pivot_high_age < 0)
        {
         pivot_high = rates[candidate].high;
         pivot_high_age = age;
        }
      if(pivot_low_age >= 0 && pivot_high_age >= 0)
         break;
     }

   return (pivot_low_age >= 0 || pivot_high_age >= 0);
  }

bool Strategy_NoTradeFilter()
  {
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int half_window = strategy_swing_pivot_lookback_bars / 2;
   const int needed = strategy_pivot_max_age_bars + half_window + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, needed, rates); // perf-allowed: bounded pivot scan after framework new-bar gate
   if(copied < needed)
      return false;

   double pivot_low = 0.0;
   double pivot_high = 0.0;
   int pivot_low_age = -1;
   int pivot_high_age = -1;
   if(!Strategy_FindRecentPivots(rates, copied, pivot_low, pivot_low_age, pivot_high, pivot_high_age))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double pip = Strategy_PipSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const MqlRates signal = rates[0];
   const double min_breach = strategy_breach_min_pips * pip;
   const double max_breach = strategy_breach_max_pips_atr_mult * atr;
   const double long_breach = (pivot_low_age >= 0) ? pivot_low - signal.low : -1.0;
   const double short_breach = (pivot_high_age >= 0) ? signal.high - pivot_high : -1.0;

   const bool long_signal =
      (pivot_low_age >= 0 &&
       long_breach >= min_breach &&
       long_breach <= max_breach &&
       (!strategy_close_back_inside_required || signal.close > pivot_low));
   const bool short_signal =
      (pivot_high_age >= 0 &&
       short_breach >= min_breach &&
       short_breach <= max_breach &&
       (!strategy_close_back_inside_required || signal.close < pivot_high));

   // A single outside bar can theoretically fail both sides. The card does not
   // authorize an arbitrary tie-break, so ambiguous bars are skipped.
   if(long_signal == short_signal)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double stop_buffer = strategy_stop_buffer_pips * pip;
   if(long_signal)
     {
      const double entry = ask;
      const double stop = signal.low - stop_buffer;
      const double risk = entry - stop;
      if(risk <= 0.0)
         return false;

      double target = entry + strategy_target_rr * risk;
      if(pivot_high_age >= 0 && pivot_high > entry)
         target = MathMin(target, pivot_high);
      if(target <= entry)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(stop, digits);
      req.tp = NormalizeDouble(target, digits);
      req.reason = "GRIMES_2B_LONG";
      return true;
     }

   const double entry = bid;
   const double stop = signal.high + stop_buffer;
   const double risk = stop - entry;
   if(risk <= 0.0)
      return false;

   double target = entry - strategy_target_rr * risk;
   if(pivot_low_age >= 0 && pivot_low < entry)
      target = MathMax(target, pivot_low);
   if(target >= entry || target <= 0.0)
      return false;

   req.type = QM_SELL;
   req.sl = NormalizeDouble(stop, digits);
   req.tp = NormalizeDouble(target, digits);
   req.reason = "GRIMES_2B_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card authorizes the initial stop, target, and 48-bar time exit only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_open = iBarShift(_Symbol, PERIOD_H1, open_time, false); // perf-allowed: one lookup while a position is open
      return (bars_since_open >= strategy_time_exit_bars);
     }
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   if(strategy_swing_pivot_lookback_bars < 2 ||
      strategy_swing_pivot_lookback_bars % 2 != 0 ||
      strategy_pivot_min_age_bars < strategy_swing_pivot_lookback_bars / 2 ||
      strategy_pivot_max_age_bars < strategy_pivot_min_age_bars ||
      strategy_breach_min_pips <= 0 ||
      strategy_breach_max_pips_atr_mult <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_target_method != "prior_swing_or_rr" ||
      strategy_target_rr <= 0.0 ||
      strategy_stop_buffer_pips <= 0 ||
      strategy_time_exit_bars <= 0)
     {
      QM_LogEvent(QM_ERROR, "INIT_FAILED", "{\"card\":\"QM5_11904\",\"reason\":\"strategy_inputs\"}");
      return INIT_PARAMETERS_INCORRECT;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11904\",\"pattern\":\"failure_test_2b\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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
