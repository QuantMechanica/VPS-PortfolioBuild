#property strict
#property version   "5.0"
#property description "QM5_11127 TradingMarkets ConnorsRSI Pullback"

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
input int    qm_ea_id                   = 11127;
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
input int    strategy_crsi_rsi_period        = 3;
input int    strategy_crsi_streak_rsi_period = 2;
input int    strategy_crsi_rank_period       = 100;
input double strategy_crsi_entry             = 5.0;
input double strategy_crsi_exit              = 70.0;
input int    strategy_sma_period             = 200;
input int    strategy_atr_period             = 14;
input int    strategy_pullback_lookback      = 20;
input double strategy_pullback_atr_mult      = 2.0;
input double strategy_closing_range_max      = 0.25;
input double strategy_entry_limit_atr_mult   = 1.0;
input double strategy_atr_sl_mult            = 2.5;
input int    strategy_max_hold_bars          = 7;
input int    strategy_max_spread_points      = 300;

double g_last_closed_crsi = 0.0;
bool   g_last_closed_crsi_valid = false;

bool Strategy_HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

void Strategy_RemoveExpiredPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   if(d1_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_LIMIT)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && (now - setup_time) >= d1_seconds)
         QM_TM_RemovePendingOrder(ticket, "one_d1_bar_unfilled");
     }
  }

bool Strategy_RsiChron(const double &values[],
                       const int count,
                       const int period,
                       const int index,
                       double &out_rsi)
  {
   out_rsi = 0.0;
   if(period <= 0 || index < period || index >= count)
      return false;

   double avg_gain = 0.0;
   double avg_loss = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      const double change = values[i] - values[i - 1];
      if(change > 0.0)
         avg_gain += change;
      else
         avg_loss -= change;
     }

   avg_gain /= (double)period;
   avg_loss /= (double)period;

   for(int i = period + 1; i <= index; ++i)
     {
      const double change = values[i] - values[i - 1];
      const double gain = (change > 0.0) ? change : 0.0;
      const double loss = (change < 0.0) ? -change : 0.0;
      avg_gain = ((avg_gain * (period - 1)) + gain) / (double)period;
      avg_loss = ((avg_loss * (period - 1)) + loss) / (double)period;
     }

   if(avg_loss <= 0.0)
     {
      out_rsi = 100.0;
      return true;
     }
   if(avg_gain <= 0.0)
     {
      out_rsi = 0.0;
      return true;
     }

   const double rs = avg_gain / avg_loss;
   out_rsi = 100.0 - (100.0 / (1.0 + rs));
   return true;
  }

