#property strict
#property version   "5.0"
#property description "QM5_36007 NNFX VIDYA TRIX Fisher Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: QM5_36007_nnfx-vidya-trix-fisher-momentum (G0 APPROVED 2026-08-15)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 36007;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // Live setfile uses 0.5; tester defaults to fixed risk.
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vidya_period                  = 9;     // Card range: 5..15.
input int    strategy_cmo_period                    = 12;    // Card range: 8..20.
input int    strategy_trix_period                   = 14;    // Card range: 9..21.
input int    strategy_trix_signal_period            = 9;     // Card omits value; conventional fixed default.
input int    strategy_fisher_period                 = 10;    // Card omits value; conventional fixed default.
input int    strategy_mfi_period                    = 14;
input int    strategy_atr_period                    = 14;
input double strategy_mfi_midline                   = 50.0;
input double strategy_sl_atr_mult                   = 1.0;
input double strategy_tp1_atr_mult                  = 1.0;
input double strategy_spread_atr_mult               = 1.8;
input double strategy_daily_loss_limit_pct          = 2.0;
input double strategy_daily_drawdown_hard_stop_pct  = 2.5;
input double strategy_total_drawdown_stop_pct       = 5.0;
input double strategy_max_slippage_ticks            = 3.0;

// Closed-D1 signal cache. QM_CalendarPeriodKey provides the sanctioned,
// restart-safe D1 cadence without consuming the framework's entry new-bar gate.
int    g_signal_period_key = 0;
bool   g_signal_ready      = false;
double g_cached_close      = 0.0;
double g_cached_vidya      = 0.0;
double g_cached_trix       = 0.0;
double g_cached_trix_sig   = 0.0;
double g_cached_fisher     = 0.0;
double g_cached_mfi        = 0.0;
double g_cached_atr        = 0.0;
bool   g_long_exit_cross   = false;
bool   g_short_exit_cross  = false;
bool   g_entry_blocked     = true;

// Card loss-limit state. Daily limits reset on the broker D1 key; the total
// drawdown latch remains set for the life of the EA instance once breached.
int    g_risk_day_key             = 0;
double g_initial_equity           = 0.0;
double g_day_start_balance        = 0.0;
bool   g_daily_realized_halt      = false;
bool   g_daily_drawdown_halt      = false;
bool   g_total_drawdown_halt      = false;
bool   g_strategy_risk_halt       = false;

// One-position TP1 state. A protective SL at/through entry reconstructs the
// completed state after an ordinary terminal restart.
ulong    g_tp1_ticket      = 0;
double   g_tp1_price       = 0.0;
bool     g_tp1_done        = false;
datetime g_tp1_retry_after = 0;

bool Strategy_InputsValid()
  {
   return (strategy_vidya_period >= 2 &&
           strategy_cmo_period >= 2 &&
           strategy_trix_period >= 2 &&
           strategy_trix_signal_period >= 2 &&
           strategy_fisher_period >= 2 &&
           strategy_mfi_period >= 2 &&
           strategy_atr_period >= 2 &&
           strategy_mfi_midline >= 0.0 && strategy_mfi_midline <= 100.0 &&
           strategy_sl_atr_mult > 0.0 &&
           strategy_tp1_atr_mult > 0.0 &&
           strategy_spread_atr_mult > 0.0 &&
           strategy_daily_loss_limit_pct > 0.0 &&
           strategy_daily_drawdown_hard_stop_pct > 0.0 &&
           strategy_total_drawdown_stop_pct > 0.0 &&
           strategy_max_slippage_ticks > 0.0);
  }

