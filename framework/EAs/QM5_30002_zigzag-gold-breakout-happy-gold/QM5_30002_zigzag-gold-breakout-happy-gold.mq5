#property strict
#property version   "5.0"
#property description "ZigZag Gold Reversal Breakout (Happy Gold)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 30002;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int InpZZDepth      = 12;
input int InpH4EMAPeriod  = 50;
input int InpTPPoints     = 360;
input int InpSLPoints     = 240;

double g_strategy_initial_equity = 0.0;

bool Strategy_RolloverBlackout()
  {
   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return true;
   const int minute_of_day = utc.hour * 60 + utc.min;
   return minute_of_day >= 1435 || minute_of_day <= 5;
  }

bool Strategy_EntryCircuitBreaker()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;

   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity * 0.98)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_EquityExitRequired()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;

   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity * 0.975)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, 14, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   return ask > bid && (ask - bid) > 1.8 * atr;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_FindConfirmedPivots(double &pivot_high, double &pivot_low)
  {
   if(InpZZDepth < 2)
      return false;

   const int backstep = 3;
   const int scan_bars = 60 + InpZZDepth + backstep;
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, scan_bars, bars) != scan_bars) // perf-allowed: bounded ZigZag reconstruction after the framework new-bar gate.
      return false;

   const double deviation = 5.0 * _Point;
   bool have_high = false;
   bool have_low = false;
   pivot_high = 0.0;
   pivot_low = 0.0;

   for(int shift = backstep; shift < scan_bars - InpZZDepth; ++shift)
     {
      bool is_high = true;
      bool is_low = true;
      double neighbour_high = -1.0e100;
      double neighbour_low = 1.0e100;

      for(int offset = 1; offset <= InpZZDepth; ++offset)
        {
         neighbour_high = MathMax(neighbour_high, bars[shift + offset].high);
         neighbour_low = MathMin(neighbour_low, bars[shift + offset].low);
         if(bars[shift].high <= bars[shift + offset].high)
            is_high = false;
         if(bars[shift].low >= bars[shift + offset].low)
            is_low = false;
        }

      for(int offset = 1; offset <= backstep; ++offset)
        {
         neighbour_high = MathMax(neighbour_high, bars[shift - offset].high);
         neighbour_low = MathMin(neighbour_low, bars[shift - offset].low);
         if(bars[shift].high <= bars[shift - offset].high)
            is_high = false;
         if(bars[shift].low >= bars[shift - offset].low)
            is_low = false;
        }

      if(!have_high && is_high &&
         bars[shift].high - neighbour_high >= deviation)
        {
         pivot_high = bars[shift].high;
         have_high = true;
        }
      if(!have_low && is_low &&
         neighbour_low - bars[shift].low >= deviation)
        {
         pivot_low = bars[shift].low;
         have_low = true;
        }
      if(have_high && have_low)
         break;
     }

   return have_high && have_low;
  }

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(Strategy_RolloverBlackout())
      return true;
   return Strategy_EntryCircuitBreaker();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1 ||
      Strategy_WideSpread())
      return false;

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   if(!Strategy_FindConfirmedPivots(pivot_high, pivot_low))
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: one closed-bar price read inside the framework entry gate.
   const double ema_h4 = QM_EMA(_Symbol, PERIOD_H4, InpH4EMAPeriod, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close_1 <= 0.0 || ema_h4 <= 0.0 || ask <= 0.0 || bid <= 0.0 ||
      InpTPPoints <= 0 || InpSLPoints <= 0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(close_1 > pivot_high && close_1 > ema_h4)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - InpSLPoints * _Point, digits);
      req.tp = NormalizeDouble(ask + InpTPPoints * _Point, digits);
      req.reason = "confirmed_zigzag_high_break_h4_up";
      return req.sl > 0.0 && req.sl < req.price && req.tp > req.price;
     }

   if(close_1 < pivot_low && close_1 < ema_h4)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + InpSLPoints * _Point, digits);
      req.tp = NormalizeDouble(bid - InpTPPoints * _Point, digits);
      req.reason = "confirmed_zigzag_low_break_h4_down";
      return req.tp > 0.0 && req.tp < req.price && req.sl > req.price;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE side =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      double proposed_sl = 0.0;

      if(side == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - open_price < 150.0 * _Point)
            continue;
         proposed_sl = NormalizeDouble(bid - 100.0 * _Point, digits);
         if(proposed_sl > open_price &&
            (current_sl <= 0.0 || proposed_sl > current_sl))
            QM_TM_MoveSL(ticket, proposed_sl, "zigzag_ratchet_trail");
        }
      else if(side == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open_price - ask < 150.0 * _Point)
            continue;
         proposed_sl = NormalizeDouble(ask + 100.0 * _Point, digits);
         if(proposed_sl < open_price &&
            (current_sl <= 0.0 || proposed_sl < current_sl))
            QM_TM_MoveSL(ticket, proposed_sl, "zigzag_ratchet_trail");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   return Strategy_EquityExitRequired();
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
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

