#property strict
#property version   "5.0"
#property description "QM5_12546 Katz seasonal crossover stoch confirmation stop D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12546;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_seasonal_years    = 10;
input int    strategy_min_years         = 6;
input int    strategy_seasonal_sma      = 15;
input int    strategy_sma_displacement  = 7;
input int    strategy_momentum_atr      = 20;
input int    strategy_exit_atr          = 50;
input double strategy_sl_atr_mult       = 1.0;
input double strategy_tp_atr_mult       = 4.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_long_max    = 25.0;
input double strategy_stoch_short_min   = 75.0;
input int    strategy_stop_valid_bars   = 3;
input int    strategy_time_exit_bars    = 10;
input int    strategy_history_bars      = 4500;

double g_seasonal_cum[367];
int    g_seasonal_cache_year = 0;

int DateDoy(const datetime t, int &year)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   year = dt.year;
   return dt.day_of_year + 1;
  }

double TrueRangeAt(const MqlRates &rates[], const int index, const int total)
  {
   if(index < 0 || index + 1 >= total)
      return 0.0;

   const double prev_close = rates[index + 1].close;
   const double hl = rates[index].high - rates[index].low;
   const double hc = MathAbs(rates[index].high - prev_close);
   const double lc = MathAbs(rates[index].low - prev_close);
   return MathMax(hl, MathMax(hc, lc));
  }

double AtrFromRates(const MqlRates &rates[], const int index, const int total, const int period)
  {
   if(period <= 0 || index < 0 || index + period >= total)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double tr = TrueRangeAt(rates, index + i, total);
      if(tr <= 0.0)
         return 0.0;
      sum += tr;
     }
   return sum / period;
  }

bool FindPriorYearMomentum(const MqlRates &rates[],
                           const int total,
                           const int target_year,
                           const int target_doy,
                           const int years_back,
                           double &out_mom)
  {
   out_mom = 0.0;
   const int wanted_year = target_year - years_back;
   int best_index = -1;
   int best_delta = 999;

   for(int i = 0; i < total - strategy_momentum_atr - 1; ++i)
     {
      int y = 0;
      const int d = DateDoy(rates[i].time, y);
      if(y != wanted_year)
         continue;

      const int delta = MathAbs(d - target_doy);
      if(delta <= 3 && delta < best_delta)
        {
         best_delta = delta;
         best_index = i;
        }
     }

   if(best_index < 0)
      return false;

   const double atr = AtrFromRates(rates, best_index, total, strategy_momentum_atr);
   if(atr <= 0.0)
      return false;

   out_mom = (rates[best_index].close - rates[best_index + 1].close) / atr;
   return true;
  }

double SeasonalMomentumForDoy(const MqlRates &rates[],
                              const int total,
                              const int target_year,
                              const int target_doy)
  {
   double sum = 0.0;
   int samples = 0;
   const int max_years = MathMax(strategy_min_years, strategy_seasonal_years);

   for(int y = 1; y <= max_years; ++y)
     {
      double mom = 0.0;
      if(!FindPriorYearMomentum(rates, total, target_year, target_doy, y, mom))
         continue;
      sum += mom;
      samples++;
     }

   if(samples < strategy_min_years)
      return EMPTY_VALUE;
   return sum / samples;
  }

bool EnsureSeasonalCache(const int target_year)
  {
   if(g_seasonal_cache_year == target_year)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: D1 seasonal cache rebuilt only on first closed-bar call per year.
   if(copied < strategy_min_years * 220)
      return false;

   g_seasonal_cum[0] = 0.0;
   for(int doy = 1; doy <= 366; ++doy)
     {
      const double mom = SeasonalMomentumForDoy(rates, copied, target_year, doy);
      if(mom == EMPTY_VALUE)
         g_seasonal_cum[doy] = EMPTY_VALUE;
      else if(doy > 1 && g_seasonal_cum[doy - 1] != EMPTY_VALUE)
         g_seasonal_cum[doy] = g_seasonal_cum[doy - 1] + mom;
      else
         g_seasonal_cum[doy] = mom;
     }

   g_seasonal_cache_year = target_year;
   return true;
  }