bool Strategy_ComputeClosedBarSignals()
  {
   if(!Strategy_InputsValid())
      return false;

   const int mfi_handle = QM_IndMFI(_Symbol, PERIOD_D1, strategy_mfi_period);
   if(!QM_IndicatorWarmupReady(mfi_handle, 0, 1,
                               strategy_mfi_period + 2,
                               "nnfx_mfi"))
      return false;

   int warmup_bars = 256;
   int candidate = (strategy_trix_period * 3 + strategy_trix_signal_period) * 6;
   if(candidate > warmup_bars)
      warmup_bars = candidate;
   candidate = (strategy_vidya_period + strategy_cmo_period) * 8;
   if(candidate > warmup_bars)
      warmup_bars = candidate;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, warmup_bars, rates); // perf-allowed: one bounded D1 cache fill per QM_CalendarPeriodKey; no QM_VIDYA/TRIX/Fisher helper exists.
   int minimum_bars = strategy_fisher_period + 2;
   if(strategy_cmo_period + 2 > minimum_bars)
      minimum_bars = strategy_cmo_period + 2;
   if(strategy_trix_period * 3 + strategy_trix_signal_period + 2 > minimum_bars)
      minimum_bars = strategy_trix_period * 3 + strategy_trix_signal_period + 2;
   if(copied < minimum_bars)
      return false;

   double gains[];
   double losses[];
   ArrayResize(gains, copied);
   ArrayResize(losses, copied);
   ArrayInitialize(gains, 0.0);
   ArrayInitialize(losses, 0.0);

   const double vidya_alpha = 2.0 / ((double)strategy_vidya_period + 1.0);
   const double trix_alpha = 2.0 / ((double)strategy_trix_period + 1.0);
   const double signal_alpha = 2.0 / ((double)strategy_trix_signal_period + 1.0);

   double vidya = rates[0].close;
   double gain_sum = 0.0;
   double loss_sum = 0.0;
   double ema1 = rates[0].close;
   double ema2 = rates[0].close;
   double ema3 = rates[0].close;
   double previous_ema3 = ema3;
   double trix_signal = 0.0;
   bool trix_signal_seeded = false;
   double trix_previous = 0.0;
   double signal_previous = 0.0;
   double trix_current = 0.0;
   double signal_current = 0.0;

   for(int i = 1; i < copied; ++i)
     {
      const double close_now = rates[i].close;
      const double close_before = rates[i - 1].close;
      if(close_now <= 0.0 || close_before <= 0.0)
         return false;

      const double change = close_now - close_before;
      gains[i] = (change > 0.0) ? change : 0.0;
      losses[i] = (change < 0.0) ? -change : 0.0;
      gain_sum += gains[i];
      loss_sum += losses[i];
      if(i > strategy_cmo_period)
        {
         const int remove_index = i - strategy_cmo_period;
         gain_sum -= gains[remove_index];
         loss_sum -= losses[remove_index];
        }

      double cmo_abs = 0.0;
      const double cmo_denominator = gain_sum + loss_sum;
      if(i >= strategy_cmo_period && cmo_denominator > 0.0)
         cmo_abs = MathAbs(gain_sum - loss_sum) / cmo_denominator;
      const double adaptive_alpha = vidya_alpha * cmo_abs;
      vidya = adaptive_alpha * close_now + (1.0 - adaptive_alpha) * vidya;

      ema1 = trix_alpha * close_now + (1.0 - trix_alpha) * ema1;
      ema2 = trix_alpha * ema1 + (1.0 - trix_alpha) * ema2;
      ema3 = trix_alpha * ema2 + (1.0 - trix_alpha) * ema3;
      const double trix_value = (previous_ema3 > 0.0)
                                ? ((ema3 - previous_ema3) / previous_ema3) * 10000.0
                                : 0.0;
      previous_ema3 = ema3;

      if(!trix_signal_seeded)
        {
         trix_signal = trix_value;
         trix_signal_seeded = true;
        }
      else
         trix_signal = signal_alpha * trix_value + (1.0 - signal_alpha) * trix_signal;

      if(i == copied - 2)
        {
         trix_previous = trix_value;
         signal_previous = trix_signal;
        }
      if(i == copied - 1)
        {
         trix_current = trix_value;
         signal_current = trix_signal;
        }
     }

   const int newest = copied - 1;
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   const int fisher_first = newest - strategy_fisher_period + 1;
   for(int i = fisher_first; i <= newest; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         return false;
      if(rates[i].high > highest)
         highest = rates[i].high;
      if(rates[i].low < lowest)
         lowest = rates[i].low;
     }
   const double fisher_range = highest - lowest;
   if(fisher_range <= 0.0)
      return false;
   const double median = (rates[newest].high + rates[newest].low) * 0.5;
   double fisher_x = 2.0 * ((median - lowest) / fisher_range - 0.5);
   if(fisher_x > 0.999)
      fisher_x = 0.999;
   if(fisher_x < -0.999)
      fisher_x = -0.999;
   const double fisher = 0.5 * MathLog((1.0 + fisher_x) / (1.0 - fisher_x));

   const double mfi = QM_MFI(_Symbol, PERIOD_D1, strategy_mfi_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(!MathIsValidNumber(vidya) || !MathIsValidNumber(trix_current) ||
      !MathIsValidNumber(signal_current) || !MathIsValidNumber(fisher) ||
      !MathIsValidNumber(mfi) || !MathIsValidNumber(atr) ||
      rates[newest].close <= 0.0 || atr <= 0.0 || mfi < 0.0 || mfi > 100.0)
      return false;

   g_cached_close = rates[newest].close;
   g_cached_vidya = vidya;
   g_cached_trix = trix_current;
   g_cached_trix_sig = signal_current;
   g_cached_fisher = fisher;
   g_cached_mfi = mfi;
   g_cached_atr = atr;
   g_long_exit_cross = (trix_current <= signal_current && trix_previous > signal_previous);
   g_short_exit_cross = (trix_current >= signal_current && trix_previous < signal_previous);
   return true;
  }

