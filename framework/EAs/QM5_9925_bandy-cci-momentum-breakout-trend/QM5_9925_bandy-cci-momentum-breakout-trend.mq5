#property strict
#property version   "5.0"
#property description "QM5_9925 Bandy CCI Momentum Breakout Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9925
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9925_bandy-cci-momentum-breakout-trend/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9925;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period          = 20;
input double strategy_cci_entry_threshold = 100.0;
input double strategy_cci_exit_threshold  = 0.0;
input int    strategy_regime_sma_period   = 200;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_time_stop_bars      = 45;
input double strategy_doji_threshold      = 0.1;
input int    strategy_warmup_bars         = 250;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   return (strategy_cci_period < 1 ||
           strategy_cci_entry_threshold <= 0.0 ||
           strategy_regime_sma_period < 2 ||
           strategy_atr_period < 1 ||
           strategy_atr_stop_mult <= 0.0 ||
           strategy_time_stop_bars < 1 ||
           strategy_doji_threshold < 0.0);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double cci1 = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 1, PRICE_TYPICAL);
   const double cci2 = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 2, PRICE_TYPICAL);
   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double open1  = iOpen(_Symbol, PERIOD_D1, 1);
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);

   if(regime_sma <= 0.0 || close1 <= 0.0 || high1 <= low1)
      return false;

   // Doji filter: reject entry if cross bar is a doji: |close - open| < strategy_doji_threshold * (high - low)
   const double bar_range = high1 - low1;
   const double body_range = MathAbs(close1 - open1);
   if(body_range < strategy_doji_threshold * bar_range)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Long: cci crosses above +100 (cci2 <= 100, cci1 > 100) AND close > regime
   if(cci2 <= strategy_cci_entry_threshold && cci1 > strategy_cci_entry_threshold && close1 > regime_sma)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      const double stop_price = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_value, strategy_atr_stop_mult);
      if(stop_price <= 0.0 || stop_price >= ask) return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = stop_price;
      req.tp     = 0.0;
      req.reason = StringFormat("BANDY_CCI_BREAKOUT_BUY cci=%.2f", cci1);
      return true;
   }

   // Short: cci crosses below -100 (cci2 >= -100, cci1 < -100) AND close < regime
   if(cci2 >= -strategy_cci_entry_threshold && cci1 < -strategy_cci_entry_threshold && close1 < regime_sma)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      const double stop_price = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_atr_stop_mult);
      if(stop_price <= 0.0 || stop_price <= bid) return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = stop_price;
      req.tp     = 0.0;
      req.reason = StringFormat("BANDY_CCI_BREAKOUT_SELL cci=%.2f", cci1);
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   // Fixed catastrophic stop set at entry; no trailing or BE modification per card.
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   const double cci1 = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 1, PRICE_TYPICAL);
   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic, _Symbol, PERIOD_D1, TimeCurrent());
   const bool time_stop_hit = (held_bars >= strategy_time_stop_bars);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(time_stop_hit)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && cci1 < strategy_cci_exit_threshold)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
      else if(pos_type == POSITION_TYPE_SELL && cci1 > strategy_cci_exit_threshold)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();
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
