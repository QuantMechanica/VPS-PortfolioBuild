#property strict
#property version   "5.0"
#property description "QM5_10650 TradingView Wyckoff Range SMA Cross (tv-wyckoff-ma)"
// Strategy Card: QM5_10650 (tv-wyckoff-ma), G0 APPROVED 2026-05-22.
// Source: TradingView "Wyckoff Range Strategy" by deperp
//   (https://www.tradingview.com/script/vQSBf9rh-Wyckoff-Range-Strategy/).

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10650 tv-wyckoff-ma
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   Baselines: SMA(close, crossOverLength), SMA(low, 20), SMA(high, 20).
//   Long  entry: close crosses above SMA(close,L) AND low above SMA(low,20).
//   Short entry: close crosses below SMA(close,L) AND high below SMA(high,20).
//   Exit long : close below SMA(close,L) OR high below SMA(high,20).
//   Exit short: close above SMA(close,L) OR low  above SMA(low,20).
//   Stop: percentage of entry close (stopPercentage).
// .DWX invariant #4: the close/SMA(close) crossover is the single trigger EVENT;
// the low/high-vs-baseline condition is a confirming STATE (not a 2nd same-bar
// event). Closed-bar reads only (shift 1 = last closed bar, shift 2 = prior).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10650;
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
// Card §Entry: SMA(close) crossover length.
input int    strategy_cross_len         = 20;
// Card §Entry/Exit: SMA(low)/SMA(high) range baseline length (fixed 20 in source).
input int    strategy_range_len         = 20;
// Card §Stop Loss: percentage stop from entry close. Baseline 1.5% indices/gold,
// 0.75% FX (set per symbol in the setfile; swept in P3).
input double strategy_stop_percent      = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No session/regime/spread gate beyond framework news + Friday-close.
   // (.DWX invariant #1: never block on zero spread.)
   return false;
  }

// Long-side close/SMA(close) bullish crossover on the last closed bar.
bool CloseCrossUp()
  {
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_cross_len, 1, PRICE_CLOSE);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_cross_len, 2, PRICE_CLOSE);
   const double c1   = iClose(_Symbol, _Period, 1);
   const double c2   = iClose(_Symbol, _Period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0 || c1 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 <= sma2 && c1 > sma1);
  }

// Short-side close/SMA(close) bearish crossover on the last closed bar.
bool CloseCrossDown()
  {
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_cross_len, 1, PRICE_CLOSE);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_cross_len, 2, PRICE_CLOSE);
   const double c1   = iClose(_Symbol, _Period, 1);
   const double c2   = iClose(_Symbol, _Period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0 || c1 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 >= sma2 && c1 < sma1);
  }

// Range-state confirmations on the last closed bar.
bool LowAboveBaseline()
  {
   const double sma_low = QM_SMA(_Symbol, _Period, strategy_range_len, 1, PRICE_LOW);
   const double l1      = iLow(_Symbol, _Period, 1);
   if(sma_low <= 0.0 || l1 <= 0.0)
      return false;
   return (l1 > sma_low);
  }

bool HighBelowBaseline()
  {
   const double sma_high = QM_SMA(_Symbol, _Period, strategy_range_len, 1, PRICE_HIGH);
   const double h1       = iHigh(_Symbol, _Period, 1);
   if(sma_high <= 0.0 || h1 <= 0.0)
      return false;
   return (h1 < sma_high);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_cross_len < 2 || strategy_range_len < 2 || strategy_stop_percent <= 0.0)
      return false;

   const double c1 = iClose(_Symbol, _Period, 1);
   if(c1 <= 0.0)
      return false;
   const double stop_dist = c1 * (strategy_stop_percent / 100.0);
   if(stop_dist <= 0.0)
      return false;

   // Long: close crosses above SMA(close,L) AND low above SMA(low,20).
   if(CloseCrossUp() && LowAboveBaseline())
     {
      req.type   = QM_BUY;
      req.price  = 0.0; // framework fills market price at send.
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, c1 - stop_dist);
      req.tp     = 0.0;
      req.reason = "WYCKOFF_LONG";
      return true;
     }

   // Short: close crosses below SMA(close,L) AND high below SMA(high,20).
   if(CloseCrossDown() && HighBelowBaseline())
     {
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, c1 + stop_dist);
      req.tp     = 0.0;
      req.reason = "WYCKOFF_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §Position Sizing/Exit: no trailing/partial/BE; exits via SL + ExitSignal.
  }

// Card §Exit: close long when close<SMA(close,L) OR high<SMA(high,20);
//             close short when close>SMA(close,L) OR low >SMA(low,20).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_long = false;
   bool have_short = false;
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
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY)
         have_long = true;
      else if(pt == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(!have_long && !have_short)
      return false;

   const double sma_c  = QM_SMA(_Symbol, _Period, strategy_cross_len, 1, PRICE_CLOSE);
   const double sma_h  = QM_SMA(_Symbol, _Period, strategy_range_len, 1, PRICE_HIGH);
   const double sma_l  = QM_SMA(_Symbol, _Period, strategy_range_len, 1, PRICE_LOW);
   const double c1     = iClose(_Symbol, _Period, 1);
   const double h1     = iHigh(_Symbol, _Period, 1);
   const double l1     = iLow(_Symbol, _Period, 1);
   if(sma_c <= 0.0 || sma_h <= 0.0 || sma_l <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return false;

   if(have_long && (c1 < sma_c || h1 < sma_h))
      return true;
   if(have_short && (c1 > sma_c || l1 > sma_l))
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10650_tv_wyckoff_ma\"}");
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
