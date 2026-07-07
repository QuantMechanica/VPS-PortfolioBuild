#property strict
#property version   "5.0"
#property description "QM5_9136 Alpha Architect MRI Regime Timing"

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
input int    qm_ea_id                   = 9136;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_sma_period        = 200;
input int    strategy_return_period     = 252;
input int    strategy_trading_days_year = 252;
input int    strategy_mean_years        = 10;
input int    strategy_fallback_years    = 5;
input int    strategy_min_history_bars  = 1260;
input double strategy_mri_threshold     = 0.50;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.50;
input int    strategy_max_hold_d1_bars  = 21;
input int    strategy_spread_lookback   = 20;
input double strategy_spread_median_mult = 2.50;

int    g_strategy_day_key = 0;
bool   g_strategy_state_valid = false;
bool   g_strategy_have_prev_mri = false;
bool   g_strategy_have_prev_regime = false;
bool   g_strategy_regime_up = false;
bool   g_strategy_prev_regime_up = false;
bool   g_strategy_spread_blocks = false;
bool   g_strategy_exit_signal = false;
bool   g_strategy_time_stop_due = false;
int    g_strategy_entry_direction = 0;
double g_strategy_mri = 0.0;
double g_strategy_prev_mri = 0.0;
double g_strategy_atr = 0.0;

int Strategy_CopyBarsNeeded()
  {
   int needed = strategy_mean_years * strategy_trading_days_year + 2;
   const int min_needed = strategy_min_history_bars + 1;
   if(needed < min_needed)
      needed = min_needed;
   if(needed < strategy_return_period + 3)
      needed = strategy_return_period + 3;
   if(needed < strategy_sma_period + 3)
      needed = strategy_sma_period + 3;
   if(needed < strategy_spread_lookback + 2)
      needed = strategy_spread_lookback + 2;
   return needed;
  }

bool Strategy_LoadD1Rates(MqlRates &rates[], int &copied)
  {
   copied = 0;
   const int needed = Strategy_CopyBarsNeeded();
   if(needed <= 0)
      return false;

   ArrayResize(rates, needed);
   ArraySetAsSeries(rates, true);
   copied = CopyRates(_Symbol, PERIOD_D1, 1, needed, rates); // perf-allowed: daily MRI lookback cache, called once per new D1 calendar key.
   ArraySetAsSeries(rates, true);
   return (copied >= strategy_min_history_bars && copied > strategy_return_period + 1);
  }

bool Strategy_ComputeMRI(MqlRates &rates[], const int copied, const int shift, double &out_mri)
  {
   out_mri = 0.0;
   if(shift < 0 || strategy_return_period < 2 || strategy_trading_days_year <= 0)
      return false;
   if(strategy_mean_years <= 0 || strategy_fallback_years <= 0)
      return false;

   int window_bars = strategy_mean_years * strategy_trading_days_year;
   const int fallback_bars = strategy_fallback_years * strategy_trading_days_year;
   const int available = copied - shift;
   if(available < window_bars)
      window_bars = fallback_bars;
   if(available < window_bars || window_bars <= strategy_return_period + 1)
      return false;
   if(shift + strategy_return_period >= copied)
      return false;

   const double close_now = rates[shift].close;
   const double close_252 = rates[shift + strategy_return_period].close;
   if(close_now <= 0.0 || close_252 <= 0.0)
      return false;

   const double ret252 = close_now / close_252 - 1.0;

   double mean_sum = 0.0;
   int mean_count = 0;
   const int mean_samples = window_bars - strategy_return_period;
   for(int i = 0; i < mean_samples; ++i)
     {
      const int idx_now = shift + i;
      const int idx_past = idx_now + strategy_return_period;
      if(idx_past >= copied)
         break;
      const double c_now = rates[idx_now].close;
      const double c_past = rates[idx_past].close;
      if(c_now <= 0.0 || c_past <= 0.0)
         continue;
      mean_sum += c_now / c_past - 1.0;
      mean_count++;
     }
   if(mean_count <= 0)
      return false;

   const double mean_ret = mean_sum / (double)mean_count;

   double daily_sum = 0.0;
   double daily_sq_sum = 0.0;
   int daily_count = 0;
   for(int j = 0; j < strategy_return_period; ++j)
     {
      const int idx = shift + j;
      if(idx + 1 >= copied)
         break;
      const double c0 = rates[idx].close;
      const double c1 = rates[idx + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;
      const double r = c0 / c1 - 1.0;
      daily_sum += r;
      daily_sq_sum += r * r;
      daily_count++;
     }
   if(daily_count < 2)
      return false;

   double variance = (daily_sq_sum - daily_sum * daily_sum / (double)daily_count) / (double)(daily_count - 1);
   if(variance <= 0.0)
      return false;

   const double vol252 = MathSqrt(variance) * MathSqrt((double)strategy_trading_days_year);
   if(vol252 <= 0.0)
      return false;

   out_mri = (ret252 - mean_ret) / vol252;
   return true;
  }

double Strategy_MedianSpread(MqlRates &rates[], const int copied)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_spread_lookback <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);

   int max_count = strategy_spread_lookback;
   if(copied < max_count)
      max_count = copied;

   int count = 0;
   for(int i = 0; i < max_count; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread * point;
      count++;
     }
   if(count <= 0)
      return 0.0;

   for(int j = 1; j < count; ++j)
     {
      const double key = spreads[j];
      int k = j - 1;
      while(k >= 0 && spreads[k] > key)
        {
         spreads[k + 1] = spreads[k];
         k--;
        }
      spreads[k + 1] = key;
     }

   if((count % 2) == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[count / 2 - 1] + spreads[count / 2]);
  }

