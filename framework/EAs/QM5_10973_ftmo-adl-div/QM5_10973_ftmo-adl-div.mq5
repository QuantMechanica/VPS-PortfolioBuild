#property strict
#property version   "5.0"
#property description "QM5_10973 FTMO ADL Divergence Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_10973 ftmo-adl-div
// Source: FTMO blog "Technical analysis - what does Accumulation/Distribution
// tell you?" — H4 Accumulation/Distribution Line swing divergence reversal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10973;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period              = 14;
input int    strategy_ema_trend_period        = 100;  // EMA(100) below/above filter
input int    strategy_ema_tp_cap_period       = 50;   // EMA(50) secondary TP cap
input int    strategy_pivot_lookback_bars     = 60;   // confirmed-fractal scan window
input int    strategy_swing_sep_min_bars      = 5;    // card: "5-30 H4 bars" separation
input int    strategy_swing_sep_max_bars      = 30;
input int    strategy_adl_window_bars         = 70;   // ADL windowed-cumulative anchor
input int    strategy_extreme_lookback_bars   = 60;   // "60-bar low/high" proximity check
input double strategy_extreme_atr_mult        = 0.75; // card: "within 0.75*ATR of a 60-bar low/high"
input double strategy_sl_atr_buffer_mult      = 0.25; // card: stop buffer beyond swing extreme
input double strategy_tp_r_mult               = 2.0;  // card: "2.0R"
input int    strategy_time_exit_bars          = 20;   // card: "after 20 H4 bars"
input int    strategy_atr_percentile_sample   = 100;  // card: "100-bar 25th percentile"

// -----------------------------------------------------------------------------
// Bespoke structural helpers — no QM_* Accumulation/Distribution or
// multi-pivot helper exists. Both are bounded (<= ~100 iterations), called at
// most a few times per CLOSED H4 bar from Strategy_EntrySignal (itself only
// invoked after QM_IsNewBar()==true by the framework OnTick wiring) — never
// per-tick. perf-allowed throughout: bespoke structural logic.
// -----------------------------------------------------------------------------

// Windowed (relative, not all-time) Accumulation/Distribution cumulative sum
// anchored at `window` bars back. Two calls sharing the same `window` are
// directly comparable for divergence purposes: both differ from the true
// all-time ADL by the same constant offset (sum of MFV older than `window`).
double QM_ADL_Windowed(const string sym, const ENUM_TIMEFRAMES tf, const int shift, const int window)
  {
   double sum = 0.0;
   for(int s = window; s >= shift; s--)
     {
      const double h = iHigh(sym, tf, s);  // perf-allowed
      const double l = iLow(sym, tf, s);   // perf-allowed
      const double c = iClose(sym, tf, s); // perf-allowed
      const long   v = iTickVolume(sym, tf, s);
      const double range = h - l;
      const double mfm = (range > 0.0) ? (((c - l) - (h - c)) / range) : 0.0;
      sum += mfm * (double)v;
     }
   return sum;
  }

// Last two confirmed fractal shifts + values (shift1 = most recent, shift2 = prior).
bool FindLastTwoFractalShifts(const string sym, const ENUM_TIMEFRAMES tf, const bool upper,
                              const int max_lookback, int &shift1, double &val1,
                              int &shift2, double &val2)
  {
   shift1 = -1;
   shift2 = -1;
   val1 = 0.0;
   val2 = 0.0;
   int found = 0;
   for(int s = 2; s <= max_lookback; s++)
     {
      const double v = upper ? QM_FractalUpper(sym, tf, s) : QM_FractalLower(sym, tf, s);
      if(v != EMPTY_VALUE && v != 0.0)
        {
         if(found == 0)
           {
            shift1 = s;
            val1 = v;
            found = 1;
           }
         else
           {
            shift2 = s;
            val2 = v;
            return true;
           }
        }
     }
   return false;
  }

