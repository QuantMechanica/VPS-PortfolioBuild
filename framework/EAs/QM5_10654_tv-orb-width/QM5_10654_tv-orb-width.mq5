#property strict
#property version   "5.0"
#property description "QM5_10654 TradingView Opening Range Width Filter"

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
input int    qm_ea_id                   = 10654;
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
input int    strategy_broker_to_ny_offset_hours = 7;
input int    strategy_or_start_hhmm             = 930;
input int    strategy_or_end_hhmm               = 1015;
input int    strategy_session_close_hhmm        = 1545;
input double strategy_min_width_pct             = 0.35;
input double strategy_stop_range_fraction       = 0.50;
input double strategy_reward_risk               = 1.10;

int    g_or_day_key = 0;
double g_or_high = 0.0;
double g_or_low = 0.0;
bool   g_or_has_range = false;
bool   g_or_locked = false;
bool   g_skip_day = false;
bool   g_orders_submitted = false;

int HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int DayKeyFromBrokerAsNy(const datetime broker_time)
  {
   const datetime ny_time = broker_time - strategy_broker_to_ny_offset_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int HhmmFromBrokerAsNy(const datetime broker_time)
  {
   const datetime ny_time = broker_time - strategy_broker_to_ny_offset_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return dt.hour * 100 + dt.min;
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

void ResetOpeningRangeState(const int day_key)
  {
   g_or_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_has_range = false;
   g_or_locked = false;
   g_skip_day = false;
   g_orders_submitted = false;
  }

bool LoadClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 1, rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
  }

void AdvanceOpeningRangeState()
  {
   const datetime broker_now = TimeCurrent();
   const int today_key = DayKeyFromBrokerAsNy(broker_now);
   if(g_or_day_key != today_key)
      ResetOpeningRangeState(today_key);

   MqlRates closed_bar;
   if(!LoadClosedBar(closed_bar))
      return;
   if(DayKeyFromBrokerAsNy(closed_bar.time) != today_key)
      return;

   const int bar_hhmm = HhmmFromBrokerAsNy(closed_bar.time);
   if(!g_or_locked && HhmmInWindow(bar_hhmm, strategy_or_start_hhmm, strategy_or_end_hhmm))
     {
      if(!g_or_has_range)
        {
         g_or_high = closed_bar.high;
         g_or_low = closed_bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, closed_bar.high);
         g_or_low = MathMin(g_or_low, closed_bar.low);
        }
     }

   const int now_hhmm = HhmmFromBrokerAsNy(broker_now);
   if(!g_or_locked && now_hhmm >= strategy_or_end_hhmm && g_or_has_range)
     {
      g_or_locked = true;
      const double reference_price = (closed_bar.close > 0.0) ? closed_bar.close : ((g_or_high + g_or_low) * 0.5);
      const double width = g_or_high - g_or_low;
      const double width_pct = (reference_price > 0.0) ? (100.0 * width / reference_price) : 0.0;
      if(width <= 0.0 || width_pct < strategy_min_width_pct)
         g_skip_day = true;
     }
  }

bool SessionCloseReached()
  {
   return (HhmmFromBrokerAsNy(TimeCurrent()) >= strategy_session_close_hhmm);
  }

int SecondsUntilSessionClose()
  {
   const int now_minutes = HhmmToMinutes(HhmmFromBrokerAsNy(TimeCurrent()));
   const int close_minutes = HhmmToMinutes(strategy_session_close_hhmm);
   if(now_minutes < 0 || close_minutes < 0 || now_minutes >= close_minutes)
      return 0;
   return (close_minutes - now_minutes) * 60;
  }

bool HasOurPosition()
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

int PendingStopCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         count++;
     }
   return count;
  }

void RemoveOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildOrbRequest(QM_EntryRequest &req, const bool is_long)
  {
   ResetEntryRequest(req);
   if(!g_or_locked || g_skip_day || g_or_high <= g_or_low)
      return false;

   const double range_width = g_or_high - g_or_low;
   const double stop_distance = range_width * strategy_stop_range_fraction;
   if(stop_distance <= 0.0 || strategy_reward_risk <= 0.0)
      return false;

   const int expiry_seconds = SecondsUntilSessionClose();
   if(expiry_seconds <= 0)
      return false;

   req.type = is_long ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = QM_StopRulesNormalizePrice(_Symbol, is_long ? g_or_high : g_or_low);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, is_long ? (req.price - stop_distance) : (req.price + stop_distance));
   req.tp = QM_StopRulesNormalizePrice(_Symbol, is_long ? (req.price + stop_distance * strategy_reward_risk)
                                                        : (req.price - stop_distance * strategy_reward_risk));
   req.reason = is_long ? "TV_ORB_WIDTH_LONG_STOP" : "TV_ORB_WIDTH_SHORT_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(is_long && !(req.sl < req.price && req.tp > req.price))
      return false;
   if(!is_long && !(req.sl > req.price && req.tp < req.price))
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time gating for new entries is handled in Strategy_EntrySignal so the
   // session-close exit can still run after the NY regular-session cutoff.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);
   AdvanceOpeningRangeState();

   if(g_skip_day || !g_or_locked || g_orders_submitted)
      return false;
   if(SessionCloseReached())
      return false;
   if(HasOurPosition() || PendingStopCount() > 0)
      return false;

   QM_EntryRequest short_req;
   if(!BuildOrbRequest(req, true) || !BuildOrbRequest(short_req, false))
      return false;

   ulong short_ticket = 0;
   QM_TM_OpenPosition(short_req, short_ticket);
   g_orders_submitted = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(HasOurPosition())
      RemoveOurPendingStops("one_side_triggered");
   if(SessionCloseReached())
      RemoveOurPendingStops("ny_session_close");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return (SessionCloseReached() && HasOurPosition());
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
