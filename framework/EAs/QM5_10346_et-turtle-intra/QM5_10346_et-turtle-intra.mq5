#property strict
#property version   "5.0"
#property description "QM5_10346 Elite Trader Intraday Turtle Donchian"

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
input int    qm_ea_id                   = 10346;
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
input int    strategy_system1_entry_bars    = 20;
input int    strategy_system1_exit_bars     = 10;
input int    strategy_system2_entry_bars    = 55;
input int    strategy_system2_exit_bars     = 20;
input int    strategy_atr_period            = 20;
input double strategy_atr_stop_mult         = 2.0;
input double strategy_min_channel_atr_mult  = 1.5;
input bool   strategy_skip_s1_after_win     = true;
input int    strategy_session_start_hour    = 7;
input int    strategy_session_end_hour      = 20;
input double strategy_max_spread_points     = 80.0;
input int    strategy_max_hold_bars         = 480;

double g_s1_entry_high = 0.0;
double g_s1_entry_low = 0.0;
double g_s1_exit_high = 0.0;
double g_s1_exit_low = 0.0;
double g_s2_entry_high = 0.0;
double g_s2_entry_low = 0.0;
double g_s2_exit_high = 0.0;
double g_s2_exit_low = 0.0;
double g_last_closed_close = 0.0;
bool   g_channel_cache_ready = false;
bool   g_last_s1_was_win = false;
bool   g_position_was_open = false;
int    g_tracked_system = 0;
long   g_tracked_position_id = 0;
datetime g_tracked_position_time = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

double DonchianHigh(const int bars, const int start_shift)
  {
   if(bars <= 0)
      return 0.0;

   double high = -DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double v = iHigh(_Symbol, PERIOD_H1, i); // perf-allowed: bounded Donchian structural channel, called from closed-bar hook.
      if(v <= 0.0)
         return 0.0;
      if(v > high)
         high = v;
     }
   return high;
  }

double DonchianLow(const int bars, const int start_shift)
  {
   if(bars <= 0)
      return 0.0;

   double low = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double v = iLow(_Symbol, PERIOD_H1, i); // perf-allowed: bounded Donchian structural channel, called from closed-bar hook.
      if(v <= 0.0)
         return 0.0;
      if(v < low)
         low = v;
     }
   return low;
  }

bool RefreshChannelCache()
  {
   g_channel_cache_ready = false;
   if(strategy_system1_entry_bars < 1 || strategy_system1_exit_bars < 1 ||
      strategy_system2_entry_bars < 1 || strategy_system2_exit_bars < 1)
      return false;

   g_last_closed_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar close for Donchian breakout/exit state.
   if(g_last_closed_close <= 0.0)
      return false;

   g_s1_entry_high = DonchianHigh(strategy_system1_entry_bars, 2);
   g_s1_entry_low  = DonchianLow(strategy_system1_entry_bars, 2);
   g_s1_exit_high  = DonchianHigh(strategy_system1_exit_bars, 2);
   g_s1_exit_low   = DonchianLow(strategy_system1_exit_bars, 2);
   g_s2_entry_high = DonchianHigh(strategy_system2_entry_bars, 2);
   g_s2_entry_low  = DonchianLow(strategy_system2_entry_bars, 2);
   g_s2_exit_high  = DonchianHigh(strategy_system2_exit_bars, 2);
   g_s2_exit_low   = DonchianLow(strategy_system2_exit_bars, 2);

   g_channel_cache_ready =
      (g_s1_entry_high > 0.0 && g_s1_entry_low > 0.0 &&
       g_s1_exit_high > 0.0 && g_s1_exit_low > 0.0 &&
       g_s2_entry_high > 0.0 && g_s2_entry_low > 0.0 &&
       g_s2_exit_high > 0.0 && g_s2_exit_low > 0.0);
   return g_channel_cache_ready;
  }

int SystemFromComment(const string comment)
  {
   if(StringFind(comment, "S1") >= 0)
      return 1;
   if(StringFind(comment, "S2") >= 0)
      return 2;
   return 0;
  }

bool SelectOurPosition(ulong &ticket, int &system_id)
  {
   ticket = 0;
   system_id = 0;

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
      system_id = SystemFromComment(PositionGetString(POSITION_COMMENT));
      if(system_id == 0)
         system_id = g_tracked_system;
      return true;
     }

   return false;
  }

