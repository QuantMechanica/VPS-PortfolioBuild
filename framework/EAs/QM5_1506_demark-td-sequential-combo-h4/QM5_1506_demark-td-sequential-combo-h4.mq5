#property strict
#property version   "5.0"
#property description "QM5_1506 DeMark TD Sequential Combo H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1506;
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
input int    strategy_setup_bars              = 9;
input int    strategy_setup_compare_lag       = 4;
input int    strategy_countdown_target        = 13;
input int    strategy_valid_setup_window      = 60;
input int    strategy_d1_sma_period           = 50;
input int    strategy_d1_slope_bars           = 5;
input int    strategy_atr_period              = 14;
input int    strategy_atr_baseline_bars       = 200;
input double strategy_atr_floor_mult          = 0.60;
input double strategy_sl_atr_mult             = 1.0;
input double strategy_max_sl_atr_mult         = 2.5;
input double strategy_tp1_atr_mult            = 1.5;
input double strategy_tp1_close_fraction      = 0.60;
input double strategy_max_spread_atr_mult     = 0.15;
input int    strategy_cooldown_bars           = 30;
input int    strategy_time_stop_bars          = 24;
input int    strategy_min_warmup_bars         = 300;

datetime g_last_entry_time = 0;
ulong    g_tp1_ticket = 0;
double   g_entry_atr = 0.0;

int MaxInt(const int left, const int right)
  {
   return (left > right) ? left : right;
  }

bool ReadClosedBar(const string symbol, const ENUM_TIMEFRAMES tf, const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, shift, 1, rates); // perf-allowed: one closed bar read inside strategy hook.
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
  }

bool LoadH4Rates(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates); // perf-allowed: TD Combo structural bar-window scan runs after QM_IsNewBar.
   return (copied >= bars_needed);
  }

double AverageATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int bars, const int start_shift)
  {
   if(period <= 0 || bars <= 0 || start_shift < 1)
      return 0.0;

   double total = 0.0;
   int samples = 0;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double value = QM_ATR(symbol, tf, period, shift);
      if(value <= 0.0)
         continue;
      total += value;
      samples++;
     }

   if(samples < MathMin(20, bars))
      return 0.0;
   return total / samples;
  }

bool StrategyParametersValid()
  {
   if(strategy_setup_bars <= 0 ||
      strategy_setup_compare_lag <= 0 ||
      strategy_countdown_target <= 0 ||
      strategy_valid_setup_window <= 0 ||
      strategy_d1_sma_period <= 0 ||
      strategy_d1_slope_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_baseline_bars <= 0 ||
      strategy_atr_floor_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_max_sl_atr_mult <= strategy_sl_atr_mult ||
      strategy_tp1_atr_mult <= 0.0 ||
      strategy_tp1_close_fraction <= 0.0 ||
      strategy_tp1_close_fraction >= 1.0 ||
      strategy_min_warmup_bars < 100)
      return false;
   return true;
  }

bool HasOpenPositionForMagic()
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

bool CooldownAllowsEntry()
  {
   if(strategy_cooldown_bars <= 0 || g_last_entry_time <= 0)
      return true;
   const int shift = iBarShift(_Symbol, PERIOD_H4, g_last_entry_time, false);
   if(shift < 0)
      return true;
   return (shift >= strategy_cooldown_bars);
  }

double TrueHigh(MqlRates &rates[], const int idx)
  {
   const int n = ArraySize(rates);
   if(idx < 0 || idx >= n)
      return 0.0;
   const double prev_close = (idx + 1 < n) ? rates[idx + 1].close : rates[idx].close;
   return MathMax(rates[idx].high, prev_close);
  }

double TrueLow(MqlRates &rates[], const int idx)
  {
   const int n = ArraySize(rates);
   if(idx < 0 || idx >= n)
      return 0.0;
   const double prev_close = (idx + 1 < n) ? rates[idx + 1].close : rates[idx].close;
   return MathMin(rates[idx].low, prev_close);
  }

bool IsSellSetupAt(MqlRates &rates[], const int setup_shift)
  {
   const int n = ArraySize(rates);
   if(setup_shift < 0 || setup_shift + strategy_setup_bars + strategy_setup_compare_lag >= n)
      return false;

   for(int i = 0; i < strategy_setup_bars; ++i)
     {
      const int idx = setup_shift + i;
      if(rates[idx].close <= rates[idx + strategy_setup_compare_lag].close)
         return false;
     }
   return true;
  }

