#property strict
#property version   "5.0"
#property description "QM5_10320 International Index Lead-Lag Momentum"

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
input int    qm_ea_id                   = 10320;
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
input string strategy_leader_primary    = "SP500.DWX";
input string strategy_leader_secondary  = "NDX.DWX";
input int    strategy_atr_period        = 14;
input double strategy_lead_atr_mult     = 0.20;
input double strategy_follower_max_frac = 0.50;
input double strategy_catchup_frac      = 0.75;
input double strategy_stop_atr_mult     = 0.60;
input int    strategy_max_hold_bars     = 5;
input int    strategy_us_open_start_hhmm = 1530;
input int    strategy_us_open_minutes   = 60;
input int    strategy_eu_close_start_hhmm = 1630;
input int    strategy_eu_close_minutes  = 60;
input int    strategy_missing_bar_lookback = 10;
input int    strategy_spread_samples    = 64;
input int    strategy_spread_min_samples = 5;
input double strategy_spread_percentile = 60.0;
input int    strategy_daily_stop_limit  = 3;

#define STRATEGY_MINUTES_PER_DAY 1440
#define STRATEGY_MAX_SPREAD_SAMPLES 64

struct StrategyLeadSignal
  {
   bool   valid;
   int    direction;
   double lead_return;
   double follow_return;
   double leader_close;
   double follower_close;
   string leader_symbol;
  };

int      g_spread_samples[STRATEGY_MINUTES_PER_DAY][STRATEGY_MAX_SPREAD_SAMPLES];
int      g_spread_counts[STRATEGY_MINUTES_PER_DAY];
int      g_spread_next[STRATEGY_MINUTES_PER_DAY];
int      g_stop_day_key = -1;
int      g_stops_today = 0;
datetime g_active_entry_time = 0;
double   g_active_leader_return = 0.0;
double   g_active_leader_close = 0.0;
double   g_active_follower_close = 0.0;
int      g_active_direction = 0;
string   g_active_leader_symbol = "";

int Strategy_HhmmToMinute(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

void Strategy_ResetStopCounterIfNeeded()
  {
   const int day_key = Strategy_DayKey(TimeCurrent());
   if(day_key != g_stop_day_key)
     {
      g_stop_day_key = day_key;
      g_stops_today = 0;
     }
  }

bool Strategy_TimeInWindow(const int now_minute, const int start_hhmm, const int duration_minutes)
  {
   const int start_minute = Strategy_HhmmToMinute(start_hhmm);
   if(start_minute < 0 || duration_minutes <= 0)
      return false;
   const int end_minute = (start_minute + duration_minutes) % STRATEGY_MINUTES_PER_DAY;
   if(duration_minutes >= STRATEGY_MINUTES_PER_DAY)
      return true;
   if(start_minute < end_minute)
      return (now_minute >= start_minute && now_minute < end_minute);
   return (now_minute >= start_minute || now_minute < end_minute);
  }

bool Strategy_InOverlapWindow()
  {
   const int now_minute = Strategy_MinuteOfDay(TimeCurrent());
   return Strategy_TimeInWindow(now_minute, strategy_us_open_start_hhmm, strategy_us_open_minutes) ||
          Strategy_TimeInWindow(now_minute, strategy_eu_close_start_hhmm, strategy_eu_close_minutes);
  }

bool Strategy_GetOurPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &position_type,
                             datetime &open_time,
                             double &open_price)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }

   return false;
  }

bool Strategy_ReadTwoCloses(const string symbol, double &close_last, double &close_prev)
  {
   close_last = 0.0;
   close_prev = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   // perf-allowed: two closed M1 bars only, called from the framework new-bar entry path.
   if(CopyClose(symbol, PERIOD_M1, 1, 2, closes) != 2)
      return false;
   close_last = closes[0];
   close_prev = closes[1];
   return (close_last > 0.0 && close_prev > 0.0);
  }

bool Strategy_HasRecentM1Bars(const string symbol)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int lookback = MathMax(2, strategy_missing_bar_lookback);
   datetime times[];
   ArraySetAsSeries(times, true);
   // perf-allowed: bounded 10-bar freshness check, called from the new-bar entry path.
   if(CopyTime(symbol, PERIOD_M1, 1, lookback, times) != lookback)
      return false;

   for(int i = 0; i < lookback - 1; ++i)
     {
      if((times[i] - times[i + 1]) > 120)
         return false;
     }
   return true;
  }

bool Strategy_UpdateSpreadCache(int &minute, int &spread_points)
  {
   minute = -1;
   spread_points = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: one closed follower M1 bar, called from the framework new-bar entry path.
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, rates) != 1)
      return false;

   minute = Strategy_MinuteOfDay(rates[0].time);
   if(minute < 0 || minute >= STRATEGY_MINUTES_PER_DAY)
      return false;

   spread_points = (int)rates[0].spread;
   if(spread_points <= 0)
      spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return false;

   const int capacity = MathMin(STRATEGY_MAX_SPREAD_SAMPLES, MathMax(1, strategy_spread_samples));
   const int idx = g_spread_next[minute] % capacity;
   g_spread_samples[minute][idx] = spread_points;
   g_spread_next[minute] = (idx + 1) % capacity;
   if(g_spread_counts[minute] < capacity)
      g_spread_counts[minute]++;
   return true;
  }

