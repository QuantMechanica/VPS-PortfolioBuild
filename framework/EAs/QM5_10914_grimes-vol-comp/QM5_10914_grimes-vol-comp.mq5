#property strict
#property version   "5.0"
#property description "QM5_10914 Grimes Volatility Compression Breakout (grimes-vol-comp)"
// rework v2 2026-06-16 — fix 0-trade scale bug: a 20-bar high-low RANGE was gated
// against 1.25*ATR(60), a SINGLE-bar quantity, so the consolidation test could
// never pass (a 20-bar range is several ATRs wide even in compression). Scale the
// baseline to the window via sqrt(RangeLookback) random-walk expectation so the
// 1.25 slack factor from the card applies to a window-sized range, not one bar.
// Strategy Card: QM5_10914 (grimes-vol-comp), G0 APPROVED 2026-05-22.
// Source: Adam H. Grimes, "Volatility Compression" (2011) + "Trading Volatility
// Compression" (2014). ATR(5)/ATR(60) compression -> first range-expansion break.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10914;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- Compression detection (card Entry §) ---
input int    InpAtrFastPeriod        = 5;     // ATR fast leg of compression ratio
input int    InpAtrSlowPeriod        = 60;    // ATR slow leg (baseline volatility)
input int    InpAtrSignalPeriod      = 14;    // ATR used for breakout offset / stop / trail
input double InpCompressionRatioMax  = 0.75;  // ATR(5)/ATR(60) must be below this
input int    InpCompressionLookback  = 5;     // ...for >= MinCount of the last N bars
input int    InpCompressionMinCount  = 3;     // 3 of last 5
input int    InpRangeLookback        = 20;    // 20-bar consolidation window
input double InpRangeAtrMult         = 1.25;  // 20-bar range <= 1.25 * ATR(60) * sqrt(lookback) to qualify
// --- Breakout trigger (card Entry §) ---
input double InpBreakoutAtrMult      = 0.10;  // close must exceed range by 0.1 * ATR(14)
// --- Stop loss (card Stop Loss §) ---
input double InpStopAtrMult          = 1.20;  // entry -/+ 1.2 * ATR(14) candidate
input double InpStopAtrMinMult       = 0.80;  // floor: stop distance never < 0.8 * ATR(14)
// --- Exit (card Exit §) ---
input double InpTpRMultiple          = 1.50;  // partial target at 1.5R
input double InpPartialCloseFraction = 0.50;  // fraction closed at 1.5R; trail remainder
input double InpChandelierAtrMult    = 2.00;  // trail = extreme close -/+ 2.0 * ATR(14)
input int    InpTimeExitBars         = 20;    // exit after 20 H1 bars if neither stop nor target
// --- Filters (card Zusaetzliche Filter §) ---
input double InpSpreadCapFrac        = 0.10;  // skip if spread > 10% of stop distance

