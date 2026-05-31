#property strict
#property version   "5.0"
#property description "QM5_10679 TradingView FVG 1R Session Strategy"

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
input int    qm_ea_id                   = 10679;
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
input int    strategy_atr_period               = 14;
input double strategy_min_fvg_atr              = 0.15;
input double strategy_stop_buffer_atr          = 0.10;
input double strategy_reward_r                 = 1.00;
input int    strategy_setup_expiry_bars        = 24;
input int    strategy_min_exit_bars            = 3;
input bool   strategy_enter_on_formation       = true;
input bool   strategy_enter_on_midpoint_retest = true;
input int    strategy_max_spread_points        = 0;
input int    strategy_fx_session_start_min     = 780;
input int    strategy_fx_session_end_min       = 1020;
input int    strategy_index_session_start_min  = 930;
input int    strategy_index_session_end_min    = 1320;

int    g_active_fvg_dir       = 0;
int    g_active_fvg_age_bars  = -1;
double g_active_fvg_bottom    = 0.0;
double g_active_fvg_top       = 0.0;
double g_active_fvg_stop_wick = 0.0;
bool   g_active_fvg_traded    = false;

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_IsIndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0 ||
           StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "DE30") >= 0 ||
           StringFind(_Symbol, "GER40") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0);
  }

bool Strategy_MinuteWindowContains(const int minute_of_day,
                                   const int raw_start,
                                   const int raw_end)
  {
   const int start_min = MathMax(0, MathMin(raw_start, 1439));
   const int end_min = MathMax(0, MathMin(raw_end, 1440));
   if(start_min == end_min)
      return true;
   if(start_min < end_min)
      return (minute_of_day >= start_min && minute_of_day < end_min);
   return (minute_of_day >= start_min || minute_of_day < end_min);
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime tm;
   TimeToStruct(broker_time, tm);
   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return false;

   const int minute_of_day = tm.hour * 60 + tm.min;
   if(Strategy_IsIndexSymbol())
      return Strategy_MinuteWindowContains(minute_of_day,
                                           strategy_index_session_start_min,
                                           strategy_index_session_end_min);

   return Strategy_MinuteWindowContains(minute_of_day,
                                        strategy_fx_session_start_min,
                                        strategy_fx_session_end_min);
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &ptype,
                                datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   return Strategy_SelectOurPosition(ptype, open_time);
  }

void Strategy_ResetActiveFVG()
  {
   g_active_fvg_dir = 0;
   g_active_fvg_age_bars = -1;
   g_active_fvg_bottom = 0.0;
   g_active_fvg_top = 0.0;
   g_active_fvg_stop_wick = 0.0;
   g_active_fvg_traded = false;
  }

bool Strategy_DetectFVG(const int shift,
                        int &direction,
                        double &gap_bottom,
                        double &gap_top,
                        double &middle_wick)
  {
   direction = 0;
   gap_bottom = 0.0;
   gap_top = 0.0;
   middle_wick = 0.0;

   const int atr_period = MathMax(1, strategy_atr_period);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_period, shift);
   if(atr <= 0.0)
      return false;

   const double current_low = iLow(_Symbol, _Period, shift);
   const double current_high = iHigh(_Symbol, _Period, shift);
   const double middle_low = iLow(_Symbol, _Period, shift + 1);
   const double middle_high = iHigh(_Symbol, _Period, shift + 1);
   const double older_high = iHigh(_Symbol, _Period, shift + 2);
   const double older_low = iLow(_Symbol, _Period, shift + 2);
   if(current_low <= 0.0 || current_high <= 0.0 ||
      middle_low <= 0.0 || middle_high <= 0.0 ||
      older_high <= 0.0 || older_low <= 0.0)
      return false;

   const double min_gap = MathMax(0.0, strategy_min_fvg_atr) * atr;
   if(current_low > older_high && current_low - older_high >= min_gap)
     {
      direction = 1;
      gap_bottom = older_high;
      gap_top = current_low;
      middle_wick = middle_low;
      return true;
     }

   if(current_high < older_low && older_low - current_high >= min_gap)
     {
      direction = -1;
      gap_bottom = current_high;
      gap_top = older_low;
      middle_wick = middle_high;
      return true;
     }

   return false;
  }

