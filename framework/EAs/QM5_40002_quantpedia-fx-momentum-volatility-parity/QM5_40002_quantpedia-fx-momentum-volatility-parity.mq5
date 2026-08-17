#property strict
#property version   "5.0"
#property description "QM5_40002 FX momentum with volatility-parity sizing"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_40002
// Quantpedia FX Momentum & Volatility Risk Parity
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 40002;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1 = 63;
input int    strategy_volatility_lookback_d1 = 21;
input int    strategy_ema_period            = 50;
input int    strategy_atr_period            = 14;
input double strategy_stop_atr_mult         = 2.0;
input double strategy_reward_risk           = 2.0;
input double strategy_spread_atr_mult       = 1.8;

double g_strategy_cached_atr = 0.0;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool Strategy_IsRolloverBlackout()
  {
   MqlDateTime utc_parts;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc_parts))
      return true;

   return ((utc_parts.hour == 23 && utc_parts.min >= 55) ||
           (utc_parts.hour == 0 && utc_parts.min <= 5));
  }

bool Strategy_SpreadTooWide(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) > strategy_spread_atr_mult * atr_value);
  }

bool Strategy_RealizedVolatility(const int lookback, double &annualized_volatility)
  {
   annualized_volatility = 0.0;
   if(lookback < 2)
      return false;

   double mean = 0.0;
   double sum_squared_deviations = 0.0;
   int observations = 0;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      MqlRates newer_bar;
      MqlRates older_bar;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, shift, newer_bar) ||
         !QM_ReadBar(_Symbol, PERIOD_D1, shift + 1, older_bar))
         return false;
      if(newer_bar.close <= 0.0 || older_bar.close <= 0.0)
         return false;

      const double log_return = MathLog(newer_bar.close / older_bar.close);
      if(!MathIsValidNumber(log_return))
         return false;

      observations++;
      const double delta = log_return - mean;
      mean += delta / observations;
      sum_squared_deviations += delta * (log_return - mean);
     }

   if(observations < 2 || sum_squared_deviations <= 0.0)
      return false;

   annualized_volatility = MathSqrt(sum_squared_deviations / (observations - 1)) * MathSqrt(252.0);
   return (MathIsValidNumber(annualized_volatility) && annualized_volatility > 0.0);
  }

bool Strategy_SelectOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return (open_time > 0);
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Entry suppression only. If this instance already has exposure, return false
// so the framework can continue management and monthly-close processing.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_EntryHasOpenPosition((long)magic, _Symbol))
      return false;

   if(Strategy_IsRolloverBlackout())
      return true;

   return Strategy_SpreadTooWide(g_strategy_cached_atr);
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

   if(strategy_momentum_lookback_d1 < 2 ||
      strategy_volatility_lookback_d1 < 2 ||
      strategy_ema_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_stop_atr_mult <= 0.0 ||
      strategy_reward_risk <= 0.0 ||
      strategy_spread_atr_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_EntryHasOpenPosition((long)magic, _Symbol))
      return false;
   if(Strategy_IsRolloverBlackout())
      return false;

   MqlRates signal_bar;
   MqlRates momentum_anchor_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1 + strategy_momentum_lookback_d1, momentum_anchor_bar))
      return false;
   if(signal_bar.close <= 0.0 || momentum_anchor_bar.close <= 0.0)
      return false;

   const double momentum_return =
      (signal_bar.close - momentum_anchor_bar.close) / momentum_anchor_bar.close;
   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   double realized_volatility = 0.0;
   if(!MathIsValidNumber(momentum_return) || ema <= 0.0 || atr <= 0.0 ||
      !Strategy_RealizedVolatility(strategy_volatility_lookback_d1, realized_volatility))
      return false;

   g_strategy_cached_atr = atr;
   if(Strategy_SpreadTooWide(atr))
      return false;

   const bool long_signal = (momentum_return > 0.0 && signal_bar.close > ema);
   const bool short_signal = (momentum_return < 0.0 && signal_bar.close < ema);
   if(!long_signal && !short_signal)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_atr_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_reward_risk);

   // The inverse-volatility value is encoded in the order reason for audit.
   // V5 derives lots from fixed dollar risk and the ATR stop distance; monthly
   // close/re-entry below refreshes that volatility-normalized exposure.
   const double inverse_volatility = 1.0 / realized_volatility;
   req.reason = StringFormat(long_signal ? "FXMOM_L_IV%.2f" : "FXMOM_S_IV%.2f",
                             inverse_volatility);

   if(req.sl <= 0.0 || req.tp <= 0.0 || !MathIsValidNumber(inverse_volatility))
      return false;
   return (MathAbs(entry - req.sl) / point > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // The approved card defines broker-side 2*ATR SL and 2R TP only. It gives
   // no deterministic break-even or trailing thresholds, so none are invented.
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(open_time))
      return false;

   MqlDateTime opened_utc;
   MqlDateTime current_utc;
   if(!TimeToStruct(QM_BrokerToUTC(open_time), opened_utc) ||
      !TimeToStruct(QM_BrokerToUTC(TimeCurrent()), current_utc))
      return false;

   const int opened_month = opened_utc.year * 100 + opened_utc.mon;
   const int current_month = current_utc.year * 100 + current_utc.mon;
   return (current_month > opened_month);
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

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
