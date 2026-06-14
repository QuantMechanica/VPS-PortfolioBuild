#property strict
#property version   "5.0"
#property description "QM5_10674 TradingView ORB Gap VWAP"

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
input int    qm_ea_id                   = 10674;
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
input int    strategy_ny_open_hour        = 9;
input int    strategy_ny_open_minute      = 30;
input int    strategy_ny_eod_hour         = 15;
input int    strategy_ny_eod_minute       = 0;
input int    strategy_or_minutes          = 15;
input int    strategy_vwap_slope_bars     = 1;
input double strategy_volume_mult         = 1.20;
input double strategy_min_or_size_pct     = 0.02;
input double strategy_max_or_size_pct     = 0.80;
input bool   strategy_gap_filter_enabled  = true;
input double strategy_breakout_max_points = 7.0;
input double strategy_tp_points           = 10.0;
input double strategy_reward_risk         = 2.0;
input double strategy_min_avg_volume      = 1.0;
input int    strategy_max_spread_points   = 0;

datetime Strategy_NYTime(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (QM_IsUSDSTUTC(utc) ? -4 : -5) * 3600;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_IsWeekdayNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_NYTime(broker_time), dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
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

double Strategy_PriorCloseBeforeNYSession(const int session_key,
                                          const int eod_minutes,
                                          const int period_minutes)
  {
   double fallback_close = 0.0;
   double target_close = 0.0;
   const int target_minutes = (eod_minutes > period_minutes) ? (eod_minutes - period_minutes) : 0;

   for(int shift = 2; shift <= 600; ++shift)
     {
      const datetime t = iTime(_Symbol, _Period, shift); // perf-allowed: bounded prior-close search inside framework QM_IsNewBar gate.
      if(t <= 0)
         break;
      const datetime ny_t = Strategy_NYTime(t);
      const int key = Strategy_DateKey(ny_t);
      if(key >= session_key)
         continue;

      const double close_price = iClose(_Symbol, _Period, shift); // perf-allowed: bounded prior-close search inside framework QM_IsNewBar gate.
      if(close_price <= 0.0)
         continue;
      if(fallback_close <= 0.0)
         fallback_close = close_price;

      const int minutes = Strategy_MinutesOfDay(ny_t);
      if(minutes <= target_minutes)
        {
         target_close = close_price;
         break;
        }
     }

   return (target_close > 0.0) ? target_close : fallback_close;
  }

bool Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWeekdayNY(TimeCurrent()) && !Strategy_HasOpenPosition())
      return true;

   if(strategy_max_spread_points > 0 && !Strategy_HasOpenPosition())
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
         return true;
      if((ask - bid) / point > (double)strategy_max_spread_points)
         return true;
     }

   const datetime ny_now = Strategy_NYTime(TimeCurrent());
   const int now_minutes = Strategy_MinutesOfDay(ny_now);
   const int open_minutes = strategy_ny_open_hour * 60 + strategy_ny_open_minute;
   const int eod_minutes = strategy_ny_eod_hour * 60 + strategy_ny_eod_minute;
   if(!Strategy_HasOpenPosition() && (now_minutes < open_minutes || now_minutes >= eod_minutes))
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(strategy_or_minutes <= 0 ||
      strategy_vwap_slope_bars < 1 ||
      strategy_volume_mult <= 0.0 ||
      strategy_min_or_size_pct < 0.0 ||
      strategy_max_or_size_pct <= strategy_min_or_size_pct ||
      strategy_breakout_max_points <= 0.0 ||
      strategy_tp_points <= 0.0 ||
      strategy_reward_risk <= 0.0 ||
      strategy_min_avg_volume < 0.0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   static int    session_key = 0;
   static bool   session_trade_taken = false;
   static bool   session_break_seen = false;
   static bool   opening_range_ready = false;
   static double opening_range_high = 0.0;
   static double opening_range_low = 0.0;
   static double prior_close = 0.0;
   static double cumulative_pv = 0.0;
   static double cumulative_volume = 0.0;
   static int    session_bar_count = 0;
   static double vwap_now = 0.0;
   static double vwap_prev = 0.0;

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: one closed-bar timestamp after framework QM_IsNewBar gate.
   if(bar_time <= 0)
      return false;

   const datetime ny_bar = Strategy_NYTime(bar_time);
   const int key = Strategy_DateKey(ny_bar);
   const int bar_minutes = Strategy_MinutesOfDay(ny_bar);
   const int open_minutes = strategy_ny_open_hour * 60 + strategy_ny_open_minute;
   const int eod_minutes = strategy_ny_eod_hour * 60 + strategy_ny_eod_minute;
   const int period_minutes = (int)MathMax(1.0, (double)PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60.0);
   const int or_end_minutes = open_minutes + strategy_or_minutes;

   if(bar_minutes < open_minutes || bar_minutes >= eod_minutes)
      return false;

   if(session_key != key)
     {
      session_key = key;
      session_trade_taken = false;
      session_break_seen = false;
      opening_range_ready = false;
      opening_range_high = 0.0;
      opening_range_low = 0.0;
      prior_close = Strategy_PriorCloseBeforeNYSession(session_key, eod_minutes, period_minutes);
      cumulative_pv = 0.0;
      cumulative_volume = 0.0;
      session_bar_count = 0;
      vwap_now = 0.0;
      vwap_prev = 0.0;
     }

   if(session_trade_taken || session_break_seen)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);     // perf-allowed: one closed-bar OHLCV read after framework QM_IsNewBar gate.
   const double low1 = iLow(_Symbol, _Period, 1);       // perf-allowed: one closed-bar OHLCV read after framework QM_IsNewBar gate.
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: one closed-bar OHLCV read after framework QM_IsNewBar gate.
   const long volume1_raw = iVolume(_Symbol, _Period, 1); // perf-allowed: one closed-bar tick-volume read after framework QM_IsNewBar gate.
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || volume1_raw <= 0)
      return false;

   const double volume1 = (double)volume1_raw;
   const double typical1 = (high1 + low1 + close1) / 3.0;
   const double prior_avg_volume = (session_bar_count > 0) ? cumulative_volume / (double)session_bar_count : 0.0;

   cumulative_pv += typical1 * volume1;
   cumulative_volume += volume1;
   session_bar_count++;
   vwap_prev = vwap_now;
   if(cumulative_volume > 0.0)
      vwap_now = cumulative_pv / cumulative_volume;

   if(bar_minutes >= open_minutes && bar_minutes < or_end_minutes)
     {
      if(opening_range_high <= 0.0 || high1 > opening_range_high)
         opening_range_high = high1;
      if(opening_range_low <= 0.0 || low1 < opening_range_low)
         opening_range_low = low1;
      return false;
     }

   if(!opening_range_ready)
     {
      if(opening_range_high <= 0.0 || opening_range_low <= 0.0 || opening_range_high <= opening_range_low)
         return false;
      opening_range_ready = true;
     }

   if(prior_close <= 0.0 || vwap_now <= 0.0 || vwap_prev <= 0.0 || prior_avg_volume < strategy_min_avg_volume)
      return false;

   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: one closed-bar cross confirmation read after framework QM_IsNewBar gate.
   if(close2 <= 0.0)
      return false;

   const bool long_cross = (close2 <= opening_range_high && close1 > opening_range_high);
   const bool short_cross = (close2 >= opening_range_low && close1 < opening_range_low);
   if(!long_cross && !short_cross)
      return false;

   session_break_seen = true;

   const double or_size_pct = (opening_range_high - opening_range_low) / close1 * 100.0;
   if(or_size_pct < strategy_min_or_size_pct || or_size_pct > strategy_max_or_size_pct)
      return false;

   if(volume1 < prior_avg_volume * strategy_volume_mult)
      return false;

   const bool vwap_up = (vwap_now > vwap_prev);
   const bool vwap_down = (vwap_now < vwap_prev);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double tp_dist = strategy_tp_points;
   const double sl_dist = tp_dist / strategy_reward_risk;

   if(long_cross)
     {
      if(close1 <= vwap_now || !vwap_up)
         return false;
      if(strategy_gap_filter_enabled && close1 >= prior_close)
         return false;
      if(MathAbs(close1 - opening_range_high) > strategy_breakout_max_points)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "orb_gap_vwap_long";
      session_trade_taken = true;
      return (req.sl > 0.0 && req.tp > ask && req.sl < ask);
     }

   if(short_cross)
     {
      if(close1 >= vwap_now || !vwap_down)
         return false;
      if(strategy_gap_filter_enabled && close1 <= prior_close)
         return false;
      if(MathAbs(close1 - opening_range_low) > strategy_breakout_max_points)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "orb_gap_vwap_short";
      session_trade_taken = true;
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial close, or break-even logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime ny_now = Strategy_NYTime(TimeCurrent());
   const int now_minutes = Strategy_MinutesOfDay(ny_now);
   const int eod_minutes = strategy_ny_eod_hour * 60 + strategy_ny_eod_minute;
   return (now_minutes >= eod_minutes);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // News blackout is delegated to the framework for P8.
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
