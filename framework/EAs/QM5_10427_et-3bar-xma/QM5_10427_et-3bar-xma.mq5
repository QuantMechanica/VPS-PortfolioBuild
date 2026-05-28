#property strict
#property version   "5.0"
#property description "QM5_10427 Elite Trader Three-Bar XMA Range Breakout"

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
input int    qm_ea_id                   = 10427;
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
input int    strategy_xma_period          = 200;
input int    strategy_atr_period          = 20;
input double strategy_max_range_atr_mult  = 0.75;
input double strategy_min_stop_atr_mult   = 0.75;
input double strategy_body_range_min      = 0.65;
input double strategy_target_range_mult   = 0.50;
input int    strategy_entry_buffer_points = 0;
input int    strategy_window1_start_hhmm  = 0;
input int    strategy_window1_end_hhmm    = 2359;
input int    strategy_window2_start_hhmm  = -1;
input int    strategy_window2_end_hhmm    = -1;
input int    strategy_window3_start_hhmm  = -1;
input int    strategy_window3_end_hhmm    = -1;
input int    strategy_session_close_hhmm  = 2359;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm < 0 || end_hhmm < 0)
      return false;
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm <= end_hhmm);
   return (hhmm >= start_hhmm || hhmm <= end_hhmm);
  }

bool Strategy_InEntryWindow(const datetime t)
  {
   const int hhmm = Strategy_Hhmm(t);
   return (Strategy_HhmmInWindow(hhmm, strategy_window1_start_hhmm, strategy_window1_end_hhmm) ||
           Strategy_HhmmInWindow(hhmm, strategy_window2_start_hhmm, strategy_window2_end_hhmm) ||
           Strategy_HhmmInWindow(hhmm, strategy_window3_start_hhmm, strategy_window3_end_hhmm));
  }

datetime Strategy_EndTimeForWindow(const datetime t, const int start_hhmm, const int end_hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = end_hhmm / 100;
   dt.min = end_hhmm % 100;
   dt.sec = 0;
   datetime end_time = StructToTime(dt);
   if(start_hhmm > end_hhmm && Strategy_Hhmm(t) >= start_hhmm)
      end_time += 86400;
   return end_time;
  }

int Strategy_SecondsUntilWindowClose(const datetime t)
  {
   const int hhmm = Strategy_Hhmm(t);
   datetime best = 0;
   if(Strategy_HhmmInWindow(hhmm, strategy_window1_start_hhmm, strategy_window1_end_hhmm))
      best = Strategy_EndTimeForWindow(t, strategy_window1_start_hhmm, strategy_window1_end_hhmm);
   if(Strategy_HhmmInWindow(hhmm, strategy_window2_start_hhmm, strategy_window2_end_hhmm))
     {
      const datetime e = Strategy_EndTimeForWindow(t, strategy_window2_start_hhmm, strategy_window2_end_hhmm);
      if(best == 0 || e < best)
         best = e;
     }
   if(Strategy_HhmmInWindow(hhmm, strategy_window3_start_hhmm, strategy_window3_end_hhmm))
     {
      const datetime e = Strategy_EndTimeForWindow(t, strategy_window3_start_hhmm, strategy_window3_end_hhmm);
      if(best == 0 || e < best)
         best = e;
     }
   if(best <= t)
      return 0;
   return (int)(best - t);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void Strategy_RemoveOurPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_HasFilledTradeThisSession(const datetime t)
  {
   MqlDateTime start_dt;
   TimeToStruct(t, start_dt);
   start_dt.hour = 0;
   start_dt.min = 0;
   start_dt.sec = 0;
   const datetime session_start = StructToTime(start_dt);
   if(!HistorySelect(session_start, t))
      return false;

   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

double Strategy_HighestHigh3()
  {
   return MathMax(iHigh(_Symbol, _Period, 1),
                  MathMax(iHigh(_Symbol, _Period, 2), iHigh(_Symbol, _Period, 3)));
  }

double Strategy_LowestLow3()
  {
   return MathMin(iLow(_Symbol, _Period, 1),
                  MathMin(iLow(_Symbol, _Period, 2), iLow(_Symbol, _Period, 3)));
  }

bool Strategy_Bullish3()
  {
   return (iClose(_Symbol, _Period, 1) > iOpen(_Symbol, _Period, 1) &&
           iClose(_Symbol, _Period, 2) > iOpen(_Symbol, _Period, 2) &&
           iClose(_Symbol, _Period, 3) > iOpen(_Symbol, _Period, 3));
  }

bool Strategy_Bearish3()
  {
   return (iClose(_Symbol, _Period, 1) < iOpen(_Symbol, _Period, 1) &&
           iClose(_Symbol, _Period, 2) < iOpen(_Symbol, _Period, 2) &&
           iClose(_Symbol, _Period, 3) < iOpen(_Symbol, _Period, 3));
  }

bool Strategy_PriorBodyFilter()
  {
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2 = iLow(_Symbol, _Period, 2);
   const double range2 = high2 - low2;
   if(range2 <= 0.0)
      return false;
   const double body2 = MathAbs(iClose(_Symbol, _Period, 2) - iOpen(_Symbol, _Period, 2));
   return (body2 / range2 > strategy_body_range_min);
  }

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InEntryWindow(TimeCurrent()))
      Strategy_RemoveOurPendingOrders("entry_window_closed");

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   if(!Strategy_InEntryWindow(now))
      return false;
   if(Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;
   if(Strategy_HasFilledTradeThisSession(now))
      return false;

   if(Bars(_Symbol, _Period) < strategy_xma_period + 5)
      return false;
   if(strategy_xma_period < 1 || strategy_atr_period < 1 ||
      strategy_max_range_atr_mult <= 0.0 || strategy_min_stop_atr_mult <= 0.0 ||
      strategy_body_range_min <= 0.0 || strategy_target_range_mult <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   if(!Strategy_PriorBodyFilter())
      return false;

   const double setup_high = Strategy_HighestHigh3();
   const double setup_low = Strategy_LowestLow3();
   const double setup_range = setup_high - setup_low;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double xma = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_xma_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(setup_range <= 0.0 || atr <= 0.0 || xma <= 0.0 || point <= 0.0)
      return false;
   if(setup_range >= strategy_max_range_atr_mult * atr)
      return false;

   const double buffer = strategy_entry_buffer_points * point;
   const double stop_dist = MathMax(setup_range, strategy_min_stop_atr_mult * atr);
   const int expiry = Strategy_SecondsUntilWindowClose(now);
   if(expiry <= 0)
      return false;

   if(Strategy_Bullish3() && close1 < high1 && close1 > xma)
     {
      req.type = QM_BUY_STOP;
      req.price = Strategy_NormalizePrice(setup_high + buffer);
      req.sl = Strategy_NormalizePrice(req.price - stop_dist);
      req.tp = Strategy_NormalizePrice(req.price + strategy_target_range_mult * setup_range);
      req.reason = "three_bar_xma_long_stop";
      req.expiration_seconds = expiry;
      return true;
     }

   if(Strategy_Bearish3() && close1 > low1 && close1 < xma)
     {
      req.type = QM_SELL_STOP;
      req.price = Strategy_NormalizePrice(setup_low - buffer);
      req.sl = Strategy_NormalizePrice(req.price + stop_dist);
      req.tp = Strategy_NormalizePrice(req.price - strategy_target_range_mult * setup_range);
      req.reason = "three_bar_xma_short_stop";
      req.expiration_seconds = expiry;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   const int hhmm = Strategy_Hhmm(TimeCurrent());
   return (hhmm >= strategy_session_close_hhmm);
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