void Strategy_AdvanceClosedBarState()
  {
   const int period_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(period_key <= 0 || period_key == g_signal_period_key)
      return;

   g_signal_period_key = period_key;
   g_signal_ready = Strategy_ComputeClosedBarSignals();
   if(!g_signal_ready)
     {
      g_long_exit_cross = false;
      g_short_exit_cross = false;
     }
  }

void Strategy_RefreshRiskState()
  {
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0 && equity > 0.0)
      g_initial_equity = equity;

   const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(day_key > 0 && day_key != g_risk_day_key)
     {
      g_risk_day_key = day_key;
      g_day_start_balance = balance;
      g_daily_realized_halt = false;
      g_daily_drawdown_halt = false;
     }
   else if(g_day_start_balance <= 0.0 && balance > 0.0)
      g_day_start_balance = balance;

   if(g_day_start_balance > 0.0)
     {
      const double realized_loss_pct = ((g_day_start_balance - balance) /
                                        g_day_start_balance) * 100.0;
      const double daily_drawdown_pct = ((g_day_start_balance - equity) /
                                         g_day_start_balance) * 100.0;
      if(realized_loss_pct >= strategy_daily_loss_limit_pct)
         g_daily_realized_halt = true;
      if(daily_drawdown_pct >= strategy_daily_drawdown_hard_stop_pct)
         g_daily_drawdown_halt = true;
     }

   if(g_initial_equity > 0.0)
     {
      const double total_drawdown_pct = ((g_initial_equity - equity) /
                                         g_initial_equity) * 100.0;
      if(total_drawdown_pct >= strategy_total_drawdown_stop_pct)
         g_total_drawdown_halt = true;
     }

   g_strategy_risk_halt = (g_daily_realized_halt ||
                           g_daily_drawdown_halt ||
                           g_total_drawdown_halt);
  }

void Strategy_ConfigureEntrySlippage()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int deviation_points = 1;
   if(point > 0.0 && tick_size > 0.0)
     {
      deviation_points = (int)MathCeil(strategy_max_slippage_ticks * tick_size / point);
      if(deviation_points < 1)
         deviation_points = 1;
     }
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
  }

