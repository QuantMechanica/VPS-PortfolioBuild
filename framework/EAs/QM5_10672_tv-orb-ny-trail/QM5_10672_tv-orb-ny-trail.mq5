#property strict
#property version   "5.0"
#property description "QM5_10672 TradingView Opening Range NY Trail"

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
input int    qm_ea_id                   = 10672;
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
input int    strategy_opening_range_minutes = 15;
input int    strategy_open_hour             = 15;
input int    strategy_open_minute           = 30;
input int    strategy_max_entry_hour        = 20;
input int    strategy_max_entry_minute      = 0;
input bool   strategy_force_close_enabled   = true;
input int    strategy_force_close_hour      = 21;
input int    strategy_force_close_minute    = 55;
input double strategy_stop_pct              = 0.5;
input double strategy_rr_target             = 2.0;
input int    strategy_atr_period            = 14;
input double strategy_atr_trail_mult        = 2.0;
input int    strategy_max_consec_losses_day = 2;
input int    strategy_max_spread_points     = 100;

int     g_session_key = -1;
double  g_or_high = 0.0;
double  g_or_low = 0.0;
bool    g_or_defined = false;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_OpenMinutes()
  {
   return MathMax(0, MathMin(1439, strategy_open_hour * 60 + strategy_open_minute));
  }

int Strategy_MaxEntryMinutes()
  {
   return MathMax(0, MathMin(1439, strategy_max_entry_hour * 60 + strategy_max_entry_minute));
  }

int Strategy_ForceCloseMinutes()
  {
   return MathMax(0, MathMin(1439, strategy_force_close_hour * 60 + strategy_force_close_minute));
  }

void Strategy_ResetSession(const int key)
  {
   g_session_key = key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_defined = false;
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_InEntryWindow(const int minute_of_day)
  {
   const int open_min = Strategy_OpenMinutes();
   const int max_min = Strategy_MaxEntryMinutes();
   if(max_min >= open_min)
      return (minute_of_day >= open_min && minute_of_day <= max_min);
   return (minute_of_day >= open_min || minute_of_day <= max_min);
  }

void Strategy_UpdateOpeningRange()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return;

   const int key = Strategy_SessionKey(bar_time);
   if(key != g_session_key)
      Strategy_ResetSession(key);

   const int bar_min = Strategy_MinutesOfDay(bar_time);
   const int open_min = Strategy_OpenMinutes();
   const int since_open = (bar_min >= open_min) ? (bar_min - open_min) : (bar_min + 1440 - open_min);
   if(since_open < 0 || since_open >= 12 * 60)
      return;

   if(since_open < MathMax(1, strategy_opening_range_minutes))
     {
      const double high1 = iHigh(_Symbol, _Period, 1);
      const double low1 = iLow(_Symbol, _Period, 1);
      if(high1 <= 0.0 || low1 <= 0.0)
         return;
      if(g_or_high <= 0.0 || high1 > g_or_high)
         g_or_high = high1;
      if(g_or_low <= 0.0 || low1 < g_or_low)
         g_or_low = low1;
      return;
     }

   if(g_or_high > g_or_low && g_or_low > 0.0)
      g_or_defined = true;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_ConsecutiveLossesToday()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const datetime now = TimeCurrent();
   if(!HistorySelect(Strategy_DayStart(now), now))
      return 0;

   int losses = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT && entry_type != DEAL_ENTRY_INOUT && entry_type != DEAL_ENTRY_OUT_BY)
         continue;

      const double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT)
                       + HistoryDealGetDouble(deal, DEAL_SWAP)
                       + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(pnl < 0.0)
        {
         losses++;
         continue;
        }
      break;
     }
   return losses;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_InEntryWindow(Strategy_MinutesOfDay(TimeCurrent())))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point > 0.0 && ask > 0.0 && bid > 0.0)
     {
      const double spread_points = (ask - bid) / point;
      if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
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

   Strategy_UpdateOpeningRange();

   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_opening_range_minutes <= 0 || strategy_stop_pct <= 0.0 ||
      strategy_rr_target <= 0.0 || strategy_atr_period <= 0 || strategy_atr_trail_mult <= 0.0)
      return false;
   if(strategy_max_consec_losses_day > 0 &&
      Strategy_ConsecutiveLossesToday() >= strategy_max_consec_losses_day)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0 || !Strategy_InEntryWindow(Strategy_MinutesOfDay(TimeCurrent())))
      return false;
   if(!g_or_defined || g_or_high <= g_or_low || g_or_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > g_or_high)
     {
      const double entry = ask;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_stop_pct / 100.0));
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr_target);
      if(sl > 0.0 && sl < entry && tp > 0.0)
        {
         req.type = QM_BUY;
         req.sl = sl;
         req.tp = tp;
         req.reason = "TV_ORB_NY_TRAIL_LONG";
         return true;
        }
     }

   if(close1 < g_or_low)
     {
      const double entry = bid;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_stop_pct / 100.0));
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr_target);
      if(sl > entry && tp > 0.0)
        {
         req.type = QM_SELL;
         req.sl = sl;
         req.tp = tp;
         req.reason = "TV_ORB_NY_TRAIL_SHORT";
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_force_close_enabled || !Strategy_HasOpenPosition())
      return false;

   const int now_min = Strategy_MinutesOfDay(TimeCurrent());
   if(now_min >= Strategy_ForceCloseMinutes())
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
