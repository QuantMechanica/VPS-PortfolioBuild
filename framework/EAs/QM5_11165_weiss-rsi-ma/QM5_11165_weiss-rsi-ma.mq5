#property strict
#property version   "5.0"
#property description "QM5_11165 Weissman RSI Moving Average Filter Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy implementation is limited to inputs and the five Strategy_* hooks.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11165;
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
input ENUM_TIMEFRAMES strategy_timeframe      = PERIOD_H1;
input int             strategy_rsi_period     = 9;
input int             strategy_sma_period     = 200;
input double          strategy_long_rsi       = 25.0;
input double          strategy_short_rsi      = 75.0;
input double          strategy_exit_rsi       = 50.0;
input double          strategy_stop_pct       = 1.0;
input int             strategy_max_hold_bars  = 60;
input int             strategy_max_spread_pts = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): framework handles news, kill-switch,
// Friday close, and broker guards. This hook enforces card timeframe and an
// optional spread cap when supplied by a setfile sweep.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;

   if(strategy_max_spread_pts > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_pts)
         return true;
     }

   return false;
  }

// Trade Entry: completed-bar RSI(9) extreme in the direction of SMA(200).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_period < 1 ||
      strategy_sma_period < 1 ||
      strategy_stop_pct <= 0.0 ||
      strategy_long_rsi >= strategy_short_rsi)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double rsi_1 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 2);
   const double sma_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1);
   const double close_1 = QM_SMA(_Symbol, strategy_timeframe, 1, 1);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0 || sma_1 <= 0.0 || close_1 <= 0.0)
      return false;

   const bool long_signal = (close_1 > sma_1 &&
                             rsi_2 >= strategy_long_rsi &&
                             rsi_1 < strategy_long_rsi);
   const bool short_signal = (close_1 < sma_1 &&
                              rsi_2 <= strategy_short_rsi &&
                              rsi_1 > strategy_short_rsi);
   if(long_signal == short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = QM_EntryMarketPrice(req.type);
   if(req.price <= 0.0)
      return false;

   const double stop_mult = strategy_stop_pct / 100.0;
   const double raw_sl = long_signal ? req.price * (1.0 - stop_mult)
                                     : req.price * (1.0 + stop_mult);
   req.sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
   if(req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(req.price - req.sl) / point;
   const int min_stop_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)min_stop_points)
      return false;

   req.tp = 0.0;
   req.reason = long_signal ? "WEISS_RSI_MA_LONG" : "WEISS_RSI_MA_SHORT";
   return true;
  }

// Trade Management: card specifies no trailing, break-even, partial close, or
// pyramiding beyond the initial fixed stop.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: RSI midpoint cross, or elapsed 60 H1 bars when no RSI exit or
// stop has fired.
bool Strategy_ExitSignal()
  {
   if(strategy_rsi_period < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 2);
   const int hold_seconds_per_bar = PeriodSeconds(strategy_timeframe);
   const long max_hold_seconds = (strategy_max_hold_bars > 0 && hold_seconds_per_bar > 0)
                                 ? (long)strategy_max_hold_bars * (long)hold_seconds_per_bar
                                 : 0;
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(rsi_1 > 0.0 && rsi_2 > 0.0)
        {
         if(ptype == POSITION_TYPE_BUY &&
            rsi_2 <= strategy_exit_rsi &&
            rsi_1 > strategy_exit_rsi)
            return true;
         if(ptype == POSITION_TYPE_SELL &&
            rsi_2 >= strategy_exit_rsi &&
            rsi_1 < strategy_exit_rsi)
            return true;
        }

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && open_time > 0 && now - open_time >= max_hold_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook: callable for P8 News Impact phase; defer to the central
// two-axis framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11165_weiss-rsi-ma\"}");
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