void UpdateSystem1OutcomeState()
  {
   ulong ticket = 0;
   int system_id = 0;
   if(SelectOurPosition(ticket, system_id))
     {
      g_position_was_open = true;
      if(system_id > 0)
         g_tracked_system = system_id;
      g_tracked_position_id = (long)PositionGetInteger(POSITION_IDENTIFIER);
      g_tracked_position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return;
     }

   if(!g_position_was_open)
      return;

   if(g_tracked_system == 1 && g_tracked_position_id > 0)
     {
      double closed_profit = 0.0;
      const datetime from_time = (g_tracked_position_time > 0) ? g_tracked_position_time - 86400 : 0;
      if(HistorySelect(from_time, TimeCurrent() + 86400))
        {
         for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
           {
            const ulong deal = HistoryDealGetTicket(i);
            if(deal == 0)
               continue;
            if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
               continue;
            if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != QM_FrameworkMagic())
               continue;
            if((long)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != g_tracked_position_id)
               continue;

            const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
               closed_profit += HistoryDealGetDouble(deal, DEAL_PROFIT) +
                                HistoryDealGetDouble(deal, DEAL_SWAP) +
                                HistoryDealGetDouble(deal, DEAL_COMMISSION);
           }
        }
      g_last_s1_was_win = (closed_profit > 0.0);
     }

   g_position_was_open = false;
   g_tracked_system = 0;
   g_tracked_position_id = 0;
   g_tracked_position_time = 0;
  }

bool ChannelWidthAllows(const double high, const double low, const double atr_value)
  {
   if(strategy_min_channel_atr_mult <= 0.0)
      return true;
   if(high <= low || atr_value <= 0.0)
      return false;
   return ((high - low) >= strategy_min_channel_atr_mult * atr_value);
  }

bool FillMarketRequest(QM_EntryRequest &req, const int system_id, const int direction, const double atr_value)
  {
   const double entry_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0 || atr_value <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeStrategyPrice((direction > 0)
                                   ? entry_price - strategy_atr_stop_mult * atr_value
                                   : entry_price + strategy_atr_stop_mult * atr_value);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = StringFormat("ET_TURTLE_S%d_%s", system_id, (direction > 0) ? "LONG" : "SHORT");
   return (req.sl > 0.0);
  }

bool InConfiguredSession(const datetime broker_time)
  {
   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;

   MqlDateTime t;
   TimeToStruct(broker_time, t);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   if(end_h >= 24)
      return (t.hour >= start_h);
   if(start_h < end_h)
      return (t.hour >= start_h && t.hour < end_h);
   return (t.hour >= start_h || t.hour < end_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: time/session and spread; news is handled by Strategy_NewsFilterHook/framework.
   if(!InConfiguredSession(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
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
   UpdateSystem1OutcomeState();
   if(!RefreshChannelCache())
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   int system_id = 0;
   int direction = 0;

   if(ChannelWidthAllows(g_s2_entry_high, g_s2_entry_low, atr_value))
     {
      if(g_last_closed_close > g_s2_entry_high)
        {
         system_id = 2;
         direction = 1;
        }
      else if(g_last_closed_close < g_s2_entry_low)
        {
         system_id = 2;
         direction = -1;
        }
     }

   if(system_id == 0 && (!strategy_skip_s1_after_win || !g_last_s1_was_win) &&
      ChannelWidthAllows(g_s1_entry_high, g_s1_entry_low, atr_value))
     {
      if(g_last_closed_close > g_s1_entry_high)
        {
         system_id = 1;
         direction = 1;
        }
      else if(g_last_closed_close < g_s1_entry_low)
        {
         system_id = 1;
         direction = -1;
        }
     }

   if(system_id == 0 || direction == 0)
      return false;

   return FillMarketRequest(req, system_id, direction, atr_value);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   UpdateSystem1OutcomeState();
   if(!g_channel_cache_ready)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      int system_id = SystemFromComment(PositionGetString(POSITION_COMMENT));
      if(system_id == 0)
         system_id = g_tracked_system;
      if(system_id != 1 && system_id != 2)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double channel_sl = is_buy
                                ? ((system_id == 1) ? g_s1_exit_low : g_s2_exit_low)
                                : ((system_id == 1) ? g_s1_exit_high : g_s2_exit_high);
      if(channel_sl <= 0.0)
         continue;

      const double target_sl = NormalizeStrategyPrice(channel_sl);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "donchian_channel_exit_trail");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_channel_cache_ready)
      return false;

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

      int system_id = SystemFromComment(PositionGetString(POSITION_COMMENT));
      if(system_id == 0)
         system_id = g_tracked_system;
      if(system_id != 1 && system_id != 2)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double exit_low = (system_id == 1) ? g_s1_exit_low : g_s2_exit_low;
      const double exit_high = (system_id == 1) ? g_s1_exit_high : g_s2_exit_high;
      if(is_buy && g_last_closed_close < exit_low)
         return true;
      if(!is_buy && g_last_closed_close > exit_high)
         return true;

      if(strategy_max_hold_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_H1);
         if(opened > 0 && hold_seconds > 0 && TimeCurrent() - opened >= hold_seconds)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: callable for P8. The central framework applies the card's high-impact blackout.
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
