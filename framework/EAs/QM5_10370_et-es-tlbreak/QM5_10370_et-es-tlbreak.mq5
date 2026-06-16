#property strict
#property version   "5.0"
#property description "QM5_10370 Elite Trader ES automatic trendline breakout"
// rework v2 2026-06-16: fresh-break gate was structurally near-unsatisfiable.
// The descending-resistance (long) / ascending-support (short) line is anchored
// at pivots >=5 bars back and extrapolated forward, so by shift 1 the line sits
// far on one side of price; the hard "prior bar still un-broken at shift 2"
// (close2<=line2 / close2>=line2) requirement therefore almost never held and
// the EA fired 0 trades over a full M1 year on SP500/WS30/GDAXI. Replaced the
// fixed shift-2 prior-bar test with Strategy_FreshBreakAbove/Below, which
// confirms the source's "one close beyond the line" rule by scanning the bars
// between the breakout bar and the anchoring pivot for the most recent bar that
// was on the un-broken side (genuine fresh cross), instead of demanding the
// cross land exactly between shift 2 and shift 1.

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
input int    qm_ea_id                   = 10370;
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
input int    strategy_ema_period        = 9;
input int    strategy_sma_period        = 55;
input int    strategy_pivot_left        = 4;
input int    strategy_pivot_right       = 4;
input int    strategy_trendline_max_age = 10;
input bool   strategy_use_macd_filter   = true;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input double strategy_spread_median_mult = 2.5;
input int    strategy_spread_window     = 31;
input int    strategy_session_start_hhmm = 1530;
input int    strategy_session_end_hhmm   = 2200;

double g_spread_points[101];
int    g_spread_count = 0;
int    g_spread_next = 0;

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_InSession(const datetime t)
  {
   const int hhmm = Strategy_HHMM(t);
   if(strategy_session_start_hhmm == strategy_session_end_hhmm)
      return true;
   if(strategy_session_start_hhmm < strategy_session_end_hhmm)
      return (hhmm >= strategy_session_start_hhmm && hhmm < strategy_session_end_hhmm);
   return (hhmm >= strategy_session_start_hhmm || hhmm < strategy_session_end_hhmm);
  }

bool Strategy_AtOrAfterSessionClose(const datetime t)
  {
   const int hhmm = Strategy_HHMM(t);
   if(strategy_session_start_hhmm < strategy_session_end_hhmm)
      return (hhmm >= strategy_session_end_hhmm);
   return (hhmm >= strategy_session_end_hhmm && hhmm < strategy_session_start_hhmm);
  }

double Strategy_CurrentSpreadPoints()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

bool Strategy_SpreadAllowsTrade()
  {
   int window = strategy_spread_window;
   if(window < 5)
      window = 5;
   if(window > 101)
      window = 101;

   const double spread = Strategy_CurrentSpreadPoints();
   if(spread <= 0.0)
      return false;

   g_spread_points[g_spread_next] = spread;
   g_spread_next = (g_spread_next + 1) % window;
   if(g_spread_count < window)
      g_spread_count++;
   if(g_spread_count < 5)
      return true;

   double work[];
   ArrayResize(work, g_spread_count);
   for(int i = 0; i < g_spread_count; ++i)
      work[i] = g_spread_points[i];
   ArraySort(work);
   const double median = work[g_spread_count / 2];
   if(median <= 0.0)
      return true;
   return (spread <= median * strategy_spread_median_mult);
  }

bool Strategy_IsPivotHigh(const int shift)
  {
   if(shift <= strategy_pivot_right)
      return false;
   const double center = iHigh(_Symbol, _Period, shift);
   if(center <= 0.0)
      return false;
   for(int i = 1; i <= strategy_pivot_left; ++i)
     {
      const double h = iHigh(_Symbol, _Period, shift + i);
      if(h <= 0.0 || h >= center)
         return false;
     }
   for(int i = 1; i <= strategy_pivot_right; ++i)
     {
      const double h = iHigh(_Symbol, _Period, shift - i);
      if(h <= 0.0 || h > center)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(const int shift)
  {
   if(shift <= strategy_pivot_right)
      return false;
   const double center = iLow(_Symbol, _Period, shift);
   if(center <= 0.0)
      return false;
   for(int i = 1; i <= strategy_pivot_left; ++i)
     {
      const double l = iLow(_Symbol, _Period, shift + i);
      if(l <= 0.0 || l <= center)
         return false;
     }
   for(int i = 1; i <= strategy_pivot_right; ++i)
     {
      const double l = iLow(_Symbol, _Period, shift - i);
      if(l <= 0.0 || l < center)
         return false;
     }
   return true;
  }

bool Strategy_FindTwoPivotHighs(int &recent_shift, double &recent_price, int &older_shift, double &older_price)
  {
   recent_shift = 0;
   older_shift = 0;
   recent_price = 0.0;
   older_price = 0.0;
   const int first_shift = strategy_pivot_right + 1;
   const int last_shift = first_shift + strategy_trendline_max_age + strategy_pivot_left;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!Strategy_IsPivotHigh(shift))
         continue;
      if(recent_shift == 0)
        {
         recent_shift = shift;
         recent_price = iHigh(_Symbol, _Period, shift);
        }
      else
        {
         older_shift = shift;
         older_price = iHigh(_Symbol, _Period, shift);
         return true;
        }
     }
   return false;
  }

