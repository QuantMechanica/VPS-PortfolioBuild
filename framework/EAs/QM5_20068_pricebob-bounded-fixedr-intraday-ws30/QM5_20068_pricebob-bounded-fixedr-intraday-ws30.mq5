#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 20068;
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
input int    strategy_lookback_bars                  = 6;
input int    strategy_max_entries_per_direction      = 3;
input double strategy_reward_risk                    = 2.0;
input int    strategy_daily_atr_period               = 14;
input double strategy_min_range_atr                  = 0.3;
input double strategy_max_range_atr                  = 2.5;
input double strategy_max_spread_range_fraction      = 0.15;
input int    strategy_session_open_hour_ny           = 9;
input int    strategy_session_open_minute_ny         = 30;
input int    strategy_session_close_hour_ny          = 16;
input int    strategy_session_close_minute_ny        = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // An open position must reach management and the session-close exit even
   // outside entry hours. The central news gate remains below those paths.
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now <= 0)
      return true;

   const int ny_utc_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + ny_utc_offset_hours * 3600;
   MqlDateTime ny_dt;
   if(!TimeToStruct(ny_now, ny_dt))
      return true;

   const int open_minute =
      strategy_session_open_hour_ny * 60 + strategy_session_open_minute_ny;
   const int close_minute =
      strategy_session_close_hour_ny * 60 + strategy_session_close_minute_ny;
   const int now_minute = ny_dt.hour * 60 + ny_dt.min;

   if(open_minute < 0 || close_minute > 1440 || open_minute >= close_minute)
      return true;
   return (now_minute < open_minute || now_minute >= close_minute);
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

   if(strategy_lookback_bars < 2 ||
      strategy_max_entries_per_direction < 1 ||
      strategy_reward_risk <= 0.0 ||
      strategy_daily_atr_period < 2 ||
      strategy_min_range_atr < 0.0 ||
      strategy_max_range_atr <= strategy_min_range_atr ||
      strategy_max_spread_range_fraction < 0.0)
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   if(utc_now <= 0)
      return false;

   const int ny_utc_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + ny_utc_offset_hours * 3600;
   MqlDateTime ny_dt;
   if(!TimeToStruct(ny_now, ny_dt))
      return false;

   const int open_minute =
      strategy_session_open_hour_ny * 60 + strategy_session_open_minute_ny;
   const int close_minute =
      strategy_session_close_hour_ny * 60 + strategy_session_close_minute_ny;
   const int now_minute = ny_dt.hour * 60 + ny_dt.min;
   if(open_minute < 0 || close_minute > 1440 || open_minute >= close_minute ||
      now_minute < open_minute || now_minute >= close_minute)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Rebuild the hard per-direction cap from executed deals since today's
   // New York cash-session open. This survives an EA restart mid-session.
   MqlDateTime session_start_dt = ny_dt;
   session_start_dt.hour = strategy_session_open_hour_ny;
   session_start_dt.min = strategy_session_open_minute_ny;
   session_start_dt.sec = 0;
   const datetime session_start_ny = StructToTime(session_start_dt);
   const datetime session_start_utc =
      session_start_ny - ny_utc_offset_hours * 3600;
   const datetime session_start_broker = QM_UTCToBroker(session_start_utc);
   if(session_start_broker <= 0 || !HistorySelect(session_start_broker, broker_now))
      return false;

   int long_entries = 0;
   int short_entries = 0;
   const int deal_total = HistoryDealsTotal();
   for(int i = 0; i < deal_total; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT)
         continue;

      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY)
         long_entries++;
      else if(deal_type == DEAL_TYPE_SELL)
         short_entries++;
     }

   // The trigger is the latest closed M15 bar. Its reference is the high/low
   // of the six bars immediately before it, so the trigger bar is excluded.
   const ENUM_TIMEFRAMES signal_tf = (ENUM_TIMEFRAMES)_Period;
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, signal_tf, 1, signal_bar) || signal_bar.close <= 0.0)
      return false;

   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   for(int shift = 2; shift < 2 + strategy_lookback_bars; ++shift)
     {
      MqlRates reference_bar;
      if(!QM_ReadBar(_Symbol, signal_tf, shift, reference_bar))
         return false;
      if(reference_bar.high <= 0.0 || reference_bar.low <= 0.0)
         return false;
      range_high = MathMax(range_high, reference_bar.high);
      range_low = MathMin(range_low, reference_bar.low);
     }

   const double range_width = range_high - range_low;
   const double daily_atr =
      QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, 1);
   if(range_width <= 0.0 || daily_atr <= 0.0)
      return false;
   if(range_width < strategy_min_range_atr * daily_atr ||
      range_width > strategy_max_range_atr * daily_atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   // DWX Model-4 quotes can validly carry ask == bid. Block only a genuinely
   // positive spread wider than the card's fraction of the rolling range.
   if(ask > bid &&
      (ask - bid) > strategy_max_spread_range_fraction * range_width)
      return false;

   if(signal_bar.close > range_high &&
      long_entries < strategy_max_entries_per_direction)
     {
      if(range_low >= ask)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, range_low);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_reward_risk);
      req.reason = "PRICEBOB_ROLLING_RANGE_LONG";
      return (req.sl > 0.0 && req.tp > ask);
     }

   if(signal_bar.close < range_low &&
      short_entries < strategy_max_entries_per_direction)
     {
      if(range_high <= bid)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, range_high);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_reward_risk);
      req.reason = "PRICEBOB_ROLLING_RANGE_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card rule: fixed SL and 2R TP only. No break-even, trail, partial close,
   // scale-in, or other mutation is authorized.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now <= 0)
      return false;

   const int ny_utc_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + ny_utc_offset_hours * 3600;
   MqlDateTime ny_dt;
   if(!TimeToStruct(ny_now, ny_dt))
      return false;

   const int open_minute =
      strategy_session_open_hour_ny * 60 + strategy_session_open_minute_ny;
   const int close_minute =
      strategy_session_close_hour_ny * 60 + strategy_session_close_minute_ny;
   if(open_minute < 0 || close_minute > 1440 || open_minute >= close_minute)
      return false;

   const int now_minute = ny_dt.hour * 60 + ny_dt.min;
   return (now_minute < open_minute || now_minute >= close_minute);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // central high-impact PRE30/POST30 entry gate applies
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

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
