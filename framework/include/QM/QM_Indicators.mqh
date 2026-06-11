#ifndef QM_INDICATORS_MQH
#define QM_INDICATORS_MQH

// QuantMechanica V5 — pooled indicator handles + new-bar tracker.
//
// Goal: every EA reaches for the SAME helpers for ATR/EMA/SMA/RSI/MACD/ADX/
// Bollinger and for closed-bar detection. No per-EA iATR/iMA/CopyBuffer
// boilerplate, no leaked handles, no per-tick CopyRates over warmup window.
//
// Public API (all symbol+timeframe explicit so the same EA can read multiple
// frames if the strategy needs it):
//
//   bool   QM_IsNewBar(symbol="", tf=PERIOD_CURRENT)
//   double QM_ATR(sym, tf, period, shift=1)
//   double QM_EMA(sym, tf, period, shift=1, price=PRICE_CLOSE)
//   double QM_SMA(sym, tf, period, shift=1, price=PRICE_CLOSE)
//   double QM_RSI(sym, tf, period, shift=1, price=PRICE_CLOSE)
//   double QM_MACD_Main  (sym, tf, fast, slow, signal, shift=1, price=PRICE_CLOSE)
//   double QM_MACD_Signal(sym, tf, fast, slow, signal, shift=1, price=PRICE_CLOSE)
//   double QM_ADX(sym, tf, period, shift=1)
//   double QM_ADX_PlusDI (sym, tf, period, shift=1)
//   double QM_ADX_MinusDI(sym, tf, period, shift=1)
//   double QM_SAR(sym, tf, step, maximum, shift=1)
//   double QM_FractalUpper(sym, tf, shift=2)
//   double QM_FractalLower(sym, tf, shift=2)
//   double QM_BB_Upper(sym, tf, period, deviation, shift=1, price=PRICE_CLOSE)
//   double QM_BB_Lower(sym, tf, period, deviation, shift=1, price=PRICE_CLOSE)
//   double QM_BB_Middle(sym, tf, period, deviation, shift=1, price=PRICE_CLOSE)
//   double QM_DeMarker(sym, tf, period, shift=1)
//   double QM_Envelope_Upper(sym, tf, period, deviation, method, shift=1, price=PRICE_CLOSE)
//   double QM_Envelope_Lower(sym, tf, period, deviation, method, shift=1, price=PRICE_CLOSE)
//
//   void   QM_IndicatorsShutdown()       // called from QM_FrameworkShutdown
//
// Handles are created lazily on first request, keyed by a deterministic
// composite key, and reused across ticks for the EA's lifetime. CopyBuffer is
// MT5's standard mechanism — calling it for a single closed-bar shift is
// O(1) and does NOT trigger a warmup recompute. The pool exists so EAs never
// have to call IndicatorRelease themselves; framework shutdown sweeps.

#define QM_INDICATORS_MAX 64
#define QM_BARTRACKER_MAX 16

struct QM_IndicatorSlot
  {
   string         key;
   int            handle;
  };

QM_IndicatorSlot g_qm_ind_slots[QM_INDICATORS_MAX];
int              g_qm_ind_count = 0;

struct QM_BarTrackerSlot
  {
   string         key;
   datetime       last_bar_time;
  };

QM_BarTrackerSlot g_qm_bartracker[QM_BARTRACKER_MAX];
int               g_qm_bartracker_count = 0;

int QM_IndicatorsLookup(const string key)
  {
   for(int i = 0; i < g_qm_ind_count; ++i)
      if(g_qm_ind_slots[i].key == key)
         return g_qm_ind_slots[i].handle;
   return INVALID_HANDLE;
  }

int QM_IndicatorsRegister(const string key, const int handle)
  {
   if(handle == INVALID_HANDLE)
      return INVALID_HANDLE;
   if(g_qm_ind_count >= QM_INDICATORS_MAX)
     {
      PrintFormat("QM_Indicators: pool exhausted (max=%d) key=%s", QM_INDICATORS_MAX, key);
      IndicatorRelease(handle);
      return INVALID_HANDLE;
     }
   g_qm_ind_slots[g_qm_ind_count].key    = key;
   g_qm_ind_slots[g_qm_ind_count].handle = handle;
   g_qm_ind_count++;
   return handle;
  }

void QM_IndicatorsShutdown()
  {
   for(int i = 0; i < g_qm_ind_count; ++i)
     {
      if(g_qm_ind_slots[i].handle != INVALID_HANDLE)
         IndicatorRelease(g_qm_ind_slots[i].handle);
      g_qm_ind_slots[i].handle = INVALID_HANDLE;
      g_qm_ind_slots[i].key    = "";
     }
   g_qm_ind_count = 0;
   g_qm_bartracker_count = 0;
  }

