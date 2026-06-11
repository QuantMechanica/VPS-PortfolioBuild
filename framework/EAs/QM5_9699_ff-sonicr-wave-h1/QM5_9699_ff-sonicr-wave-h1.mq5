#property strict
#property version   "5.0"
#property description "QM5_9699 — ForexFactory Sonic R Wave Breakout H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9699 ff-sonicr-wave-h1
// Source: sonicdeejay/traderathome, Sonic R. System, ForexFactory thread 114792
// H1 PA-wave (A-B-C swing structure) breakout during London session.
// Dragon = EMA(34), Trend = EMA(89). SL below swing C. TP = min(2R, next level).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9699;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker            = 21;

input group "Stress"
input double qm_stress_reject_probability           = 0.0;

input group "Strategy"
input int    strategy_ema_dragon                    = 34;    // Dragon EMA period
input int    strategy_ema_trend                     = 89;    // Trend EMA period
input int    strategy_atr_period                    = 14;    // ATR period (H1)
input int    strategy_wave_lookback                 = 24;    // Bars for A-B-C scan
input int    strategy_dragon_slope_bars             = 5;     // Dragon slope comparison shift
input double strategy_wave_min_atr_mult             = 1.0;   // Min B-A range (ATR multiples)
input double strategy_level_atr_mult               = 0.25;  // Level proximity & SL buffer (ATR)
input double strategy_tp_r_mult                    = 2.0;   // TP at N*R or next level (closer)
input int    strategy_time_stop_hours              = 10;    // Time stop in hours (~10 H1 bars)
input int    strategy_london_start_hour            = 8;     // London session start (broker hr)
input int    strategy_london_end_hour              = 17;    // London session end (broker hr)

// ---------------------------------------------------------------------------
// Per-bar cached state — updated once per closed bar in Strategy_EntrySignal
// ---------------------------------------------------------------------------
static bool   g_bull_valid    = false;
static bool   g_bear_valid    = false;
static double g_bull_above    = 0.0;  // Long entry: close must be above this
static double g_bear_below    = 0.0;  // Short entry: close must be below this
static double g_bull_sl       = 0.0;  // SL for long (below C - buffer)
static double g_bear_sl       = 0.0;  // SL for short (above C + buffer)
static double g_bull_tp_level = 0.0;  // Next round level above bull entry for TP
static double g_bear_tp_level = 0.0;  // Next round level below bear entry for TP
static double g_dragon        = 0.0;  // EMA(34) at bar 1
static double g_atr           = 0.0;  // ATR(14) at bar 1
static double g_close1        = 0.0;  // Close of bar 1 (most recently closed)
static bool   g_exit_long     = false; // Close[1] crossed below Dragon
static bool   g_exit_short    = false; // Close[1] crossed above Dragon

// ---------------------------------------------------------------------------
// Level helpers: round / half-round number detection
// Non-JPY pairs (point ~0.00001): level step = 0.0050 (50 pips figure half)
// JPY pairs   (point ~0.001):     level step = 0.50  (50 points figure half)
// ---------------------------------------------------------------------------
double LevelStep()
  {
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (pt < 0.001) ? 0.0050 : 0.50;
  }

double LevelAbove(double price, double step)
  { return (MathFloor(price / step) + 1.0) * step; }

double LevelBelow(double price, double step)
  { return MathFloor(price / step) * step; }

