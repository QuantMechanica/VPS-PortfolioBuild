#property strict
#property version   "5.0"
#property description "QM5_2003 The Wave Sniper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2003: The Wave Sniper
// -----------------------------------------------------------------------------
// Baseline: price above McGinley Dynamic proxy
// Confirmation: WAE green bar above deadzone
// Volume: ADX > 25
// Exit: WAE bar decrease
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2003;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_mcginley_period      = 14;
input int    strategy_wae_fast             = 20;
input int    strategy_wae_slow             = 40;
input int    strategy_wae_signal           = 9;
input int    strategy_adx_period           = 14;
input double strategy_adx_min              = 25.0;
input int    strategy_atr_period           = 14;
input double strategy_wae_deadzone_atr_mult = 0.10;
input double strategy_atr_sl_mult          = 1.5;
input double strategy_rr                   = 1.5;
input int    strategy_spread_cap_points    = 25;

double Strategy_McGinleyValue(const int shift)
  {
   return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_mcginley_period, shift);
  }

double Strategy_WaeHistogram(const int shift)
  {
   const double main = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    strategy_wae_fast,
                                    strategy_wae_slow,
                                    strategy_wae_signal,
                                    shift);
   const double signal = QM_MACD_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                        strategy_wae_fast,
                                        strategy_wae_slow,
                                        strategy_wae_signal,
                                        shift);
   return main - signal;
  }

double Strategy_WaeDeadzone(const int shift)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
   if(atr <= 0.0 || strategy_wae_deadzone_atr_mult <= 0.0)
      return 0.0;
   return atr * strategy_wae_deadzone_atr_mult;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(Strategy_HasOpenPosition())
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double baseline_1 = Strategy_McGinleyValue(1);
   const double wae_1 = Strategy_WaeHistogram(1);
   const double deadzone_1 = Strategy_WaeDeadzone(1);
   const double adx_1 = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);

   if(close_1 <= 0.0 || baseline_1 <= 0.0 || deadzone_1 <= 0.0)
      return false;
   if(adx_1 < strategy_adx_min)
      return false;
   if(close_1 <= baseline_1)
      return false;
   if(wae_1 <= deadzone_1)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = QM_EntryMarketPrice(req.type);
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr);
   req.reason = "NNFX_WAVE_SNIPER_LONG";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || MathAbs(entry - req.sl) <= point)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype != POSITION_TYPE_BUY)
         continue;

      const double wae_1 = Strategy_WaeHistogram(1);
      const double wae_2 = Strategy_WaeHistogram(2);
      if(wae_1 <= 0.0)
         return true;
      if(wae_2 > 0.0 && wae_1 < wae_2)
         return true;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(qm_ea_id != 2003)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
