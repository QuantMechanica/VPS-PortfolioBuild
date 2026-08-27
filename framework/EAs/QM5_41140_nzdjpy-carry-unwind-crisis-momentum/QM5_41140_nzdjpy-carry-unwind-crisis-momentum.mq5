#property strict
#property version   "5.0"
#property description "QM5_41140 NZDJPY Carry-Unwind Crisis Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41140 - NZDJPY Carry-Unwind Crisis Momentum
// -----------------------------------------------------------------------------
// On each completed NZDJPY D1 bar, require synchronized five-session weakness
// across AUDJPY/NZDJPY/CADJPY/EURJPY, a strict target close below the previous
// 20-bar low, and elevated target realized volatility. Execute only a short
// NZDJPY position with a frozen completed-bar ATR stop. Auxiliary symbols are
// signal inputs only and are never execution targets.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41140;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    breadth_return_days          = 5;
input double breadth_threshold            = -0.010;
input int    breakout_lookback            = 20;
input int    vol_short_days               = 10;
input int    vol_baseline_days            = 60;
input int    atr_period                    = 14;
input double hard_stop_atr                 = 2.0;
input int    max_hold_bars                 = 10;

string   g_breadth_symbols[4] =
  {
   "AUDJPY.DWX",
   "NZDJPY.DWX",
   "CADJPY.DWX",
   "EURJPY.DWX"
  };
datetime g_last_exit_completed_bar = 0;

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 41140 && qm_magic_slot_offset == 0 &&
           breadth_return_days >= 1 && breadth_return_days <= 252 &&
           breadth_threshold < 0.0 && breadth_threshold > -1.0 &&
           breakout_lookback >= 2 && breakout_lookback <= 500 &&
           vol_short_days >= 2 && vol_short_days <= 252 &&
           vol_baseline_days >= 2 && vol_baseline_days <= 2520 &&
           atr_period >= 2 && atr_period <= 500 &&
           hard_stop_atr > 0.0 && hard_stop_atr <= 100.0 &&
           max_hold_bars >= 1 && max_hold_bars <= 252 &&
           RISK_PERCENT >= 0.0 && RISK_FIXED >= 0.0 &&
           (RISK_PERCENT > 0.0 || RISK_FIXED > 0.0) &&
           PORTFOLIO_WEIGHT > 0.0 &&
           qm_stress_reject_probability >= 0.0 &&
           qm_stress_reject_probability <= 1.0);
  }

int Strategy_RequiredHistoryBars()
  {
   int required = vol_baseline_days + vol_short_days + 5;
   required = MathMax(required, breakout_lookback + 5);
   required = MathMax(required, atr_period + 5);
   required = MathMax(required, breadth_return_days + 5);
   return required;
  }

int Strategy_OwnedPositionCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         ++count;
     }
   return count;
  }

bool Strategy_GetOwnedPosition(datetime &opened_at,
                               ulong &ticket_out,
                               bool &integrity_ok)
  {
   opened_at = 0;
   ticket_out = 0;
   integrity_ok = false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int count = 0;
   bool valid = true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++count;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(symbol != _Symbol || type != POSITION_TYPE_SELL || opened <= 0 ||
         open_price <= 0.0 || stop <= open_price || volume <= 0.0)
         valid = false;

      if(opened_at <= 0 || (opened > 0 && opened < opened_at))
        {
         opened_at = opened;
         ticket_out = ticket;
        }
     }

   integrity_ok = (count == 1 && valid);
   return (count > 0);
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_ExecutionMetadataValid(const string symbol,
                                     const MqlTick &tick)
  {
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask))
      return false;

   long trade_mode = 0;
   long swap_mode = 0;
   double swap_short = 0.0;
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, trade_mode) ||
      trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      trade_mode == SYMBOL_TRADE_MODE_LONGONLY ||
      !SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE, swap_mode) ||
      !SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT, swap_short) ||
      !MathIsValidNumber(swap_short))
      return false;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   return (point > 0.0 && tick_size > 0.0 && tick_value > 0.0 &&
           contract_size > 0.0 && volume_min > 0.0 &&
           volume_max >= volume_min && volume_step > 0.0 &&
           MathIsValidNumber(point) && MathIsValidNumber(tick_size) &&
           MathIsValidNumber(tick_value) &&
           MathIsValidNumber(contract_size));
  }

