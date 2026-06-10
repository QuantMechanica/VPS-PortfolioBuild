#property strict
#property version   "5.0"
#property description "QM5_1614 DSP Filter-Bank Turning Points (Alpha Architect / Henry Stern)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1614 aa-dsp-fbank-turn
// Source: Henry Stern, "Trend-Following Filters - Part 3", Alpha Architect 2021.
// Trades local troughs/crests in a 6-band IIR synthesis filter-bank applied to
// daily close prices. Long on completed local trough below zero; short on
// completed local crest above zero. 2xATR(20) initial SL, 40-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1614;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled              = true;
input int    qm_friday_close_hour_broker          = 21;

input group "Stress"
input double qm_stress_reject_probability         = 0.0;

input group "Strategy"
input int    strategy_atr_period                  = 20;    // ATR period for initial SL
input double strategy_atr_sl_mult                 = 2.0;   // SL = mult * ATR(20)
input int    strategy_max_hold_bars               = 40;    // max D1 bars per position
input int    strategy_warmup_bars                 = 300;   // min bars before first signal
input double strategy_spread_mult                 = 2.5;   // skip entry if spread > mult*median
input int    strategy_spread_lookback             = 20;    // bars for median spread

// ---------------------------------------------------------------------------
// Filter-bank constants (card §Entry: six fixed IIR bandpass center periods)
// ---------------------------------------------------------------------------
#define NBAND 6

static double g_band_t[NBAND];     // center periods
static double g_band_r[NBAND];     // pole radii
static double g_band_a1[NBAND];    // IIR coefficient a1
static double g_band_a2[NBAND];    // IIR coefficient a2
static double g_band_b0[NBAND];    // IIR coefficient b0

const double SYNTH_GAIN = 0.886;

// ---------------------------------------------------------------------------
// Per-bar filter state
// ---------------------------------------------------------------------------
static double g_filt_y1[NBAND];   // y[n-1] per band
static double g_filt_y2[NBAND];   // y[n-2] per band
static double g_filt_x1;          // x[n-1] (close price)
static double g_filt_x2;          // x[n-2] (close price)
static double g_Y;                 // synthesized output at t   (last closed bar)
static double g_Y1;                // synthesized output at t-1
static double g_Y2;                // synthesized output at t-2
static int    g_warmup_done;       // bars fed into filter so far
static bool   g_filter_ready;      // true after warmup complete
static bool   g_spread_ok;         // cached spread gate result
static int    g_bar_count;         // total new-bar events since init
static int    g_pos_entry_bar;     // g_bar_count at position open (for time stop)

// ---------------------------------------------------------------------------
// Coefficient initialisation (run once)
// ---------------------------------------------------------------------------
void InitBandCoefficients()
  {
   const double periods[NBAND] = {15.0, 88.0, 513.0, 2990.0, 17427.0, 101572.0};
   for(int i = 0; i < NBAND; i++)
     {
      g_band_t[i]  = periods[i];
      double omega = 2.0 * M_PI / periods[i];
      // pole radius: exp(-2π/T) — gives bandwidth proportional to center frequency
      double r     = MathExp(-2.0 * M_PI / periods[i]);
      g_band_r[i]  = r;
      g_band_a1[i] = 2.0 * r * MathCos(omega);
      g_band_a2[i] = -(r * r);
      // unit-gain normalisation at centre frequency
      g_band_b0[i] = (1.0 - r * r) * 0.5;
     }
  }

// ---------------------------------------------------------------------------
// Advance the IIR filter by one sample (called once per closed D1 bar)
// ---------------------------------------------------------------------------
void AdvanceFilter(double x)
  {
   double Y = 0.0;
   for(int i = 0; i < NBAND; i++)
     {
      double y = g_band_a1[i] * g_filt_y1[i]
               + g_band_a2[i] * g_filt_y2[i]
               + g_band_b0[i] * (x - g_filt_x2);
      g_filt_y2[i] = g_filt_y1[i];
      g_filt_y1[i] = y;
      Y += SYNTH_GAIN * y;
     }
   g_filt_x2 = g_filt_x1;
   g_filt_x1 = x;
   g_Y2 = g_Y1;
   g_Y1 = g_Y;
   g_Y  = Y;
   g_warmup_done++;
   g_bar_count++;
  }

// ---------------------------------------------------------------------------
// One-time full initialisation from historical closes
// ---------------------------------------------------------------------------
void InitializeFilter()
  {
   ArrayInitialize(g_filt_y1, 0.0);
   ArrayInitialize(g_filt_y2, 0.0);
   g_filt_x1     = 0.0;
   g_filt_x2     = 0.0;
   g_Y           = 0.0;
   g_Y1          = 0.0;
   g_Y2          = 0.0;
   g_warmup_done = 0;
   g_bar_count   = 0;
   g_filter_ready = false;

   // perf-allowed: one-time warmup CopyClose to seed IIR filter state
   double closes[];
   ArraySetAsSeries(closes, false);   // closes[0]=most recent closed, closes[n-1]=oldest
   int n   = strategy_warmup_bars + 10;
   int got = CopyClose(_Symbol, PERIOD_D1, 1, n, closes);
   if(got < strategy_warmup_bars)
      return; // insufficient history — will retry on next bar

   // Process from oldest to newest so filter converges in chronological order
   for(int i = got - 1; i >= 0; i--)
      AdvanceFilter(closes[i]);

   if(g_warmup_done >= strategy_warmup_bars)
      g_filter_ready = true;
  }

