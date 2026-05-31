#property strict
#property version   "5.0"
#property description "QM5_10701 TradingView NY Opening Range Fixed RR"

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
input int    qm_ea_id                   = 10701;
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
input int    strategy_or_start_hhmm           = 1530;
input int    strategy_or_duration_minutes     = 15;
input double strategy_stop_percent            = 0.50;
input double strategy_rr_target               = 2.0;
input int    strategy_max_losses_per_day      = 2;
input bool   strategy_max_entry_enabled       = true;
input int    strategy_max_entry_minutes       = 90;
input bool   strategy_session_close_enabled   = true;
input int    strategy_session_close_hhmm      = 2200;
input int    strategy_atr_period              = 14;
input double strategy_atr_trailing_mult       = 0.0;
input double strategy_atr_trailing_start_r    = 1.0;
input int    strategy_max_spread_points       = 0;
input int    strategy_or_scan_bars            = 128;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

int TimeOfDayMinutes(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HasOurOpenPosition()
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

int TodayConsecutiveLosses()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   if(!HistorySelect(DayStart(TimeCurrent()), TimeCurrent()))
      return 0;

   int losses = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
         continue;

      const double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                       + HistoryDealGetDouble(deal, DEAL_SWAP)
                       + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(net < 0.0)
        {
         losses++;
         continue;
        }
      break;
     }
   return losses;
  }

bool ComputeOpeningRange(double &or_high, double &or_low)
  {
   or_high = -DBL_MAX;
   or_low = DBL_MAX;

   const datetime day_start = DayStart(TimeCurrent());
   const int start_min = HhmmToMinutes(strategy_or_start_hhmm);
   const int end_min = start_min + strategy_or_duration_minutes;
   if(start_min < 0 || strategy_or_duration_minutes <= 0 || end_min > 1440)
      return false;

   bool found = false;
   const int scan_bars = MathMax(1, MathMin(strategy_or_scan_bars, 512));
   for(int shift = 1; shift <= scan_bars; ++shift)
     {
      const datetime bt = iTime(_Symbol, _Period, shift);
      if(bt <= 0)
         continue;
      if(bt < day_start)
         break;

      const int minute = TimeOfDayMinutes(bt);
      if(minute < start_min || minute >= end_min)
         continue;

      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0 || h < l)
         continue;

      or_high = MathMax(or_high, h);
      or_low = MathMin(or_low, l);
      found = true;
     }

   return found && or_high > or_low && or_low > 0.0;
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

// Return TRUE to BLOCK new entries this tick. Existing positions still reach
// management and close hooks, including the session-close exit.
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   if(!SpreadAllowed())
      return true;

   const int start_min = HhmmToMinutes(strategy_or_start_hhmm);
   const int end_min = start_min + strategy_or_duration_minutes;
   const int now_min = TimeOfDayMinutes(TimeCurrent());
   if(start_min < 0 || strategy_or_duration_minutes <= 0 || end_min > 1440)
      return true;

   if(now_min < end_min)
      return true;

   if(strategy_max_entry_enabled && now_min > end_min + strategy_max_entry_minutes)
      return true;

   if(strategy_session_close_enabled && now_min >= HhmmToMinutes(strategy_session_close_hhmm))
      return true;

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

   if(HasOurOpenPosition())
      return false;

   if(strategy_max_losses_per_day > 0 && TodayConsecutiveLosses() >= strategy_max_losses_per_day)
      return false;

   const int start_min = HhmmToMinutes(strategy_or_start_hhmm);
   const int end_min = start_min + strategy_or_duration_minutes;
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(start_min < 0 || strategy_or_duration_minutes <= 0 || end_min > 1440 || bar_time <= 0)
      return false;

   const int bar_min = TimeOfDayMinutes(bar_time);
   if(bar_min < end_min)
      return false;
   if(strategy_max_entry_enabled && bar_min > end_min + strategy_max_entry_minutes)
      return false;
   if(strategy_session_close_enabled && bar_min >= HhmmToMinutes(strategy_session_close_hhmm))
      return false;

   double or_high = 0.0;
   double or_low = 0.0;
   if(!ComputeOpeningRange(or_high, or_low))
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(close_1 <= 0.0 || bid <= 0.0 || ask <= 0.0 || strategy_stop_percent <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const double stop_frac = strategy_stop_percent / 100.0;
   if(close_1 > or_high)
     {
      req.type = QM_BUY;
      req.price = QM_StopRulesNormalizePrice(_Symbol, ask);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, req.price * (1.0 - stop_frac));
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_target);
      req.reason = "TV_OR_NY_RR_LONG";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < or_low)
     {
      req.type = QM_SELL;
      req.price = QM_StopRulesNormalizePrice(_Symbol, bid);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, req.price * (1.0 + stop_frac));
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_target);
      req.reason = "TV_OR_NY_RR_SHORT";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_atr_trailing_mult <= 0.0 || strategy_atr_period <= 0)
      return;

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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double base_risk = open_price * strategy_stop_percent / 100.0;
      if(open_price <= 0.0 || base_risk <= 0.0)
         continue;

      const double market = (type == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double favorable = (type == POSITION_TYPE_BUY) ? (market - open_price) : (open_price - market);
      if(favorable < base_risk * strategy_atr_trailing_start_r)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trailing_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_session_close_enabled)
      return false;

   const int close_min = HhmmToMinutes(strategy_session_close_hhmm);
   if(close_min < 0)
      return false;

   return TimeOfDayMinutes(TimeCurrent()) >= close_min;
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
