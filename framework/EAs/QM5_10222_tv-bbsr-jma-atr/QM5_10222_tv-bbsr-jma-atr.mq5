#property strict
#property version   "5.0"
#property description "QM5_10222 TradingView BBSR JMA ATR"
// Strategy Card: QM5_10222 (tv-bbsr-jma-atr), G0 APPROVED 2026-05-19.
// Source: TradingView "BBSR Extreme Strategy [nachodog]" (author ryanwhitham).
// Mechanic: Bollinger-band extreme reclaim + Stochastic extreme + JMA-trend
// gate, ATR trailing-stop exit, opposite-signal close. JMA is reproduced with
// the framework Hull-MA low-lag proxy (card §Stop Loss license).

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — 5 strategy hooks over the framework scaffold.
// All indicator access goes through QM_* readers / QM_Sig_* helpers so no raw
// iClose/iBands/iStochastic/Bars calls live in this EA (framework corset).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10222;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Card §Entry: Bollinger(20,2) extreme reclaim + Stochastic(14,3,3) extreme
// + JMA trend gate (Hull-MA proxy). Card §Exit/§Stop: ATR trailing stop.
input int    strategy_bb_period          = 20;     // Bollinger lookback.
input double strategy_bb_deviation       = 2.0;    // Bollinger band stddev.
input int    strategy_stoch_k_period     = 14;     // Stochastic %K period.
input int    strategy_stoch_d_period     = 3;      // Stochastic %D period.
input int    strategy_stoch_slowing      = 3;      // Stochastic slowing.
input double strategy_stoch_oversold     = 20.0;   // Long gate: K & D below this.
input double strategy_stoch_overbought   = 80.0;   // Short gate: K & D above this.
input int    strategy_jma_proxy_period   = 55;     // JMA trend filter -> Hull-MA proxy.
input int    strategy_atr_period         = 14;     // ATR period for SL + trail.
input double strategy_atr_trail_mult     = 3.0;    // ATR multiple (initial SL + trailing).
// Card §Filters: "avoid very low-spread but flat overnight sessions".
input bool   strategy_skip_overnight     = true;   // Block flat overnight window.
input int    strategy_skip_start_hour    = 22;     // Broker-hour window start (inclusive).
input int    strategy_skip_end_hour      = 2;      // Broker-hour window end (exclusive, wrap-safe).

// -----------------------------------------------------------------------------
// Shared signal core. Returns +1 (long reclaim), -1 (short reclaim), 0 (none),
// evaluated on the last two CLOSED bars of the chart timeframe. Uses only
// framework readers/signal helpers — no raw series access in this EA.
// -----------------------------------------------------------------------------
int Strategy_BBSRSignal()
  {
   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_stoch_k_period <= 1 || strategy_stoch_d_period <= 0 ||
      strategy_stoch_slowing <= 0 || strategy_stoch_oversold <= 0.0 ||
      strategy_stoch_overbought <= strategy_stoch_oversold ||
      strategy_jma_proxy_period < 4)
      return 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Bollinger mean-reversion state on the prior and current closed bar.
   //   +1 => close pierced BELOW lower band ; -1 => close pierced ABOVE upper band.
   const int bb_prev = QM_Sig_BB_MeanRev(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2);
   const int bb_curr = QM_Sig_BB_MeanRev(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);

   // Card §Entry: previous close beyond band, current close reclaimed back inside.
   const bool bullish_reclaim = (bb_prev == +1 && bb_curr != +1); // was below lower, now reclaimed
   const bool bearish_reclaim = (bb_prev == -1 && bb_curr != -1); // was above upper, now reclaimed
   if(!bullish_reclaim && !bearish_reclaim)
      return 0;

   const double k1 = QM_Stoch_K(_Symbol, tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);

   // JMA trend filter (Hull-MA proxy): green = rising, red = falling.
   const double hma1 = QM_HMA(_Symbol, tf, strategy_jma_proxy_period, 1);
   const double hma2 = QM_HMA(_Symbol, tf, strategy_jma_proxy_period, 2);
   if(hma1 <= 0.0 || hma2 <= 0.0)
      return 0;

   const bool stoch_oversold   = (k1 > 0.0 && d1 > 0.0 && k1 < strategy_stoch_oversold && d1 < strategy_stoch_oversold);
   const bool stoch_overbought = (k1 > strategy_stoch_overbought && d1 > strategy_stoch_overbought);
   const bool jma_green        = (hma1 > hma2);
   const bool jma_red          = (hma1 < hma2);

   if(bullish_reclaim && stoch_oversold && jma_green)
      return +1;
   if(bearish_reclaim && stoch_overbought && jma_red)
      return -1;
   return 0;
  }

// Position direction held under this EA's magic on _Symbol.
//   +1 long, -1 short, 0 flat.
int Strategy_OpenDirection()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (pt == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------
// Return TRUE to BLOCK trading this tick. Card §Filters: avoid the flat
// overnight session. News/spread are handled by the framework OnTick wiring.
bool Strategy_NoTradeFilter()
  {
   if(strategy_skip_overnight)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int h = dt.hour;
      if(strategy_skip_start_hour < strategy_skip_end_hour)
        {
         if(h >= strategy_skip_start_hour && h < strategy_skip_end_hour)
            return true;
        }
      else if(strategy_skip_start_hour > strategy_skip_end_hour)
        {
         if(h >= strategy_skip_start_hour || h < strategy_skip_end_hour)
            return true; // wrap-around window (e.g. 22:00 -> 02:00)
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
// Populate `req` and return TRUE for a new entry on this closed bar. Caller
// guarantees QM_IsNewBar()==true. SL = ATR trailing-stop distance at entry
// (card §Stop Loss). No fixed TP — exits via ATR trail / opposite signal.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_atr_trail_mult <= 0.0)
      return false;

   const int sig = Strategy_BBSRSignal();
   if(sig == 0)
      return false;

   if(sig > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_trail_mult);
      req.reason = "BBSR_JMA_ATR_LONG";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.type = QM_SELL;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_trail_mult);
   req.reason = "BBSR_JMA_ATR_SHORT";
   return (entry > 0.0 && req.sl > 0.0 && req.sl > entry);
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
// Card §Exit: ATR trailing stop in both directions, tightened each tick a
// position is open.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
// Card §Exit: close a long on a fresh bearish entry signal, close a short on a
// fresh bullish entry signal. SL/TP and Friday-close are handled by framework.
bool Strategy_ExitSignal()
  {
   const int dir = Strategy_OpenDirection();
   if(dir == 0)
      return false;

   const int sig = Strategy_BBSRSignal();
   if(dir > 0 && sig < 0)
      return true; // long held, bearish signal -> close
   if(dir < 0 && sig > 0)
      return true; // short held, bullish signal -> close
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for Q09 News Impact phase)
// -----------------------------------------------------------------------------
// Defer to the central two-axis news filter wired in OnTick.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10222_tv-bbsr-jma-atr\"}");
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

   // Per-tick: discretionary exit (opposite signal). Separate from SL/TP.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   // Per-closed-bar: entry-signal evaluation.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