bool Strategy_SpreadAllowed()
  {
   int minute = -1;
   int spread_points = 0;
   if(!Strategy_UpdateSpreadCache(minute, spread_points))
      return false;

   const int count = g_spread_counts[minute];
   if(count < MathMax(1, strategy_spread_min_samples))
      return true;

   int values[STRATEGY_MAX_SPREAD_SAMPLES];
   for(int i = 0; i < count; ++i)
      values[i] = g_spread_samples[minute][i];

   for(int i = 1; i < count; ++i)
     {
      const int v = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > v)
        {
         values[j + 1] = values[j];
         j--;
        }
      values[j + 1] = v;
     }

   const double pct = MathMax(0.0, MathMin(100.0, strategy_spread_percentile));
   int threshold_idx = (int)MathFloor((pct / 100.0) * (count - 1));
   if(threshold_idx < 0)
      threshold_idx = 0;
   if(threshold_idx >= count)
      threshold_idx = count - 1;
   return (spread_points <= values[threshold_idx]);
  }

bool Strategy_EvaluateLeader(const string leader, StrategyLeadSignal &signal)
  {
   signal.valid = false;
   signal.direction = 0;
   signal.lead_return = 0.0;
   signal.follow_return = 0.0;
   signal.leader_close = 0.0;
   signal.follower_close = 0.0;
   signal.leader_symbol = leader;

   if(leader == "" || leader == _Symbol)
      return false;
   if(!Strategy_HasRecentM1Bars(leader) || !Strategy_HasRecentM1Bars(_Symbol))
      return false;

   double leader_close = 0.0;
   double leader_prev = 0.0;
   double follower_close = 0.0;
   double follower_prev = 0.0;
   if(!Strategy_ReadTwoCloses(leader, leader_close, leader_prev))
      return false;
   if(!Strategy_ReadTwoCloses(_Symbol, follower_close, follower_prev))
      return false;

   const double atr = QM_ATR(leader, PERIOD_M1, strategy_atr_period, 1);
   if(atr <= 0.0 || leader_close <= 0.0 || follower_close <= 0.0)
      return false;

   const double threshold = strategy_lead_atr_mult * atr / leader_close;
   if(threshold <= 0.0)
      return false;

   const double lead_ret = leader_close / leader_prev - 1.0;
   const double follow_ret = follower_close / follower_prev - 1.0;
   const double max_follow = strategy_follower_max_frac * threshold;

   if(lead_ret > threshold && follow_ret < max_follow)
     {
      signal.valid = true;
      signal.direction = 1;
     }
   else if(lead_ret < -threshold && follow_ret > -max_follow)
     {
      signal.valid = true;
      signal.direction = -1;
     }

   if(!signal.valid)
      return false;

   signal.lead_return = lead_ret;
   signal.follow_return = follow_ret;
   signal.leader_close = leader_close;
   signal.follower_close = follower_close;
   return true;
  }

void Strategy_CacheEntryState(const StrategyLeadSignal &signal)
  {
   g_active_entry_time = TimeCurrent();
   g_active_leader_return = signal.lead_return;
   g_active_leader_close = signal.leader_close;
   g_active_follower_close = signal.follower_close;
   g_active_direction = signal.direction;
   g_active_leader_symbol = signal.leader_symbol;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetStopCounterIfNeeded();

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   if(Strategy_GetOurPosition(ticket, position_type, open_time, open_price))
      return false;

   if(g_stops_today >= strategy_daily_stop_limit)
      return true;

   return !Strategy_InOverlapWindow();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M1)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   if(Strategy_GetOurPosition(ticket, position_type, open_time, open_price))
      return false;

   if(!Strategy_SpreadAllowed())
      return false;

   StrategyLeadSignal primary;
   StrategyLeadSignal secondary;
   const bool has_primary = Strategy_EvaluateLeader(strategy_leader_primary, primary);
   const bool has_secondary = Strategy_EvaluateLeader(strategy_leader_secondary, secondary);
   if(!has_primary && !has_secondary)
      return false;

   StrategyLeadSignal chosen = primary;
   if(!has_primary || (has_secondary && MathAbs(secondary.lead_return) > MathAbs(primary.lead_return)))
      chosen = secondary;

   const QM_OrderType side = (chosen.direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = StringFormat("index_leadlag_%s_%s",
                             (chosen.direction > 0) ? "long" : "short",
                             chosen.leader_symbol);
   Strategy_CacheEntryState(chosen);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or add-to-position rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   if(!Strategy_GetOurPosition(ticket, position_type, open_time, open_price))
      return false;

   const int hold_seconds = (int)(TimeCurrent() - open_time);
   if(hold_seconds >= MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_M1))
      return true;

   if(g_active_entry_time <= 0 ||
      g_active_leader_close <= 0.0 ||
      g_active_follower_close <= 0.0 ||
      g_active_direction == 0 ||
      g_active_leader_symbol == "")
      return false;

   double leader_now = 0.0;
   double follower_now = 0.0;
   if(!QM_FrameworkSymbolPrice(g_active_leader_symbol, leader_now))
      return false;
   if(!QM_FrameworkSymbolPrice(_Symbol, follower_now))
      return false;

   const double leader_move = leader_now / g_active_leader_close - 1.0;
   const double follower_move = follower_now / g_active_follower_close - 1.0;

   if(g_active_direction > 0)
     {
      if(leader_move <= 0.0)
         return true;
      if(follower_move >= MathAbs(g_active_leader_return) * strategy_catchup_frac)
         return true;
     }
   else
     {
      if(leader_move >= 0.0)
         return true;
      if(follower_move <= -MathAbs(g_active_leader_return) * strategy_catchup_frac)
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

   string basket_symbols[4] = {"GDAXI.DWX", "UK100.DWX", "SP500.DWX", "NDX.DWX"};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_M1, 300);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10320_index-leadlag\"}");
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

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic())
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;

   const long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;

   const long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
   if(reason != DEAL_REASON_SL)
      return;

   Strategy_ResetStopCounterIfNeeded();
   g_stops_today++;
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