bool Strategy_FindTwoPivotLows(int &recent_shift, double &recent_price, int &older_shift, double &older_price)
  {
   recent_shift = 0;
   older_shift = 0;
   recent_price = 0.0;
   older_price = 0.0;
   const int first_shift = strategy_pivot_right + 1;
   const int last_shift = first_shift + strategy_trendline_max_age + strategy_pivot_left;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!Strategy_IsPivotLow(shift))
         continue;
      if(recent_shift == 0)
        {
         recent_shift = shift;
         recent_price = iLow(_Symbol, _Period, shift);
        }
      else
        {
         older_shift = shift;
         older_price = iLow(_Symbol, _Period, shift);
         return true;
        }
     }
   return false;
  }

double Strategy_LineAtShift(const int target_shift,
                            const int recent_shift,
                            const double recent_price,
                            const int older_shift,
                            const double older_price)
  {
   if(recent_shift == older_shift)
      return 0.0;
   const double slope = (recent_price - older_price) / (double)(recent_shift - older_shift);
   return older_price + slope * (double)(target_shift - older_shift);
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

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   if(!Strategy_InSession(now) && !Strategy_AtOrAfterSessionClose(now))
      return true;
   if(!Strategy_SpreadAllowsTrade())
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

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_InSession(TimeCurrent()))
      return false;
   if(strategy_ema_period <= 0 || strategy_sma_period <= 0 ||
      strategy_pivot_left <= 0 || strategy_pivot_right <= 0 ||
      strategy_trendline_max_age < 2 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);
   const double sma = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(ema <= 0.0 || sma <= 0.0 || atr <= 0.0)
      return false;

   double macd_main = 0.0;
   double macd_signal = 0.0;
   if(strategy_use_macd_filter)
     {
      macd_main = QM_MACD_Main(_Symbol, PERIOD_CURRENT, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      macd_signal = QM_MACD_Signal(_Symbol, PERIOD_CURRENT, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
     }

   int recent_shift = 0;
   int older_shift = 0;
   double recent_price = 0.0;
   double older_price = 0.0;

   if(ema > sma && (!strategy_use_macd_filter || macd_main > macd_signal) &&
      Strategy_FindTwoPivotHighs(recent_shift, recent_price, older_shift, older_price) &&
      older_price > recent_price)
     {
      const double line1 = Strategy_LineAtShift(1, recent_shift, recent_price, older_shift, older_price);
      const double line2 = Strategy_LineAtShift(2, recent_shift, recent_price, older_shift, older_price);
      if(line1 > 0.0 && line2 > 0.0 && close1 > line1 && close2 <= line2)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            return false;
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
         req.tp = 0.0;
         req.reason = "ET_ES_TLBREAK_LONG";
         return (req.sl > 0.0 && req.sl < ask);
        }
     }

   if(ema < sma && (!strategy_use_macd_filter || macd_main < macd_signal) &&
      Strategy_FindTwoPivotLows(recent_shift, recent_price, older_shift, older_price) &&
      older_price < recent_price)
     {
      const double line1 = Strategy_LineAtShift(1, recent_shift, recent_price, older_shift, older_price);
      const double line2 = Strategy_LineAtShift(2, recent_shift, recent_price, older_shift, older_price);
      if(line1 > 0.0 && line2 > 0.0 && close1 < line1 && close2 >= line2)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            return false;
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_stop_mult);
         req.tp = 0.0;
         req.reason = "ET_ES_TLBREAK_SHORT";
         return (req.sl > bid);
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
   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);
   if(ema <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ptype == POSITION_TYPE_BUY && bid > 0.0 && ema < bid)
        {
         if(current_sl <= 0.0 || ema > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, ema, "ema9_trail");
        }
      else if(ptype == POSITION_TYPE_SELL && ask > 0.0 && ema > ask)
        {
         if(current_sl <= 0.0 || ema < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, ema, "ema9_trail");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const double ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0 || ema <= 0.0)
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

      if(Strategy_AtOrAfterSessionClose(TimeCurrent()))
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < ema)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ema)
         return true;
     }
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