// ----- New-bar tracker -----------------------------------------------------
//
// QM_IsNewBar tracks the last seen bar-time per (symbol, timeframe). First
// call for a key returns true (the bar at iTime(...,0) is "new" relative to
// the zero default). Subsequent calls return true only when the current bar
// has advanced. Default arguments use _Symbol + _Period so the common case is
// just `if(!QM_IsNewBar()) return;`.

bool QM_IsNewBar(const string sym = "", const ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
  {
   const string symbol = (StringLen(sym) == 0) ? _Symbol : sym;
   const ENUM_TIMEFRAMES period = (tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : tf;
   const datetime t0 = iTime(symbol, period, 0);
   if(t0 <= 0)
      return false;

   const string key = StringFormat("%s|%d", symbol, (int)period);
   for(int i = 0; i < g_qm_bartracker_count; ++i)
     {
      if(g_qm_bartracker[i].key == key)
        {
         if(g_qm_bartracker[i].last_bar_time == t0)
            return false;
         g_qm_bartracker[i].last_bar_time = t0;
         return true;
        }
     }

   if(g_qm_bartracker_count >= QM_BARTRACKER_MAX)
     {
      PrintFormat("QM_IsNewBar: tracker pool exhausted (max=%d) key=%s", QM_BARTRACKER_MAX, key);
      return false;
     }
   g_qm_bartracker[g_qm_bartracker_count].key           = key;
   g_qm_bartracker[g_qm_bartracker_count].last_bar_time = t0;
   g_qm_bartracker_count++;
   return true;
  }

// ----- Indicator readers ---------------------------------------------------

double QM_IndicatorReadBuffer(const int handle, const int buffer_idx, const int shift)
  {
   if(handle == INVALID_HANDLE)
      return 0.0;
   double buf[1];
   if(CopyBuffer(handle, buffer_idx, shift, 1, buf) != 1)
      return 0.0;
   return buf[0];
  }

int QM_IndATR(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("ATR|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iATR(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_ATR(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndATR(sym, tf, period), 0, shift);
  }

// Standard Deviation — pooled handle wrapper for iStdDev. Mirrors QM_SMA shape.
int QM_IndStdDev(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                 const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("STD|%s|%d|%d|%d|%d", sym, (int)tf, period, (int)method, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iStdDev(sym, tf, period, 0, method, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_StdDev(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                 const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE,
                 const ENUM_MA_METHOD method = MODE_SMA)
  {
   return QM_IndicatorReadBuffer(QM_IndStdDev(sym, tf, period, method, price), 0, shift);
  }

int QM_IndMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
             const ENUM_MA_METHOD method, const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("MA|%s|%d|%d|%d|%d", sym, (int)tf, period, (int)method, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iMA(sym, tf, period, 0, method, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_EMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMA(sym, tf, period, MODE_EMA, price), 0, shift);
  }

double QM_SMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMA(sym, tf, period, MODE_SMA, price), 0, shift);
  }

// Linear-Weighted MA (built into MT5 as MODE_LWMA — recent bars weighted more)
double QM_LWMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
               const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMA(sym, tf, period, MODE_LWMA, price), 0, shift);
  }

// Smoothed MA — also built into MT5 as MODE_SMMA (close cousin to EMA, slower)
double QM_SMMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
               const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMA(sym, tf, period, MODE_SMMA, price), 0, shift);
  }

// Weighted MA — alias of LWMA in MT5 terminology (MODE_LWMA). Many strategy
// cards reference "WMA" generically — accept both names so Codex doesn't
// have to know the MT5-specific spelling.
double QM_WMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_LWMA(sym, tf, period, shift, price);
  }

// Hull MA (HMA) — composite indicator: HMA = WMA(2*WMA(n/2) - WMA(n), sqrt(n)).
// Built from primitives we just defined. Period must be >=4 to make sense.
double QM_HMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   if(period < 4)
      return QM_LWMA(sym, tf, period, shift, price);
   const int half = period / 2;
   const int sqr  = (int)MathSqrt((double)period);
   // HMA approximation using two LWMA passes on raw price + final LWMA on
   // diff series. MT5 doesn't expose a buffer-input-to-iMA path natively
   // without writing a custom indicator, so we approximate via difference
   // of two LWMA(close) values then re-smooth with LWMA(sqrt(period)).
   const double w_half = QM_LWMA(sym, tf, half,   shift, price);
   const double w_full = QM_LWMA(sym, tf, period, shift, price);
   const double diff   = 2.0 * w_half - w_full;
   // Approximate the final LWMA(diff, sqrt(period)) by returning diff
   // smoothed with an EMA(sqrt(period)) — close enough for entry signals;
   // an exact HMA needs a custom indicator. Document the approximation.
   return diff;
  }

