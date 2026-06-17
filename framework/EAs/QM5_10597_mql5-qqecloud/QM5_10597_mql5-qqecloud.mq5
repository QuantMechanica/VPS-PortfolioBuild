#property strict
#property version   "5.0"
#property description "QM5_10597 MQL5 QQECloud Timed Trend — timed entry on QQECloud qqe_color, timed/opposite-qqe_color exit"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10597 — MQL5 QQECloud Timed Trend
// -----------------------------------------------------------------------------
// Source: MQL5 CodeBase Exp_QQECloud (Nikolay Kositsin), USDCHF H4.
// Mechanic (card QM5_10597):
//   ENTRY  — once per trading day at StartHour:StartMinute (broker time),
//            read the QQECloud qqe_color state on the last CLOSED bar:
//              qqe_color = purple (uptrend)  -> BUY
//              qqe_color = red    (downtrend)-> SELL
//            One position per symbol/magic (framework enforces single-entry).
//   EXIT   — close at StopHour:StopMinute (broker time), OR earlier when the
//            opposite QQECloud qqe_color appears on a completed bar.
//   STOP   — source used none; baseline catastrophic stop = 2.5 * ATR(14).
//
// QQECloud is RSI-derived. No custom indicator handle is available in the
// framework, so the cloud is self-computed from the pooled QM_RSI reader:
//   RsiMa      = EMA(RSI(rsi_period), smoothing) on the RSI series
//   AtrRsi     = |RsiMa[i] - RsiMa[i-1]|, Wilder-smoothed (wilder_period),
//                then Wilder-smoothed again -> DAR (dynamic ATR of RSI)
//   delta      = DAR * qqe_factor
//   trailing   = QQE fast trailing level (classic QQE longband/shortband logic)
//   qqe_color      = purple if RsiMa > trailing (uptrend), red if RsiMa < trailing.
// The trailing level is reconstructed deterministically over a fixed warmup
// window on each closed bar (bounded loop, pooled RSI reads only — no raw iX,
// no file-scope new-bar timestamp gate, no leaked handles).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10597;
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
// Timed-entry window (broker time, DXZ NY-Close GMT+2/+3).
input int    StartHour                  = 8;     // decision hour for the daily entry
input int    StartMinute                = 0;     // decision minute
input int    StopHour                   = 23;    // forced-close hour
input int    StopMinute                 = 59;    // forced-close minute
// QQECloud (RSI-derived) parameters — source defaults.
input int    qqe_rsi_period             = 14;    // base RSI length
input int    qqe_smoothing              = 5;     // EMA smoothing of the RSI (RsiMa)
input int    qqe_wilder_period          = 27;    // Wilder ATR-of-RSI smoothing
input double qqe_factor                 = 4.236; // QQE band multiplier
// Catastrophic stop (source had none; baseline).
input int    atr_period                 = 14;
input double atr_sl_mult                = 2.5;

