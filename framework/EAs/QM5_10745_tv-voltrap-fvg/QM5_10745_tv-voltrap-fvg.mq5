#property strict
#property version   "5.0"
#property description "QM5_10745 TradingView Volume Trap FVG Long"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10745;
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
input int    strategy_atr_period          = 14;
input double strategy_breakdown_atr_mult  = 0.5;
input int    strategy_volume_sma_period   = 20;
input double strategy_volume_band_pct     = 5.0;
input double strategy_sl_atr_mult         = 0.1;
input int    strategy_pending_expiry_bars = 10;
input int    strategy_swing_lookback_bars = 40;
input double strategy_max_swing_rr        = 3.0;
input double strategy_fallback_rr         = 2.0;

double BarOpen(const int shift)
  {
   return iOpen(_Symbol, _Period, shift); // perf-allowed: bounded FVG/engulfing structural read on closed-bar entry path.
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: bounded FVG/swing structural read on closed-bar entry path.
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: bounded FVG/swing structural read on closed-bar entry path.
  }

double BarClose(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: bounded FVG/engulfing structural read on closed-bar entry path.
  }

long BarVolume(const int shift)
  {
   return iVolume(_Symbol, _Period, shift); // perf-allowed: card requires DWX tick-volume proxy; bounded closed-bar SMA.
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT)
         return true;
     }

   return false;
  }

bool VolumeWithinBand(const int shift)
  {
   if(strategy_volume_sma_period <= 0 || strategy_volume_band_pct < 0.0)
      return false;

   const long current_volume = BarVolume(shift);
   if(current_volume <= 0)
      return false;

   double sum = 0.0;
   int samples = 0;
   for(int i = shift + 1; i <= shift + strategy_volume_sma_period; ++i)
     {
      const long v = BarVolume(i);
      if(v <= 0)
         continue;
      sum += (double)v;
      samples++;
     }

   if(samples <= 0 || sum <= 0.0)
      return false;

   const double sma = sum / (double)samples;
   const double tolerance = sma * strategy_volume_band_pct / 100.0;
   return (MathAbs((double)current_volume - sma) <= tolerance);
  }

bool IsBearishEngulfing(const int shift)
  {
   const double o = BarOpen(shift);
   const double c = BarClose(shift);
   const double po = BarOpen(shift + 1);
   const double pc = BarClose(shift + 1);
   if(o <= 0.0 || c <= 0.0 || po <= 0.0 || pc <= 0.0)
      return false;

   return (c < o && pc > po && o >= pc && c <= po);
  }

bool IsBreakdownCandle(const int shift, const double atr)
  {
   const double close_now = BarClose(shift);
   const double prior_low = BarLow(shift + 1);
   if(close_now <= 0.0 || prior_low <= 0.0 || atr <= 0.0)
      return false;

   return (close_now <= prior_low - strategy_breakdown_atr_mult * atr);
  }

bool FindRecentSwingHigh(const double entry, const double risk_distance, double &out_tp)
  {
   out_tp = 0.0;
   if(entry <= 0.0 || risk_distance <= 0.0 || strategy_swing_lookback_bars < 3)
      return false;

   const double max_tp = entry + strategy_max_swing_rr * risk_distance;
   for(int shift = 2; shift <= strategy_swing_lookback_bars; ++shift)
     {
      const double h = BarHigh(shift);
      if(h <= entry || h > max_tp)
         continue;

      const double left = BarHigh(shift + 1);
      const double right = BarHigh(shift - 1);
      if(h > left && h > right)
        {
         out_tp = h;
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurPendingOrder())
      return false;

   if(strategy_atr_period <= 0 || strategy_breakdown_atr_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_pending_expiry_bars <= 0 ||
      strategy_fallback_rr <= 0.0 || strategy_max_swing_rr <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 3);
   if(atr <= 0.0)
      return false;

   const int trap_shift = 3;
   if(!VolumeWithinBand(trap_shift))
      return false;

   if(!IsBearishEngulfing(trap_shift) && !IsBreakdownCandle(trap_shift, atr))
      return false;

   const double fvg_low = BarHigh(3);
   const double fvg_high = BarLow(1);
   if(fvg_low <= 0.0 || fvg_high <= 0.0 || fvg_high <= fvg_low)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0 || fvg_low >= ask)
      return false;

   const double entry = fvg_low;
   const double sl = entry - strategy_sl_atr_mult * atr;
   const double risk_distance = entry - sl;
   if(sl <= 0.0 || risk_distance <= 0.0)
      return false;

   double tp = 0.0;
   if(!FindRecentSwingHigh(entry, risk_distance, tp))
      tp = entry + strategy_fallback_rr * risk_distance;

   if(tp <= entry)
      return false;

   int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      seconds = 300;

   req.type = QM_BUY_LIMIT;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "TV_VOLTRAP_FVG_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = seconds * strategy_pending_expiry_bars;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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
