#property strict
#property version   "5.0"
#property description "QM5_10778 TradingView ATR T3 Trend (tv-atr-t3)"
// Strategy Card: QM5_10778 (tv-atr-t3), G0 APPROVED 2026-05-22.
// Source: TradingView 'ATR and T3 strategy' by CryptoJoncis
//         (source_id d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7).
//
// Mechanik (mechanical, per card):
//   - Tillson T3 band: T3(High) = upper band, T3(Low) = lower band. T3 is the
//     classic 6-stage EMA cascade with volume factor; advanced ONE step per
//     closed bar (O(1)/bar, no per-tick or per-bar history rescan).
//   - Two ATR trend states (SuperTrend direction) — a fast and a slow ATR
//     component. Both must agree on direction.
//   - Long  : both ATR states up   AND last close > upper T3 band, no position.
//   - Short : both ATR states down AND last close < lower T3 band, no position.
//   - Exit long  when hl2 < lower T3 band; exit short when hl2 > upper T3 band.
//   - V5 safety stop = strategy_safety_atr_mult * ATR(period) from entry.
//
// PERF: all strategy state is cached in file-scope and advanced exactly once
// per closed bar from Strategy_EntrySignal (the framework guarantees that hook
// fires once per new bar). The per-tick path (ManageOpenPosition / ExitSignal)
// only reads cached doubles + current Bid/Ask. No CopyRates, no history loops.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10778;
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
input int    strategy_t3_length          = 8;     // Tillson T3 smoothing length (card test: 5/8/13)
input double strategy_t3_volume_factor   = 0.70;  // Tillson T3 volume factor 0..1 (card test: 0.5/0.7/0.9)
input int    strategy_atr_fast_period    = 14;    // fast ATR trend-state period (card test: 10/14)
input double strategy_atr_fast_mult      = 2.00;  // fast ATR SuperTrend multiplier
input int    strategy_atr_slow_period    = 28;    // slow ATR trend-state period (card test: 20/28)
input double strategy_atr_slow_mult      = 3.00;  // slow ATR SuperTrend multiplier
input int    strategy_safety_atr_period  = 14;    // safety-stop ATR period
input double strategy_safety_atr_mult    = 3.00;  // safety stop = mult * ATR (card test: 2/3/4)
input int    strategy_warmup_bars        = 150;   // closed bars before signals are live
input bool   strategy_allow_shorts       = true;  // permit short entries

// -----------------------------------------------------------------------------
// Cached closed-bar state (advanced once per new bar; read O(1) on every tick).
// -----------------------------------------------------------------------------

// Tillson T3 = 6-stage EMA cascade. One instance per band (highs / lows).
struct QM_T3State
  {
   double         e[6];
   bool           seeded;
  };

// SuperTrend ("ATR trend state") direction tracker, one per ATR component.
struct QM_AtrTrendState
  {
   double         upper;
   double         lower;
   double         prev_close;
   int            dir;        // +1 up / -1 down
   bool           seeded;
  };

QM_T3State        g_t3_high;
QM_T3State        g_t3_low;
QM_AtrTrendState  g_atr_fast;
QM_AtrTrendState  g_atr_slow;

double            g_t3_upper    = 0.0;   // T3(High) — upper band
double            g_t3_lower    = 0.0;   // T3(Low)  — lower band
double            g_close_last  = 0.0;   // close of last closed bar
double            g_hl2_last    = 0.0;   // (high+low)/2 of last closed bar
long              g_bars_seen   = 0;
bool              g_state_ready = false;

int Strategy_WarmupBars()
  {
   int bars = strategy_warmup_bars;
   bars = MathMax(bars, strategy_t3_length * 6);
   bars = MathMax(bars, strategy_atr_fast_period * 4);
   bars = MathMax(bars, strategy_atr_slow_period * 4);
   bars = MathMax(bars, 50);
   return bars;
  }

// Advance a Tillson T3 cascade by ONE closed bar and return the T3 value.
double Strategy_T3Advance(QM_T3State &st, const double x, const double k,
                          const double c1, const double c2,
                          const double c3, const double c4)
  {
   if(!st.seeded)
     {
      for(int i = 0; i < 6; ++i)
         st.e[i] = x;
      st.seeded = true;
     }
   else
     {
      st.e[0] += k * (x       - st.e[0]);
      st.e[1] += k * (st.e[0] - st.e[1]);
      st.e[2] += k * (st.e[1] - st.e[2]);
      st.e[3] += k * (st.e[2] - st.e[3]);
      st.e[4] += k * (st.e[3] - st.e[4]);
      st.e[5] += k * (st.e[4] - st.e[5]);
     }
   // T3 = c1*e6 + c2*e5 + c3*e4 + c4*e3  (e index 0..5 == e1..e6)
   return c1 * st.e[5] + c2 * st.e[4] + c3 * st.e[3] + c4 * st.e[2];
  }

