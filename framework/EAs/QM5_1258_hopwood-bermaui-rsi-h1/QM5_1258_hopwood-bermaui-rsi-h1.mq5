#property strict
#property version   "5.0"
#property description "QM5_1258 Hopwood Bermaui-RSI H1 Trend-Follower"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1258;
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
input int    strategy_rsi_period        = 14;
input int    strategy_ema_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_rr_target         = 2.0;
input double strategy_midline           = 50.0;
input int    strategy_mid_zone_bars     = 4;
input double strategy_mid_zone_low      = 45.0;
input double strategy_mid_zone_high     = 55.0;
input int    strategy_max_spread_points = 25;

double Strategy_BermauiRSI(const int shift)
  {
   if(strategy_rsi_period < 2 || shift < 1)
      return 50.0;

   double gains = 0.0;
   double losses = 0.0;
   for(int i = 0; i < strategy_rsi_period; ++i)
     {
      const double now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + i, PRICE_CLOSE);
      const double prev = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + i + 1, PRICE_CLOSE);
      const double delta = now - prev;
      if(delta >= 0.0)
         gains += delta;
      else
         losses -= delta;
     }

   if(gains <= 0.0 && losses <= 0.0)
      return 50.0;
   if(losses <= 0.0)
      return 100.0;
   const double rs = gains / losses;
   return 100.0 - (100.0 / (1.0 + rs));
  }

bool Strategy_BermauiCrossUp()
  {
   const double r1 = Strategy_BermauiRSI(1);
   const double r2 = Strategy_BermauiRSI(2);
   return (r1 > strategy_midline && r2 <= strategy_midline);
  }

bool Strategy_BermauiCrossDown()
  {
   const double r1 = Strategy_BermauiRSI(1);
   const double r2 = Strategy_BermauiRSI(2);
   return (r1 < strategy_midline && r2 >= strategy_midline);
  }

bool Strategy_InMidZone(const int shift)
  {
   const double value = Strategy_BermauiRSI(shift);
   return (value >= strategy_mid_zone_low && value <= strategy_mid_zone_high);
  }

int Strategy_MidZoneRunLength()
  {
   int count = 0;
   for(int i = 1; i <= strategy_mid_zone_bars; ++i)
     {
      if(!Strategy_InMidZone(i))
         break;
      count++;
     }
   return count;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   return Strategy_SelectOurPosition(position_type, ticket);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_period < 2 || strategy_ema_period < 1 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 || strategy_mid_zone_bars < 1)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   const int ema_bias = QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_period, 0.0, 1);

   if(Strategy_BermauiCrossUp() && ema_bias > 0)
     {
      side = QM_BUY;
      reason = "BERMAUI_RSI_CROSS_UP_EMA_BIAS";
     }
   else if(Strategy_BermauiCrossDown() && ema_bias < 0)
     {
      side = QM_SELL;
      reason = "BERMAUI_RSI_CROSS_DOWN_EMA_BIAS";
     }
   else
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong position_ticket = 0;
   if(Strategy_SelectOurPosition(position_type, position_ticket))
     {
      const bool opposite = (side == QM_BUY && position_type == POSITION_TYPE_SELL) ||
                            (side == QM_SELL && position_type == POSITION_TYPE_BUY);
      if(opposite)
         QM_TM_ClosePosition(position_ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline: no trailing stop, no break-even, no partial close, no scale-in.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, ticket))
      return false;

   if((position_type == POSITION_TYPE_BUY && Strategy_BermauiCrossDown()) ||
      (position_type == POSITION_TYPE_SELL && Strategy_BermauiCrossUp()))
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   if(Strategy_MidZoneRunLength() >= strategy_mid_zone_bars)
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return false;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1258\",\"strategy\":\"hopwood-bermaui-rsi-h1\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ExitSignal();

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