// 25th percentile of the last `sample_bars` ATR(period) readings (card: "skip
// if H4 ATR(14) is below its 100-bar 25th percentile"). QM_ATR is handle-
// pooled O(1) per shift; the loop + sort runs once per closed bar.
double ATR25thPercentile(const string sym, const ENUM_TIMEFRAMES tf, const int atr_period, const int sample_bars)
  {
   double vals[];
   ArrayResize(vals, sample_bars);
   for(int i = 0; i < sample_bars; i++)
      vals[i] = QM_ATR(sym, tf, atr_period, 1 + i);
   ArraySort(vals);
   const int idx = (int)MathFloor(0.25 * (sample_bars - 1));
   return vals[idx];
  }

// -----------------------------------------------------------------------------
// Per-position risk bookkeeping (breakeven-at-1R trigger). Plain in-memory
// arrays keyed by ticket — bookkeeping only, not an adaptive/learned
// parameter (HR14 concerns weights that mutate from running PnL; this is a
// fixed R computed once from the entry/SL prices already on the ticket).
// -----------------------------------------------------------------------------
ulong  g_risk_tickets[];
double g_risk_values[];
bool   g_risk_be_done[];

int RiskTrackIndex(const ulong ticket)
  {
   for(int i = 0; i < ArraySize(g_risk_tickets); i++)
      if(g_risk_tickets[i] == ticket)
         return i;
   return -1;
  }

double RiskTrackGetOrInit(const ulong ticket, const double entry_price, const double sl_price)
  {
   const int idx = RiskTrackIndex(ticket);
   if(idx >= 0)
      return g_risk_values[idx];
   const int n = ArraySize(g_risk_tickets);
   ArrayResize(g_risk_tickets, n + 1);
   ArrayResize(g_risk_values, n + 1);
   ArrayResize(g_risk_be_done, n + 1);
   g_risk_tickets[n] = ticket;
   g_risk_values[n]  = MathAbs(entry_price - sl_price);
   g_risk_be_done[n] = false;
   return g_risk_values[n];
  }

bool RiskTrackBeDone(const ulong ticket)
  {
   const int idx = RiskTrackIndex(ticket);
   return (idx >= 0) ? g_risk_be_done[idx] : false;
  }