bool Strategy_RealizedVolatility(const MqlRates &rates[],
                                 const int start_index,
                                 const int days,
                                 double &volatility)
  {
   volatility = 0.0;
   if(days < 2 || start_index < 0 ||
      start_index + days >= ArraySize(rates))
      return false;

   double sum_squared = 0.0;
   for(int offset = 0; offset < days; ++offset)
     {
      const double newer = rates[start_index + offset].close;
      const double older = rates[start_index + offset + 1].close;
      if(newer <= 0.0 || older <= 0.0)
         return false;
      const double daily_return = MathLog(newer / older);
      if(!MathIsValidNumber(daily_return))
         return false;
      sum_squared += daily_return * daily_return;
     }

   volatility = MathSqrt(sum_squared / (double)days);
   return (volatility > 0.0 && MathIsValidNumber(volatility));
  }

double Strategy_Median(double &values[])
  {
   const int count = ArraySize(values);
   if(count <= 0)
      return 0.0;
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool Strategy_LoadTargetState(const datetime signal_time,
                              double &target_close,
                              double &prior_low,
                              double &current_vol,
                              double &baseline_median)
  {
   target_close = 0.0;
   prior_low = 0.0;
   current_vol = 0.0;
   baseline_median = 0.0;

   const int required = Strategy_RequiredHistoryBars();
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_D1, 1, required, rates); // perf-allowed: bounded target D1 history, called only from the framework new-bar entry hook.
   if(copied != required || ArraySize(rates) != required ||
      rates[0].time != signal_time || rates[0].close <= 0.0)
      return false;

   target_close = rates[0].close;
   double low = DBL_MAX;
   for(int index = 1; index <= breakout_lookback; ++index)
     {
      if(rates[index].time <= 0 || rates[index].low <= 0.0)
         return false;
      low = MathMin(low, rates[index].low);
     }
   if(low == DBL_MAX || low <= 0.0)
      return false;
   prior_low = low;

   if(!Strategy_RealizedVolatility(rates, 0, vol_short_days,
                                   current_vol))
      return false;

   double samples[];
   ArrayResize(samples, vol_baseline_days);
   for(int sample = 0; sample < vol_baseline_days; ++sample)
     {
      double value = 0.0;
      if(!Strategy_RealizedVolatility(rates, sample + 1,
                                      vol_short_days, value))
         return false;
      samples[sample] = value;
     }
   baseline_median = Strategy_Median(samples);
   return (baseline_median > 0.0 &&
           MathIsValidNumber(baseline_median));
  }

