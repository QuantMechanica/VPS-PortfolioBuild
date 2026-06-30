#property strict
#property version   "5.0"
#property description "QM5_12817 XNG Volatility Shock Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12817 - XNG Volatility-Shock Fade
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - identify unusually large multi-day XNGUSD.DWX log-return shocks
//   - require the close to be stretched away from a D1 SMA by ATR
//   - fade the shock back toward the SMA, with ATR hard stop and time exit
// Runtime uses MT5 OHLC/broker calendar only; no EIA/weather/storage/API feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12817;
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
input int    strategy_shock_lookback_d1    = 3;
input double strategy_min_abs_return_pct   = 12.0;
input int    strategy_sma_period           = 20;
input int    strategy_atr_period           = 20;
input double strategy_min_stretch_atr      = 1.40;
input double strategy_max_stretch_atr      = 5.00;
input double strategy_atr_sl_mult          = 3.25;
input double strategy_atr_tp_mult          = 2.00;
input int    strategy_max_hold_days        = 8;
input int    strategy_max_spread_points    = 1500;

datetime g_last_entry_signal_time = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
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

bool Strategy_LoadShockState(double &shock_pct,
                             double &close_last,
                             double &sma_last,
                             double &atr_last,
                             double &stretch_atr,
                             datetime &signal_time)
  {
   shock_pct = 0.0;
   close_last = 0.0;
   sma_last = 0.0;
   atr_last = 0.0;
   stretch_atr = 0.0;
   signal_time = 0;

   const int lookback = MathMax(1, strategy_shock_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes) != lookback + 1) // perf-allowed: D1 shock state is evaluated only behind QM_IsNewBar.
      return false;

   close_last = closes[0];
   const double close_then = closes[lookback];
   if(close_last <= 0.0 || close_then <= 0.0)
      return false;

   shock_pct = 100.0 * MathLog(close_last / close_then);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: cached closed-bar timestamp for duplicate-entry guard.
   if(sma_last <= 0.0 || atr_last <= 0.0 || signal_time <= 0)
      return false;

   stretch_atr = (close_last - sma_last) / atr_last;
   return (
      MathIsValidNumber(shock_pct) &&
      MathIsValidNumber(stretch_atr) &&
      MathIsValidNumber(sma_last) &&
      MathIsValidNumber(atr_last)
   );
  }

int Strategy_SignalDirection()
  {
   double shock_pct = 0.0;
   double close_last = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double stretch_atr = 0.0;
   datetime signal_time = 0;
   if(!Strategy_LoadShockState(shock_pct, close_last, sma_last, atr_last, stretch_atr, signal_time))
      return 0;

   if(signal_time == g_last_entry_signal_time)
      return 0;

   const double abs_stretch = MathAbs(stretch_atr);
   if(abs_stretch < strategy_min_stretch_atr)
      return 0;
   if(strategy_max_stretch_atr > 0.0 && abs_stretch > strategy_max_stretch_atr)
      return 0;

   if(shock_pct <= -strategy_min_abs_return_pct && stretch_atr <= -strategy_min_stretch_atr)
      return 1;
   if(shock_pct >= strategy_min_abs_return_pct && stretch_atr >= strategy_min_stretch_atr)
      return -1;
   return 0;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double shock_pct = 0.0;
   double close_last = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double stretch_atr = 0.0;
   datetime signal_time = 0;
   const bool have_state = Strategy_LoadShockState(shock_pct, close_last, sma_last, atr_last, stretch_atr, signal_time);

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_BUY && close_last >= sma_last)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_SELL && close_last <= sma_last)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_shock_lookback_d1 < 1 || strategy_shock_lookback_d1 > 10)
      return true;
   if(strategy_min_abs_return_pct <= 0.0)
      return true;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_min_stretch_atr <= 0.0)
      return true;
   if(strategy_max_stretch_atr > 0.0 && strategy_max_stretch_atr <= strategy_min_stretch_atr)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult < 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12817_XNG_VOLSHOCK_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double shock_pct = 0.0;
   double close_last = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double stretch_atr = 0.0;
   datetime signal_time = 0;
   if(!Strategy_LoadShockState(shock_pct, close_last, sma_last, atr_last, stretch_atr, signal_time))
      return false;

   const int direction = Strategy_SignalDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(strategy_atr_tp_mult > 0.0)
      req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0)
      return false;
   if(strategy_atr_tp_mult > 0.0 && req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XNG_VOLSHOCK_DOWNSIDE_FADE_LONG"
                                : "XNG_VOLSHOCK_UPSIDE_FADE_SHORT";
   g_last_entry_signal_time = signal_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12817\",\"ea\":\"xng-volshock-fade\"}");
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