// ---------------------------------------------------------------------------
// Spread gate — returns true if spread is acceptable for entry
// ---------------------------------------------------------------------------
bool CheckSpread()
  {
   // perf-allowed: called once per D1 bar from AdvanceState_OnNewBar
   double hist_spreads[];
   ArraySetAsSeries(hist_spreads, false);
   int got = CopySpread(_Symbol, PERIOD_D1, 1, strategy_spread_lookback, hist_spreads);
   if(got < strategy_spread_lookback / 2)
      return true; // not enough data, allow

   double sorted[];
   ArrayCopy(sorted, hist_spreads, 0, 0, got);
   ArraySort(sorted);
   double median = sorted[got / 2];
   if(median <= 0.0)
      return true;

   double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (current_spread <= strategy_spread_mult * median);
  }

// ---------------------------------------------------------------------------
// Per-bar state advance — called at the top of OnTick when QM_IsNewBar()
// ---------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   if(!g_filter_ready && g_warmup_done == 0)
     {
      // First call: full initialization from historical closes
      InitializeFilter();
     }
   else if(g_filter_ready)
     {
      // Normal operation: advance by one closed bar
      // perf-allowed: single-bar iClose access for IIR filter update
      double c = iClose(_Symbol, PERIOD_D1, 1);
      if(c > 0.0)
         AdvanceFilter(c);
     }
   else
     {
      // Still accumulating warmup bars (history was short at init time)
      double c = iClose(_Symbol, PERIOD_D1, 1);
      if(c > 0.0)
        {
         AdvanceFilter(c);
         if(g_warmup_done >= strategy_warmup_bars)
            g_filter_ready = true;
        }
     }

   g_spread_ok = CheckSpread();
  }

// ---------------------------------------------------------------------------
// Helper: check for an open position on this EA's magic
// ---------------------------------------------------------------------------
bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Block if: warmup not done, spread wide, or already have a position
   if(!g_filter_ready) return true;
   if(!g_spread_ok)    return true;
   if(HasOpenPosition()) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_filter_ready) return false;

   // Long: completed local trough below zero
   // Y(t-2) > Y(t-1) AND Y(t) > Y(t-1) AND Y(t-1) < 0
   bool long_signal  = (g_Y2 > g_Y1) && (g_Y > g_Y1) && (g_Y1 < 0.0);

   // Short: completed local crest above zero
   // Y(t-2) < Y(t-1) AND Y(t) < Y(t-1) AND Y(t-1) > 0
   bool short_signal = (g_Y2 < g_Y1) && (g_Y < g_Y1) && (g_Y1 > 0.0);

   if(!long_signal && !short_signal) return false;

   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double entry_price;
   if(long_signal)
     {
      req.type     = QM_BUY;
      entry_price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.price    = 0.0; // market order
      req.sl       = QM_StopATR(_Symbol, QM_BUY, entry_price,
                                strategy_atr_period, strategy_atr_sl_mult);
      req.tp       = 0.0; // no fixed TP; exits via signal or time stop
      req.reason   = "DSP_TROUGH_LONG";
     }
   else
     {
      req.type     = QM_SELL;
      entry_price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.price    = 0.0; // market order
      req.sl       = QM_StopATR(_Symbol, QM_SELL, entry_price,
                                strategy_atr_period, strategy_atr_sl_mult);
      req.tp       = 0.0;
      req.reason   = "DSP_CREST_SHORT";
     }

   if(req.sl <= 0.0) return false;

   g_pos_entry_bar = g_bar_count;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or BE logic; position managed purely by SL and ExitSignal
  }

bool Strategy_ExitSignal()
  {
   if(!g_filter_ready) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: 40 completed D1 bars
      if(g_bar_count - g_pos_entry_bar >= strategy_max_hold_bars)
         return true;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Close long on local crest above zero
         if(g_Y2 < g_Y1 && g_Y < g_Y1 && g_Y1 > 0.0)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Close short on local trough below zero
         if(g_Y2 > g_Y1 && g_Y > g_Y1 && g_Y1 < 0.0)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

int OnInit()
  {
   InitBandCoefficients();

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

   // Reset filter state (in case of re-attach)
   ArrayInitialize(g_filt_y1, 0.0);
   ArrayInitialize(g_filt_y2, 0.0);
   g_filt_x1     = 0.0;
   g_filt_x2     = 0.0;
   g_Y           = 0.0;
   g_Y1          = 0.0;
   g_Y2          = 0.0;
   g_warmup_done = 0;
   g_bar_count   = 0;
   g_filter_ready = false;
   g_spread_ok    = true;
   g_pos_entry_bar = 0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1614_aa-dsp-fbank-turn\",\"bands\":6,\"synth_gain\":0.886}");
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

   // Advance closed-bar state FIRST so all hooks see updated filter output
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         // Determine reason for logging
         bool timed_out = (g_bar_count - g_pos_entry_bar >= strategy_max_hold_bars);
         QM_TM_ClosePosition(ticket, timed_out ? QM_EXIT_TIME_STOP : QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!is_new_bar) return;

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
