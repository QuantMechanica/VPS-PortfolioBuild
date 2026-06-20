#property strict
#property version   "5.0"
#property description "QM5_11275 iaf-st-ema — SuperTrend flip + EMA crossover confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11275 iaf-st-ema
// -----------------------------------------------------------------------------
// Source: coding-kitties/investing-algorithm-framework,
// examples/tutorial/strategies/supertrend_ema_confirmation/strategy.py.
//
// Strategy mechanics are evaluated once per closed bar by Strategy_EntrySignal;
// Strategy_ExitSignal only reads the cached close decision so it stays O(1) on
// the per-tick path and does not consume QM_IsNewBar().
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11275;
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
input int    strategy_st_atr_period      = 10;
input double strategy_st_factor          = 3.0;
input int    strategy_ema_short_period   = 20;
input int    strategy_ema_long_period    = 100;
input int    strategy_confirm_lookback   = 10;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_upper          = 70.0;
input double strategy_rsi_lower          = 30.0;
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input double strategy_stop_loss_pct      = 5.0;
input double strategy_take_profit_pct    = 10.0;
input double strategy_spread_pct_of_stop = 15.0;

bool g_entry_signal_cached = false;
bool g_exit_signal_cached = false;

bool Strategy_SuperTrendDirSeries(const string sym,
                                  const ENUM_TIMEFRAMES tf,
                                  const int atr_period,
                                  const double factor,
                                  const int n_shifts,
                                  const int warmup_bars,
                                  int &dir_out[],
                                  double &last_close)
  {
   if(n_shifts < 1 || atr_period < 1 || factor <= 0.0)
      return false;

   ArrayResize(dir_out, n_shifts);
   ArrayInitialize(dir_out, 0);
   last_close = 0.0;

   const int bars_needed = n_shifts + warmup_bars + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(sym, tf, 1, bars_needed, rates); // perf-allowed: called from Strategy_EntrySignal after skeleton QM_IsNewBar()
   if(copied < n_shifts + 2)
      return false;

   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   double prev_close = 0.0;
   int prev_dir = 0;
   bool seeded = false;

   for(int idx = copied - 1; idx >= 0; --idx)
     {
      const int shift = idx + 1;
      const double high = rates[idx].high;
      const double low = rates[idx].low;
      const double close = rates[idx].close;
      const double atr = QM_ATR(sym, tf, atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         continue;

      const double hl2 = (high + low) / 2.0;
      const double basic_upper = hl2 + factor * atr;
      const double basic_lower = hl2 - factor * atr;
      int dir = 0;

      if(!seeded)
        {
         prev_final_upper = basic_upper;
         prev_final_lower = basic_lower;
         dir = (close >= hl2) ? 1 : -1;
         seeded = true;
        }
      else
        {
         double final_upper = basic_upper;
         if(!(basic_upper < prev_final_upper || prev_close > prev_final_upper))
            final_upper = prev_final_upper;

         double final_lower = basic_lower;
         if(!(basic_lower > prev_final_lower || prev_close < prev_final_lower))
            final_lower = prev_final_lower;

         if(prev_dir <= 0)
            dir = (close > final_upper) ? 1 : -1;
         else
            dir = (close < final_lower) ? -1 : 1;

         prev_final_upper = final_upper;
         prev_final_lower = final_lower;
        }

      prev_dir = dir;
      prev_close = close;

      if(idx < n_shifts)
         dir_out[idx] = dir;
      if(idx == 0)
         last_close = close;
     }

   return seeded && last_close > 0.0;
  }

void Strategy_UpdateClosedBarSignals()
  {
   g_entry_signal_cached = false;
   g_exit_signal_cached = false;

   if(strategy_confirm_lookback < 1 ||
      strategy_ema_short_period < 1 ||
      strategy_ema_long_period < 1 ||
      strategy_rsi_period < 1 ||
      strategy_bb_period < 1 ||
      strategy_stop_loss_pct <= 0.0 ||
      strategy_take_profit_pct <= 0.0)
      return;

   const int warmup = (int)MathMax(strategy_confirm_lookback + 5, 3 * strategy_st_atr_period);
   int st_dir[];
   double close1 = 0.0;
   if(!Strategy_SuperTrendDirSeries(_Symbol,
                                    _Period,
                                    strategy_st_atr_period,
                                    strategy_st_factor,
                                    strategy_confirm_lookback + 1,
                                    warmup,
                                    st_dir,
                                    close1))
      return;

   if(ArraySize(st_dir) < strategy_confirm_lookback + 1)
      return;

   bool st_flipped_bull = false;
   bool st_flipped_bear = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const int d_now = st_dir[s - 1];
      const int d_prev = st_dir[s];
      if(d_now > 0 && d_prev <= 0)
         st_flipped_bull = true;
      if(d_now < 0 && d_prev >= 0)
         st_flipped_bear = true;
     }

   const double ema_short_1 = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_long_1 = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 1);
   if(ema_short_1 <= 0.0 || ema_long_1 <= 0.0)
      return;

   bool ema_crossed_up = false;
   bool ema_crossed_down = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const double es_now = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s);
      const double el_now = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s);
      const double es_prev = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s + 1);
      const double el_prev = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s + 1);
      if(es_now <= 0.0 || el_now <= 0.0 || es_prev <= 0.0 || el_prev <= 0.0)
         continue;

      if(es_prev <= el_prev && es_now > el_now)
         ema_crossed_up = true;
      if(es_prev >= el_prev && es_now < el_now)
         ema_crossed_down = true;
     }

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return;

   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0)
      return;

   if(st_dir[0] > 0 &&
      st_flipped_bull &&
      ema_crossed_up &&
      ema_short_1 > ema_long_1 &&
      rsi1 < strategy_rsi_upper &&
      close1 < bb_upper)
      g_entry_signal_cached = true;

   if(st_dir[0] < 0 &&
      st_flipped_bear &&
      ema_crossed_down &&
      ema_short_1 < ema_long_1)
     {
      const bool suppress_capitulation_exit = (rsi1 <= strategy_rsi_lower && close1 <= bb_lower);
      if(!suppress_capitulation_exit)
         g_exit_signal_cached = true;
     }
  }

// No Trade Filter (time, spread, news): no card-specific time filter; news is
// delegated to the framework hook below. Spread only blocks genuinely wide
// modeled spread and therefore passes .DWX zero-spread tester ticks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double entry = ask;
   const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_stop_loss_pct / 100.0));
   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Trade Entry: long when SuperTrend has flipped bullish within the confirmation
// lookback, EMA(20) crossed above EMA(100) within the same lookback, RSI is not
// overbought, and the close is below the upper Bollinger band.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_UpdateClosedBarSignals();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_entry_signal_cached)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_stop_loss_pct / 100.0));
   const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_take_profit_pct / 100.0));
   if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "st_ema_confirm_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: the card specifies one position with fixed stop/take-profit;
// no trailing, partial close, or break-even rule is added.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close when a bearish SuperTrend flip and bearish EMA cross are
// present in the cached closed-bar state, unless the RSI/Bollinger capitulation
// suppression rule applied during signal calculation.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   return g_exit_signal_cached;
  }

// News Filter Hook: callable P8 hook; no strategy-specific override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