bool Strategy_LoadBreadthReturn(const datetime signal_time,
                                double &breadth_return)
  {
   breadth_return = 0.0;
   double sum = 0.0;
   for(int symbol_index = 0; symbol_index < 4; ++symbol_index)
     {
      const string symbol = g_breadth_symbols[symbol_index];
      if(!QM_SymbolAssertOrLog(symbol))
         return false;

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      const int requested = breadth_return_days + 1;
      const int copied =
         CopyRates(symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded synchronized breadth history, called only from the framework new-bar entry hook.
      if(copied != requested || ArraySize(rates) != requested ||
         rates[0].time != signal_time ||
         rates[0].close <= 0.0 ||
         rates[breadth_return_days].close <= 0.0)
         return false;

      const double component_return =
         rates[0].close / rates[breadth_return_days].close - 1.0;
      if(!MathIsValidNumber(component_return))
         return false;
      sum += component_return;
     }

   breadth_return = sum / 4.0;
   return MathIsValidNumber(breadth_return);
  }

bool Strategy_ChannelMidpoint(const datetime signal_time,
                              double &completed_close,
                              double &midpoint)
  {
   completed_close = 0.0;
   midpoint = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = breakout_lookback + 1;
   const int copied =
      CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded completed-bar exit channel, evaluated at most once per D1 bar.
   if(copied != requested || ArraySize(rates) != requested ||
      rates[0].time != signal_time || rates[0].close <= 0.0)
      return false;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int index = 1; index <= breakout_lookback; ++index)
     {
      if(rates[index].time <= 0 || rates[index].high <= 0.0 ||
         rates[index].low <= 0.0 || rates[index].high < rates[index].low)
         return false;
      highest = MathMax(highest, rates[index].high);
      lowest = MathMin(lowest, rates[index].low);
     }
   if(highest == -DBL_MAX || lowest == DBL_MAX || highest <= lowest)
      return false;

   completed_close = rates[0].close;
   midpoint = 0.5 * (highest + lowest);
   return (midpoint > 0.0 && MathIsValidNumber(midpoint));
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Entry-only data, quote, metadata, and news checks live below management.
   // OnInit binds the exact host/timeframe, so this hook must not suppress
   // protective management or completed-bar exits.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(Strategy_OwnedPositionCount() > 0)
      return false;

   const datetime signal_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact completed-bar anchor inside the framework new-bar entry hook.
   if(signal_time <= 0)
      return false;

   double breadth_return = 0.0;
   double target_close = 0.0;
   double prior_low = 0.0;
   double current_vol = 0.0;
   double baseline_median = 0.0;
   const bool breadth_valid =
      Strategy_LoadBreadthReturn(signal_time, breadth_return);
   const bool target_valid =
      Strategy_LoadTargetState(signal_time, target_close, prior_low,
                               current_vol, baseline_median);
   if(!breadth_valid || !target_valid)
      return false;

   const bool breadth_gate = (breadth_return <= breadth_threshold);
   const bool breakout_gate = (target_close < prior_low);
   const bool volatility_gate = (current_vol > baseline_median);
   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"signal_time\":%I64d,\"breadth\":%.12e,\"threshold\":%.12e,\"target_close\":%.8f,\"prior_low\":%.8f,\"rv10\":%.12e,\"rv60_median\":%.12e,\"breadth_gate\":%s,\"breakout_gate\":%s,\"volatility_gate\":%s}",
                            (long)signal_time,
                            breadth_return,
                            breadth_threshold,
                            target_close,
                            prior_low,
                            current_vol,
                            baseline_median,
                            breadth_gate ? "true" : "false",
                            breakout_gate ? "true" : "false",
                            volatility_gate ? "true" : "false"));
   if(!breadth_gate || !breakout_gate || !volatility_gate)
      return false;

   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(_Symbol, tick) ||
      !Strategy_ExecutionMetadataValid(_Symbol, tick))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, atr_period, 1);
   if(atr <= 0.0 || !MathIsValidNumber(atr))
      return false;
   const double stop =
      QM_StopATRFromValue(_Symbol, QM_SELL, tick.bid, atr, hard_stop_atr);
   if(stop <= tick.bid || !MathIsValidNumber(stop))
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = "CARRY_UNWIND_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime opened_at = 0;
   ulong ticket = 0;
   bool integrity_ok = false;
   if(!Strategy_GetOwnedPosition(opened_at, ticket, integrity_ok))
      return;
   if(!integrity_ok)
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
  }

bool Strategy_ExitSignal()
  {
   datetime opened_at = 0;
   ulong ticket = 0;
   bool integrity_ok = false;
   if(!Strategy_GetOwnedPosition(opened_at, ticket, integrity_ok) ||
      !integrity_ok)
      return false;

   const datetime completed_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed-bar exit gate.
   if(completed_time <= 0 || completed_time == g_last_exit_completed_bar)
      return false;
   g_last_exit_completed_bar = completed_time;

   const int entry_shift =
      iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: one bounded completed-D1 holding-period lookup.
   if(entry_shift >= max_hold_bars)
      return true;

   double completed_close = 0.0;
   double midpoint = 0.0;
   if(!Strategy_ChannelMidpoint(completed_time, completed_close, midpoint))
      return false;
   return (completed_close > midpoint);
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
   if(_Symbol != "NZDJPY.DWX" || _Period != PERIOD_D1 ||
      !Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

   for(int index = 0; index < 4; ++index)
      if(!SymbolSelect(g_breadth_symbols[index], true))
         return INIT_FAILED;

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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Approved D1 carry-unwind hold uses only the card's hard stop, ten-bar time exit, and completed channel exit"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(QM_MagicChecked(qm_ea_id, 0, _Symbol) <= 0)
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_SymbolGuardInit(g_breadth_symbols);
   QM_BasketWarmupHistory(g_breadth_symbols, PERIOD_D1,
                          Strategy_RequiredHistoryBars());
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41140\",\"ea\":\"nzdjpy-carry-unwind-crisis-momentum\",\"execution_symbol\":\"NZDJPY.DWX\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
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
