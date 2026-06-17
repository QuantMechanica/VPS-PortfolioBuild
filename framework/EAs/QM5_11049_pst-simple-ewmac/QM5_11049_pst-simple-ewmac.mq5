#property strict
#property version   "5.0"
#property description "QM5_11049 pst-simple-ewmac — pysystemtrade simple EWMAC (vol-normalised D1 trend, symmetric long/short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11049 pst-simple-ewmac
// -----------------------------------------------------------------------------
// Source: Rob Carver / pst-group, pysystemtrade "simple EWMAC" example.
//   docs/introduction.md ("A simple trading rule" / "A simple system"),
//   systems/provided/example/simplesystemconfig.yaml rules ewmac8 / ewmac32.
// Card: artifacts/cards_approved/QM5_11049_pst-simple-ewmac.md (g0_status APPROVED).
//
// Mechanics (D1, symmetric long/short, closed-bar reads at shift 1):
//   EWMAC core   : ewmac(f,s) = (EMA(close,f) - EMA(close,s)) / vol , scaled by
//                  a fixed forecast scalar, then capped to [-cap,+cap].
//   Volatility   : daily price volatility, normalising the raw EMA crossover so
//                  the forecast is comparable across regimes/symbols.
//                  PORT NOTE: pysystemtrade uses an EWMA std of daily price
//                  *differences*; the V5 framework exposes ATR as its native
//                  daily price-movement volatility reader (QM_ATR, handle-pooled,
//                  no raw CopyRates). We normalise by ATR(vol_period, D1), which
//                  is the same dimension (price units of daily movement). Flagged
//                  as a deterministic, non-ML port in build_result.open_questions.
//   Component 1  : ewmac8  = (EMA(8)  - EMA(32))  / vol * 5.30 , capped +/-20.
//   Component 2  : ewmac32 = (EMA(32) - EMA(128)) / vol * 2.65 , capped +/-20.
//   Combined     : forecast = fdm * (0.5*ewmac8 + 0.5*ewmac32) , fdm = 1.1.
//   Entry        : long  when forecast >= +entry_threshold (default +5).
//                  short when forecast <= -entry_threshold (default -5).
//   Exit         : close long  when forecast <= +exit_buffer  (default +1).
//                  close short when forecast >= -exit_buffer  (default -1).
//                  Flip happens only on a later bar that crosses the opposite
//                  entry threshold (close first, re-enter on a subsequent bar).
//   Emergency SL : 3.0 * ATR(20, D1) from entry (V5 risk bound; source exits by
//                  forecast). No TP — the forecast exit is the profit mechanism.
//   Spread guard : skip a genuinely wide spread > spread_pct_of_stop of the stop
//                  distance (fail-open on .DWX zero modeled spread).
//
// One open position per symbol/magic. RISK_FIXED in tester, RISK_PERCENT live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11049;
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
input int    strategy_ema_fast1         = 8;      // ewmac8 fast EMA horizon
input int    strategy_ema_slow1         = 32;     // ewmac8 slow EMA horizon
input int    strategy_ema_fast2         = 32;     // ewmac32 fast EMA horizon
input int    strategy_ema_slow2         = 128;    // ewmac32 slow EMA horizon
input int    strategy_vol_period        = 32;     // daily volatility (ATR) lookback for normalisation
input double strategy_scalar1           = 5.30;   // ewmac8 forecast scalar (Appendix B)
input double strategy_scalar2           = 2.65;   // ewmac32 forecast scalar (Appendix B)
input double strategy_forecast_cap      = 20.0;   // per-component cap (+/-)
input double strategy_fdm               = 1.10;   // forecast diversification multiplier
input double strategy_entry_threshold   = 5.0;    // |forecast| >= this to enter
input double strategy_exit_buffer       = 1.0;    // close when forecast decays past this
input int    strategy_stop_atr_period   = 20;     // emergency stop ATR period
input double strategy_stop_atr_mult     = 3.0;    // emergency stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: compute the combined EWMAC forecast on the last closed bar.
// Returns false if any input is not yet warm (indicator returned 0).
// -----------------------------------------------------------------------------
bool ComputeCombinedForecast(double &forecast_out)
  {
   forecast_out = 0.0;

   // Daily price volatility normaliser (ATR of the vol lookback, closed bar).
   const double vol = QM_ATR(_Symbol, _Period, strategy_vol_period, 1);
   if(vol <= 0.0)
      return false;

   const double ema_f1 = QM_EMA(_Symbol, _Period, strategy_ema_fast1, 1);
   const double ema_s1 = QM_EMA(_Symbol, _Period, strategy_ema_slow1, 1);
   const double ema_f2 = QM_EMA(_Symbol, _Period, strategy_ema_fast2, 1);
   const double ema_s2 = QM_EMA(_Symbol, _Period, strategy_ema_slow2, 1);
   if(ema_f1 <= 0.0 || ema_s1 <= 0.0 || ema_f2 <= 0.0 || ema_s2 <= 0.0)
      return false;

   // Raw, vol-normalised, scaled, capped components.
   double ewmac1 = ((ema_f1 - ema_s1) / vol) * strategy_scalar1;
   double ewmac2 = ((ema_f2 - ema_s2) / vol) * strategy_scalar2;

   const double cap = strategy_forecast_cap;
   if(ewmac1 >  cap) ewmac1 =  cap;
   if(ewmac1 < -cap) ewmac1 = -cap;
   if(ewmac2 >  cap) ewmac2 =  cap;
   if(ewmac2 < -cap) ewmac2 = -cap;

   // Equal-weighted combine, diversification-multiplied.
   forecast_out = strategy_fdm * (0.5 * ewmac1 + 0.5 * ewmac2);
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — forecast work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double forecast = 0.0;
   if(!ComputeCombinedForecast(forecast))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   if(forecast >= strategy_entry_threshold)
      side = QM_BUY;
   else if(forecast <= -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — forecast-decay exit handles profit-taking
   req.reason = (side == QM_BUY) ? "ewmac_long" : "ewmac_short";
   return true;
  }

// No active trade management beyond the fixed emergency ATR stop. The
// forecast-decay exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Forecast-decay exit: close long when forecast falls to +exit_buffer or below;
// close short when forecast rises to -exit_buffer or above. Direction-aware so
// it only closes the side that has actually decayed.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double forecast = 0.0;
   if(!ComputeCombinedForecast(forecast))
      return false;

   // Determine the open side for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   if(is_long  && forecast <=  strategy_exit_buffer)
      return true;
   if(is_short && forecast >= -strategy_exit_buffer)
      return true;

   return false;
  }

// Defer to the central news filter.
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
