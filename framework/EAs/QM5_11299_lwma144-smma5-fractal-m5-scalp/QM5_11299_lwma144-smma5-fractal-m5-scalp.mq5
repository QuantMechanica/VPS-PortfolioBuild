#property strict
#property version   "5.0"
#property description "QM5_11299 LWMA(144) + SMMA(5) Cross + Fractal SL Scalp (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11299
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11299;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M5;
input int             strategy_lwma_period        = 144;
input int             strategy_smma_period        = 5;
input double          strategy_max_proximity_pips = 10.0;
input int             strategy_atr_period         = 14;
input double          strategy_sl_atr_mult        = 1.0;
input double          strategy_tp_atr_mult        = 2.0;
input bool            strategy_use_fractal_sl     = true;
input int             strategy_fractal_lookback   = 20;
input bool            strategy_session_filter     = true;
input int             strategy_session_start_hour = 8;
input int             strategy_session_end_hour   = 22;
input int             strategy_max_spread_pips    = 3;

// -----------------------------------------------------------------------------
// Strategy helper functions
// -----------------------------------------------------------------------------

double Strategy_PipSize(const string symbol)
{
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
}

bool Strategy_HasOpenPosition()
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
      return true;
   }
   return false;
}

bool Strategy_SessionAllowsEntry()
{
   if(!strategy_session_filter)
      return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(strategy_session_start_hour <= strategy_session_end_hour)
      return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
   return (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
}

bool Strategy_SpreadAllowsEntry()
{
   if(strategy_max_spread_pips <= 0)
      return true;
   const double pip = Strategy_PipSize(_Symbol);
   if(pip <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_pips = (ask - bid) / pip;
   return (spread_pips <= (double)strategy_max_spread_pips);
}

double Strategy_FindLowerFractal(const int lookback)
{
   for(int i = 2; i <= lookback + 2; ++i)
   {
      const double frac = QM_FractalLower(_Symbol, strategy_timeframe, i);
      if(frac > 0.0 && frac < 2147483647.0)
         return frac;
   }
   return 0.0;
}

double Strategy_FindUpperFractal(const int lookback)
{
   for(int i = 2; i <= lookback + 2; ++i)
   {
      const double frac = QM_FractalUpper(_Symbol, strategy_timeframe, i);
      if(frac > 0.0 && frac < 2147483647.0)
         return frac;
   }
   return 0.0;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SessionAllowsEntry() || !Strategy_SpreadAllowsEntry())
      return false;

   const double smma_1 = QM_SMMA(_Symbol, strategy_timeframe, strategy_smma_period, 1);
   const double smma_2 = QM_SMMA(_Symbol, strategy_timeframe, strategy_smma_period, 2);
   const double lwma_1 = QM_LWMA(_Symbol, strategy_timeframe, strategy_lwma_period, 1);
   const double lwma_2 = QM_LWMA(_Symbol, strategy_timeframe, strategy_lwma_period, 2);

   if(smma_1 <= 0.0 || smma_2 <= 0.0 || lwma_1 <= 0.0 || lwma_2 <= 0.0)
      return false;

   const double pip = Strategy_PipSize(_Symbol);
   if(pip <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_timeframe, 1, 1, rates) != 1)
      return false;

   const double close_1 = rates[0].close;
   const double dist_to_lwma_pips = MathAbs(close_1 - lwma_1) / pip;
   if(dist_to_lwma_pips > strategy_max_proximity_pips)
      return false;

   const bool long_cross  = (smma_2 <= lwma_2 && smma_1 > lwma_1);
   const bool short_cross = (smma_2 >= lwma_2 && smma_1 < lwma_1);

   if(!long_cross && !short_cross)
      return false;

   const QM_OrderType side = long_cross ? QM_BUY : QM_SELL;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side == QM_BUY) ? ask : bid;

   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      if(strategy_use_fractal_sl)
         sl = Strategy_FindLowerFractal(strategy_fractal_lookback);
      if(sl <= 0.0 || sl >= entry)
         sl = entry - strategy_sl_atr_mult * atr_1;
      const double sl_dist = entry - sl;
      tp = entry + 2.0 * sl_dist;
   }
   else
   {
      if(strategy_use_fractal_sl)
         sl = Strategy_FindUpperFractal(strategy_fractal_lookback);
      if(sl <= 0.0 || sl <= entry)
         sl = entry + strategy_sl_atr_mult * atr_1;
      const double sl_dist = sl - entry;
      tp = entry - 2.0 * sl_dist;
   }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   if((side == QM_BUY && (sl >= entry || tp <= entry)) ||
      (side == QM_SELL && (sl <= entry || tp >= entry)))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "LWMA144_SMMA5_LONG" : "LWMA144_SMMA5_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
