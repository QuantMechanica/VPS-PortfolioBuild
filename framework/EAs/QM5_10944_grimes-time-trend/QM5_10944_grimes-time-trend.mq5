#property strict
#property version   "5.0"
#property description "QM5_10944 Grimes Time-of-Day Intraday Trend"

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
input int    qm_ea_id                   = 10944;
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
input ENUM_TIMEFRAMES strategy_tf                  = PERIOD_M15;
input int    strategy_session_open_hour            = 16;   // broker-time US cash open proxy (09:30 ET + 7 = 16:30)
input int    strategy_session_open_minute          = 30;
input int    strategy_session_close_hour           = 23;   // broker-time US cash close proxy (16:00 ET + 7 = 23:00)
input int    strategy_session_close_minute         = 0;
input int    strategy_window_minutes               = 90;
input int    strategy_atr_period                   = 20;
input double strategy_min_bar_atr_mult             = 0.70;
input double strategy_stop_buffer_atr_mult         = 0.10;
input double strategy_min_stop_atr_mult            = 0.40;
input double strategy_max_stop_atr_mult            = 1.40;
input double strategy_morning_target_r             = 1.50;
input double strategy_afternoon_target_r           = 2.00;
input double strategy_close_top_fraction           = 0.75;
input double strategy_close_bottom_fraction        = 0.25;
input double strategy_max_spread_stop_fraction     = 0.10;
input int    strategy_pending_expiry_minutes       = 15;
input int    strategy_vwap_lookback_bars           = 80;

enum StrategyWindow
  {
   STRATEGY_WINDOW_NONE = 0,
   STRATEGY_WINDOW_MORNING = 1,
   STRATEGY_WINDOW_AFTERNOON = 2
  };

bool     g_cache_ready = false;
datetime g_signal_time = 0;
double   g_vwap_proxy = 0.0;
double   g_signal_high = 0.0;
double   g_signal_low = 0.0;
double   g_signal_close = 0.0;
double   g_prev_close = 0.0;
double   g_prior_two_low = 0.0;
double   g_prior_two_high = 0.0;
int      g_morning_signal_date = 0;
int      g_afternoon_signal_date = 0;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int SessionOpenMinute()
  {
   return strategy_session_open_hour * 60 + strategy_session_open_minute;
  }

int SessionCloseMinute()
  {
   return strategy_session_close_hour * 60 + strategy_session_close_minute;
  }

int NormalizeSessionMinute(const int minute_of_day)
  {
   const int open_minute = SessionOpenMinute();
   int minute = minute_of_day;
   if(SessionCloseMinute() <= open_minute && minute < open_minute)
      minute += 1440;
   return minute;
  }

StrategyWindow ActiveWindowAt(const datetime t)
  {
   const int open_minute = SessionOpenMinute();
   int close_minute = SessionCloseMinute();
   if(close_minute <= open_minute)
      close_minute += 1440;

   const int minute = NormalizeSessionMinute(MinutesOfDay(t));
   const int window_minutes = (strategy_window_minutes > 1) ? strategy_window_minutes : 1;
   if(minute >= open_minute && minute < open_minute + window_minutes)
      return STRATEGY_WINDOW_MORNING;
   if(minute >= close_minute - window_minutes && minute < close_minute)
      return STRATEGY_WINDOW_AFTERNOON;
   return STRATEGY_WINDOW_NONE;
  }

bool IsSessionVwapBar(const MqlRates &bar, const int signal_date, const int signal_minute)
  {
   if(DateKey(bar.time) != signal_date)
      return false;

   const int open_minute = SessionOpenMinute();
   const int bar_minute = NormalizeSessionMinute(MinutesOfDay(bar.time));
   const int normalized_signal = NormalizeSessionMinute(signal_minute);
   return (bar_minute >= open_minute && bar_minute <= normalized_signal);
  }

bool HasOurPosition()
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

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
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

bool RefreshClosedBarState()
  {
   const int needed = (strategy_vwap_lookback_bars > 10) ? strategy_vwap_lookback_bars : 10;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, strategy_tf, 1, needed, rates); // perf-allowed: bounded session VWAP cache, called from framework new-bar entry hook.
   if(copied < 3)
      return false;
   ArraySetAsSeries(rates, true);

   g_signal_time = rates[0].time;
   g_signal_high = rates[0].high;
   g_signal_low = rates[0].low;
   g_signal_close = rates[0].close;
   g_prev_close = rates[1].close;
   g_prior_two_low = MathMin(rates[0].low, rates[1].low);
   g_prior_two_high = MathMax(rates[0].high, rates[1].high);

   const int signal_date = DateKey(g_signal_time);
   const int signal_minute = MinutesOfDay(g_signal_time);
   double sum_typical = 0.0;
   int count = 0;
   for(int i = copied - 1; i >= 0; --i)
     {
      if(!IsSessionVwapBar(rates[i], signal_date, signal_minute))
         continue;
      sum_typical += (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      count++;
     }

   if(count <= 0)
      return false;

   g_vwap_proxy = sum_typical / (double)count;
   g_cache_ready = true;
   return true;
  }

bool StopDistanceAllowed(const double stop_distance, const double atr_value)
  {
   if(stop_distance <= 0.0 || atr_value <= 0.0)
      return false;
   if(stop_distance < strategy_min_stop_atr_mult * atr_value)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * atr_value)
      return false;
   return true;
  }

