#property strict
#property version   "5.0"
#property description "QM5_9718 Bandy Cumulative RSI(2) Index Mean Reversion D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9718
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9718_bandy-cumulative-rsi2-mr-index.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9718;
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
input int    strategy_rsi_period        = 2;
input double strategy_crsi_entry_thresh = 15.0;
input double strategy_rsi_exit_thresh   = 65.0;
input int    strategy_sma_period        = 200;
input int    strategy_time_stop_days    = 6;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 2.5;
input double strategy_spread_max_atr    = 0.25;
input int    strategy_warmup_bars       = 200;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > (strategy_spread_max_atr * atr))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double close1   = iClose(_Symbol, PERIOD_D1, 1);
   const double sma200   = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double rsi_now  = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 2, PRICE_CLOSE);

   if(close1 <= 0.0 || sma200 <= 0.0 || rsi_now < 0.0 || rsi_prev < 0.0)
      return false;

   // SMA(200) long trend regime gate
   if(close1 <= sma200)
      return false;

   // Cumulative RSI(2) = RSI(2)[1] + RSI(2)[2] <= 15.0
   const double crsi2 = rsi_now + rsi_prev;
   if(crsi2 > strategy_crsi_entry_thresh)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = "BANDY_CRSI2_BUY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(bars_held >= strategy_time_stop_days)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
      }
   }
}

bool Strategy_ExitSignal()
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi_now >= strategy_rsi_exit_thresh)
      return true;

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
   QM_FrameworkTrackOpenPositionMae();

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
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_SIGNAL);
      }
   }

   if(!QM_IsNewBar())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong ticket = 0;
      QM_TM_OpenPosition(req, ticket);
   }
}
