#property strict
#property version   "5.0"
#property description "QM5_1673 Sperandeo Trader Vic II Trendline-Failure Reversal"
// Strategy Card: QM5_1673 (sperandeo-tvii-trendline-failure-h4), G0 APPROVED.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1673
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1673;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pivot_strength       = 5;
input int    strategy_atr_period           = 14;
input double strategy_violation_atr_mult   = 0.5;
input int    strategy_cancellation_bars    = 4;
input int    strategy_trendline_max_age    = 144;
input int    strategy_regime_sma_period    = 200;
input double strategy_target_retrace       = 0.5;
input double strategy_stop_buffer_atr      = 0.5;
input double strategy_stop_atr_cap         = 3.0;
input int    strategy_time_stop_bars       = 30;
input double strategy_be_trigger_atr       = 1.5;
input double strategy_partial_target_frac  = 0.5;
input double strategy_partial_close_frac   = 0.5;
input int    strategy_cooldown_bars         = 18;
input double strategy_spread_atr_mult       = 0.3;

bool g_strategy_new_bar = false;

struct StrategySignal
  {
   bool         valid;
   QM_OrderType side;
   int          older_pivot_shift;
   int          newer_pivot_shift;
   double       trend_start_price;
   double       pre_violation_extreme;
  };

void ResetSignal(StrategySignal &signal)
  {
   signal.valid                 = false;
   signal.side                  = QM_BUY;
   signal.older_pivot_shift     = 0;
   signal.newer_pivot_shift     = 0;
   signal.trend_start_price     = 0.0;
   signal.pre_violation_extreme = 0.0;
  }

double H4High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: new-bar-gated bespoke structural pivot scan.
  }

double H4Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: new-bar-gated bespoke structural pivot scan.
  }

double H4Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: new-bar-gated bespoke trendline projection.
  }

bool IsPivotLow(const int shift)
  {
   if(shift <= strategy_pivot_strength)
      return false;

   const double pivot = H4Low(shift);
   if(pivot <= 0.0)
      return false;

   for(int distance = 1; distance <= strategy_pivot_strength; ++distance)
     {
      const double older = H4Low(shift + distance);
      const double newer = H4Low(shift - distance);
      if(older <= 0.0 || newer <= 0.0 || pivot >= older || pivot >= newer)
         return false;
     }
   return true;
  }

bool IsPivotHigh(const int shift)
  {
   if(shift <= strategy_pivot_strength)
      return false;

   const double pivot = H4High(shift);
   if(pivot <= 0.0)
      return false;

   for(int distance = 1; distance <= strategy_pivot_strength; ++distance)
     {
      const double older = H4High(shift + distance);
      const double newer = H4High(shift - distance);
      if(older <= 0.0 || newer <= 0.0 || pivot <= older || pivot <= newer)
         return false;
     }
   return true;
  }

bool FindTrendlinePivots(const bool rising,
                         const int violation_shift,
                         int &older_shift,
                         int &newer_shift,
                         double &older_price,
                         double &newer_price)
  {
   older_shift = 0;
   newer_shift = 0;
   older_price = 0.0;
   newer_price = 0.0;

   const int min_shift = violation_shift + strategy_pivot_strength;
   const int max_shift = strategy_trendline_max_age;
   if(min_shift >= max_shift)
      return false;

   for(int recent = min_shift; recent < max_shift; ++recent)
     {
      const bool recent_is_pivot = rising ? IsPivotLow(recent) : IsPivotHigh(recent);
      if(!recent_is_pivot)
         continue;

      const double recent_price = rising ? H4Low(recent) : H4High(recent);
      for(int older = recent + 1; older <= max_shift; ++older)
        {
         const bool older_is_pivot = rising ? IsPivotLow(older) : IsPivotHigh(older);
         if(!older_is_pivot)
            continue;

         const double candidate_price = rising ? H4Low(older) : H4High(older);
         const bool direction_ok = rising ? (recent_price > candidate_price)
                                          : (recent_price < candidate_price);
         if(!direction_ok)
            continue;

         older_shift = older;
         newer_shift = recent;
         older_price = candidate_price;
         newer_price = recent_price;
         return true;
        }
     }
   return false;
  }

double ProjectTrendline(const int older_shift,
                        const int newer_shift,
                        const double older_price,
                        const double newer_price,
                        const int target_shift)
  {
   const int elapsed = older_shift - newer_shift;
   if(elapsed <= 0)
      return 0.0;

   const double slope_per_bar = (newer_price - older_price) / (double)elapsed;
   return newer_price + slope_per_bar * (double)(newer_shift - target_shift);
  }

