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

// No Trade Filter - no card-specific time or spread gate; framework gates news and Friday close.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry - HTF swing bias plus LTF ATR extension beyond the latest swing extreme.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static datetime triggered_buy_swing_time = 0;
   static datetime triggered_sell_swing_time = 0;

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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int pos_i = PositionsTotal() - 1; pos_i >= 0; --pos_i)
     {
      const ulong ticket = PositionGetTicket(pos_i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates htf_bars[];
   MqlRates ltf_bars[];
   ArraySetAsSeries(htf_bars, true);
   ArraySetAsSeries(ltf_bars, true);

   // perf-allowed: bespoke swing structure scan, called only after OnTick passes QM_IsNewBar().
   const int htf_copied = CopyRates(_Symbol, strategy_htf, 1, strategy_swing_scan_bars, htf_bars);
   const int ltf_copied = CopyRates(_Symbol, strategy_ltf, 1, strategy_swing_scan_bars, ltf_bars);
   const int min_bars = strategy_swing_bars * 2 + 3;
   if(htf_copied < min_bars || ltf_copied < min_bars)
      return false;

   bool htf_last_high_found = false;
   bool htf_prev_high_found = false;
   bool htf_last_low_found = false;
   bool htf_prev_low_found = false;
   double htf_last_high = 0.0;
   double htf_prev_high = 0.0;
   double htf_last_low = 0.0;
   double htf_prev_low = 0.0;

   for(int i = strategy_swing_bars; i < htf_copied - strategy_swing_bars; ++i)
     {
      bool swing_high = true;
      bool swing_low = true;
      for(int j = 1; j <= strategy_swing_bars; ++j)
        {
         if(htf_bars[i].high <= htf_bars[i - j].high || htf_bars[i].high <= htf_bars[i + j].high)
            swing_high = false;
         if(htf_bars[i].low >= htf_bars[i - j].low || htf_bars[i].low >= htf_bars[i + j].low)
            swing_low = false;
        }

      if(swing_high)
        {
         if(!htf_last_high_found)
           {
            htf_last_high_found = true;
            htf_last_high = htf_bars[i].high;
           }
         else if(!htf_prev_high_found)
           {
            htf_prev_high_found = true;
            htf_prev_high = htf_bars[i].high;
           }
        }

      if(swing_low)
        {
         if(!htf_last_low_found)
           {
            htf_last_low_found = true;
            htf_last_low = htf_bars[i].low;
           }
         else if(!htf_prev_low_found)
           {
            htf_prev_low_found = true;
            htf_prev_low = htf_bars[i].low;
           }
        }

      if(htf_last_high_found && htf_prev_high_found && htf_last_low_found && htf_prev_low_found)
         break;
     }

   if(!(htf_last_high_found && htf_prev_high_found && htf_last_low_found && htf_prev_low_found))
      return false;

   int bias = 0;
   if(htf_last_high > htf_prev_high && htf_last_low > htf_prev_low)
      bias = 1;
   else if(htf_last_high < htf_prev_high && htf_last_low < htf_prev_low)
      bias = -1;
   if(bias == 0)
      return false;

   bool ltf_last_high_found = false;
   bool ltf_prev_high_found = false;
   bool ltf_last_low_found = false;
   bool ltf_prev_low_found = false;
   double ltf_last_high = 0.0;
   double ltf_last_low = 0.0;
   datetime ltf_last_high_time = 0;
   datetime ltf_last_low_time = 0;

   for(int i = strategy_swing_bars; i < ltf_copied - strategy_swing_bars; ++i)
     {
      bool swing_high = true;
      bool swing_low = true;
      for(int j = 1; j <= strategy_swing_bars; ++j)
        {
         if(ltf_bars[i].high <= ltf_bars[i - j].high || ltf_bars[i].high <= ltf_bars[i + j].high)
            swing_high = false;
         if(ltf_bars[i].low >= ltf_bars[i - j].low || ltf_bars[i].low >= ltf_bars[i + j].low)
            swing_low = false;
        }

      if(swing_high)
        {
         if(!ltf_last_high_found)
           {
            ltf_last_high_found = true;
            ltf_last_high = ltf_bars[i].high;
            ltf_last_high_time = ltf_bars[i].time;
           }
         else if(!ltf_prev_high_found)
           {
            ltf_prev_high_found = true;
           }
        }

      if(swing_low)
        {
         if(!ltf_last_low_found)
           {
            ltf_last_low_found = true;
            ltf_last_low = ltf_bars[i].low;
            ltf_last_low_time = ltf_bars[i].time;
           }
         else if(!ltf_prev_low_found)
           {
            ltf_prev_low_found = true;
           }
        }

      if(ltf_last_high_found && ltf_prev_high_found && ltf_last_low_found && ltf_prev_low_found)
         break;
     }

   if(!(ltf_last_high_found && ltf_prev_high_found && ltf_last_low_found && ltf_prev_low_found))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_ltf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);
   const double extension = atr * strategy_atr_multiplier;
   const double midpoint = (ltf_last_high + ltf_last_low) * 0.5;

   if(bias > 0)
     {
      if(triggered_buy_swing_time == ltf_last_low_time)
         return false;
      if(ask > ltf_last_low - extension)
         return false;

      double sl = NormalizeDouble(ltf_last_low - extension, digits);
      double tp = NormalizeDouble(midpoint, digits);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
         return false;
      if(ask - sl < min_stop_distance)
         sl = NormalizeDouble(ask - min_stop_distance - point, digits);
      if(tp - ask < min_stop_distance)
         tp = NormalizeDouble(ask + min_stop_distance + point, digits);

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BUY_HTF_UP_LTF_LOW_EXTENSION";
      triggered_buy_swing_time = ltf_last_low_time;
      return true;
     }

   if(triggered_sell_swing_time == ltf_last_high_time)
      return false;
   if(bid < ltf_last_high + extension)
      return false;
   if(bid <= ltf_last_low)
      return false;

   double sl = NormalizeDouble(ltf_last_high + extension, digits);
   double tp = NormalizeDouble(midpoint, digits);
   if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
      return false;
   if(sl - bid < min_stop_distance)
      sl = NormalizeDouble(bid + min_stop_distance + point, digits);
   if(bid - tp < min_stop_distance)
      tp = NormalizeDouble(bid - min_stop_distance - point, digits);

   req.type = QM_SELL;
   req.sl = sl;
   req.tp = tp;
   req.reason = "SELL_HTF_DOWN_LTF_HIGH_EXTENSION";
   triggered_sell_swing_time = ltf_last_high_time;
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