void RiskTrackMarkBeDone(const ulong ticket)
  {
   const int idx = RiskTrackIndex(ticket);
   if(idx >= 0)
      g_risk_be_done[idx] = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double atr_p25 = ATR25thPercentile(_Symbol, PERIOD_CURRENT, strategy_atr_period, strategy_atr_percentile_sample);
   if(atr < atr_p25)
      return false; // card: skip low-volatility regime

   const double ema_trend = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_trend_period, 1);
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed

   bool long_setup = false, short_setup = false;
   double sl_price = 0.0, tp_price_2r = 0.0;

   // --- Long: bullish ADL divergence at swing lows ---
   int sl1, sl2;
   double pl1, pl2;
   if(FindLastTwoFractalShifts(_Symbol, PERIOD_CURRENT, false, strategy_pivot_lookback_bars, sl1, pl1, sl2, pl2))
     {
      const int sep = sl2 - sl1;
      if(sep >= strategy_swing_sep_min_bars && sep <= strategy_swing_sep_max_bars && pl1 < pl2)
        {
         const double adl1 = QM_ADL_Windowed(_Symbol, PERIOD_CURRENT, sl1, strategy_adl_window_bars);
         const double adl2 = QM_ADL_Windowed(_Symbol, PERIOD_CURRENT, sl2, strategy_adl_window_bars);
         if(adl1 > adl2)
           {
            const int idx_low60 = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, strategy_extreme_lookback_bars, 1);
            const double low60 = (idx_low60 >= 0) ? iLow(_Symbol, PERIOD_CURRENT, idx_low60) : 0.0; // perf-allowed
            const bool below_ema = close1 < ema_trend;
            const bool near_low  = (low60 > 0.0) && (MathAbs(close1 - low60) <= strategy_extreme_atr_mult * atr);
            if(below_ema || near_low)
              {
               const double trigger_high = iHigh(_Symbol, PERIOD_CURRENT, sl1); // perf-allowed
               if(close1 > trigger_high)
                 {
                  long_setup  = true;
                  sl_price    = MathMin(pl1, pl2) - strategy_sl_atr_buffer_mult * atr;
                 }
              }
           }
        }
     }

   // --- Short: bearish ADL divergence at swing highs ---
   if(!long_setup)
     {
      int sh1, sh2;
      double ph1, ph2;
      if(FindLastTwoFractalShifts(_Symbol, PERIOD_CURRENT, true, strategy_pivot_lookback_bars, sh1, ph1, sh2, ph2))
        {
         const int sep = sh2 - sh1;
         if(sep >= strategy_swing_sep_min_bars && sep <= strategy_swing_sep_max_bars && ph1 > ph2)
           {
            const double adl1 = QM_ADL_Windowed(_Symbol, PERIOD_CURRENT, sh1, strategy_adl_window_bars);
            const double adl2 = QM_ADL_Windowed(_Symbol, PERIOD_CURRENT, sh2, strategy_adl_window_bars);
            if(adl1 < adl2)
              {
               const int idx_high60 = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, strategy_extreme_lookback_bars, 1);
               const double high60 = (idx_high60 >= 0) ? iHigh(_Symbol, PERIOD_CURRENT, idx_high60) : 0.0; // perf-allowed
               const bool above_ema = close1 > ema_trend;
               const bool near_high = (high60 > 0.0) && (MathAbs(close1 - high60) <= strategy_extreme_atr_mult * atr);
               if(above_ema || near_high)
                 {
                  const double trigger_low = iLow(_Symbol, PERIOD_CURRENT, sh1); // perf-allowed
                  if(close1 < trigger_low)
                    {
                     short_setup = true;
                     sl_price    = MathMax(ph1, ph2) + strategy_sl_atr_buffer_mult * atr;
                    }
                 }
              }
           }
        }
     }

   if(!long_setup && !short_setup)
      return false;

   const double entry_price = long_setup ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - sl_price);
   if(stop_distance <= 0.0)
      return false;

   tp_price_2r = long_setup ? entry_price + strategy_tp_r_mult * stop_distance
                             : entry_price - strategy_tp_r_mult * stop_distance;

   req.type               = long_setup ? QM_BUY : QM_SELL;
   req.price               = 0.0;
   req.sl                  = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp                  = QM_StopRulesNormalizePrice(_Symbol, tp_price_2r);
   req.reason               = long_setup ? "adl_bullish_divergence" : "adl_bearish_divergence";
   req.symbol_slot          = 0;
   req.expiration_seconds   = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double ema_cap = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_tp_cap_period, 1);
   const int period_sec = PeriodSeconds(PERIOD_CURRENT);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long   pos_type = PositionGetInteger(POSITION_TYPE);
      const double entry    = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_now   = PositionGetDouble(POSITION_SL);
      const double risk     = RiskTrackGetOrInit(ticket, entry, sl_now);
      if(risk <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(!RiskTrackBeDone(ticket))
        {
         const double favorable = (pos_type == POSITION_TYPE_BUY) ? (bid - entry) : (entry - ask);
         if(favorable >= risk)
           {
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry), "breakeven_1R");
            RiskTrackMarkBeDone(ticket);
           }
        }

      const double tp2r = (pos_type == POSITION_TYPE_BUY) ? (entry + strategy_tp_r_mult * risk)
                                                            : (entry - strategy_tp_r_mult * risk);
      bool ema_cap_hit = false;
      if(pos_type == POSITION_TYPE_BUY && bid >= ema_cap && ema_cap < tp2r)
         ema_cap_hit = true;
      else if(pos_type == POSITION_TYPE_SELL && ask <= ema_cap && ema_cap > tp2r)
         ema_cap_hit = true;

      bool time_exit = false;
      if(period_sec > 0)
        {
         const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
         const int      bars_elapsed = (int)((TimeCurrent() - open_time) / period_sec);
         if(bars_elapsed >= strategy_time_exit_bars)
            time_exit = true;
        }

      if(ema_cap_hit)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      else if(time_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false; // handled per-ticket in Strategy_ManageOpenPosition
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...) — card's "skip high-impact
                 // news windows" is the framework's own news gate, no override needed
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