bool FindPreViolationExtreme(const bool rising,
                             const int violation_shift,
                             const int older_pivot_shift,
                             double &extreme)
  {
   extreme = rising ? -DBL_MAX : DBL_MAX;
   const int newest_shift = violation_shift + 1;
   const int oldest_shift = older_pivot_shift - 1;
   if(newest_shift > oldest_shift)
      return false;

   for(int shift = newest_shift; shift <= oldest_shift; ++shift)
     {
      const double value = rising ? H4High(shift) : H4Low(shift);
      if(value <= 0.0)
         return false;
      if(rising)
         extreme = MathMax(extreme, value);
      else
         extreme = MathMin(extreme, value);
     }

   return (extreme > 0.0 && extreme < DBL_MAX);
  }

bool DetectFailureSignal(const bool rising_trendline, StrategySignal &signal)
  {
   ResetSignal(signal);

   const int violation_shift = 1 + strategy_cancellation_bars;
   int older_shift = 0;
   int newer_shift = 0;
   double older_price = 0.0;
   double newer_price = 0.0;
   if(!FindTrendlinePivots(rising_trendline,
                           violation_shift,
                           older_shift,
                           newer_shift,
                           older_price,
                           newer_price))
      return false;

   const double violation_line = ProjectTrendline(older_shift,
                                                   newer_shift,
                                                   older_price,
                                                   newer_price,
                                                   violation_shift);
   const double prior_line = ProjectTrendline(older_shift,
                                               newer_shift,
                                               older_price,
                                               newer_price,
                                               violation_shift + 1);
   const double violation_close = H4Close(violation_shift);
   const double prior_close = H4Close(violation_shift + 1);
   const double atr_violation = QM_ATR(_Symbol,
                                       PERIOD_H4,
                                       strategy_atr_period,
                                       violation_shift);
   if(violation_line <= 0.0 || prior_line <= 0.0 ||
      violation_close <= 0.0 || prior_close <= 0.0 || atr_violation <= 0.0)
      return false;

   const double tolerance = atr_violation * strategy_violation_atr_mult;
   if(rising_trendline)
     {
      if(violation_close >= violation_line - tolerance)
         return false;
      if(prior_close < prior_line - tolerance)
         return false;
     }
   else
     {
      if(violation_close <= violation_line + tolerance)
         return false;
      if(prior_close > prior_line + tolerance)
         return false;
     }

   for(int shift = violation_shift - 1; shift >= 1; --shift)
     {
      const double line_value = ProjectTrendline(older_shift,
                                                  newer_shift,
                                                  older_price,
                                                  newer_price,
                                                  shift);
      const double close_value = H4Close(shift);
      if(line_value <= 0.0 || close_value <= 0.0)
         return false;

      if(rising_trendline && close_value >= line_value)
         return false;
      if(!rising_trendline && close_value <= line_value)
         return false;
     }

   double extreme = 0.0;
   if(!FindPreViolationExtreme(rising_trendline,
                               violation_shift,
                               older_shift,
                               extreme))
      return false;

   signal.valid                 = true;
   signal.side                  = rising_trendline ? QM_SELL : QM_BUY;
   signal.older_pivot_shift     = older_shift;
   signal.newer_pivot_shift     = newer_shift;
   signal.trend_start_price     = older_price;
   signal.pre_violation_extreme = extreme;
   return true;
  }

bool DetectCurrentSignal(StrategySignal &signal)
  {
   StrategySignal short_signal;
   StrategySignal long_signal;
   const bool has_short = DetectFailureSignal(true, short_signal);
   const bool has_long = DetectFailureSignal(false, long_signal);

   ResetSignal(signal);
   if(has_short == has_long)
      return false;

   signal = has_short ? short_signal : long_signal;
   return signal.valid;
  }

bool RegimeAllows(const QM_OrderType side)
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 regime sample on a new H4 bar.
   const double d1_sma = QM_SMA(_Symbol,
                                PERIOD_D1,
                                strategy_regime_sma_period,
                                1,
                                PRICE_CLOSE);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;
   return (side == QM_BUY) ? (d1_close > d1_sma) : (d1_close < d1_sma);
  }

bool EntrySpreadBlocked()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask < bid)
      return true;
   return ((ask - bid) > atr * strategy_spread_atr_mult);
  }

bool CooldownActive(const QM_OrderType side)
  {
   if(strategy_cooldown_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(now <= 0 || h4_seconds <= 0)
      return true;

   const datetime cutoff = now - (datetime)(strategy_cooldown_bars * h4_seconds);
   if(!HistorySelect(cutoff, now))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal = HistoryDealGetTicket(index);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if((side == QM_BUY && deal_type == DEAL_TYPE_BUY) ||
         (side == QM_SELL && deal_type == DEAL_TYPE_SELL))
         return true;
     }
   return false;
  }