// ---------------------------------------------------------------------------
// Bullish A-B-C wave detection
// rates[]: CopyRates output — rates[0]=bar1(newest), rates[1]=bar2 ...
// Returns true and sets out_entry_above, out_sl, out_tp_level
// ---------------------------------------------------------------------------
bool FindBullishWave(const MqlRates &rates[], int n,
                     double &out_entry_above,
                     double &out_sl,
                     double &out_tp_level)
  {
   if(n < 6 || g_atr <= 0.0) return false;
   double step = LevelStep();
   double atr  = g_atr;
   int    lkb  = strategy_wave_lookback;

   // rates[0] = breakout-bar candidate (bar 1, just closed)
   // Scan rates[1..n-2] for C, B, A (C most recent, A oldest)
   for(int ic = 1; ic < n - 3 && ic <= lkb; ic++)
     {
      // Swing low at ic: lower than both neighbors
      if(rates[ic].low >= rates[ic - 1].low || rates[ic].low >= rates[ic + 1].low)
         continue;
      double C = rates[ic].low;

      for(int ib = ic + 1; ib < n - 2; ib++)
        {
         // Swing high at ib
         if(rates[ib].high <= rates[ib - 1].high || rates[ib].high <= rates[ib + 1].high)
            continue;
         double B = rates[ib].high;

         for(int ia = ib + 1; ia < n - 1; ia++)
           {
            // Swing low at ia (oldest A)
            if(rates[ia].low >= rates[ia - 1].low || rates[ia].low >= rates[ia + 1].low)
               continue;
            double A = rates[ia].low;

            if(C <= A) continue;                              // C must be higher than A
            if(B - A < strategy_wave_min_atr_mult * atr) continue; // B-A >= 1*ATR

            // Level that capped B: nearest whole/half level above B within 0.25*ATR
            double lvl = LevelAbove(B, step);
            if(lvl - B > strategy_level_atr_mult * atr) continue;

            out_entry_above = MathMax(B, lvl);                // close must exceed both
            out_sl          = C - strategy_level_atr_mult * atr;
            out_tp_level    = LevelAbove(out_entry_above, step);
            return true;
           }
        }
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Bearish A-B-C wave detection (mirror of bullish)
// ---------------------------------------------------------------------------
bool FindBearishWave(const MqlRates &rates[], int n,
                     double &out_entry_below,
                     double &out_sl,
                     double &out_tp_level)
  {
   if(n < 6 || g_atr <= 0.0) return false;
   double step = LevelStep();
   double atr  = g_atr;
   int    lkb  = strategy_wave_lookback;

   for(int ic = 1; ic < n - 3 && ic <= lkb; ic++)
     {
      // Swing high at ic (most recent bearish C)
      if(rates[ic].high <= rates[ic - 1].high || rates[ic].high <= rates[ic + 1].high)
         continue;
      double C = rates[ic].high;

      for(int ib = ic + 1; ib < n - 2; ib++)
        {
         // Swing low at ib (bearish B)
         if(rates[ib].low >= rates[ib - 1].low || rates[ib].low >= rates[ib + 1].low)
            continue;
         double B = rates[ib].low;

         for(int ia = ib + 1; ia < n - 1; ia++)
           {
            // Swing high at ia (oldest bearish A)
            if(rates[ia].high <= rates[ia - 1].high || rates[ia].high <= rates[ia + 1].high)
               continue;
            double A = rates[ia].high;

            if(C >= A) continue;                              // C must be lower than A
            if(A - B < strategy_wave_min_atr_mult * atr) continue; // A-B >= 1*ATR

            // Level that supported B: nearest whole/half level below B within 0.25*ATR
            double lvl = LevelBelow(B, step);
            if(B - lvl > strategy_level_atr_mult * atr) continue;

            out_entry_below = MathMin(B, lvl);
            out_sl          = C + strategy_level_atr_mult * atr;
            out_tp_level    = LevelBelow(out_entry_below, step);
            return true;
           }
        }
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Per-closed-bar state update — called at start of Strategy_EntrySignal
// (which is gated by QM_IsNewBar() in the framework OnTick)
// ---------------------------------------------------------------------------
void UpdateBarState()
  {
   g_bull_valid  = false;
   g_bear_valid  = false;
   g_exit_long   = false;
   g_exit_short  = false;

   g_dragon = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_dragon, 1);
   double dragon_old = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_dragon, strategy_dragon_slope_bars);
   double trend_cur  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend, 1);
   double trend_old  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend, strategy_dragon_slope_bars);
   g_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);

   if(g_dragon <= 0.0 || g_atr <= 0.0) return;

   MqlRates rates[];
   int n = CopyRates(_Symbol, PERIOD_H1, 1, strategy_wave_lookback + 4, rates); // perf-allowed — structural swing scan, gated per-bar via QM_IsNewBar in framework OnTick
   if(n < 6) return;

   g_close1     = rates[0].close;
   g_exit_long  = (g_close1 < g_dragon);   // long exit: bar 1 closed below Dragon
   g_exit_short = (g_close1 > g_dragon);   // short exit: bar 1 closed above Dragon

   bool dragon_up = (g_dragon > dragon_old);
   bool trend_up  = (trend_cur > trend_old);

   // Bullish wave: both EMAs sloping upward
   if(dragon_up && trend_up)
     {
      double b = 0.0, sl = 0.0, tp = 0.0;
      if(FindBullishWave(rates, n, b, sl, tp))
        {
         g_bull_valid    = true;
         g_bull_above    = b;
         g_bull_sl       = sl;
         g_bull_tp_level = tp;
        }
     }

   // Bearish wave: both EMAs sloping downward
   if(!dragon_up && !trend_up)
     {
      double b = 0.0, sl = 0.0, tp = 0.0;
      if(FindBearishWave(rates, n, b, sl, tp))
        {
         g_bear_valid    = true;
         g_bear_below    = b;
         g_bear_sl       = sl;
         g_bear_tp_level = tp;
        }
     }
  }

