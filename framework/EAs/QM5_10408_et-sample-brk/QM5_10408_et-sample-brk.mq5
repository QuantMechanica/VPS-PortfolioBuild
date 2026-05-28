#property strict
#property version   "5.0"
#property description "QM5_10408 Elite Trader Sample-Time Breakout"

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
input int    qm_ea_id                   = 10408;
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
input int    strategy_sample_start_hhmm      = 1000;
input int    strategy_sample_end_hhmm        = 1001;
input int    strategy_session_end_hhmm       = 2200;
input double strategy_percent_hi             = 0.001;
input double strategy_percent_low            = 0.001;
input int    strategy_atr_period             = 20;
input double strategy_max_stop_atr_mult      = 2.0;
input double strategy_target_rr              = 1.0;
input double strategy_daily_profit_cutoff    = 1000.0;
input double strategy_daily_loss_cutoff      = 1000.0;
input int    strategy_max_spread_points      = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesOfDay(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_InMinuteWindow(const int now_min, const int start_min, const int end_min)
  {
   if(start_min <= end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

bool Strategy_AfterOrAtMinute(const int now_min, const int mark_min)
  {
   return (now_min >= mark_min);
  }

bool Strategy_ParamsOK()
  {
   return (strategy_sample_start_hhmm >= 0 &&
           strategy_sample_start_hhmm <= 2359 &&
           strategy_sample_end_hhmm >= 0 &&
           strategy_sample_end_hhmm <= 2359 &&
           strategy_session_end_hhmm >= 0 &&
           strategy_session_end_hhmm <= 2359 &&
           strategy_percent_hi > 0.0 &&
           strategy_percent_low > 0.0 &&
           strategy_atr_period > 0 &&
           strategy_max_stop_atr_mult > 0.0 &&
           strategy_target_rr > 0.0 &&
           strategy_daily_profit_cutoff >= 0.0 &&
           strategy_daily_loss_cutoff >= 0.0 &&
           strategy_max_spread_points >= 0);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   return QM_TradeContextSend(request, result, error_class);
  }

void Strategy_DeleteOurPendingStops(const string reason)
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
      if(!Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeletePendingOrder(ticket, reason);
     }
  }

bool Strategy_SpreadOK()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
      return false;
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

double Strategy_OpenPnL()
  {
   const int magic = QM_FrameworkMagic();
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

double Strategy_ClosedPnLToday()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   if(!HistorySelect(Strategy_DayStart(now), now))
      return 0.0;

   double pnl = 0.0;
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
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
   return pnl;
  }

double Strategy_DayPnL()
  {
   return Strategy_ClosedPnLToday() + Strategy_OpenPnL();
  }

bool Strategy_DailyCutoffHit()
  {
   const double pnl = Strategy_DayPnL();
   if(strategy_daily_profit_cutoff > 0.0 && pnl >= strategy_daily_profit_cutoff)
      return true;
   if(strategy_daily_loss_cutoff > 0.0 && pnl <= -strategy_daily_loss_cutoff)
      return true;
   return false;
  }

bool Strategy_HasFilledTradeToday()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   if(!HistorySelect(Strategy_DayStart(now), now))
      return false;

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
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

int Strategy_SecondsUntilSessionEnd()
  {
   const int end_min = Strategy_MinutesOfDay(strategy_session_end_hhmm);
   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   int remaining = end_min - now_min;
   if(remaining <= 0)
      remaining += 24 * 60;
   return MathMax(60, remaining * 60);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news; this hook
   // blocks fresh entries after the session cutoff and on excessive spread.
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   if(!Strategy_ParamsOK())
      return true;

   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   if(Strategy_AfterOrAtMinute(now_min, Strategy_MinutesOfDay(strategy_session_end_hhmm)))
      return true;

   return !Strategy_SpreadOK();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: collect the fixed sample-window high/low, then place one
   // stop entry if the last close sits inside the card's trigger region.
   Strategy_InitRequest(req);

   if(!Strategy_ParamsOK())
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;
   if(Strategy_DailyCutoffHit() || Strategy_HasFilledTradeToday())
      return false;

   static int    s_day_key = -1;
   static bool   s_sample_started = false;
   static bool   s_sample_ready = false;
   static bool   s_order_submitted = false;
   static double s_high_val = 0.0;
   static double s_low_val = 0.0;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   const int day_key = Strategy_DayKey(bar_time);
   if(day_key != s_day_key)
     {
      s_day_key = day_key;
      s_sample_started = false;
      s_sample_ready = false;
      s_order_submitted = false;
      s_high_val = 0.0;
      s_low_val = 0.0;
     }

   if(s_order_submitted)
      return false;

   const int bar_min = Strategy_MinutesOfDay(Strategy_Hhmm(bar_time));
   const int sample_start_min = Strategy_MinutesOfDay(strategy_sample_start_hhmm);
   const int sample_end_min = Strategy_MinutesOfDay(strategy_sample_end_hhmm);
   const int session_end_min = Strategy_MinutesOfDay(strategy_session_end_hhmm);

   if(Strategy_InMinuteWindow(bar_min, sample_start_min, sample_end_min))
     {
      const double h = iHigh(_Symbol, _Period, 1);
      const double l = iLow(_Symbol, _Period, 1);
      if(h <= 0.0 || l <= 0.0 || h < l)
         return false;

      if(!s_sample_started)
        {
         s_sample_started = true;
         s_high_val = h;
         s_low_val = l;
        }
      else
        {
         s_high_val = MathMax(s_high_val, h);
         s_low_val = MathMin(s_low_val, l);
        }
      return false;
     }

   if(s_sample_started && !s_sample_ready && !Strategy_InMinuteWindow(bar_min, sample_start_min, sample_end_min))
      s_sample_ready = true;

   if(!s_sample_ready)
      return false;
   if(Strategy_AfterOrAtMinute(bar_min, session_end_min))
      return false;

   const double range = s_high_val - s_low_val;
   if(range <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close1 <= 0.0 || point <= 0.0)
      return false;

   const double long_trigger = QM_TM_NormalizePrice(_Symbol, s_high_val * (1.0 + strategy_percent_hi * 0.01));
   const double short_trigger = QM_TM_NormalizePrice(_Symbol, s_low_val * (1.0 - strategy_percent_low * 0.01));
   if(long_trigger <= s_high_val || short_trigger >= s_low_val || short_trigger <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(close1 >= s_high_val && close1 <= long_trigger)
     {
      const double stop_distance = long_trigger - s_low_val;
      if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * atr)
         return false;
      req.type = QM_BUY_STOP;
      req.price = long_trigger;
      req.sl = QM_TM_NormalizePrice(_Symbol, s_low_val);
      req.tp = QM_TM_NormalizePrice(_Symbol, long_trigger + strategy_target_rr * stop_distance);
      req.reason = "ET_SAMPLE_BRK_BUY_STOP";
      req.expiration_seconds = Strategy_SecondsUntilSessionEnd();
      if(req.sl <= 0.0 || req.sl >= req.price || req.tp <= req.price)
         return false;
      s_order_submitted = true;
      return true;
     }

   if(close1 <= s_low_val && close1 >= short_trigger)
     {
      const double stop_distance = s_high_val - short_trigger;
      if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * atr)
         return false;
      req.type = QM_SELL_STOP;
      req.price = short_trigger;
      req.sl = QM_TM_NormalizePrice(_Symbol, s_high_val);
      req.tp = QM_TM_NormalizePrice(_Symbol, short_trigger - strategy_target_rr * stop_distance);
      req.reason = "ET_SAMPLE_BRK_SELL_STOP";
      req.expiration_seconds = Strategy_SecondsUntilSessionEnd();
      if(req.sl <= req.price || req.tp >= req.price || req.tp <= 0.0)
         return false;
      s_order_submitted = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing or partial logic; remove obsolete stop
   // orders after a fill, after daily cutoff, or beyond the session end.
   if(Strategy_HasOurOpenPosition())
      Strategy_DeleteOurPendingStops("opposite_stop_after_fill");

   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   if(Strategy_AfterOrAtMinute(now_min, Strategy_MinutesOfDay(strategy_session_end_hhmm)) ||
      Strategy_DailyCutoffHit())
      Strategy_DeleteOurPendingStops("daily_or_session_stop_cleanup");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: exit at daily P/L cutoff or end of session.
   if(!Strategy_HasOurOpenPosition())
      return false;

   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   if(Strategy_AfterOrAtMinute(now_min, Strategy_MinutesOfDay(strategy_session_end_hhmm)))
      return true;

   return Strategy_DailyCutoffHit();
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook (callable for P8 News Impact phase): defer to framework.
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