bool SpreadAllowed(const double stop_distance)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_fraction);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurPosition() || HasOurPendingOrder())
      return false;
   return (ActiveWindowAt(TimeCurrent()) == STRATEGY_WINDOW_NONE);
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
   req.expiration_seconds = ((strategy_pending_expiry_minutes > 1) ? strategy_pending_expiry_minutes : 1) * 60;

   if(!RefreshClosedBarState())
      return false;
   if(HasOurPosition() || HasOurPendingOrder())
      return false;

   const StrategyWindow window = ActiveWindowAt(g_signal_time);
   if(window == STRATEGY_WINDOW_NONE)
      return false;

   const int signal_date = DateKey(g_signal_time);
   if(window == STRATEGY_WINDOW_MORNING && g_morning_signal_date == signal_date)
      return false;
   if(window == STRATEGY_WINDOW_AFTERNOON && g_afternoon_signal_date == signal_date)
      return false;

   const double atr_value = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double bar_range = g_signal_high - g_signal_low;
   if(atr_value <= 0.0 || bar_range <= 0.0)
      return false;
   if(bar_range < strategy_min_bar_atr_mult * atr_value)
      return false;

   const double close_position = (g_signal_close - g_signal_low) / bar_range;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double target_r = (window == STRATEGY_WINDOW_AFTERNOON) ? strategy_afternoon_target_r : strategy_morning_target_r;

   if(g_signal_close > g_vwap_proxy && close_position >= strategy_close_top_fraction)
     {
      const double stop_loss = g_signal_low - strategy_stop_buffer_atr_mult * atr_value;
      const double fill_price = (ask >= g_signal_high) ? ask : g_signal_high;
      const double stop_distance = fill_price - stop_loss;
      if(!StopDistanceAllowed(stop_distance, atr_value) || !SpreadAllowed(stop_distance))
         return false;

      req.type = (ask >= g_signal_high) ? QM_BUY : QM_BUY_STOP;
      req.price = (req.type == QM_BUY_STOP) ? NormalizeDouble(g_signal_high, _Digits) : 0.0;
      req.sl = NormalizeDouble(stop_loss, _Digits);
      req.tp = NormalizeDouble(fill_price + target_r * stop_distance, _Digits);
      req.reason = (window == STRATEGY_WINDOW_AFTERNOON) ? "QM5_10944_AFTERNOON_LONG" : "QM5_10944_MORNING_LONG";
      if(window == STRATEGY_WINDOW_MORNING)
         g_morning_signal_date = signal_date;
      else
         g_afternoon_signal_date = signal_date;
      return true;
     }

   if(g_signal_close < g_vwap_proxy && close_position <= strategy_close_bottom_fraction)
     {
      const double stop_loss = g_signal_high + strategy_stop_buffer_atr_mult * atr_value;
      const double fill_price = (bid <= g_signal_low) ? bid : g_signal_low;
      const double stop_distance = stop_loss - fill_price;
      if(!StopDistanceAllowed(stop_distance, atr_value) || !SpreadAllowed(stop_distance))
         return false;

      req.type = (bid <= g_signal_low) ? QM_SELL : QM_SELL_STOP;
      req.price = (req.type == QM_SELL_STOP) ? NormalizeDouble(g_signal_low, _Digits) : 0.0;
      req.sl = NormalizeDouble(stop_loss, _Digits);
      req.tp = NormalizeDouble(fill_price - target_r * stop_distance, _Digits);
      req.reason = (window == STRATEGY_WINDOW_AFTERNOON) ? "QM5_10944_AFTERNOON_SHORT" : "QM5_10944_MORNING_SHORT";
      if(window == STRATEGY_WINDOW_MORNING)
         g_morning_signal_date = signal_date;
      else
         g_afternoon_signal_date = signal_date;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!g_cache_ready)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const string comment = PositionGetString(POSITION_COMMENT);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double target_mult = (StringFind(comment, "AFTERNOON") >= 0) ? strategy_afternoon_target_r : strategy_morning_target_r;
      double initial_r = 0.0;
      if(current_tp > 0.0 && target_mult > 0.0)
         initial_r = MathAbs(current_tp - open_price) / target_mult;
      if(initial_r <= 0.0)
         initial_r = MathAbs(open_price - current_sl);
      if(initial_r <= 0.0)
         continue;

      const double market_move = is_buy ? (bid - open_price) : (open_price - ask);
      if(market_move < initial_r)
         continue;

      const double target_sl = is_buy ? g_prior_two_low : g_prior_two_high;
      if(target_sl <= 0.0)
         continue;

      if(is_buy && target_sl > current_sl + point * 0.5 && target_sl < bid)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "trail_prior_two_m15_lows");
      if(!is_buy && target_sl < current_sl - point * 0.5 && target_sl > ask)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "trail_prior_two_m15_highs");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      has_position = true;
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(g_cache_ready && position_type == POSITION_TYPE_BUY &&
         g_signal_close < g_vwap_proxy && g_prev_close < g_vwap_proxy)
         return true;
      if(g_cache_ready && position_type == POSITION_TYPE_SELL &&
         g_signal_close > g_vwap_proxy && g_prev_close > g_vwap_proxy)
         return true;
     }

   if(has_position && ActiveWindowAt(TimeCurrent()) == STRATEGY_WINDOW_NONE)
      return true;

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