// ---------------------------------------------------------------------------
// London session check (broker time)
// ---------------------------------------------------------------------------
bool InLondonSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_london_start_hour && dt.hour < strategy_london_end_hour);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   // Entry-only filters are checked inside Strategy_EntrySignal to avoid
   // blocking position management and exit on positions opened in-session.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Update per-bar state (called only when QM_IsNewBar() is true)
   UpdateBarState();

   // London session filter: entries only
   if(!InLondonSession()) return false;

   // One active position per magic-symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double step = LevelStep();
   if(pt <= 0.0) return false;

   // --- Long entry: close[1] above entry level AND above Dragon ---
   if(g_bull_valid && g_close1 > g_bull_above && g_close1 > g_dragon)
     {
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_pts = (ask - g_bull_sl) / pt;
      if(sl_pts <= 0.0) return false;

      double r_dist  = strategy_tp_r_mult * (ask - g_bull_sl);
      double tp_r    = ask + r_dist;
      double tp_lvl  = (g_bull_tp_level > ask) ? g_bull_tp_level : LevelAbove(ask, step);
      double tp      = MathMin(tp_r, tp_lvl);
      if(tp <= ask) return false;

      req.type           = QM_BUY;
      req.price          = ask;
      req.sl             = g_bull_sl;
      req.tp             = tp;
      req.lots           = QM_LotsForRisk(_Symbol, sl_pts);
      req.reason         = "SONICR_BULL_WAVE";
      req.symbol_slot    = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // --- Short entry: close[1] below entry level AND below Dragon ---
   if(g_bear_valid && g_close1 < g_bear_below && g_close1 < g_dragon)
     {
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl_pts = (g_bear_sl - bid) / pt;
      if(sl_pts <= 0.0) return false;

      double r_dist  = strategy_tp_r_mult * (g_bear_sl - bid);
      double tp_r    = bid - r_dist;
      double tp_lvl  = (g_bear_tp_level < bid) ? g_bear_tp_level : LevelBelow(bid, step);
      double tp      = MathMax(tp_r, tp_lvl);
      if(tp >= bid) return false;

      req.type           = QM_SELL;
      req.price          = bid;
      req.sl             = g_bear_sl;
      req.tp             = tp;
      req.lots           = QM_LotsForRisk(_Symbol, sl_pts);
      req.reason         = "SONICR_BEAR_WAVE";
      req.symbol_slot    = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // SL is fixed at swing C - buffer (no trail). Time stop handled in ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop: ~10 H1 bars = 10 hours wall clock
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(TimeCurrent() - open_time) >= (long)(strategy_time_stop_hours * 3600))
         return true;

      // Dragon cross exit (uses per-bar cached state from UpdateBarState)
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_exit_long)  return true;
      if(ptype == POSITION_TYPE_SELL && g_exit_short) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework QM_NewsAllowsTrade2 (qm_news_temporal axis)
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
