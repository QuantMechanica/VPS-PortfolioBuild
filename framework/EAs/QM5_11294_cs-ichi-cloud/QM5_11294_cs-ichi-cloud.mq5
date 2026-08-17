#property strict
#property version   "5.0"
#property description "QM5_11294 CryptoSignal Ichimoku Cloud State"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11294_cs-ichi-cloud
// Card: CryptoSignal Ichimoku Cloud State, G0 APPROVED.
// Source lineage: CryptoSignal/Crypto-Signal Ichimoku analyzer.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11294;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;
input double qm_stress_reject_probability = 0.0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_tenkan_period       = 9;
input int    strategy_kijun_period        = 26;
input int    strategy_senkou_b_period     = 52;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 3.0;

enum QM11294CloudState
  {
   QM11294_CLOUD_BEAR = -1,
   QM11294_CLOUD_FLAT = 0,
   QM11294_CLOUD_BULL = 1
  };

int  g_cloud_state = QM11294_CLOUD_FLAT;
bool g_cloud_ready = false;
bool g_block_entry_this_bar = false;

// -----------------------------------------------------------------------------
// Closed-bar state cache
// -----------------------------------------------------------------------------

bool AdvanceState_OnNewBar()
  {
   g_cloud_ready = false;
   g_cloud_state = QM11294_CLOUD_FLAT;
   g_block_entry_this_bar = false;

   if(strategy_tenkan_period <= 0 ||
      strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0)
      return false;

   const int signal_shift = 1;
   const double close_price = iClose(_Symbol, PERIOD_H4, signal_shift); // perf-allowed: one completed H4 close, read only behind QM_IsNewBar.
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol,
                                                  PERIOD_H4,
                                                  strategy_tenkan_period,
                                                  strategy_kijun_period,
                                                  strategy_senkou_b_period,
                                                  signal_shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol,
                                                  PERIOD_H4,
                                                  strategy_tenkan_period,
                                                  strategy_kijun_period,
                                                  strategy_senkou_b_period,
                                                  signal_shift);
   if(close_price <= 0.0 || span_a <= 0.0 || span_b <= 0.0)
      return false;

   if(span_a > span_b && close_price > span_a)
      g_cloud_state = QM11294_CLOUD_BULL;
   else if(span_a < span_b && close_price < span_a)
      g_cloud_state = QM11294_CLOUD_BEAR;

   g_cloud_ready = true;
   return true;
  }

int OwnPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (position_type == POSITION_TYPE_BUY) ? 1 : -1;
     }

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // The card adds no session, spread, or regime filter.
   return false;
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

   if(!g_cloud_ready || g_block_entry_this_bar || OwnPositionDirection() != 0)
      return false;
   if(g_cloud_state != QM11294_CLOUD_BULL &&
      g_cloud_state != QM11294_CLOUD_BEAR)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const bool is_long = (g_cloud_state == QM11294_CLOUD_BULL);
   const double entry_price = SymbolInfoDouble(_Symbol, is_long ? SYMBOL_ASK : SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = QM_StopATR(_Symbol,
                       req.type,
                       entry_price,
                       strategy_atr_period,
                       strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(is_long && req.sl >= entry_price)
      return false;
   if(!is_long && req.sl <= entry_price)
      return false;

   // The card has no profit target; the cloud reversal is the primary exit.
   req.reason = is_long ? "CS_ICHI_CLOUD_LONG" : "CS_ICHI_CLOUD_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing, break-even, partial close, or pyramiding in the card.
  }

bool Strategy_ExitSignal()
  {
   if(!g_cloud_ready)
      return false;

   const int position_direction = OwnPositionDirection();
   if(position_direction > 0 && g_cloud_state == QM11294_CLOUD_BEAR)
      return true;
   if(position_direction < 0 && g_cloud_state == QM11294_CLOUD_BULL)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Entry suppression is delegated to the framework two-axis news gate.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11294\",\"tf\":\"H4\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();

   // All strategy reads and decisions use one completed H4 bar.
   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   QM_EquityStreamOnNewBar();
   if(!AdvanceState_OnNewBar())
      return;

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool exit_requested = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         exit_requested = true;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }

      // A cloud reversal may enter only after another completed bar.
      if(exit_requested)
         g_block_entry_this_bar = true;
     }

   if(g_block_entry_this_bar || Strategy_NoTradeFilter())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