bool Strategy_SpreadBlocksEntry(MqlRates &rates[], const int copied)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!(ask > 0.0 && bid > 0.0 && ask > bid))
      return false;

   const double median_spread = Strategy_MedianSpread(rates, copied);
   if(median_spread <= 0.0 || strategy_spread_median_mult <= 0.0)
      return false;
   return ((ask - bid) > median_spread * strategy_spread_median_mult);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

int Strategy_D1BarsHeld(MqlRates &rates[], const int copied, const datetime entry_time)
  {
   if(entry_time <= 0)
      return 0;

   int held = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time > entry_time)
         held++;
      else
         break;
     }
   return held;
  }

void Strategy_UpdatePositionTimeStop(MqlRates &rates[], const int copied)
  {
   g_strategy_time_stop_due = false;
   if(strategy_max_hold_d1_bars <= 0)
      return;

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

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_D1BarsHeld(rates, copied, entry_time) >= strategy_max_hold_d1_bars)
        {
         g_strategy_time_stop_due = true;
         return;
        }
     }
  }

bool Strategy_RefreshState()
  {
   const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(day_key <= 0)
      return false;
   if(day_key == g_strategy_day_key)
      return g_strategy_state_valid;

   g_strategy_day_key = day_key;
   g_strategy_state_valid = false;
   g_strategy_have_prev_mri = false;
   g_strategy_have_prev_regime = false;
   g_strategy_spread_blocks = false;
   g_strategy_exit_signal = false;
   g_strategy_time_stop_due = false;
   g_strategy_entry_direction = 0;
   g_strategy_atr = 0.0;

   MqlRates rates[];
   int copied = 0;
   if(!Strategy_LoadD1Rates(rates, copied))
      return false;

   if(!Strategy_ComputeMRI(rates, copied, 0, g_strategy_mri))
      return false;
   g_strategy_have_prev_mri = Strategy_ComputeMRI(rates, copied, 1, g_strategy_prev_mri);

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2, PRICE_CLOSE);
   g_strategy_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(rates[0].close <= 0.0 || sma_now <= 0.0 || g_strategy_atr <= 0.0)
      return false;

   g_strategy_regime_up = (rates[0].close > sma_now);
   if(copied > 1 && rates[1].close > 0.0 && sma_prev > 0.0)
     {
      g_strategy_prev_regime_up = (rates[1].close > sma_prev);
      g_strategy_have_prev_regime = true;
     }

   const bool mri_zero_cross = g_strategy_have_prev_mri &&
                               ((g_strategy_prev_mri < 0.0 && g_strategy_mri >= 0.0) ||
                                (g_strategy_prev_mri > 0.0 && g_strategy_mri <= 0.0));
   const bool regime_flip = g_strategy_have_prev_regime &&
                            (g_strategy_prev_regime_up != g_strategy_regime_up);
   g_strategy_exit_signal = (mri_zero_cross || regime_flip);

   Strategy_UpdatePositionTimeStop(rates, copied);
   g_strategy_spread_blocks = Strategy_SpreadBlocksEntry(rates, copied);

   if(!g_strategy_spread_blocks)
     {
      if(g_strategy_regime_up)
        {
         if(g_strategy_mri < -strategy_mri_threshold)
            g_strategy_entry_direction = 1;
         else if(g_strategy_mri > strategy_mri_threshold)
            g_strategy_entry_direction = -1;
        }
      else
        {
         if(g_strategy_mri > strategy_mri_threshold)
            g_strategy_entry_direction = 1;
         else if(g_strategy_mri < -strategy_mri_threshold)
            g_strategy_entry_direction = -1;
        }
     }

   g_strategy_state_valid = true;
   return true;
  }

double Strategy_MarketPriceForSide(const QM_OrderType type)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(QM_OrderTypeIsBuy(type))
     {
      if(ask > 0.0)
         return ask;
      return bid;
     }
   if(bid > 0.0)
      return bid;
   return ask;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!Strategy_RefreshState())
      return false;
   if(g_strategy_entry_direction == 0 || Strategy_HasOpenPosition())
      return false;

   req.type = (g_strategy_entry_direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.tp = 0.0;

   const double entry_price = Strategy_MarketPriceForSide(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, g_strategy_atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (g_strategy_entry_direction > 0) ? "AA_MRI_LONG" : "AA_MRI_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies initial ATR stop and time/signal exits only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_RefreshState())
      return false;
   return (g_strategy_exit_signal || g_strategy_time_stop_due);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework news filter axes.
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