// -----------------------------------------------------------------------------
// Open-trade state (cached; advanced once per closed bar via Strategy_EntrySignal,
// read O(1) per tick in Strategy_ManageOpenPosition / Strategy_ExitSignal).
// -----------------------------------------------------------------------------
ulong  g_active_ticket = 0;
bool   g_is_long       = false;
double g_entry_price   = 0.0;
double g_risk_R        = 0.0;   // |entry - initial SL|, captured at first sight of the position
double g_extreme_close = 0.0;   // highest close (long) / lowest close (short) since entry
bool   g_partial_done  = false;
int    g_bars_in_trade = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &cur_sl)
  {
   ticket = 0;
   open_price = 0.0;
   cur_sl = 0.0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      cur_sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

void EnsureTracking(const ulong ticket, const ENUM_POSITION_TYPE ptype,
                    const double open_price, const double cur_sl)
  {
   if(ticket == g_active_ticket)
      return;
   // First sight of a new position — capture entry baseline (SL not yet trailed).
   g_active_ticket = ticket;
   g_is_long       = (ptype == POSITION_TYPE_BUY);
   g_entry_price   = open_price;
   g_extreme_close = open_price;
   g_partial_done  = false;
   g_bars_in_trade = 0;
   g_risk_R        = MathAbs(open_price - cur_sl);
  }

// Card Stop Loss §: stop = opposite side of compression range OR entry -/+ 1.2*ATR,
// whichever is closer to entry, but never closer than 0.8*ATR.
double ComputeStop(const bool is_long, const double entry,
                   const double range_extreme, const double atr_sig)
  {
   double stop;
   if(is_long)
     {
      const double cand_range = range_extreme;                 // compression range low
      const double cand_atr   = entry - InpStopAtrMult * atr_sig;
      stop = MathMax(cand_range, cand_atr);                    // closer to entry = higher
      const double min_dist_stop = entry - InpStopAtrMinMult * atr_sig;
      if(stop > min_dist_stop)                                 // too tight -> push out to floor
         stop = min_dist_stop;
     }
   else
     {
      const double cand_range = range_extreme;                 // compression range high
      const double cand_atr   = entry + InpStopAtrMult * atr_sig;
      stop = MathMin(cand_range, cand_atr);                    // closer to entry = lower
      const double min_dist_stop = entry + InpStopAtrMinMult * atr_sig;
      if(stop < min_dist_stop)
         stop = min_dist_stop;
     }
   return NormalizeDouble(stop, _Digits);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news). Spread vs stop-distance is enforced in
// Strategy_EntrySignal (it needs the computed stop); news/time are handled by the
// framework axes + Friday-close guard. Cheap O(1) per-tick block goes here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar()==true, so this runs once per closed
// bar. It also advances cached open-trade state (chandelier extreme + bar counter)
// because this is the single framework-provided per-closed-bar hook.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // --- per-closed-bar advance of any open trade -------------------------------
   ulong ot;
   ENUM_POSITION_TYPE op;
   double oop, osl;
   if(GetOurPosition(ot, op, oop, osl))
     {
      EnsureTracking(ot, op, oop, osl);
      const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: last closed bar, new-bar gated
      if(c1 > 0.0)
        {
         if(op == POSITION_TYPE_BUY)
            g_extreme_close = MathMax(g_extreme_close, c1);
         else
            g_extreme_close = MathMin(g_extreme_close, c1);
        }
      g_bars_in_trade++;
      return false; // one active position per symbol/magic (card Filter §)
     }
   g_active_ticket = 0; // flat

   // --- compression state ------------------------------------------------------
   if(InpCompressionLookback < 1 || InpRangeLookback < 1)
      return false;

   int comp_count = 0;
   for(int s = 1; s <= InpCompressionLookback; ++s)
     {
      const double atr_fast = QM_ATR(_Symbol, _Period, InpAtrFastPeriod, s);
      const double atr_slow = QM_ATR(_Symbol, _Period, InpAtrSlowPeriod, s);
      if(atr_slow > 0.0 && (atr_fast / atr_slow) < InpCompressionRatioMax)
         comp_count++;
     }
   if(comp_count < InpCompressionMinCount)
      return false;

   const double atr_slow1 = QM_ATR(_Symbol, _Period, InpAtrSlowPeriod, 1);
   const double atr_sig   = QM_ATR(_Symbol, _Period, InpAtrSignalPeriod, 1);
   if(atr_slow1 <= 0.0 || atr_sig <= 0.0)
      return false;

   // 20-bar consolidation window PRIOR to the breakout bar (shifts 2..N+1).
   double hh = -DBL_MAX, ll = DBL_MAX;
   for(int i = 2; i <= InpRangeLookback + 1; ++i) // bespoke structural HH/LL, new-bar gated
     {
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed: structural 20-bar high, new-bar gated
      const double l = iLow(_Symbol, _Period, i);  // perf-allowed: structural 20-bar low, new-bar gated
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   const double range20 = hh - ll;
   if(range20 <= 0.0)
      return false;
   // A 20-bar HIGH-LOW range is a window quantity; ATR(60) is a single-bar quantity.
   // Compare like-for-like by scaling the baseline to the lookback window via the
   // random-walk sqrt(N) expectation, then apply the card's 1.25 compression slack.
   const double range_budget = InpRangeAtrMult * atr_slow1 * MathSqrt((double)InpRangeLookback);
   if(range20 > range_budget) // not compressed enough
      return false;

   // --- breakout trigger -------------------------------------------------------
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: breakout bar close
   if(c1 <= 0.0)
      return false;
   const double brk_offset = InpBreakoutAtrMult * atr_sig;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double spread = ask - bid;

   // Long: close breaks above the 20-bar high by >= 0.1*ATR(14).
   if(c1 > hh + brk_offset)
     {
      const double entry = ask;
      const double stop  = ComputeStop(true, entry, ll, atr_sig);
      if(stop <= 0.0 || stop >= entry)
         return false;
      if(spread > InpSpreadCapFrac * (entry - stop))
         return false;
      req.type               = QM_BUY;
      req.price              = 0.0; // market on next tick
      req.sl                 = stop;
      req.tp                 = 0.0; // managed: 1.5R partial + chandelier trail + time stop
      req.reason             = "grimes_volcomp_long";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short: close breaks below the 20-bar low by >= 0.1*ATR(14).
   if(c1 < ll - brk_offset)
     {
      const double entry = bid;
      const double stop  = ComputeStop(false, entry, hh, atr_sig);
      if(stop <= 0.0 || stop <= entry)
         return false;
      if(spread > InpSpreadCapFrac * (stop - entry))
         return false;
      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = stop;
      req.tp                 = 0.0;
      req.reason             = "grimes_volcomp_short";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Trade Management. Per tick, O(1): 1.5R partial close (once) + chandelier trail
// from the cached extreme close. No history scans, no recompute.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, cur_sl;
   if(!GetOurPosition(ticket, ptype, open_price, cur_sl))
     {
      g_active_ticket = 0;
      return;
     }
   EnsureTracking(ticket, ptype, open_price, cur_sl);
   if(g_risk_R <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;
   const double exit_price = is_long ? bid : ask;

   // Target 1: take partial at 1.5R, once.
   if(!g_partial_done)
     {
      const double target = is_long ? (g_entry_price + InpTpRMultiple * g_risk_R)
                                    : (g_entry_price - InpTpRMultiple * g_risk_R);
      const bool reached = is_long ? (exit_price >= target) : (exit_price <= target);
      if(reached)
        {
         const double vol = PositionGetDouble(POSITION_VOLUME);
         const double part = vol * InpPartialCloseFraction;
         if(part > 0.0 && QM_TM_PartialClose(ticket, part, QM_EXIT_PARTIAL))
            g_partial_done = true;
        }
     }

   // Chandelier trail from highest/lowest close since entry.
   const double atr = QM_ATR(_Symbol, _Period, InpAtrSignalPeriod, 1);
   if(atr > 0.0)
     {
      double trail_sl = is_long ? (g_extreme_close - InpChandelierAtrMult * atr)
                                : (g_extreme_close + InpChandelierAtrMult * atr);
      trail_sl = NormalizeDouble(trail_sl, _Digits);
      const bool valid = is_long ? (trail_sl < bid) : (trail_sl > ask);
      const bool improves = (cur_sl <= 0.0) ||
                            (is_long ? (trail_sl > cur_sl + point * 0.5)
                                     : (trail_sl < cur_sl - point * 0.5));
      if(valid && improves)
         QM_TM_MoveSL(ticket, trail_sl, "chandelier_trail");
     }
  }

// Trade Close. Discretionary time stop: close after InpTimeExitBars closed bars.
bool Strategy_ExitSignal()
  {
   if(g_active_ticket == 0)
      return false;
   return (g_bars_in_trade >= InpTimeExitBars);
  }

// News Filter Hook (callable for the Q09 News Impact phase). Defer to the
// framework two-axis filter; no bespoke event handling for this EA.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10914_grimes-vol-comp\"}");
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

   Strategy_ManageOpenPosition();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
