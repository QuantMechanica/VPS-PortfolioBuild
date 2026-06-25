#property strict
#property version   "5.0"
#property description "QM5_11260 cs-stoch-mfi - StochRSI and MFI M5 reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11260 cs-stoch-mfi
// -----------------------------------------------------------------------------
// Approved card baseline:
//   - Long-only.
//   - StochRSI(14) < 20 and MFI(14) < 20 on the same closed M5 bar.
//   - MFI uses the framework tick-volume MFI reader for .DWX custom symbols.
//   - ATR(14) hard stop at 1.5 ATR.
//   - Move stop to break-even after +0.8R.
//   - Exit when StochRSI > 80, MFI > 80, or after 36 M5 bars.
//   - Entry filter: liquid session, central news blackout, spread <= 0.25 ATR.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11260;
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
input int    strategy_stochrsi_period      = 14;
input double strategy_hot_threshold        = 20.0;
input double strategy_cold_threshold       = 80.0;
input int    strategy_mfi_period           = 14;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_mult          = 1.5;
input double strategy_breakeven_trigger_r  = 0.8;
input int    strategy_max_hold_bars        = 36;
input double strategy_spread_atr_fraction  = 0.25;
input int    strategy_session_start_hour   = 7;
input int    strategy_session_end_hour     = 22;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to block this tick. The card requires liquid-session entries,
// news blackout entries, and spread <= 0.25 ATR. News is handled centrally.
bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
      const int end_h   = MathMax(0, MathMin(23, strategy_session_end_hour));
      bool in_session = false;
      if(start_h < end_h)
         in_session = (dt.hour >= start_h && dt.hour < end_h);
      else
         in_session = (dt.hour >= start_h || dt.hour < end_h);
      if(!in_session)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread = ask - bid;
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(spread > 0.0 && spread > strategy_spread_atr_fraction * atr_value)
      return true;

   return false;
  }

// Populate a long market entry when StochRSI and MFI are both below hot.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_stochrsi_period < 2 || strategy_mfi_period < 2 || strategy_atr_period < 1)
      return false;

   double rsi_now = QM_RSI(_Symbol, _Period, strategy_stochrsi_period, 1, PRICE_CLOSE);
   if(rsi_now <= 0.0)
      return false;

   double rsi_low = rsi_now;
   double rsi_high = rsi_now;
   for(int shift = 1; shift <= strategy_stochrsi_period; ++shift)
     {
      const double rsi_value = QM_RSI(_Symbol, _Period, strategy_stochrsi_period, shift, PRICE_CLOSE);
      if(rsi_value <= 0.0)
         return false;
      if(rsi_value < rsi_low)
         rsi_low = rsi_value;
      if(rsi_value > rsi_high)
         rsi_high = rsi_value;
     }

   const double rsi_range = rsi_high - rsi_low;
   if(rsi_range <= 0.0)
      return false;

   const double stochrsi = 100.0 * (rsi_now - rsi_low) / rsi_range;
   if(!(stochrsi < strategy_hot_threshold))
      return false;

   const double mfi_now = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi_now <= 0.0)
      return false;
   if(!(mfi_now < strategy_hot_threshold))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "cs_stoch_mfi_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Move the hard ATR stop to break-even after +0.8R, as specified by the card.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl_price <= 0.0)
         continue;

      const double initial_r = open_price - sl_price;
      if(initial_r <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      if((bid - open_price) >= strategy_breakeven_trigger_r * initial_r && sl_price < open_price)
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "cs_stoch_mfi_breakeven");
     }
  }

// Close long when either oscillator reaches cold, or after max_hold_bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(strategy_stochrsi_period >= 2)
     {
      double rsi_now = QM_RSI(_Symbol, _Period, strategy_stochrsi_period, 1, PRICE_CLOSE);
      if(rsi_now > 0.0)
        {
         double rsi_low = rsi_now;
         double rsi_high = rsi_now;
         bool rsi_ok = true;
         for(int shift = 1; shift <= strategy_stochrsi_period; ++shift)
           {
            const double rsi_value = QM_RSI(_Symbol, _Period, strategy_stochrsi_period, shift, PRICE_CLOSE);
            if(rsi_value <= 0.0)
              {
               rsi_ok = false;
               break;
              }
            if(rsi_value < rsi_low)
               rsi_low = rsi_value;
            if(rsi_value > rsi_high)
               rsi_high = rsi_value;
           }

         const double rsi_range = rsi_high - rsi_low;
         if(rsi_ok && rsi_range > 0.0)
           {
            const double stochrsi = 100.0 * (rsi_now - rsi_low) / rsi_range;
            if(stochrsi > strategy_cold_threshold)
               return true;
           }
        }
     }

   const double mfi_now = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi_now > strategy_cold_threshold)
      return true;

   const int tf_secs = PeriodSeconds(_Period);
   if(tf_secs > 0 && strategy_max_hold_bars > 0)
     {
      const datetime broker_now = TimeCurrent();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && (broker_now - opened) >= (long)strategy_max_hold_bars * tf_secs)
            return true;
        }
     }

   return false;
  }

// Defer to the framework's central P8-callable news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
