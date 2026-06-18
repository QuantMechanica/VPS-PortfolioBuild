#property strict
#property version   "5.0"
#property description "QM5_1614 Alpha Architect DSP filter-bank turns"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1614 aa-dsp-fbank-turn
// Card: Alpha Architect DSP Filter-Bank Turning Points, G0 APPROVED.
// Source: Henry Stern, "Trend-Following Filters - Part 3", 2021-04-08.
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled              = true;
input int    qm_friday_close_hour_broker          = 21;

input group "Stress"
input double qm_stress_reject_probability         = 0.0;

input group "Strategy"
input int    strategy_atr_period                  = 20;
input double strategy_atr_sl_mult                 = 2.0;
input int    strategy_max_hold_bars               = 40;
input int    strategy_warmup_bars                 = 300;
input int    strategy_spread_lookback             = 20;
input double strategy_spread_mult                 = 2.5;

#define QM_DSP_BANDS 6

const double QM_DSP_PI         = 3.14159265358979323846;
const double QM_DSP_Q          = 0.5;
const double QM_DSP_SYNTH_GAIN = 0.886;

double g_dsp_a[QM_DSP_BANDS];
double g_dsp_b[QM_DSP_BANDS];
double g_dsp_c[QM_DSP_BANDS];
double g_dsp_band_y1[QM_DSP_BANDS];
double g_dsp_band_y2[QM_DSP_BANDS];
double g_dsp_x1 = 0.0;
double g_dsp_x2 = 0.0;
double g_dsp_y  = 0.0;
double g_dsp_y1 = 0.0;
double g_dsp_y2 = 0.0;
int    g_dsp_samples = 0;
int    g_dsp_bar_count = 0;
int    g_dsp_entry_bar = 0;
bool   g_dsp_ready = false;
bool   g_dsp_spread_ok = true;

void DSP_InitCoefficients()
  {
   const double periods[QM_DSP_BANDS] = {15.0, 88.0, 513.0, 2990.0, 17427.0, 101572.0};
   for(int i = 0; i < QM_DSP_BANDS; ++i)
     {
      const double f0 = 1.0 / periods[i];
      const double tangent = MathTan((2.0 * QM_DSP_PI * f0) / (2.0 * QM_DSP_Q));
      g_dsp_b[i] = 0.5 * (1.0 - tangent) / (1.0 + tangent);
      g_dsp_c[i] = (0.5 + g_dsp_b[i]) * MathCos(2.0 * QM_DSP_PI * f0);
      g_dsp_a[i] = 0.5 * (0.5 - g_dsp_b[i]);
     }
  }

void DSP_ResetState()
  {
   ArrayInitialize(g_dsp_band_y1, 0.0);
   ArrayInitialize(g_dsp_band_y2, 0.0);
   g_dsp_x1 = 0.0;
   g_dsp_x2 = 0.0;
   g_dsp_y = 0.0;
   g_dsp_y1 = 0.0;
   g_dsp_y2 = 0.0;
   g_dsp_samples = 0;
   g_dsp_bar_count = 0;
   g_dsp_entry_bar = 0;
   g_dsp_ready = false;
   g_dsp_spread_ok = true;
  }

void DSP_Advance(const double close_price)
  {
   double synth = 0.0;
   for(int i = 0; i < QM_DSP_BANDS; ++i)
     {
      const double band_y = g_dsp_a[i] * (close_price - g_dsp_x2)
                          + 2.0 * g_dsp_c[i] * g_dsp_band_y1[i]
                          - 2.0 * g_dsp_b[i] * g_dsp_band_y2[i];
      g_dsp_band_y2[i] = g_dsp_band_y1[i];
      g_dsp_band_y1[i] = band_y;
      synth += QM_DSP_SYNTH_GAIN * band_y;
     }

   g_dsp_x2 = g_dsp_x1;
   g_dsp_x1 = close_price;
   g_dsp_y2 = g_dsp_y1;
   g_dsp_y1 = g_dsp_y;
   g_dsp_y = synth;
   g_dsp_samples++;
   g_dsp_bar_count++;
   if(g_dsp_samples >= strategy_warmup_bars)
      g_dsp_ready = true;
  }