double SeasonalSmaAtDoy(const int doy)
  {
   const int start_doy = doy - strategy_sma_displacement;
   const int end_doy = start_doy - strategy_seasonal_sma + 1;
   if(end_doy < 1)
      return EMPTY_VALUE;

   double sum = 0.0;
   for(int d = start_doy; d >= end_doy; --d)
     {
      if(g_seasonal_cum[d] == EMPTY_VALUE)
         return EMPTY_VALUE;
      sum += g_seasonal_cum[d];
     }
   return sum / strategy_seasonal_sma;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card timeframe is D1 only; spread/news/time gates are framework-owned.
   if(_Period != PERIOD_D1)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_seasonal_sma <= 1 || strategy_sma_displacement < 0 ||
      strategy_min_years < 1 || strategy_seasonal_years < strategy_min_years)
      return false;

   if(HasOurPendingOrder())
      return false;

   MqlRates recent[];
   ArraySetAsSeries(recent, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_sma_displacement + strategy_seasonal_sma + 5, recent); // perf-allowed: EntrySignal is called only after QM_IsNewBar by the framework.
   if(copied < strategy_sma_displacement + strategy_seasonal_sma + 3)
      return false;

   int signal_year = 0;
   const int signal_doy = DateDoy(recent[0].time, signal_year);
   int prior_year = 0;
   const int prior_doy = DateDoy(recent[1].time, prior_year);
   if(signal_year != prior_year)
      return false;

   if(!EnsureSeasonalCache(signal_year))
      return false;

   const double seasonal_now = g_seasonal_cum[signal_doy];
   const double seasonal_prev = g_seasonal_cum[prior_doy];
   const double sma_now = SeasonalSmaAtDoy(signal_doy);
   const double sma_prev = SeasonalSmaAtDoy(prior_doy);
   if(seasonal_now == EMPTY_VALUE || seasonal_prev == EMPTY_VALUE ||
      sma_now == EMPTY_VALUE || sma_prev == EMPTY_VALUE)
      return false;

   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_D1,
                                     strategy_stoch_k,
                                     strategy_stoch_d,
                                     strategy_stoch_slowing,
                                     1);
   if(stoch_k == EMPTY_VALUE)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_exit_atr, 1);
   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(atr <= 0.0 || tick <= 0.0 || point <= 0.0)
      return false;

   int valid_bars = strategy_stop_valid_bars;
   if(valid_bars < 1)
      valid_bars = 1;
   const int expiry_seconds = valid_bars * PeriodSeconds(PERIOD_D1);
   const bool bullish_cross = (seasonal_now > sma_now && seasonal_prev <= sma_prev);
   const bool bearish_cross = (seasonal_now < sma_now && seasonal_prev >= sma_prev);

   if(bullish_cross && stoch_k < strategy_stoch_long_max)
     {
      const double entry = NormalizeDouble(recent[0].high + tick, digits);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= ask)
         return false;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = NormalizeDouble(entry - atr * strategy_sl_atr_mult, digits);
      req.tp = NormalizeDouble(entry + atr * strategy_tp_atr_mult, digits);
      req.expiration_seconds = expiry_seconds;
      req.reason = "KATZ_SEASONAL_LONG_STOP";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(bearish_cross && stoch_k > strategy_stoch_short_min)
     {
      const double entry = NormalizeDouble(recent[0].low - tick, digits);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry >= bid)
         return false;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = NormalizeDouble(entry + atr * strategy_sl_atr_mult, digits);
      req.tp = NormalizeDouble(entry - atr * strategy_tp_atr_mult, digits);
      req.expiration_seconds = expiry_seconds;
      req.reason = "KATZ_SEASONAL_SHORT_STOP";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // SES management is static: broker SL, broker TP, and time exit only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int hold_bars = strategy_time_exit_bars;
   if(hold_bars < 1)
      hold_bars = 1;
   const int hold_seconds = hold_bars * PeriodSeconds(PERIOD_D1);
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
      if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