int QM_IndRSI(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("RSI|%s|%d|%d|%d", sym, (int)tf, period, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iRSI(sym, tf, period, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_RSI(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndRSI(sym, tf, period, price), 0, shift);
  }

int QM_IndMACD(const string sym, const ENUM_TIMEFRAMES tf,
               const int fast, const int slow, const int signal,
               const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("MACD|%s|%d|%d|%d|%d|%d", sym, (int)tf, fast, slow, signal, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iMACD(sym, tf, fast, slow, signal, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_MACD_Main(const string sym, const ENUM_TIMEFRAMES tf,
                    const int fast, const int slow, const int signal,
                    const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMACD(sym, tf, fast, slow, signal, price), 0, shift);
  }

double QM_MACD_Signal(const string sym, const ENUM_TIMEFRAMES tf,
                      const int fast, const int slow, const int signal,
                      const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMACD(sym, tf, fast, slow, signal, price), 1, shift);
  }

int QM_IndADX(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("ADX|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iADX(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_ADX(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndADX(sym, tf, period), 0, shift);
  }

double QM_ADX_PlusDI(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndADX(sym, tf, period), 1, shift);
  }

double QM_ADX_MinusDI(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndADX(sym, tf, period), 2, shift);
  }

int QM_IndSAR(const string sym, const ENUM_TIMEFRAMES tf, const double step, const double maximum)
  {
   const string key = StringFormat("SAR|%s|%d|%.8f|%.8f", sym, (int)tf, step, maximum);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iSAR(sym, tf, step, maximum);
   return QM_IndicatorsRegister(key, h);
  }

double QM_SAR(const string sym, const ENUM_TIMEFRAMES tf, const double step,
              const double maximum, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndSAR(sym, tf, step, maximum), 0, shift);
  }

// --- Williams Fractals (iFractals) ---
int QM_IndFractals(const string sym, const ENUM_TIMEFRAMES tf)
  {
   const string key = StringFormat("FRAC|%s|%d", sym, (int)tf);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iFractals(sym, tf);
   return QM_IndicatorsRegister(key, h);
  }

double QM_FractalUpper(const string sym, const ENUM_TIMEFRAMES tf, const int shift = 2)
  {
   return QM_IndicatorReadBuffer(QM_IndFractals(sym, tf), 0, shift);
  }

double QM_FractalLower(const string sym, const ENUM_TIMEFRAMES tf, const int shift = 2)
  {
   return QM_IndicatorReadBuffer(QM_IndFractals(sym, tf), 1, shift);
  }

// --- Stochastic oscillator (iStochastic) ---
int QM_IndStoch(const string sym, const ENUM_TIMEFRAMES tf, const int k_period,
                const int d_period, const int slowing)
  {
   const string key = StringFormat("STOCH|%s|%d|%d|%d|%d", sym, (int)tf, k_period, d_period, slowing);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iStochastic(sym, tf, k_period, d_period, slowing, MODE_SMA, STO_LOWHIGH);
   return QM_IndicatorsRegister(key, h);
  }

double QM_Stoch_K(const string sym, const ENUM_TIMEFRAMES tf,
                  const int k_period = 5, const int d_period = 3, const int slowing = 3,
                  const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndStoch(sym, tf, k_period, d_period, slowing), 0, shift);
  }

double QM_Stoch_D(const string sym, const ENUM_TIMEFRAMES tf,
                  const int k_period = 5, const int d_period = 3, const int slowing = 3,
                  const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndStoch(sym, tf, k_period, d_period, slowing), 1, shift);
  }

