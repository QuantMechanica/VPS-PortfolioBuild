#property strict
#property version   "5.0"
#property description "QM5_10097 MQL5 Swing Extreme Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10097 mql5-swing-ext
// Card: artifacts/cards_approved/QM5_10097_mql5-swing-ext.md
// Source: Hlomohang John Borotho, MQL5 Swing Extremes and Pullbacks Part 2.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10097;
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
input ENUM_TIMEFRAMES strategy_htf        = PERIOD_H1; // Higher-timeframe structure bias.
input ENUM_TIMEFRAMES strategy_ltf        = PERIOD_M5; // Lower-timeframe swing trigger.
input int    strategy_swing_bars          = 3;         // Bars on both sides needed to confirm a swing.
input int    strategy_atr_period          = 14;        // ATR period for extension and stop buffer.
input double strategy_atr_multiplier      = 1.0;       // ATR multiple for entry extension and SL buffer.
input int    strategy_swing_scan_bars     = 180;       // Closed bars scanned for recent swing points.

struct SwingPoint
  {
   bool     found;
   double   price;
   datetime time;
   int      index;
  };

datetime g_triggered_buy_swing_time = 0;
datetime g_triggered_sell_swing_time = 0;

void ResetSwingPoint(SwingPoint &p)
  {
   p.found = false;
   p.price = 0.0;
   p.time = 0;
   p.index = -1;
  }

bool IsSwingHigh(const MqlRates &bars[], const int i, const int swing_bars)
  {
   const double price = bars[i].high;
   if(price <= 0.0)
      return false;

   for(int j = 1; j <= swing_bars; ++j)
     {
      if(price <= bars[i - j].high || price <= bars[i + j].high)
         return false;
     }
   return true;
  }

bool IsSwingLow(const MqlRates &bars[], const int i, const int swing_bars)
  {
   const double price = bars[i].low;
   if(price <= 0.0)
      return false;

   for(int j = 1; j <= swing_bars; ++j)
     {
      if(price >= bars[i - j].low || price >= bars[i + j].low)
         return false;
     }
   return true;
  }

bool LoadClosedBars(const ENUM_TIMEFRAMES tf, const int requested, MqlRates &bars[])
  {
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, tf, 1, requested, bars); // perf-allowed: one closed-bar gated structural swing scan.
   return (copied >= requested);
  }

bool FindRecentSwings(const MqlRates &bars[],
                      const int copied,
                      const int swing_bars,
                      SwingPoint &last_high,
                      SwingPoint &prev_high,
                      SwingPoint &last_low,
                      SwingPoint &prev_low)
  {
   ResetSwingPoint(last_high);
   ResetSwingPoint(prev_high);
   ResetSwingPoint(last_low);
   ResetSwingPoint(prev_low);

   if(copied < (swing_bars * 2 + 3))
      return false;

   for(int i = swing_bars; i < copied - swing_bars; ++i)
     {
      if(IsSwingHigh(bars, i, swing_bars))
        {
         if(!last_high.found)
           {
            last_high.found = true;
            last_high.price = bars[i].high;
            last_high.time = bars[i].time;
            last_high.index = i;
           }
         else if(!prev_high.found)
           {
            prev_high.found = true;
            prev_high.price = bars[i].high;
            prev_high.time = bars[i].time;
            prev_high.index = i;
           }
        }

      if(IsSwingLow(bars, i, swing_bars))
        {
         if(!last_low.found)
           {
            last_low.found = true;
            last_low.price = bars[i].low;
            last_low.time = bars[i].time;
            last_low.index = i;
           }
         else if(!prev_low.found)
           {
            prev_low.found = true;
            prev_low.price = bars[i].low;
            prev_low.time = bars[i].time;
            prev_low.index = i;
           }
        }

      if(last_high.found && prev_high.found && last_low.found && prev_low.found)
         return true;
     }

   return (last_high.found && prev_high.found && last_low.found && prev_low.found);
  }