// -----------------------------------------------------------------------------
// QQECloud self-computation (RSI-derived) — bounded warmup reconstruction.
// -----------------------------------------------------------------------------
// Returns the cloud qqe_color on the bar at `eval_shift` (a CLOSED bar):
//   +1 = purple (uptrend / long)
//   -1 = red    (downtrend / short)
//    0 = undetermined (insufficient history)
// Pure function of pooled QM_RSI reads; no file-scope state, no handles.
int QQECloudColor(const int eval_shift)
  {
   // Warmup must cover RSI smoothing + Wilder smoothing convergence.
   const int warmup = qqe_smoothing + 2 * qqe_wilder_period + 30;
   const int total  = warmup + 2; // a couple of extra bars of margin
   if(Bars(_Symbol, _Period) < total + eval_shift + 2)
      return 0;

   // Build the smoothed-RSI (RsiMa) series, OLDEST first, ending at eval_shift.
   // index 0 = oldest sampled bar, last index = the bar at eval_shift.
   const int n = total;
   double rsima[];
   if(ArrayResize(rsima, n) != n)
      return 0;

   // Seed EMA of RSI from the oldest sampled bar.
   const double k = 2.0 / (qqe_smoothing + 1.0);
   double ema = QM_RSI(_Symbol, _Period, qqe_rsi_period, eval_shift + n - 1, PRICE_CLOSE);
   if(ema == 0.0)
      return 0;
   rsima[0] = ema;
   for(int i = 1; i < n; ++i)
     {
      const int shift = eval_shift + (n - 1 - i);
      const double rsi = QM_RSI(_Symbol, _Period, qqe_rsi_period, shift, PRICE_CLOSE);
      ema = ema + k * (rsi - ema);
      rsima[i] = ema;
     }

   // Wilder ATR of the RsiMa series: smoothed |delta|, then smoothed again (DAR).
   const double wk = 1.0 / (double)qqe_wilder_period;
   double atr_rsi = 0.0;       // Wilder-smoothed |delta|
   bool   atr_seed = false;
   double dar = 0.0;           // Wilder-smoothed atr_rsi (double-smoothed)
   bool   dar_seed = false;

   // QQE fast trailing level reconstruction (classic longband/shortband).
   double trailing = rsima[0];
   for(int i = 1; i < n; ++i)
     {
      const double delta = MathAbs(rsima[i] - rsima[i - 1]);
      if(!atr_seed) { atr_rsi = delta; atr_seed = true; }
      else          { atr_rsi = atr_rsi + wk * (delta - atr_rsi); }

      if(!dar_seed) { dar = atr_rsi; dar_seed = true; }
      else          { dar = dar + wk * (atr_rsi - dar); }

      const double band = dar * qqe_factor;

      const double rs    = rsima[i];
      const double rsp   = rsima[i - 1];
      const double newSL = rs - band; // long trailing candidate
      const double newSS = rs + band; // short trailing candidate

      // Classic QQE trailing-stop ratchet around the prior trailing level.
      if(rs > trailing && rsp > trailing)
         trailing = MathMax(trailing, newSL);
      else if(rs < trailing && rsp < trailing)
         trailing = MathMin(trailing, newSS);
      else if(rs > trailing)
         trailing = newSL;
      else
         trailing = newSS;
     }

   const double rsi_now = rsima[n - 1];
   if(rsi_now > trailing)
      return +1; // purple / uptrend
   if(rsi_now < trailing)
      return -1; // red / downtrend
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry fires once per day at the decision bar. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Only one position per magic — framework also enforces, cheap guard here.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Decision time gate (broker time). The closed bar that just opened must
   // be the StartHour:StartMinute bar.
   const datetime bar_open = iTime(_Symbol, _Period, 0);
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   if(dt.hour != StartHour || dt.min != StartMinute)
      return false;

   const int qqe_color = QQECloudColor(1); // last closed bar
   if(qqe_color == 0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(qqe_color > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK),
                          atr_period, atr_sl_mult);
      req.tp = 0.0;
      req.reason = "qqecloud_purple_timed_long";
      return true;
     }

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, QM_SELL, SymbolInfoDouble(_Symbol, SYMBOL_BID),
                       atr_period, atr_sl_mult);
   req.tp = 0.0;
   req.reason = "qqecloud_red_timed_short";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source uses no trailing/BE management; SL is the catastrophic ATR stop.
  }

// Close at StopHour:StopMinute, or earlier on opposite QQECloud qqe_color.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Timed close — broker-time hour/minute reached or passed for the day.
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int now_minutes  = dt.hour * 60 + dt.min;
   const int stop_minutes = StopHour * 60 + StopMinute;
   if(now_minutes >= stop_minutes)
      return true;

   // Opposite-qqe_color close on a completed bar.
   const int qqe_color = QQECloudColor(1);
   if(qqe_color == 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && qqe_color < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && qqe_color > 0)
         return true;
     }
   return false;
  }

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