bool Strategy_ConnorsRsiFromRates(const MqlRates &rates[],
                                  const int rates_total,
                                  double &out_crsi)
  {
   out_crsi = 0.0;
   if(rates_total < strategy_crsi_rank_period + 5)
      return false;

   double closes[];
   ArrayResize(closes, rates_total);
   for(int i = 0; i < rates_total; ++i)
     {
      const double close_value = rates[rates_total - 1 - i].close;
      if(close_value <= 0.0)
         return false;
      closes[i] = close_value;
     }

   const int current = rates_total - 2;
   if(current <= strategy_crsi_rank_period || current < strategy_crsi_streak_rsi_period)
      return false;

   double streaks[];
   ArrayResize(streaks, rates_total);
   streaks[0] = 0.0;
   for(int i = 1; i < rates_total; ++i)
     {
      if(closes[i] > closes[i - 1])
         streaks[i] = (streaks[i - 1] > 0.0 ? streaks[i - 1] : 0.0) + 1.0;
      else if(closes[i] < closes[i - 1])
         streaks[i] = (streaks[i - 1] < 0.0 ? streaks[i - 1] : 0.0) - 1.0;
      else
         streaks[i] = 0.0;
     }

   double streak_rsi = 0.0;
   if(!Strategy_RsiChron(streaks, rates_total, strategy_crsi_streak_rsi_period, current, streak_rsi))
      return false;

   const double current_return = (closes[current] / closes[current - 1]) - 1.0;
   int lower_count = 0;
   for(int i = current - strategy_crsi_rank_period; i < current; ++i)
     {
      if(i <= 0)
         return false;
      const double historical_return = (closes[i] / closes[i - 1]) - 1.0;
      if(historical_return < current_return)
         ++lower_count;
     }

   const double percent_rank = 100.0 * (double)lower_count / (double)strategy_crsi_rank_period;
   const double price_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_crsi_rsi_period, 1, PRICE_CLOSE);
   out_crsi = (price_rsi + streak_rsi + percent_rank) / 3.0;
   return (out_crsi >= 0.0 && out_crsi <= 100.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(!Strategy_HasOurPosition() && strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_crsi_rsi_period <= 0 ||
      strategy_crsi_streak_rsi_period <= 0 ||
      strategy_crsi_rank_period <= 0 ||
      strategy_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_pullback_lookback <= 0 ||
      strategy_pullback_atr_mult <= 0.0 ||
      strategy_closing_range_max < 0.0 ||
      strategy_closing_range_max > 1.0 ||
      strategy_entry_limit_atr_mult <= 0.0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_bars <= 0)
      return false;

   const int crsi_rates = strategy_crsi_rank_period + 10;
   const int pullback_rates = strategy_pullback_lookback + 5;
   const int required_rates = (crsi_rates > pullback_rates) ? crsi_rates : pullback_rates;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Called only after OnTick passed QM_IsNewBar(); CopyRates is closed-bar gated. // perf-allowed
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, required_rates, rates);
   if(copied < required_rates)
     {
      g_last_closed_crsi_valid = false;
      return false;
     }

   double crsi = 0.0;
   if(!Strategy_ConnorsRsiFromRates(rates, copied, crsi))
     {
      g_last_closed_crsi_valid = false;
      return false;
     }
   g_last_closed_crsi = crsi;
   g_last_closed_crsi_valid = true;

   if(Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;

   const double close_last = rates[1].close;
   const double high_last = rates[1].high;
   const double low_last = rates[1].low;
   if(close_last <= 0.0 || high_last <= low_last || low_last <= 0.0)
      return false;

   double highest_high = -DBL_MAX;
   for(int i = 1; i <= strategy_pullback_lookback; ++i)
      highest_high = MathMax(highest_high, rates[i].high);
   if(highest_high <= 0.0)
      return false;

   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_last <= 0.0 || atr_last <= 0.0)
      return false;

   if(close_last <= sma_last)
      return false;
   if((highest_high - close_last) < strategy_pullback_atr_mult * atr_last)
      return false;

   const double closing_range = (close_last - low_last) / (high_last - low_last);
   if(closing_range > strategy_closing_range_max)
      return false;
   if(crsi >= strategy_crsi_entry)
      return false;

   const double limit_price = NormalizeDouble(close_last - strategy_entry_limit_atr_mult * atr_last, _Digits);
   const double stop_price = NormalizeDouble(limit_price - strategy_atr_sl_mult * atr_last, _Digits);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(limit_price <= 0.0 || stop_price <= 0.0 || stop_price >= limit_price || ask <= 0.0 || point <= 0.0)
      return false;

   const long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double min_order_distance = (double)MathMax(stops_level, freeze_level) * point;
   if(min_order_distance > 0.0 && (ask - limit_price) < min_order_distance)
      return false;

   req.type = QM_BUY_LIMIT;
   req.price = limit_price;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = "TM_CRSI_PULLBACK_LONG";
   const int expiry = PeriodSeconds(PERIOD_D1);
   req.expiration_seconds = (expiry > 0) ? expiry : 86400;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingOrders();
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(g_last_closed_crsi_valid && g_last_closed_crsi > strategy_crsi_exit)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(d1_seconds > 0 && open_time > 0 && (now - open_time) >= strategy_max_hold_bars * d1_seconds)
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
