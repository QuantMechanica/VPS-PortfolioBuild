#property strict
#property version   "5.0"
#property description "QM5_10046 ForexFactory Momentum Divergence H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — ForexFactory Momentum(28) divergence, H4.
// Card: QM5_10046_ff-momentum-div-h4
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10046;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_period       = 28;
input int    strategy_fractal_left          = 3;
input int    strategy_fractal_right         = 3;
input int    strategy_divergence_min_bars   = 8;
input int    strategy_divergence_max_bars   = 28;
input int    strategy_atr_period            = 14;
input double strategy_min_stop_atr_mult     = 0.5;
input double strategy_max_stop_atr_mult     = 4.0;
input double strategy_take_profit_rr        = 2.0;
input double strategy_extra_buffer_points   = 0.0;

double PriceHigh(const int shift)
  {
   return iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: fixed 3L/3R fractal structural scan behind framework QM_IsNewBar gate.
  }

double PriceLow(const int shift)
  {
   return iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: fixed 3L/3R fractal structural scan behind framework QM_IsNewBar gate.
  }

bool IsSwingHigh(const int shift)
  {
   if(shift <= strategy_fractal_right)
      return false;
   const double center = PriceHigh(shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= strategy_fractal_left; ++i)
      if(PriceHigh(shift + i) >= center)
         return false;
   for(int i = 1; i <= strategy_fractal_right; ++i)
      if(PriceHigh(shift - i) >= center)
         return false;
   return true;
  }

bool IsSwingLow(const int shift)
  {
   if(shift <= strategy_fractal_right)
      return false;
   const double center = PriceLow(shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= strategy_fractal_left; ++i)
      if(PriceLow(shift + i) <= center)
         return false;
   for(int i = 1; i <= strategy_fractal_right; ++i)
      if(PriceLow(shift - i) <= center)
         return false;
   return true;
  }

bool HasOurPosition(ENUM_POSITION_TYPE &pos_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool FindMomentumDivergence(const bool bullish, double &point_c, double &point_f)
  {
   point_c = 0.0;
   point_f = 0.0;

   if(strategy_momentum_period < 1 ||
      strategy_fractal_left < 1 ||
      strategy_fractal_right < 1 ||
      strategy_divergence_min_bars < 1 ||
      strategy_divergence_max_bars < strategy_divergence_min_bars)
      return false;

   const int first_newer_shift = strategy_fractal_right + 1;
   const int last_newer_shift = strategy_divergence_max_bars + strategy_fractal_right;

   for(int newer = first_newer_shift; newer <= last_newer_shift; ++newer)
     {
      if(bullish)
        {
         if(!IsSwingLow(newer))
            continue;
        }
      else
        {
         if(!IsSwingHigh(newer))
            continue;
        }

      for(int older = newer + strategy_divergence_min_bars;
          older <= newer + strategy_divergence_max_bars;
          ++older)
        {
         if(bullish)
           {
            if(!IsSwingLow(older))
               continue;
           }
         else
           {
            if(!IsSwingHigh(older))
               continue;
           }

         const double price_new = bullish ? PriceLow(newer) : PriceHigh(newer);
         const double price_old = bullish ? PriceLow(older) : PriceHigh(older);
         const double mom_new = QM_Momentum(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_momentum_period, newer);
         const double mom_old = QM_Momentum(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_momentum_period, older);
         if(price_new <= 0.0 || price_old <= 0.0 || mom_new <= 0.0 || mom_old <= 0.0)
            continue;

         const bool diverged = bullish ? (price_new < price_old && mom_new > mom_old)
                                       : (price_new > price_old && mom_new < mom_old);
         if(!diverged)
            continue;

         double c = bullish ? DBL_MAX : -DBL_MAX;
         double f = bullish ? -DBL_MAX : DBL_MAX;
         for(int s = newer; s <= older; ++s)
           {
            const double px = bullish ? PriceLow(s) : PriceHigh(s);
            const double mo = QM_Momentum(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_momentum_period, s);
            if(px <= 0.0 || mo <= 0.0)
               return false;
            if(bullish)
              {
               c = MathMin(c, px);
               f = MathMax(f, mo);
              }
            else
              {
               c = MathMax(c, px);
               f = MathMin(f, mo);
              }
           }

         const double mom_1 = QM_Momentum(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_momentum_period, 1);
         const double mom_2 = QM_Momentum(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_momentum_period, 2);
         if(mom_1 <= 0.0 || mom_2 <= 0.0)
            return false;

         const bool break_f = bullish ? (mom_2 <= f && mom_1 > f)
                                      : (mom_2 >= f && mom_1 < f);
         if(!break_f)
            continue;

         point_c = c;
         point_f = f;
         return true;
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(HasOurPosition(existing_type))
      return false;

   if(strategy_take_profit_rr <= 0.0 || strategy_min_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult < strategy_min_stop_atr_mult)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double spread_buffer = (ask - bid) + MathMax(0.0, strategy_extra_buffer_points) * point;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double point_c = 0.0;
   double point_f = 0.0;

   if(FindMomentumDivergence(false, point_c, point_f))
     {
      const double entry = bid;
      const double sl = point_c + spread_buffer;
      const double risk = sl - entry;
      if(risk < strategy_min_stop_atr_mult * atr || risk > strategy_max_stop_atr_mult * atr)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - strategy_take_profit_rr * risk, _Digits);
      req.reason = "FF_MOM_DIV_SHORT_F_BREAK";
      return (req.sl > entry && req.tp < entry);
     }

   if(FindMomentumDivergence(true, point_c, point_f))
     {
      const double entry = ask;
      const double sl = point_c - spread_buffer;
      const double risk = entry - sl;
      if(risk < strategy_min_stop_atr_mult * atr || risk > strategy_max_stop_atr_mult * atr)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + strategy_take_profit_rr * risk, _Digits);
      req.reason = "FF_MOM_DIV_LONG_F_BREAK";
      return (req.sl < entry && req.tp > entry);
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         if(current_sl >= open_price)
            continue;
         const double risk = open_price - current_sl;
         const double profit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - open_price;
         if(risk > 0.0 && profit >= risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "FF_MOM_DIV_BE_AT_1R_LONG");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(current_sl <= open_price)
            continue;
         const double risk = current_sl - open_price;
         const double profit = open_price - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(risk > 0.0 && profit >= risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "FF_MOM_DIV_BE_AT_1R_SHORT");
        }
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(!HasOurPosition(pos_type))
      return false;

   if(!QM_IsNewBar(_Symbol, (ENUM_TIMEFRAMES)_Period))
      return false;

   double point_c = 0.0;
   double point_f = 0.0;
   if(pos_type == POSITION_TYPE_BUY)
      return FindMomentumDivergence(false, point_c, point_f);
   if(pos_type == POSITION_TYPE_SELL)
      return FindMomentumDivergence(true, point_c, point_f);
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for P8 News Impact phase)
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless the framework changes.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10046\",\"strategy\":\"ff-momentum-div-h4\"}");
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
