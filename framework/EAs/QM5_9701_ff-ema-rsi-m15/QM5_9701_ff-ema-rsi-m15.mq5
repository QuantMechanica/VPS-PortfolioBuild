#property strict
#property version   "5.0"
#property description "QM5_9701 ForexFactory EMA-RSI Intraday M15"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9701 — ForexFactory EMA-RSI M15
// Source: sashadeol, EMA & RSI Intraday M15 system, ForexFactory thread 316055, 2011-09-20
//         (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36 — see SPEC.md for citation)
//
// Rules (card QM5_9701_ff-ema-rsi-m15.md):
//   Long  = EMA(5) crosses above EMA(12) on last closed M15 bar AND RSI(7)>50
//          AND spread < 20% of ATR(14,M15) AND inside London/early-NY session
//   Short = mirror
//   SL    = prev candle low/high ± spread, capped at 20 pips, floored at 0.45×ATR
//   TP    = 1.4 × SL distance (risk:reward 1:1.4, symbol-agnostic)
//   Exit  = opposite EMA(5/12) cross OR 24 M15 bars elapsed
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9701;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_ema_fast             = 5;     // Fast EMA period (card: EMA 5)
input int    strategy_ema_slow             = 12;    // Slow EMA period (card: EMA 12)
input int    strategy_rsi_period           = 7;     // RSI period (card: RSI 7)
input int    strategy_atr_period           = 14;    // ATR period for SL and spread gate
input double strategy_spread_atr_ratio     = 0.20;  // Max allowed spread / ATR(14)
input int    strategy_sl_max_pips          = 20;    // SL cap in pips (card: 20 pips)
input double strategy_sl_atr_min_mult      = 0.45;  // SL floor as ATR(14) multiple
input double strategy_tp_rr_mult           = 1.4;   // TP = SL distance × this (card: 1.4×)
input int    strategy_time_stop_bars       = 24;    // Close after N M15 bars (card: 24)
input int    strategy_session_start_hour   = 8;     // Session open, broker time (London ~08:00 broker)
input int    strategy_session_end_hour     = 18;    // Session close, broker time (early NY ~18:00)

// -----------------------------------------------------------------------------
// No Trade Filter — session and spread gates are evaluated at entry time to
// avoid blocking trade management and exits outside the session window.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Entry Signal — fires once per closed M15 bar when QM_IsNewBar() is true.
// Implements the three-condition card rule: EMA cross + RSI + spread + session.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Session gate: London through early NY (broker time hours)
   if(QM_Sig_Session(TimeCurrent(), strategy_session_start_hour, strategy_session_end_hour) == 0)
      return false;

   // ATR(14, M15): needed for spread filter and SL floor
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Spread filter: current spread must be < 20% of ATR(14)
   const double point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   if(spread_price > strategy_spread_atr_ratio * atr)
      return false;

   // EMA(5/12) cross on the last closed bar
   const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                     strategy_ema_fast, strategy_ema_slow, 1);
   if(cross == 0)
      return false;

   // RSI(7) momentum confirmation
   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   const bool is_long  = (cross == +1 && rsi > 50.0);
   const bool is_short = (cross == -1 && rsi < 50.0);
   if(!is_long && !is_short)
      return false;

   // Pip size: 10 × point for 5/3-decimal symbols; 1 × point otherwise.
   // This matches the MT5 convention: EURUSD 5-dec pip=10×point, USDJPY 3-dec pip=10×point.
   const int digits      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor  = (digits == 3 || digits == 5) ? 10 : 1;
   const double pip_size = point * pip_factor;

   const double sl_cap_dist = (double)strategy_sl_max_pips * pip_size;
   const double sl_min_dist = strategy_sl_atr_min_mult * atr;

   double sl_dist;

   if(is_long)
     {
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double prev_low = iLow(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: structure stop
      sl_dist = ask - (prev_low - spread_price);
      sl_dist = MathMin(sl_dist, sl_cap_dist);   // cap: tighter = smaller distance
      sl_dist = MathMax(sl_dist, sl_min_dist);   // floor: widen if below 0.45×ATR
      if(sl_dist <= 0.0)
         return false;
      req.type  = QM_BUY;
      req.price = 0.0;   // market order — framework resolves to SYMBOL_ASK
      req.sl    = NormalizeDouble(ask - sl_dist, digits);
      req.tp    = NormalizeDouble(ask + sl_dist * strategy_tp_rr_mult, digits);
     }
   else
     {
      const double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double prev_high = iHigh(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: structure stop
      sl_dist = (prev_high + spread_price) - bid;
      sl_dist = MathMin(sl_dist, sl_cap_dist);
      sl_dist = MathMax(sl_dist, sl_min_dist);
      if(sl_dist <= 0.0)
         return false;
      req.type  = QM_SELL;
      req.price = 0.0;   // market order — framework resolves to SYMBOL_BID
      req.sl    = NormalizeDouble(bid + sl_dist, digits);
      req.tp    = NormalizeDouble(bid - sl_dist * strategy_tp_rr_mult, digits);
     }

   req.reason            = "FF_EMA_RSI_M15";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management — card specifies no trailing stop, break-even, or partial
// close logic; exits exclusively via TP/SL, time stop, and EMA cross.
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Exit Signal — runs once per closed bar from the OnTick new-bar gate.
//   1. Time stop: close after strategy_time_stop_bars × 15 minutes.
//   2. Opposite EMA(5/12) cross on the last closed bar.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: card rule = 24 M15 bars = 6 hours
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(TimeCurrent() - open_time) >= (long)(strategy_time_stop_bars * 15 * 60))
         return true;

      // Opposite EMA cross exit
      const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                        strategy_ema_fast, strategy_ema_slow, 1);
      if(cross != 0)
        {
         const ENUM_POSITION_TYPE ptype =
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY  && cross == -1)
            return true;
         if(ptype == POSITION_TYPE_SELL && cross == +1)
            return true;
        }

      return false;   // our position found, no exit condition triggered
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook — defers to the framework two-axis QM_NewsAllowsTrade2 check.
// -----------------------------------------------------------------------------
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

   QM_LogEvent(QM_INFO, "INIT_OK",
      "{\"card\":\"QM5_9701\",\"ea\":\"ff-ema-rsi-m15\",\"source\":\"ForexFactory_316055\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