bool BuildEntryRequest(const StrategySignal &signal, QM_EntryRequest &req)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry = (signal.side == QM_BUY) ? ask : bid;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   double stop = 0.0;
   double target = 0.0;
   if(signal.side == QM_BUY)
     {
      const double structural_stop = signal.pre_violation_extreme - strategy_stop_buffer_atr * atr;
      const double capped_stop = entry - strategy_stop_atr_cap * atr;
      stop = MathMax(structural_stop, capped_stop);

      const double prior_range = signal.trend_start_price - signal.pre_violation_extreme;
      if(prior_range <= point)
         return false;
      target = entry + prior_range * strategy_target_retrace;
      if(stop <= 0.0 || stop >= entry || target <= entry)
         return false;
     }
   else
     {
      const double structural_stop = signal.pre_violation_extreme + strategy_stop_buffer_atr * atr;
      const double capped_stop = entry + strategy_stop_atr_cap * atr;
      stop = MathMin(structural_stop, capped_stop);

      const double prior_range = signal.pre_violation_extreme - signal.trend_start_price;
      if(prior_range <= point)
         return false;
      target = entry - prior_range * strategy_target_retrace;
      if(stop <= entry || target <= 0.0 || target >= entry)
         return false;
     }

   req.type               = signal.side;
   req.price              = 0.0;
   req.sl                 = QM_StopRulesNormalizePrice(_Symbol, stop);
   req.tp                 = QM_StopRulesNormalizePrice(_Symbol, target);
   req.reason             = (signal.side == QM_BUY) ? "tvii_tlf_long" : "tvii_tlf_short";
   req.symbol_slot        = 0;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool PositionHasPartialExit(const ulong position_id)
  {
   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return false;

   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal = HistoryDealGetTicket(index);
      if(deal == 0)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

double PartialCloseLots(const string symbol, const double current_volume)
  {
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   const double minimum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0 || minimum <= 0.0 || current_volume <= minimum)
      return 0.0;

   double lots = MathFloor((current_volume * strategy_partial_close_frac) / step + 1e-9) * step;
   lots = NormalizeDouble(lots, 8);
   if(lots < minimum || current_volume - lots < minimum - step * 0.1)
      return 0.0;
   return lots;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_H4);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(strategy_pivot_strength < 1 ||
      strategy_atr_period < 2 ||
      strategy_violation_atr_mult <= 0.0 ||
      strategy_cancellation_bars < 1 ||
      strategy_trendline_max_age <= strategy_pivot_strength + strategy_cancellation_bars + 2 ||
      strategy_regime_sma_period < 20 ||
      strategy_target_retrace <= 0.0 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_stop_atr_cap <= 0.0 ||
      strategy_spread_atr_mult <= 0.0)
      return false;

   if(Bars(_Symbol, PERIOD_H4) < strategy_trendline_max_age + strategy_pivot_strength + 10 || // perf-allowed: new-bar-gated history readiness check.
      Bars(_Symbol, PERIOD_D1) < strategy_regime_sma_period + 10) // perf-allowed: new-bar-gated D1 regime readiness check.
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(EntrySpreadBlocked())
      return false;

   StrategySignal signal;
   if(!DetectCurrentSignal(signal))
      return false;
   if(!RegimeAllows(signal.side) || CooldownActive(signal.side))
      return false;

   return BuildEntryRequest(signal, req);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask < bid)
      return;

   const double spread = ask - bid;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? bid : ask;
      const double favorable_move = is_buy ? (market_price - open_price)
                                          : (open_price - market_price);

      if(favorable_move >= strategy_be_trigger_atr * atr)
        {
         const double be_stop = QM_StopRulesNormalizePrice(_Symbol,
                                                            is_buy ? open_price + spread
                                                                   : open_price - spread);
         const bool improves = (be_stop > 0.0) &&
                               ((current_sl <= 0.0) ||
                                (is_buy ? (be_stop > current_sl) : (be_stop < current_sl)));
         if(improves)
            QM_TM_MoveSL(ticket, be_stop, "tvii_tlf_be_atr");
        }

      const double target_distance = is_buy ? (current_tp - open_price)
                                            : (open_price - current_tp);
      if(target_distance <= 0.0 ||
         favorable_move < target_distance * strategy_partial_target_frac)
         continue;

      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(PositionHasPartialExit(position_id))
         continue;

      const double lots = PartialCloseLots(_Symbol, PositionGetDouble(POSITION_VOLUME));
      if(lots > 0.0)
         QM_TM_PartialClose(ticket, lots, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(opened_at > 0 && h4_seconds > 0 && strategy_time_stop_bars > 0 &&
         TimeCurrent() - opened_at >= strategy_time_stop_bars * h4_seconds)
         return true;

      if(!g_strategy_new_bar)
         continue;

      StrategySignal signal;
      if(!DetectCurrentSignal(signal))
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((type == POSITION_TYPE_BUY && signal.side == QM_SELL) ||
         (type == POSITION_TYPE_SELL && signal.side == QM_BUY))
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
   if(Strategy_NoTradeFilter())
      return;

   g_strategy_new_bar = QM_IsNewBar();
   if(g_strategy_new_bar)
      QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return;
     }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !g_strategy_new_bar)
      return;

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