int HigherTimeframeBias(const SwingPoint &last_high,
                        const SwingPoint &prev_high,
                        const SwingPoint &last_low,
                        const SwingPoint &prev_low)
  {
   if(!(last_high.found && prev_high.found && last_low.found && prev_low.found))
      return 0;
   if(last_high.price > prev_high.price && last_low.price > prev_low.price)
      return 1;
   if(last_high.price < prev_high.price && last_low.price < prev_low.price)
      return -1;
   return 0;
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool HasOpenPositionForMagic()
  {
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
      if((long)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// No Trade Filter - no card-specific time/spread gate; news and Friday close are framework gates.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry - HTF swing bias plus LTF ATR extension beyond the latest swing extreme.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "SWING_EXTREME_PULLBACK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_swing_bars < 1 ||
      strategy_atr_period < 1 ||
      strategy_atr_multiplier <= 0.0 ||
      strategy_swing_scan_bars < (strategy_swing_bars * 2 + 10))
      return false;

   if(HasOpenPositionForMagic())
      return false;

   MqlRates htf_bars[];
   MqlRates ltf_bars[];
   if(!LoadClosedBars(strategy_htf, strategy_swing_scan_bars, htf_bars))
      return false;
   if(!LoadClosedBars(strategy_ltf, strategy_swing_scan_bars, ltf_bars))
      return false;

   SwingPoint htf_high;
   SwingPoint htf_prev_high;
   SwingPoint htf_low;
   SwingPoint htf_prev_low;
   if(!FindRecentSwings(htf_bars, ArraySize(htf_bars), strategy_swing_bars,
                        htf_high, htf_prev_high, htf_low, htf_prev_low))
      return false;

   SwingPoint ltf_high;
   SwingPoint ltf_prev_high;
   SwingPoint ltf_low;
   SwingPoint ltf_prev_low;
   if(!FindRecentSwings(ltf_bars, ArraySize(ltf_bars), strategy_swing_bars,
                        ltf_high, ltf_prev_high, ltf_low, ltf_prev_low))
      return false;

   const int bias = HigherTimeframeBias(htf_high, htf_prev_high, htf_low, htf_prev_low);
   if(bias == 0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_ltf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);
   const double extension = atr * strategy_atr_multiplier;
   const double midpoint = (ltf_high.price + ltf_low.price) * 0.5;

   if(bias > 0)
     {
      if(g_triggered_buy_swing_time == ltf_low.time)
         return false;
      if(ask > ltf_low.price - extension)
         return false;

      double sl = NormalizeStrategyPrice(ltf_low.price - extension);
      double tp = NormalizeStrategyPrice(midpoint);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
         return false;
      if(ask - sl < min_stop_distance)
         sl = NormalizeStrategyPrice(ask - min_stop_distance - point);
      if(tp - ask < min_stop_distance)
         tp = NormalizeStrategyPrice(ask + min_stop_distance + point);

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BUY_HTF_UP_LTF_LOW_EXTENSION";
      g_triggered_buy_swing_time = ltf_low.time;
      return true;
     }

   if(g_triggered_sell_swing_time == ltf_high.time)
      return false;
   if(bid < ltf_high.price + extension)
      return false;
   if(bid <= ltf_low.price)
      return false;

   double sl = NormalizeStrategyPrice(ltf_high.price + extension);
   double tp = NormalizeStrategyPrice(midpoint);
   if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
      return false;
   if(sl - bid < min_stop_distance)
      sl = NormalizeStrategyPrice(bid + min_stop_distance + point);
   if(bid - tp < min_stop_distance)
      tp = NormalizeStrategyPrice(bid - min_stop_distance - point);

   req.type = QM_SELL;
   req.sl = sl;
   req.tp = tp;
   req.reason = "SELL_HTF_DOWN_LTF_HIGH_EXTENSION";
   g_triggered_sell_swing_time = ltf_high.time;
   return true;
  }

// Trade Management - no card-authorized trailing, break-even, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close - discretionary exits are represented by the initial structure TP/SL.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook - defer to the framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line
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
