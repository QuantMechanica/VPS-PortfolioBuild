#property strict
#property version   "5.0"
#property description "QM5_9198 MQL5 CCI Zero Cross Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9198 — MQL5 CCI Zero Cross Momentum
// Card: artifacts/cards_approved/QM5_9198_mql5-cci-zero.md
// Source: Mohamed Abdelmaaboud, "Learn how to design a trading system by CCI",
//         MQL5 Articles, 2022-04-06. https://www.mql5.com/en/articles/10592
// Strategy: CCI(14) zero-line cross entries; +100/-100 CCI TP; ATR(14)*1.5 SL.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9198;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

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

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period          = 14;    // CCI lookback period
input int    strategy_atr_period          = 14;    // ATR lookback for stop distance
input double strategy_atr_sl_mult         = 1.5;   // ATR multiplier for SL
input bool   strategy_ema_filter          = false; // Enable EMA(100) trend filter (P3 sweep)
input int    strategy_ema_period          = 100;   // EMA period for optional trend filter

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — framework news/time guards handle baseline filtering.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: CCI zero-line cross on the last two closed bars.
// Long  when prev_bar CCI <= 0 and current_bar CCI > 0.
// Short when prev_bar CCI >= 0 and current_bar CCI < 0.
// Called only after QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   if(GetOurPosition(ptype, ticket))
      return false; // one position per magic

   const double cci_curr = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);
   if(cci_curr == EMPTY_VALUE || cci_prev == EMPTY_VALUE)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Optional EMA(100) trend filter (enabled in P3 sweep)
   if(strategy_ema_filter)
     {
      const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      if(ema == EMPTY_VALUE || ema <= 0.0)
         return false;
      // Long only above EMA; short only below EMA
      if(cci_prev <= 0.0 && cci_curr > 0.0 && bid < ema)
         return false;
      if(cci_prev >= 0.0 && cci_curr < 0.0 && ask > ema)
         return false;
     }

   // Long zero-cross: prev CCI <= 0 and current CCI > 0
   if(cci_prev <= 0.0 && cci_curr > 0.0)
     {
      const double sl      = ask - atr * strategy_atr_sl_mult;
      const double sl_pts  = (ask - sl) / point;
      if(sl_pts <= 0.0)
         return false;
      req.type             = QM_BUY;
      req.price            = 0.0;
      req.sl               = sl;
      req.tp               = 0.0; // CCI-based TP managed in ExitSignal
      req.lots             = QM_LotsForRisk(_Symbol, sl_pts);
      req.reason           = "CCI_ZERO_LONG";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short zero-cross: prev CCI >= 0 and current CCI < 0
   if(cci_prev >= 0.0 && cci_curr < 0.0)
     {
      const double sl      = bid + atr * strategy_atr_sl_mult;
      const double sl_pts  = (sl - bid) / point;
      if(sl_pts <= 0.0)
         return false;
      req.type             = QM_SELL;
      req.price            = 0.0;
      req.sl               = sl;
      req.tp               = 0.0; // CCI-based TP managed in ExitSignal
      req.lots             = QM_LotsForRisk(_Symbol, sl_pts);
      req.reason           = "CCI_ZERO_SHORT";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Manage Open Position — no trailing stop per card; ATR SL is fixed at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal — CCI-based TP and opposite zero-cross exit.
// Long  exit: CCI(shift=1) >= +100 (TP) OR CCI(shift=1) < 0 (opposite cross).
// Short exit: CCI(shift=1) <= -100 (TP) OR CCI(shift=1) > 0 (opposite cross).
// Reads last-closed-bar CCI (shift=1); stable every tick until next bar close.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   if(!GetOurPosition(ptype, ticket))
      return false;

   const double cci = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   if(cci == EMPTY_VALUE)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (cci >= 100.0 || cci < 0.0);

   return (cci <= -100.0 || cci > 0.0);
  }

// News Filter Hook — defer to framework two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