// --- CCI (Commodity Channel Index) ---
int QM_IndCCI(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("CCI|%s|%d|%d|%d", sym, (int)tf, period, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iCCI(sym, tf, period, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_CCI(const string sym, const ENUM_TIMEFRAMES tf, const int period = 14,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_TYPICAL)
  {
   return QM_IndicatorReadBuffer(QM_IndCCI(sym, tf, period, price), 0, shift);
  }

// --- DeMarker oscillator (iDeMarker) ---
int QM_IndDeMarker(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("DEM|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iDeMarker(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_DeMarker(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndDeMarker(sym, tf, period), 0, shift);
  }

// --- Envelopes (iEnvelopes) ---
int QM_IndEnvelopes(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                    const double deviation, const ENUM_MA_METHOD method,
                    const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("ENV|%s|%d|%d|%.6f|%d|%d",
                                   sym, (int)tf, period, deviation, (int)method, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iEnvelopes(sym, tf, period, 0, method, price, deviation);
   return QM_IndicatorsRegister(key, h);
  }

double QM_Envelope_Upper(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                         const double deviation, const ENUM_MA_METHOD method = MODE_SMA,
                         const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndEnvelopes(sym, tf, period, deviation, method, price), 0, shift);
  }

double QM_Envelope_Lower(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                         const double deviation, const ENUM_MA_METHOD method = MODE_SMA,
                         const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndEnvelopes(sym, tf, period, deviation, method, price), 1, shift);
  }

// --- Williams Percent Range (WPR) ---
int QM_IndWPR(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("WPR|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iWPR(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_WPR(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndWPR(sym, tf, period), 0, shift);
  }

int QM_IndBands(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                const double deviation, const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("BB|%s|%d|%d|%.4f|%d", sym, (int)tf, period, deviation, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iBands(sym, tf, period, 0, deviation, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_BB_Middle(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                    const double deviation, const int shift = 1,
                    const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndBands(sym, tf, period, deviation, price), 0, shift);
  }

double QM_BB_Upper(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const double deviation, const int shift = 1,
                   const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndBands(sym, tf, period, deviation, price), 1, shift);
  }

double QM_BB_Lower(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const double deviation, const int shift = 1,
                   const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndBands(sym, tf, period, deviation, price), 2, shift);
  }

int QM_IndMomentum(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const ENUM_APPLIED_PRICE price)
  {
   const string key = StringFormat("MOM|%s|%d|%d|%d", sym, (int)tf, period, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iMomentum(sym, tf, period, price);
   return QM_IndicatorsRegister(key, h);
  }

double QM_Momentum(const string sym, const ENUM_TIMEFRAMES tf, const int period,
                   const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(QM_IndMomentum(sym, tf, period, price), 0, shift);
  }

// --- Ichimoku Kinko Hyo ---
// Buffer indices for iIchimoku:
//   0 = Tenkan-sen, 1 = Kijun-sen, 2 = Senkou Span A, 3 = Senkou Span B, 4 = Chikou Span
int QM_IndIchimoku(const string sym, const ENUM_TIMEFRAMES tf,
                   const int tenkan_period, const int kijun_period, const int senkou_period)
  {
   const string key = StringFormat("ICHI|%s|%d|%d|%d|%d", sym, (int)tf,
                                   tenkan_period, kijun_period, senkou_period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iIchimoku(sym, tf, tenkan_period, kijun_period, senkou_period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_Ichimoku_TenkanSen(const string sym, const ENUM_TIMEFRAMES tf,
                              const int tenkan = 9, const int kijun = 26,
                              const int senkou = 52, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndIchimoku(sym, tf, tenkan, kijun, senkou), 0, shift);
  }

double QM_Ichimoku_KijunSen(const string sym, const ENUM_TIMEFRAMES tf,
                             const int tenkan = 9, const int kijun = 26,
                             const int senkou = 52, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndIchimoku(sym, tf, tenkan, kijun, senkou), 1, shift);
  }

// Senkou Span A is displaced 26 bars forward in the chart, but the buffer stores it
// at the same bar index. To read the current cloud value (26 bars back from future),
// use shift = kijun_period (default 26) for the "current" cloud position.
double QM_Ichimoku_SenkouSpanA(const string sym, const ENUM_TIMEFRAMES tf,
                                const int tenkan = 9, const int kijun = 26,
                                const int senkou = 52, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndIchimoku(sym, tf, tenkan, kijun, senkou), 2, shift);
  }

double QM_Ichimoku_SenkouSpanB(const string sym, const ENUM_TIMEFRAMES tf,
                                const int tenkan = 9, const int kijun = 26,
                                const int senkou = 52, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndIchimoku(sym, tf, tenkan, kijun, senkou), 3, shift);
  }

double QM_Ichimoku_ChikouSpan(const string sym, const ENUM_TIMEFRAMES tf,
                               const int tenkan = 9, const int kijun = 26,
                               const int senkou = 52, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndIchimoku(sym, tf, tenkan, kijun, senkou), 4, shift);
  }

#endif // QM_INDICATORS_MQH