// Advance a SuperTrend direction tracker by ONE closed bar; return +1 / -1.
int Strategy_AtrTrendAdvance(QM_AtrTrendState &st, const double hl2,
                             const double close_px, const double atr,
                             const double mult)
  {
   const double basic_upper = hl2 + mult * atr;
   const double basic_lower = hl2 - mult * atr;

   if(!st.seeded)
     {
      st.upper      = basic_upper;
      st.lower      = basic_lower;
      st.prev_close = close_px;
      st.dir        = 1;
      st.seeded     = true;
      return st.dir;
     }

   const double final_upper = (basic_upper < st.upper || st.prev_close > st.upper)
                              ? basic_upper : st.upper;
   const double final_lower = (basic_lower > st.lower || st.prev_close < st.lower)
                              ? basic_lower : st.lower;

   int dir = st.dir;
   if(st.dir > 0)
      dir = (close_px < final_lower) ? -1 : 1;   // was up (riding lower band)
   else
      dir = (close_px > final_upper) ?  1 : -1;  // was down (riding upper band)

   st.upper      = final_upper;
   st.lower      = final_lower;
   st.prev_close = close_px;
   st.dir        = dir;
   return dir;
  }

// Called ONCE per new closed bar (from Strategy_EntrySignal). Reads only the
// last closed bar (shift 1) and advances all cached state by a single step.
void Strategy_AdvanceState()
  {
   const double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read, bespoke T3 band
   const double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read, bespoke T3 band
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read, bespoke trend state
   if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;

   g_close_last = c1;
   g_hl2_last   = 0.5 * (h1 + l1);

   // Tillson T3 coefficients from the volume factor.
   const double k  = 2.0 / ((double)strategy_t3_length + 1.0);
   const double b  = MathMax(0.01, MathMin(strategy_t3_volume_factor, 1.50));
   const double b2 = b * b;
   const double b3 = b2 * b;
   const double c1c = -b3;
   const double c2c = 3.0 * b2 + 3.0 * b3;
   const double c3c = -6.0 * b2 - 3.0 * b - 3.0 * b3;
   const double c4c = 1.0 + 3.0 * b + b3 + 3.0 * b2;

   g_t3_upper = Strategy_T3Advance(g_t3_high, h1, k, c1c, c2c, c3c, c4c);
   g_t3_lower = Strategy_T3Advance(g_t3_low,  l1, k, c1c, c2c, c3c, c4c);

   const double atr_fast = QM_ATR(_Symbol, _Period, strategy_atr_fast_period, 1);
   const double atr_slow = QM_ATR(_Symbol, _Period, strategy_atr_slow_period, 1);
   if(atr_fast > 0.0)
      Strategy_AtrTrendAdvance(g_atr_fast, g_hl2_last, c1, atr_fast, strategy_atr_fast_mult);
   if(atr_slow > 0.0)
      Strategy_AtrTrendAdvance(g_atr_slow, g_hl2_last, c1, atr_slow, strategy_atr_slow_mult);

   g_bars_seen++;
   g_state_ready = (g_bars_seen >= Strategy_WarmupBars() &&
                    g_t3_high.seeded && g_t3_low.seeded &&
                    g_atr_fast.seeded && g_atr_slow.seeded &&
                    g_t3_upper > g_t3_lower);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter — time/spread/news gating beyond the framework. None required;
// the framework news + Friday-close guards already run before this hook.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true, so this is where we
// advance the cached closed-bar state exactly once per bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_AdvanceState();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;   // one position per symbol/magic

   const bool both_up   = (g_atr_fast.dir > 0 && g_atr_slow.dir > 0);
   const bool both_down = (g_atr_fast.dir < 0 && g_atr_slow.dir < 0);

   // Long: both ATR trend states up AND last close above the upper T3 band.
   if(both_up && g_close_last > g_t3_upper)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;   // market
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_safety_atr_period, strategy_safety_atr_mult);
      req.tp = 0.0;      // band/safety exit only — no fixed target
      req.reason = "tv_atr_t3_long";
      return (req.sl > 0.0);
     }

   // Short: both ATR trend states down AND last close below the lower T3 band.
   if(strategy_allow_shorts && both_down && g_close_last < g_t3_lower)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;   // market
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_safety_atr_period, strategy_safety_atr_mult);
      req.tp = 0.0;
      req.reason = "tv_atr_t3_short";
      return (req.sl > 0.0);
     }

   return false;
  }

// Trade Management. The card requires no break-even/partial/trailing logic;
// exits are the T3 band (Trade Close) and the ATR safety stop.
void Strategy_ManageOpenPosition()
  {
   // Intentionally empty — see SPEC.md §1 (band + safety-stop exits only).
  }

// Trade Close — discretionary band exit (separate from the SL price).
//   Exit long  when hl2 falls below the lower T3 band.
//   Exit short when hl2 rises above the upper T3 band.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY  && g_hl2_last < g_t3_lower)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_hl2_last > g_t3_upper)
      return true;

   return false;
  }

// News Filter Hook — P8 News Impact callable. Defer to the central framework
// news filter (no bespoke high-impact handling for this EA).
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10778_tv-atr-t3\"}");
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