void Strategy_StoreActiveFVG(const int direction,
                             const double gap_bottom,
                             const double gap_top,
                             const double middle_wick)
  {
   g_active_fvg_dir = direction;
   g_active_fvg_age_bars = 0;
   g_active_fvg_bottom = gap_bottom;
   g_active_fvg_top = gap_top;
   g_active_fvg_stop_wick = middle_wick;
   g_active_fvg_traded = false;
  }

void Strategy_AdvanceActiveFVG()
  {
   if(g_active_fvg_dir == 0)
      return;

   g_active_fvg_age_bars++;
   const int expiry = MathMax(1, strategy_setup_expiry_bars);
   if(g_active_fvg_age_bars > expiry)
      Strategy_ResetActiveFVG();
  }

bool Strategy_StopDistanceAllowed(const QM_OrderType side,
                                  const double entry,
                                  const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   if(sl_points <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level > 0 && sl_points < (double)(stops_level + 1))
      return false;

   if(QM_OrderTypeIsBuy(side))
      return (sl < entry);
   return (sl > entry);
  }

bool Strategy_BuildFVGEntry(const int direction,
                            const double middle_wick,
                            QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || middle_wick <= 0.0)
      return false;

   const double buffer = MathMax(0.0, strategy_stop_buffer_atr) * atr;
   const double rr = MathMax(0.1, strategy_reward_r);

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = (direction > 0) ? ask : bid;
   req.sl = (direction > 0)
            ? Strategy_NormalizePrice(middle_wick - buffer)
            : Strategy_NormalizePrice(middle_wick + buffer);
   if(!Strategy_StopDistanceAllowed(req.type, entry, req.sl))
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, rr);
   if(req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "TV_FVG_RR1_LONG" : "TV_FVG_RR1_SHORT";
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurPosition())
      return false;

   if(!Strategy_InSession(TimeCurrent()))
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

   Strategy_AdvanceActiveFVG();

   if(Strategy_HasOurPosition() || !Strategy_InSession(TimeCurrent()))
      return false;

   int current_dir = 0;
   double current_bottom = 0.0;
   double current_top = 0.0;
   double current_stop_wick = 0.0;
   const bool new_fvg = Strategy_DetectFVG(1,
                                           current_dir,
                                           current_bottom,
                                           current_top,
                                           current_stop_wick);
   if(new_fvg)
     {
      Strategy_StoreActiveFVG(current_dir,
                              current_bottom,
                              current_top,
                              current_stop_wick);
      if(strategy_enter_on_formation &&
         Strategy_BuildFVGEntry(current_dir, current_stop_wick, req))
        {
         g_active_fvg_traded = true;
         return true;
        }
     }

   if(!strategy_enter_on_midpoint_retest ||
      g_active_fvg_dir == 0 ||
      g_active_fvg_traded ||
      g_active_fvg_age_bars <= 0)
      return false;

   const double midpoint = (g_active_fvg_bottom + g_active_fvg_top) * 0.5;
   const double bar_low = iLow(_Symbol, _Period, 1);
   const double bar_high = iHigh(_Symbol, _Period, 1);
   if(midpoint <= 0.0 || bar_low <= 0.0 || bar_high <= 0.0)
      return false;

   const bool midpoint_touched = (g_active_fvg_dir > 0)
                                 ? (bar_low <= midpoint)
                                 : (bar_high >= midpoint);
   if(!midpoint_touched)
      return false;

   if(Strategy_BuildFVGEntry(g_active_fvg_dir, g_active_fvg_stop_wick, req))
     {
      g_active_fvg_traded = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Baseline management is fixed 1R TP/SL only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ptype, open_time))
      return false;

   if(!Strategy_InSession(TimeCurrent()))
      return true;

   if(open_time <= 0)
      return false;

   const int open_bars = iBarShift(_Symbol, _Period, open_time, false);
   if(open_bars < MathMax(1, strategy_min_exit_bars))
      return false;

   int fvg_dir = 0;
   double gap_bottom = 0.0;
   double gap_top = 0.0;
   double middle_wick = 0.0;
   if(!Strategy_DetectFVG(1, fvg_dir, gap_bottom, gap_top, middle_wick))
      return false;

   if(ptype == POSITION_TYPE_BUY && fvg_dir < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && fvg_dir > 0)
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