bool IsBuySetupAt(MqlRates &rates[], const int setup_shift)
  {
   const int n = ArraySize(rates);
   if(setup_shift < 0 || setup_shift + strategy_setup_bars + strategy_setup_compare_lag >= n)
      return false;

   for(int i = 0; i < strategy_setup_bars; ++i)
     {
      const int idx = setup_shift + i;
      if(rates[idx].close >= rates[idx + strategy_setup_compare_lag].close)
         return false;
     }
   return true;
  }

double SetupTrueLow(MqlRates &rates[], const int setup_shift)
  {
   double target = DBL_MAX;
   for(int i = 0; i < strategy_setup_bars; ++i)
      target = MathMin(target, TrueLow(rates, setup_shift + i));
   return (target == DBL_MAX) ? 0.0 : target;
  }

double SetupTrueHigh(MqlRates &rates[], const int setup_shift)
  {
   double target = 0.0;
   for(int i = 0; i < strategy_setup_bars; ++i)
      target = MathMax(target, TrueHigh(rates, setup_shift + i));
   return target;
  }

bool CountdownCancellationHit(MqlRates &rates[], const int idx, const bool sell_countdown)
  {
   const int n = ArraySize(rates);
   if(idx < 0 || idx + strategy_setup_compare_lag >= n)
      return false;

   if(sell_countdown)
      return (rates[idx].close < rates[idx + strategy_setup_compare_lag].close);
   return (rates[idx].close > rates[idx + strategy_setup_compare_lag].close);
  }

bool ComboCountdownBarValid(MqlRates &rates[], const int idx, const int ordinal, const bool sell_countdown)
  {
   const int n = ArraySize(rates);
   if(idx < 0 || ordinal <= 0 || idx + 2 >= n || idx + 1 + ordinal >= n)
      return false;

   if(sell_countdown)
     {
      return (rates[idx].close > rates[idx + 2].high &&
              rates[idx].close > rates[idx + 1].close &&
              rates[idx].close > rates[idx + 1 + ordinal].close &&
              rates[idx].high  > rates[idx + 1].high);
     }

   return (rates[idx].close < rates[idx + 2].low &&
           rates[idx].close < rates[idx + 1].close &&
           rates[idx].close < rates[idx + 1 + ordinal].close &&
           rates[idx].low   < rates[idx + 1].low);
  }

bool CountdownCompletesNow(MqlRates &rates[], const int setup_shift, const bool sell_countdown, double &tdst_target)
  {
   tdst_target = 0.0;
   int count = 0;

   for(int idx = setup_shift - 1; idx >= 0; --idx)
     {
      if(CountdownCancellationHit(rates, idx, sell_countdown))
         return false;

      const int ordinal = count + 1;
      if(!ComboCountdownBarValid(rates, idx, ordinal, sell_countdown))
         continue;

      count = ordinal;
      if(count >= strategy_countdown_target)
        {
         if(idx != 0)
            return false;
         tdst_target = sell_countdown ? SetupTrueLow(rates, setup_shift)
                                      : SetupTrueHigh(rates, setup_shift);
         return (tdst_target > 0.0);
        }
     }

   return false;
  }

bool FindTDComboSignal(MqlRates &rates[], QM_OrderType &side, double &tdst_target)
  {
   side = QM_BUY;
   tdst_target = 0.0;

   const int max_setup_shift = MathMin(strategy_valid_setup_window, ArraySize(rates) - strategy_setup_bars - strategy_setup_compare_lag - 2);
   for(int setup_shift = 1; setup_shift <= max_setup_shift; ++setup_shift)
     {
      if(IsSellSetupAt(rates, setup_shift) &&
         CountdownCompletesNow(rates, setup_shift, true, tdst_target))
        {
         side = QM_SELL;
         return true;
        }

      if(IsBuySetupAt(rates, setup_shift) &&
         CountdownCompletesNow(rates, setup_shift, false, tdst_target))
        {
         side = QM_BUY;
         return true;
        }
     }

   return false;
  }

