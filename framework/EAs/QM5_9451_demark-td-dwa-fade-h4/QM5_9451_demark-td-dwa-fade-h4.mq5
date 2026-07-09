#property strict
#property version   "5.0"
#property description "QM5_9451 DeMark TD-DWA fade H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9451 - DeMark TD-DWA Fade (H4)
// -----------------------------------------------------------------------------
// Range-weighted average:
//   TD-DWA = sum(close[i] * range[i]) / sum(range[i]), i = 1..13 closed bars
//
// BUY:
//   close[2] is at least 1 ATR below TD-DWA[2], then close[1] rejects lower and
//   closes up. SELL is the mirror. The one-trigger latch re-arms only after
//   price returns to the TD-DWA band, preventing repeated entries during a
//   single extended deviation.
//
// Exit:
//   Hard SL = setup-bar extreme +/- 0.8 ATR. Manual exit at mean-band touch
//   or after 12 H4 bars. No swap/news bespoke overrides; central V5 filters
//   remain in force for new entries only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9451;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int             strategy_dwa_period         = 13;
input int             strategy_atr_period         = 14;
input double          strategy_deviation_atr_mult = 1.00;
input double          strategy_reject_tail_min     = 0.30;
input double          strategy_target_band_atr    = 0.10;
input double          strategy_sl_atr_mult        = 0.80;
input int             strategy_max_hold_bars      = 12;
input double          strategy_spread_atr_mult    = 0.20;
input bool            strategy_exclude_sunday_bar = true;
input bool            strategy_enable_longs       = true;
input bool            strategy_enable_shorts      = true;

bool g_long_rearmed = true;
bool g_short_rearmed = true;

bool Strategy_ReadBar(const int shift, double &open, double &high, double &low, double &close)
  {
   // perf-allowed: bespoke closed-bar TD-DWA arithmetic, gated by QM_IsNewBar.
   open = iOpen(_Symbol, strategy_timeframe, shift);   // perf-allowed: bespoke TD-DWA range weight
   high = iHigh(_Symbol, strategy_timeframe, shift);   // perf-allowed: bespoke TD-DWA range weight
   low = iLow(_Symbol, strategy_timeframe, shift);     // perf-allowed: bespoke TD-DWA range weight
   close = iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: bespoke TD-DWA range weight

   return (open > 0.0 && high > 0.0 && low > 0.0 && close > 0.0 && high >= low);
  }

bool Strategy_IsSundayBar(const int shift)
  {
   if(!strategy_exclude_sunday_bar)
      return false;

   // perf-allowed: card specifies excluding Sunday/gap bars from TD-DWA.
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, shift); // perf-allowed: Sunday/gap exclusion
   if(bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.day_of_week == 0);
  }

double Strategy_TDDWA(const int shift)
  {
   const int period = MathMax(2, strategy_dwa_period);
   double weighted_sum = 0.0;
   double range_sum = 0.0;

   for(int i = 0; i < period; ++i)
     {
      const int bar_shift = shift + i;
      if(Strategy_IsSundayBar(bar_shift))
         continue;

      double open, high, low, close;
      if(!Strategy_ReadBar(bar_shift, open, high, low, close))
         continue;

      const double range = high - low;
      if(range <= 0.0)
         continue;

      weighted_sum += close * range;
      range_sum += range;
     }

   if(range_sum <= 0.0)
      return 0.0;
   return weighted_sum / range_sum;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }

   return false;
  }

bool Strategy_GetOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
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
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);

   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   return ((ask - bid) > strategy_spread_atr_mult * atr);
  }

int Strategy_BarsSinceOpen(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   if(shift < 0)
      return 0;
   return shift;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;
   if(Strategy_SpreadTooWide())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(Strategy_HasOpenPosition())
      return false;

   double open1, high1, low1, close1;
   double open2, high2, low2, close2;
   if(!Strategy_ReadBar(1, open1, high1, low1, close1))
      return false;
   if(!Strategy_ReadBar(2, open2, high2, low2, close2))
      return false;

   const double dwa1 = Strategy_TDDWA(1);
   const double dwa2 = Strategy_TDDWA(2);
   const double atr1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr2 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 2);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(dwa1 <= 0.0 || dwa2 <= 0.0 || atr1 <= 0.0 || atr2 <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double band1 = strategy_target_band_atr * atr1;
   if(close1 >= (dwa1 - band1))
      g_long_rearmed = true;
   if(close1 <= (dwa1 + band1))
      g_short_rearmed = true;

   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   const bool prior_below_dwa = (close2 <= (dwa2 - strategy_deviation_atr_mult * atr2));
   const bool prior_above_dwa = (close2 >= (dwa2 + strategy_deviation_atr_mult * atr2));
   const bool bullish_reject = (close1 > close2) && (close1 > open1) && ((close1 - low1) >= strategy_reject_tail_min * range1);
   const bool bearish_reject = (close1 < close2) && (close1 < open1) && ((high1 - close1) >= strategy_reject_tail_min * range1);

   if(strategy_enable_longs && g_long_rearmed && prior_below_dwa && bullish_reject)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low1 - strategy_sl_atr_mult * atr1);
      if(sl <= 0.0 || (ask - sl) < point)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TD_DWA_FADE_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      g_long_rearmed = false;
      return true;
     }

   if(strategy_enable_shorts && g_short_rearmed && prior_above_dwa && bearish_reject)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high1 + strategy_sl_atr_mult * atr1);
      if(sl <= 0.0 || (sl - bid) < point)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TD_DWA_FADE_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      g_short_rearmed = false;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Hard SL is fixed at entry. Manual exits are handled in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_GetOpenPosition(ticket, position_type, open_time))
      return false;

   if(strategy_max_hold_bars > 0 && Strategy_BarsSinceOpen(open_time) >= strategy_max_hold_bars)
      return true;

   double open1, high1, low1, close1;
   if(!Strategy_ReadBar(1, open1, high1, low1, close1))
      return false;

   const double dwa1 = Strategy_TDDWA(1);
   const double atr1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(dwa1 <= 0.0 || atr1 <= 0.0)
      return false;

   const double band = strategy_target_band_atr * atr1;
   if(position_type == POSITION_TYPE_BUY && close1 >= (dwa1 - band))
      return true;
   if(position_type == POSITION_TYPE_SELL && close1 <= (dwa1 + band))
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9451\",\"strategy\":\"td_dwa_fade_h4\"}");
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