void Strategy_ResetTp1State()
  {
   g_tp1_ticket = 0;
   g_tp1_price = 0.0;
   g_tp1_done = false;
   g_tp1_retry_after = 0;
  }

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, loss limits, and max-one-position admission)
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   Strategy_AdvanceClosedBarState();
   Strategy_RefreshRiskState();

   bool blocked = (!g_signal_ready || g_strategy_risk_halt);

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now <= 0)
      blocked = true;
   else
     {
      MqlDateTime utc_parts;
      TimeToStruct(utc_now, utc_parts);
      const int utc_minute = utc_parts.hour * 60 + utc_parts.min;
      if(utc_minute >= (23 * 60 + 55) || utc_minute <= 5)
         blocked = true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      blocked = true;
   else if(ask > bid && g_cached_atr > 0.0 &&
           (ask - bid) > strategy_spread_atr_mult * g_cached_atr)
      blocked = true;

   int open_count = 0;
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
      open_count = QM_TM_OpenPositionCount(magic);
   else
      blocked = true;
   if(open_count >= 1)
      blocked = true;

   g_entry_blocked = blocked;

   // Keep management and exits reachable while exposure exists. EntrySignal
   // consumes the cached block flag, so this still enforces every card filter.
   if(open_count == 0)
      return blocked;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(g_entry_blocked || g_strategy_risk_halt || !g_signal_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(g_cached_close > g_cached_vidya &&
      g_cached_trix > g_cached_trix_sig &&
      g_cached_fisher > 0.0 &&
      g_cached_mfi >= strategy_mfi_midline)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price,
                                   g_cached_atr, strategy_sl_atr_mult);
      if(req.sl <= 0.0 || req.sl >= entry_price)
         return false;
      req.reason = "nnfx_vidya_trix_fisher_long";
      Strategy_ConfigureEntrySlippage();
      return true;
     }

   if(g_cached_close < g_cached_vidya &&
      g_cached_trix < g_cached_trix_sig &&
      g_cached_fisher < 0.0 &&
      g_cached_mfi <= strategy_mfi_midline)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price,
                                   g_cached_atr, strategy_sl_atr_mult);
      if(req.sl <= entry_price)
         return false;
      req.reason = "nnfx_vidya_trix_fisher_short";
      Strategy_ConfigureEntrySlippage();
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      found_position = true;
      if(g_strategy_risk_halt)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_KILLSWITCH);
         continue;
        }

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || point <= 0.0)
         continue;

      if(ticket != g_tp1_ticket)
        {
         g_tp1_ticket = ticket;
         g_tp1_retry_after = 0;
         g_tp1_done = ((position_type == POSITION_TYPE_BUY && current_sl >= open_price) ||
                       (position_type == POSITION_TYPE_SELL && current_sl > 0.0 && current_sl <= open_price));

         double initial_risk_distance = MathAbs(open_price - current_sl);
         if(initial_risk_distance <= point && g_cached_atr > 0.0)
            initial_risk_distance = strategy_sl_atr_mult * g_cached_atr;
         const double tp1_distance = (strategy_sl_atr_mult > 0.0)
                                     ? initial_risk_distance * strategy_tp1_atr_mult /
                                       strategy_sl_atr_mult
                                     : strategy_tp1_atr_mult * g_cached_atr;
         if(position_type == POSITION_TYPE_BUY)
            g_tp1_price = QM_TM_NormalizePrice(_Symbol, open_price + tp1_distance);
         else
            g_tp1_price = QM_TM_NormalizePrice(_Symbol, open_price - tp1_distance);
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool tp1_reached = (position_type == POSITION_TYPE_BUY)
                               ? (bid > 0.0 && bid >= g_tp1_price)
                               : (ask > 0.0 && ask <= g_tp1_price);

      if(!g_tp1_done && g_tp1_price > 0.0 && tp1_reached)
        {
         const datetime now = TimeCurrent();
         if(now < g_tp1_retry_after)
            continue;

         const double volume = PositionGetDouble(POSITION_VOLUME);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
         const double remaining_lots = volume - close_lots;
         const bool can_partial = (close_lots > 0.0 && close_lots < volume &&
                                   min_lot > 0.0 && step > 0.0 &&
                                   remaining_lots + step * 0.1 >= min_lot);
         if(!can_partial)
            g_tp1_done = true;
         else if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
           {
            g_tp1_done = true;
            g_tp1_retry_after = 0;
           }
         else
           {
            g_tp1_retry_after = now + 60;
            continue;
           }
        }

      if(g_tp1_done && PositionSelectByTicket(ticket))
        {
         const double be_offset = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
         const double selected_sl = PositionGetDouble(POSITION_SL);
         if(be_offset <= 0.0)
            continue;

         if(position_type == POSITION_TYPE_BUY)
           {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + be_offset);
            if(target_sl > selected_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "tp1_be_plus_one_pip");
           }
         else
           {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - be_offset);
            if(selected_sl <= 0.0 || target_sl < selected_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "tp1_be_plus_one_pip");
           }
        }
     }

   if(!found_position)
      Strategy_ResetTp1State();
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   if(!g_signal_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && g_long_exit_cross)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_short_exit_cross)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for P8 News Impact; central two-axis gate follows)
// -----------------------------------------------------------------------------

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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
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