bool MacroBiasAllows(const QM_OrderType side)
  {
   MqlRates d1_bar;
   if(!ReadClosedBar(_Symbol, PERIOD_D1, 1, d1_bar))
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1 + strategy_d1_slope_bars);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return false;

   if(side == QM_BUY)
      return (d1_bar.close > sma_now && sma_now > sma_prev);
   return (d1_bar.close < sma_now && sma_now < sma_prev);
  }

bool AtrFloorAllows(double &atr)
  {
   atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double avg_atr = AverageATR(_Symbol, PERIOD_H4, strategy_atr_period, strategy_atr_baseline_bars, 1);
   if(atr <= 0.0 || avg_atr <= 0.0)
      return false;
   return (atr > avg_atr * strategy_atr_floor_mult);
  }

bool SpreadAllowsEntry(const double atr)
  {
   if(strategy_max_spread_atr_mult <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(!(spread > 0.0))
      return true;
   return (spread <= atr * strategy_max_spread_atr_mult);
  }

bool BuildEntryRequest(MqlRates &rates[], const QM_OrderType side, const double tdst_target, const double atr, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0 || tdst_target <= 0.0)
      return false;

   const double true_high = TrueHigh(rates, 0);
   const double true_low = TrueLow(rates, 0);
   const double raw_sl = (side == QM_BUY)
                         ? true_low - atr * strategy_sl_atr_mult
                         : true_high + atr * strategy_sl_atr_mult;
   const double tp1 = (side == QM_BUY)
                      ? entry + atr * strategy_tp1_atr_mult
                      : entry - atr * strategy_tp1_atr_mult;

   if(side == QM_BUY)
     {
      if(raw_sl >= entry || tdst_target <= tp1)
         return false;
     }
   else
     {
      if(raw_sl <= entry || tdst_target >= tp1)
         return false;
     }

   const double sl_distance = MathAbs(entry - raw_sl);
   if(sl_distance <= 0.0 || sl_distance > atr * strategy_max_sl_atr_mult)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
   req.tp = QM_TM_NormalizePrice(_Symbol, tdst_target);
   req.reason = (side == QM_BUY) ? "TD_COMBO_BUY_13" : "TD_COMBO_SELL_13";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   g_last_entry_time = rates[0].time;
   g_entry_atr = atr;
   g_tp1_ticket = 0;
   return true;
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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return false;
   if(!StrategyParametersValid())
      return false;
   if(HasOpenPositionForMagic())
      return false;
   if(!CooldownAllowsEntry())
      return false;

   MqlRates rates[];
   const int bars_needed = MaxInt(strategy_min_warmup_bars,
                                  strategy_valid_setup_window + strategy_setup_bars + strategy_setup_compare_lag + strategy_countdown_target + 20);
   if(!LoadH4Rates(rates, bars_needed))
      return false;

   QM_OrderType side = QM_BUY;
   double tdst_target = 0.0;
   if(!FindTDComboSignal(rates, side, tdst_target))
      return false;
   if(!MacroBiasAllows(side))
      return false;

   double atr = 0.0;
   if(!AtrFloorAllows(atr))
      return false;
   if(!SpreadAllowsEntry(atr))
      return false;

   return BuildEntryRequest(rates, side, tdst_target, atr, req);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool active_tracked_ticket = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(ticket == g_tp1_ticket)
        {
         active_tracked_ticket = true;
         continue;
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      if(entry <= 0.0 || lots <= 0.0)
         continue;

      double atr_for_tp1 = g_entry_atr;
      if(atr_for_tp1 <= 0.0)
         atr_for_tp1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      if(atr_for_tp1 <= 0.0)
         continue;

      const double target = (ptype == POSITION_TYPE_BUY)
                            ? entry + atr_for_tp1 * strategy_tp1_atr_mult
                            : entry - atr_for_tp1 * strategy_tp1_atr_mult;
      const double price = (ptype == POSITION_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0.0)
         continue;

      const bool hit = (ptype == POSITION_TYPE_BUY) ? (price >= target) : (price <= target);
      if(!hit)
         continue;

      if(QM_Exit(ticket, QM_EXIT_TP_HIT, lots * strategy_tp1_close_fraction))
        {
         g_tp1_ticket = ticket;
         active_tracked_ticket = true;
        }
     }

   if(!active_tracked_ticket)
      g_tp1_ticket = 0;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_stop_bars <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, PERIOD_H4, opened, false);
      if(open_shift >= strategy_time_stop_bars)
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
