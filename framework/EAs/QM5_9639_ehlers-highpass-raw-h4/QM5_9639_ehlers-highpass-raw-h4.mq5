#property strict
#property version   "5.0"
#property description "QM5_9639 Ehlers raw high-pass zero-cross H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9639;
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
input int    strategy_hp_period          = 48;
input int    strategy_ema_period         = 100;
input int    strategy_atr_period         = 14;
input double strategy_max_hp_atr_mult    = 1.20;
input int    strategy_swing_lookback     = 5;
input double strategy_swing_atr_buffer   = 0.20;
input double strategy_reward_risk        = 1.70;
input int    strategy_time_stop_h4_bars  = 14;
input int    strategy_warmup_h4_bars     = 220;

#define QM9639_RECENT_HP 8

const double QM9639_PI = 3.1415926535897932384626433832795;

double        g_qm9639_hp_recent[QM9639_RECENT_HP];
int           g_qm9639_cross_direction = 0;
bool          g_qm9639_hp_ready = false;
QM_ExitReason g_qm9639_exit_reason = QM_EXIT_STRATEGY;

bool QM9639_SelectPosition(ulong &ticket,
                           ENUM_POSITION_TYPE &position_type,
                           datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool QM9639_LoadH4Rates(const int bars_needed, MqlRates &rates[])
  {
   if(bars_needed <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates); // perf-allowed: bounded closed-bar OHLC reads inside the framework QM_IsNewBar-gated entry hook.
   ArraySetAsSeries(rates, true);
   return (copied >= bars_needed);
  }

double QM9639_MedianPrice(MqlRates &rates[], const int index)
  {
   return 0.5 * (rates[index].high + rates[index].low);
  }

bool QM9639_RefreshHighPass()
  {
   g_qm9639_hp_ready = false;
   g_qm9639_cross_direction = 0;

   const int hp_period = MathMax(3, strategy_hp_period);
   const int bars_needed = MathMax(strategy_warmup_h4_bars, hp_period + QM9639_RECENT_HP + 8);

   MqlRates rates[];
   if(!QM9639_LoadH4Rates(bars_needed, rates))
      return false;

   double hp[];
   ArrayResize(hp, bars_needed);
   ArraySetAsSeries(hp, true);
   for(int i = 0; i < bars_needed; ++i)
      hp[i] = 0.0;

   const double angle = 0.707 * 2.0 * QM9639_PI / (double)hp_period;
   const double denom = MathCos(angle);
   if(MathAbs(denom) <= 0.00000001)
      return false;

   const double alpha = (MathCos(angle) + MathSin(angle) - 1.0) / denom;
   const double hp_a = MathPow(1.0 - alpha / 2.0, 2.0);
   const double hp_b = 2.0 * (1.0 - alpha);
   const double hp_c = -MathPow(1.0 - alpha, 2.0);

   for(int i = bars_needed - 3; i >= 0; --i)
     {
      const double price0 = QM9639_MedianPrice(rates, i);
      const double price1 = QM9639_MedianPrice(rates, i + 1);
      const double price2 = QM9639_MedianPrice(rates, i + 2);
      hp[i] = hp_a * (price0 - 2.0 * price1 + price2)
              + hp_b * hp[i + 1]
              + hp_c * hp[i + 2];
     }

   for(int i = 0; i < QM9639_RECENT_HP; ++i)
      g_qm9639_hp_recent[i] = hp[i];

   if(g_qm9639_hp_recent[0] > 0.0 && g_qm9639_hp_recent[1] <= 0.0)
      g_qm9639_cross_direction = 1;
   else if(g_qm9639_hp_recent[0] < 0.0 && g_qm9639_hp_recent[1] >= 0.0)
      g_qm9639_cross_direction = -1;

   g_qm9639_hp_ready = true;
   return true;
  }

bool QM9639_HaveOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   return QM9639_SelectPosition(ticket, position_type, open_time);
  }

double QM9639_SwingLow(MqlRates &rates[], const int lookback)
  {
   double low = DBL_MAX;
   for(int i = 0; i < lookback; ++i)
      low = MathMin(low, rates[i].low);
   return (low < DBL_MAX) ? low : 0.0;
  }

double QM9639_SwingHigh(MqlRates &rates[], const int lookback)
  {
   double high = -DBL_MAX;
   for(int i = 0; i < lookback; ++i)
      high = MathMax(high, rates[i].high);
   return (high > -DBL_MAX) ? high : 0.0;
  }

bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (bid <= 0.0 || ask <= 0.0);
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

   if(_Period != PERIOD_H4)
      return false;
   if(strategy_hp_period < 3 || strategy_ema_period < 2 ||
      strategy_atr_period < 2 || strategy_swing_lookback < 2 ||
      strategy_max_hp_atr_mult <= 0.0 || strategy_swing_atr_buffer < 0.0 ||
      strategy_reward_risk <= 0.0)
      return false;

   if(!QM9639_RefreshHighPass())
      return false;
   if(g_qm9639_cross_direction == 0)
      return false;
   if(QM9639_HaveOpenPosition())
      return false;

   MqlRates rates[];
   const int bars_needed = MathMax(strategy_swing_lookback, 2);
   if(!QM9639_LoadH4Rates(bars_needed, rates))
      return false;

   const double close_1 = rates[0].close;
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(close_1 <= 0.0 || ema <= 0.0 || atr <= 0.0)
      return false;

   if(MathAbs(g_qm9639_hp_recent[0]) > strategy_max_hp_atr_mult * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   if(g_qm9639_cross_direction > 0)
     {
      if(close_1 <= ema)
         return false;

      const double swing_low = QM9639_SwingLow(rates, strategy_swing_lookback);
      if(swing_low <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(swing_low - strategy_swing_atr_buffer * atr, _Digits);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;

      const double risk = ask - req.sl;
      req.tp = NormalizeDouble(ask + strategy_reward_risk * risk, _Digits);
      req.reason = "EHLERS_HP_BULL_ZERO_CROSS_H4";
      return (req.tp > ask);
     }

   if(close_1 >= ema)
      return false;

   const double swing_high = QM9639_SwingHigh(rates, strategy_swing_lookback);
   if(swing_high <= 0.0)
      return false;

   req.type = QM_SELL;
   req.sl = NormalizeDouble(swing_high + strategy_swing_atr_buffer * atr, _Digits);
   if(req.sl <= bid)
      return false;

   const double risk = req.sl - bid;
   req.tp = NormalizeDouble(bid - strategy_reward_risk * risk, _Digits);
   req.reason = "EHLERS_HP_BEAR_ZERO_CROSS_H4";
   return (req.tp > 0.0 && req.tp < bid);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   g_qm9639_exit_reason = QM_EXIT_STRATEGY;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!QM9639_SelectPosition(ticket, position_type, open_time))
      return false;

   if(strategy_time_stop_h4_bars > 0 && open_time > 0)
     {
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(h4_seconds > 0 &&
         (TimeCurrent() - open_time) >= (long)strategy_time_stop_h4_bars * h4_seconds)
        {
         g_qm9639_exit_reason = QM_EXIT_TIME_STOP;
         return true;
        }
     }

   if(!g_qm9639_hp_ready)
      return false;

   if(position_type == POSITION_TYPE_BUY && g_qm9639_cross_direction < 0)
     {
      g_qm9639_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
     }
   if(position_type == POSITION_TYPE_SELL && g_qm9639_cross_direction > 0)
     {
      g_qm9639_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9639\",\"slug\":\"ehlers-highpass-raw-h4\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_qm9639_exit_reason);
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