bool DSP_WarmupFromHistory()
  {
   if(strategy_warmup_bars < 3)
      return false;

   double closes[];
   ArraySetAsSeries(closes, false);
   const int need = strategy_warmup_bars + 3;
   const int got = CopyClose(_Symbol, PERIOD_D1, 1, need, closes); // perf-allowed: one-time D1 close warmup for fixed IIR filter-bank state
   if(got < strategy_warmup_bars)
      return false;

   for(int i = 0; i < got; ++i)
     {
      if(closes[i] > 0.0)
         DSP_Advance(closes[i]);
     }
   return g_dsp_ready;
  }

bool DSP_SpreadAllowsEntry()
  {
   if(strategy_spread_lookback <= 1 || strategy_spread_mult <= 0.0)
      return true;

   int spreads[];
   ArraySetAsSeries(spreads, false);
   const int got = CopySpread(_Symbol, PERIOD_D1, 1, strategy_spread_lookback, spreads); // perf-allowed: D1 spread median cache, advanced once per new bar
   if(got <= 0)
      return true;

   int sorted[];
   ArrayResize(sorted, got);
   for(int i = 0; i < got; ++i)
      sorted[i] = spreads[i];
   ArraySort(sorted);

   const double median = (double)sorted[got / 2];
   if(median <= 0.0)
      return true;

   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (current_spread <= median * strategy_spread_mult);
  }

void DSP_AdvanceStateOnNewBar()
  {
   if(!g_dsp_ready && g_dsp_samples == 0)
     {
      DSP_WarmupFromHistory();
     }
   else
     {
      double close_last[1];
      ArraySetAsSeries(close_last, false);
      const int got = CopyClose(_Symbol, PERIOD_D1, 1, 1, close_last); // perf-allowed: single D1 closed-bar close for IIR state advance
      if(got == 1 && close_last[0] > 0.0)
         DSP_Advance(close_last[0]);
     }

   g_dsp_spread_ok = DSP_SpreadAllowsEntry();
  }

bool DSP_HasOpenPosition()
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

bool DSP_LocalTroughBelowZero()
  {
   return (g_dsp_y2 > g_dsp_y1 && g_dsp_y > g_dsp_y1 && g_dsp_y1 < 0.0);
  }

bool DSP_LocalCrestAboveZero()
  {
   return (g_dsp_y2 < g_dsp_y1 && g_dsp_y < g_dsp_y1 && g_dsp_y1 > 0.0);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!g_dsp_ready)
      return true;
   if(!g_dsp_spread_ok)
      return true;
   if(DSP_HasOpenPosition())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_dsp_ready)
      return false;

   const bool long_signal = DSP_LocalTroughBelowZero();
   const bool short_signal = DSP_LocalCrestAboveZero();
   if(!long_signal && !short_signal)
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.price = 0.0;
   req.tp = 0.0;

   if(long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "DSP_TROUGH_LONG";
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "DSP_CREST_SHORT";
     }

   if(req.sl <= 0.0)
      return false;

   g_dsp_entry_bar = g_dsp_bar_count;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_dsp_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(g_dsp_bar_count - g_dsp_entry_bar >= strategy_max_hold_bars)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && DSP_LocalCrestAboveZero())
         return true;
      if(ptype == POSITION_TYPE_SELL && DSP_LocalTroughBelowZero())
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   DSP_InitCoefficients();
   DSP_ResetState();

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1614_aa-dsp-fbank-turn\",\"source\":\"alpha-architect-dsp-filter-bank\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      DSP_AdvanceStateOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const bool time_stop = (g_dsp_bar_count - g_dsp_entry_bar >= strategy_max_hold_bars);
         QM_TM_ClosePosition(ticket, time_stop ? QM_EXIT_TIME_STOP : QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!is_new_bar)
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

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
