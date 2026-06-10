#property strict
#property version   "5.0"
#property description "QM5_9360 Ichimoku Kumo Cross with ADX"
// Strategy Card: QM5_9360 (mql5-ichi-kumo-cross)
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 73, Pattern 2 — Senkou Span A/B Crossover with ADX.
// G0 APPROVED 2026-05-19.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9360;
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
// Ichimoku periods (standard 9/26/52)
input int    strategy_tenkan_period     = 9;    // Tenkan-sen (Conversion Line) period
input int    strategy_kijun_period      = 26;   // Kijun-sen (Base Line) period
input int    strategy_senkou_period     = 52;   // Senkou Span B period (Chikou displacement)
// ADX filter
input int    strategy_adx_period        = 14;   // ADX-Wilder period
input double strategy_adx_min           = 25.0; // Minimum ADX to allow entry (trend strength)
// ATR filter for cloud thickness
input int    strategy_atr_period        = 14;   // ATR period for cloud thickness filter
input double strategy_cloud_min_atr_mult = 0.5; // Skip if cloud thickness < mult * ATR
// Stop loss
input double strategy_sl_atr_mult       = 1.0;  // SL placed mult*ATR beyond cloud edge
// Time stop: exit after N M30 bars if no other exit fires
input int    strategy_max_hold_bars     = 96;   // 96 M30 bars = 48 hours

// -----------------------------------------------------------------------------
// Module-level state
// -----------------------------------------------------------------------------

// Bar counter for time stop (per open position)
datetime g_entry_bar_time = 0;

// Helper: get our open position for this magic+symbol
bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &open_price, ulong &ticket)
  {
   ptype      = POSITION_TYPE_BUY;
   open_price = 0.0;
   ticket     = 0;

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
      ptype      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket     = t;
      return true;
     }
   return false;
  }

// Count closed bars since entry bar time
int BarsSinceEntry()
  {
   if(g_entry_bar_time <= 0)
      return 0;
   const int idx = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
   return (idx < 0) ? 0 : idx;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No session or custom filters beyond framework defaults.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One-position-per-symbol gate: skip if already have an open position.
   ENUM_POSITION_TYPE ptype;
   double open_price;
   ulong  ticket;
   if(GetOurPosition(ptype, open_price, ticket))
      return false;

   // Read Ichimoku Senkou Span A and B for bars [0] and [1] (closed).
   // The spans are shifted 26 bars forward in chart display, so buffer[shift]
   // where shift=1 gives the most recently closed bar's span values.
   const double spanA_prev = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 2);
   const double spanA_curr = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 1);
   const double spanB_prev = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 2);
   const double spanB_curr = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 1);

   if(spanA_prev <= 0.0 || spanA_curr <= 0.0 || spanB_prev <= 0.0 || spanB_curr <= 0.0)
      return false;

   // ADX confirmation
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx < strategy_adx_min)
      return false;

   // ATR for cloud thickness filter and SL placement
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Cloud thickness filter: skip if cloud is too thin relative to ATR
   const double cloud_thickness = MathAbs(spanA_curr - spanB_curr);
   if(cloud_thickness < strategy_cloud_min_atr_mult * atr)
      return false;

   // Determine cloud top/bottom for SL reference
   const double cloud_top    = MathMax(spanA_curr, spanB_curr);
   const double cloud_bottom = MathMin(spanA_curr, spanB_curr);

   // BUY signal: Senkou Span A crosses above Span B (bullish kumo twist)
   // SenkouSpanA[1] < SenkouSpanB[1]  AND  SenkouSpanA[0] > SenkouSpanB[0]
   if(spanA_prev < spanB_prev && spanA_curr > spanB_curr)
     {
      const double sl = cloud_bottom - strategy_sl_atr_mult * atr;
      // SL must be below current ask; QM_Entry will compute lots from sl distance
      if(sl >= SymbolInfoDouble(_Symbol, SYMBOL_ASK))
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0; // market order
      req.sl     = NormalizeDouble(sl, _Digits);
      req.tp     = 0.0; // managed by exit signal
      req.reason = "ICHI_KUMO_CROSS_BUY";
      return true;
     }

   // SELL signal: Senkou Span A crosses below Span B (bearish kumo twist)
   // SenkouSpanA[1] > SenkouSpanB[1]  AND  SenkouSpanA[0] < SenkouSpanB[0]
   if(spanA_prev > spanB_prev && spanA_curr < spanB_curr)
     {
      const double sl = cloud_top + strategy_sl_atr_mult * atr;
      // SL must be above current bid; QM_Entry will compute lots from sl distance
      if(sl <= SymbolInfoDouble(_Symbol, SYMBOL_BID))
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0; // market order
      req.sl     = NormalizeDouble(sl, _Digits);
      req.tp     = 0.0; // managed by exit signal
      req.reason = "ICHI_KUMO_CROSS_SELL";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §7: no trailing/BE modifications — hold until opposite signal or time stop.
   // Time stop tracking is handled in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   double open_price;
   ulong  ticket;
   if(!GetOurPosition(ptype, open_price, ticket))
      return false;

   // Time stop: exit after strategy_max_hold_bars closed bars
   if(BarsSinceEntry() >= strategy_max_hold_bars)
      return true;

   // Opposite kumo twist: read current span values for exit
   const double spanA_prev = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 2);
   const double spanA_curr = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 1);
   const double spanB_prev = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 2);
   const double spanB_curr = QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                                     strategy_tenkan_period,
                                                     strategy_kijun_period,
                                                     strategy_senkou_period, 1);

   if(spanA_prev <= 0.0 || spanA_curr <= 0.0 || spanB_prev <= 0.0 || spanB_curr <= 0.0)
      return false;

   // Exit long on bearish kumo twist
   if(ptype == POSITION_TYPE_BUY && spanA_prev > spanB_prev && spanA_curr < spanB_curr)
      return true;

   // Exit short on bullish kumo twist
   if(ptype == POSITION_TYPE_SELL && spanA_prev < spanB_prev && spanA_curr > spanB_curr)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade
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

   g_entry_bar_time = 0;
   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_9360\",\"ea\":\"mql5-ichi-kumo-cross\","
                            "\"tenkan\":%d,\"kijun\":%d,\"senkou\":%d,\"adx_min\":%.1f}",
                            strategy_tenkan_period, strategy_kijun_period,
                            strategy_senkou_period, strategy_adx_min));
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

   // Per-tick: trade management (no-op for this strategy).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (time stop + opposite signal).
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
         g_entry_bar_time = 0;
        }
     }

   // Per-closed-bar only from here.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_entry_bar_time = iTime(_Symbol, _Period, 0);
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
