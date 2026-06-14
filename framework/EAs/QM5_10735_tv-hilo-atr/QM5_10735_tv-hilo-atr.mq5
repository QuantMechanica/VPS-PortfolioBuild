#property strict
#property version   "5.0"
#property description "QM5_10735 TradingView High-Low ATR Breakout"

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
input int    qm_ea_id                   = 10735;
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
input bool   strategy_allow_long        = true;
input bool   strategy_allow_short       = true;
input int    strategy_or_start_hhmm     = 930;
input int    strategy_or_minutes        = 30;
input int    strategy_force_flat_hhmm   = 1515;
input int    strategy_atr_period        = 14;
input double strategy_atr_mult          = 3.5;
input double strategy_fixed_stop_pct    = 1.0;
input double strategy_target_pct        = 3.0;
input int    strategy_min_or_points     = 10;
input int    strategy_max_spread_points = 0;
input int    strategy_max_trades_day    = 2;

int    g_session_day_key = 0;
bool   g_or_has_range = false;
bool   g_or_locked = false;
bool   g_skip_day = false;
double g_or_high = 0.0;
double g_or_low = 0.0;
int    g_entry_signal_count_today = 0;

int HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int MinutesToHhmm(int minutes)
  {
   while(minutes < 0)
      minutes += 24 * 60;
   minutes = minutes % (24 * 60);
   return (minutes / 60) * 100 + (minutes % 60);
  }

int HhmmAddMinutes(const int hhmm, const int add_minutes)
  {
   const int base = HhmmToMinutes(hhmm);
   if(base < 0)
      return hhmm;
   return MinutesToHhmm(base + add_minutes);
  }

int BrokerDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int BrokerHhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 100 + dt.min;
  }

datetime BrokerDayStart(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

int OrEndHhmm()
  {
   return HhmmAddMinutes(strategy_or_start_hhmm, strategy_or_minutes);
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_or_has_range = false;
   g_or_locked = false;
   g_skip_day = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_entry_signal_count_today = 0;
  }

bool ReadClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 1, rates); // perf-allowed: one closed-bar read inside framework QM_IsNewBar gate.
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
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

bool SelectOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool ForceFlatReached()
  {
   const int now_hhmm = BrokerHhmm(TimeCurrent());
   const int start_hhmm = strategy_or_start_hhmm;
   const int flat_hhmm = strategy_force_flat_hhmm;
   if(start_hhmm <= flat_hhmm)
      return (now_hhmm >= flat_hhmm);
   return (now_hhmm >= flat_hhmm && now_hhmm < start_hhmm);
  }

void AdvanceOpeningRange()
  {
   const datetime broker_now = TimeCurrent();
   const int today = BrokerDayKey(broker_now);
   if(g_session_day_key != today)
      ResetSessionState(today);

   MqlRates bar;
   if(!ReadClosedBar(bar) || BrokerDayKey(bar.time) != today)
      return;

   const int bar_hhmm = BrokerHhmm(bar.time);
   if(!g_or_locked && HhmmInWindow(bar_hhmm, strategy_or_start_hhmm, OrEndHhmm()))
     {
      if(!g_or_has_range)
        {
         g_or_high = bar.high;
         g_or_low = bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar.high);
         g_or_low = MathMin(g_or_low, bar.low);
        }
     }

   if(g_or_has_range && !g_or_locked && HhmmInWindow(BrokerHhmm(broker_now), OrEndHhmm(), strategy_force_flat_hhmm))
     {
      g_or_locked = true;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double width = g_or_high - g_or_low;
      if(point <= 0.0 || width <= strategy_min_or_points * point)
         g_skip_day = true;
     }
  }

int TodayClosedTradeCount(double &last_net)
  {
   last_net = 0.0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const datetime day_start = BrokerDayStart(TimeCurrent());
   if(!HistorySelect(day_start, TimeCurrent()))
      return 0;

   int count = 0;
   datetime last_time = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                       + HistoryDealGetDouble(deal, DEAL_SWAP)
                       + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      count++;
      if(deal_time >= last_time)
        {
         last_time = deal_time;
         last_net = net;
        }
     }
   return count;
  }

bool DailyTradeAllowance()
  {
   if(strategy_max_trades_day <= 0 || g_entry_signal_count_today >= strategy_max_trades_day)
      return false;

   double last_net = 0.0;
   const int closed_count = TodayClosedTradeCount(last_net);
   if(closed_count <= 0)
      return true;
   if(closed_count >= strategy_max_trades_day)
      return false;
   return (last_net < 0.0);
  }

double MinStopDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0)
      return 0.0;
   return MathMax(point, (double)stops * point);
  }

bool BuildBreakoutRequest(QM_EntryRequest &req, const int direction)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "TV_HILO_ATR_LONG" : "TV_HILO_ATR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_mult <= 0.0 || strategy_fixed_stop_pct <= 0.0 || strategy_target_pct <= 0.0)
      return false;

   const double pct_stop_distance = req.price * strategy_fixed_stop_pct / 100.0;
   const double atr_stop_distance = atr * strategy_atr_mult;
   const double stop_distance = MathMax(MathMax(pct_stop_distance, atr_stop_distance), MinStopDistance());
   const double target_distance = req.price * strategy_target_pct / 100.0;
   if(stop_distance <= 0.0 || target_distance <= 0.0)
      return false;

   req.sl = QM_StopRulesNormalizePrice(_Symbol, (direction > 0) ? req.price - stop_distance : req.price + stop_distance);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, (direction > 0) ? req.price + target_distance : req.price - target_distance);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(direction > 0 && !(req.sl < req.price && req.tp > req.price))
      return false;
   if(direction < 0 && !(req.sl > req.price && req.tp < req.price))
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
   // No Trade Filter (time, spread, news): news is handled by the framework
   // and Strategy_NewsFilterHook; this hook blocks new entries outside the
   // card session while allowing open-position management and the 15:15 exit.
   if(HasOurPosition())
      return false;

   const int now_hhmm = BrokerHhmm(TimeCurrent());
   if(!HhmmInWindow(now_hhmm, strategy_or_start_hhmm, strategy_force_flat_hhmm))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

   return false;
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

   AdvanceOpeningRange();

   if(HasOurPosition() || g_skip_day || !g_or_locked || ForceFlatReached() || !DailyTradeAllowance())
      return false;
   if(g_or_high <= 0.0 || g_or_low <= 0.0 || g_or_high <= g_or_low)
      return false;

   MqlRates bar;
   if(!ReadClosedBar(bar))
      return false;

   if(strategy_allow_long && bar.close > g_or_high && BuildBreakoutRequest(req, 1))
     {
      g_entry_signal_count_today++;
      return true;
     }

   if(strategy_allow_short && bar.close < g_or_low && BuildBreakoutRequest(req, -1))
     {
      g_entry_signal_count_today++;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: source baseline trails the active stop by ATR(14)*3.5.
   ulong ticket = 0;
   if(SelectOurPosition(ticket))
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: force flat at 15:15 session-local broker/chart time.
   return (ForceFlatReached() && HasOurPosition());
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to the framework axes.
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
