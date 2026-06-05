#property strict
#property version   "5.0"
#property description "QM5_10795 TradingView ATR Sell-The-Rip mean reversion (tv-atr-rip)"
// Strategy Card: QM5_10795_tv-atr-rip, G0 APPROVED 2026-05-22.
// Source: TradingView script ylozoEOC "[SHORT ONLY] ATR Sell the Rip Mean Reversion
//         Strategy", author Botnet101 (source_id d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7).
//         See SPEC.md for full citation.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — ATR "Sell the Rip" short-only mean-reversion EA
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   TRIGGER : raw_k = close[k] + ATR(trig_atr_period)[k] * trig_atr_mult ; the
//             trigger is the SMA over smooth_period of that raw series.
//   SHORT   : last closed-bar close is ABOVE the smoothed trigger (overextended
//             "rip"), price within the trading window, optional EMA(200) filter
//             permits (close below EMA200), no open position.
//   EXIT    : source signal exit (close falls below the previous bar low),
//             time exit after time_stop_bars, and a mandatory hard ATR safety
//             stop above entry (set at entry as the order SL). Friday-close is
//             handled by the framework.
//
// The smoothed trigger is a bespoke series (close + ATR) with no QM_* reader,
// so it is summed inside a bounded loop (smooth_period terms) that runs once
// per closed bar — Strategy_EntrySignal is only called after QM_IsNewBar().
// ATR is read via the pooled QM_ATR reader; the close term uses a single-shift
// iClose with an explicit perf-allowed exception.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10795;
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
input int    trig_atr_period            = 20;     // ATR period for trigger — card 14/20/30
input double trig_atr_mult              = 1.0;    // ATR multiplier in raw trigger — card 0.75/1.0/1.5
input int    smooth_period              = 10;     // SMA smoothing of raw trigger — card 5/10/20

input group "Strategy - Stop / Exit"
input int    sl_atr_period              = 20;     // hard-stop ATR period — card ATR(20)
input double sl_atr_mult                = 2.0;    // hard-stop ATR multiplier — card 1.5/2.0/3.0
input int    time_stop_bars             = 10;     // time exit in bars (0 = off) — card 10 D1 / 40 H1

input group "Strategy - Filters"
input bool   use_ema_filter             = false;  // require close below EMA(200) — card optional off/on
input int    ema_filter_period          = 200;    // EMA trend-filter period
input bool   use_session_filter         = false;  // restrict to a broker-hour window — card full/local session
input int    session_start_hour         = 0;      // session window start (broker hour)
input int    session_end_hour           = 24;     // session window end (broker hour, exclusive)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Smoothed ATR signal trigger = SMA over smooth_period of (close[k] + ATR[k]*mult).
// Bounded loop, evaluated once per closed bar. Returns 0.0 during warmup.
double QM_SmoothedTrigger()
  {
   if(smooth_period < 1 || trig_atr_period < 1)
      return 0.0;
   double sum = 0.0;
   for(int k = 1; k <= smooth_period; ++k)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, trig_atr_period, k);
      const double cl  = iClose(_Symbol, _Period, k);  // perf-allowed: bespoke ATR-trigger series, no QM_* reader
      if(atr <= 0.0 || cl <= 0.0)
         return 0.0;  // warmup — abort, no signal this bar
      sum += cl + atr * trig_atr_mult;
     }
   return sum / smooth_period;
  }

// Returns true if we hold a SHORT for this magic+symbol; fills ticket + open time.
bool QM_OurShort(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((int)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;
      ticket = t;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Optional broker-hour session window (default off).
bool Strategy_NoTradeFilter()
  {
   if(!use_session_filter)
      return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int h = dt.hour;
   bool in_window;
   if(session_start_hour <= session_end_hour)
      in_window = (h >= session_start_hour && h < session_end_hour);
   else
      in_window = (h >= session_start_hour || h < session_end_hour);  // wrap-safe
   return !in_window;
  }

// Evaluated once per closed bar (framework gates on QM_IsNewBar()).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;            // market — framework resolves Bid at send
   req.sl = 0.0;
   req.tp = 0.0;              // no fixed target; exit is signal/time/hard-stop
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong tkt = 0;
   datetime opent = 0;
   if(QM_OurShort(tkt, opent))   // one position per symbol/magic
      return false;

   const double trig = QM_SmoothedTrigger();
   if(trig <= 0.0)
      return false;
   // Compare the just-closed bar's close against the smoothed trigger.
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: closed-bar close vs trigger
   if(close1 <= 0.0)
      return false;

   // Short the rip: last close pushed above the smoothed ATR trigger.
   if(close1 <= trig)
      return false;

   // Optional EMA(200) trend filter — only short with price below EMA200.
   if(use_ema_filter)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, ema_filter_period, 1);
      if(ema <= 0.0 || close1 >= ema)
         return false;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl    = QM_StopATR(_Symbol, QM_SELL, entry, sl_atr_period, sl_atr_mult);
   if(entry <= 0.0 || sl <= entry)
      return false;

   req.type   = QM_SELL;
   req.sl     = sl;
   req.reason = "tv-atr-rip SHORT close>trig";
   return true;
  }

// Per-tick: no trailing / partial / breakeven in the baseline (card §Stop Loss).
void Strategy_ManageOpenPosition()
  {
   // Baseline carries a fixed ATR hard stop set at entry; no in-trade SL moves.
  }

// Per-tick: source signal exit (close below previous bar low) + time exit.
bool Strategy_ExitSignal()
  {
   ulong tkt = 0;
   datetime opent = 0;
   if(!QM_OurShort(tkt, opent))
      return false;
   // Source reversal exit: closed-bar close vs the prior bar's low.
   const double close1  = iClose(_Symbol, _Period, 1);  // perf-allowed: source signal exit (closed-bar)
   const double prevlow = iLow(_Symbol, _Period, 2);     // perf-allowed: source signal exit (closed-bar)
   if(close1 > 0.0 && prevlow > 0.0 && close1 < prevlow)
      return true;

   if(time_stop_bars > 0)
     {
      const int ps = PeriodSeconds(_Period);
      if(ps > 0 && opent > 0 && (int)((TimeCurrent() - opent) / ps) >= time_stop_bars)
         return true;
     }
   return false;
  }

// News-filter hook — defer to the central two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10795_tv-atr-rip\"}");
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
