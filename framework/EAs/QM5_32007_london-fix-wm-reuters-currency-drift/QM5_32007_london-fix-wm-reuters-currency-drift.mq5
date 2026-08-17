#property strict
#property version   "5.0"
#property description "QM5_32007 London-fix pre-fix currency drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_32007 london-fix-wm-reuters-currency-drift
// -----------------------------------------------------------------------------
// Approved card:
//   strategy-seeds/cards/approved/
//   QM5_32007_london-fix-wm-reuters-currency-drift.md
//
// The card defines a fixed-GMT (UTC) price-flow continuation rule. At the
// first M5 boundary after the 15:30 UTC endpoint is complete, compare the
// 15:30 close with the 11:30 close. A return of at least +0.15% buys; a return
// of at most -0.15% sells. The position carries a fixed 12-pip server stop and
// 22-pip target and is flattened at 16:05 UTC if neither has fired.
//
// The card's textual "15:31 GMT" order time is normalized to the first tick of
// the M5 bar opening at 15:30 UTC. That is the framework-safe moment at which
// the preceding bar's 15:30 closing price is fixed. Waiting for an exact 15:31
// tick would violate the closed-bar gate and can miss in Model 4.
//
// No moving average, RSI, adaptive weight, external feed, grid, martingale,
// scale-in, trailing stop, or break-even rule is added. The central V5 kill
// switch owns the card's loss caps; the EA does not duplicate risk accounting.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 32007;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string InpEntryTime                  = "15:31"; // card order time, fixed GMT/UTC
input string InpExitTime                   = "16:05"; // hard time exit, fixed GMT/UTC
input double InpROCThreshold               = 0.15;    // absolute 11:30-to-15:30 return, percent

// Card-locked constants. They are deliberately not optimization inputs.
#define LF_ROC_START_MINUTE_UTC  690   // 11:30 UTC
#define LF_ATR_PERIOD             14
#define LF_STOP_PIPS              12
#define LF_TARGET_PIPS            22
#define LF_SPREAD_ATR_MULT        1.8
#define LF_RATE_LOOKBACK_BARS     80

double g_lf_cached_atr = 0.0;
int    g_lf_last_signal_date = 0;

bool LF_ParseHHMM(const string value, int &minute_of_day)
  {
   minute_of_day = -1;
   if(StringLen(value) != 5 || StringFind(value, ":") != 2)
      return false;

   const int hour = (int)StringToInteger(StringSubstr(value, 0, 2));
   const int minute = (int)StringToInteger(StringSubstr(value, 3, 2));
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;

   minute_of_day = hour * 60 + minute;
   return true;
  }

bool LF_UtcParts(const datetime broker_time, MqlDateTime &utc_parts)
  {
   ZeroMemory(utc_parts);
   return TimeToStruct(QM_BrokerToUTC(broker_time), utc_parts);
  }

int LF_DateKey(const MqlDateTime &parts)
  {
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

bool LF_IsRegisteredHost()
  {
   if(_Symbol == "EURUSD.DWX")
      return (qm_magic_slot_offset == 0);
   if(_Symbol == "GBPUSD.DWX")
      return (qm_magic_slot_offset == 1);
   return false;
  }

bool LF_SpreadTooWide(const double atr_value)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // .DWX Model-4 runs can legitimately model zero spread. Only a genuinely
   // positive spread can trip the card's 1.8*ATR ceiling.
   if(ask < bid)
      return true;
   if(ask == bid)
      return false;
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return true;
   return ((ask - bid) > LF_SPREAD_ATR_MULT * atr_value);
  }

bool LF_ResolveEndpointCloses(const int date_key,
                              const int end_minute_utc,
                              double &start_close,
                              double &end_close)
  {
   start_close = 0.0;
   end_close = 0.0;
   int start_matches = 0;
   int end_matches = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded structural read after QM_IsNewBar.
                                PERIOD_M5,
                                1,
                                LF_RATE_LOOKBACK_BARS,
                                rates);
   if(copied < 50)
      return false;

   const int bar_seconds = PeriodSeconds(PERIOD_M5);
   for(int i = 0; i < copied; ++i)
     {
      const datetime close_utc = QM_BrokerToUTC(rates[i].time) + bar_seconds;
      MqlDateTime close_parts;
      ZeroMemory(close_parts);
      if(!TimeToStruct(close_utc, close_parts))
         continue;
      if(LF_DateKey(close_parts) != date_key)
         continue;

      const int close_minute = close_parts.hour * 60 + close_parts.min;
      if(close_minute == LF_ROC_START_MINUTE_UTC)
        {
         start_close = rates[i].close;
         ++start_matches;
        }
      if(close_minute == end_minute_utc)
        {
         end_close = rates[i].close;
         ++end_matches;
        }
     }

   return (start_matches == 1 && end_matches == 1 &&
           start_close > 0.0 && end_close > 0.0 &&
           MathIsValidNumber(start_close) && MathIsValidNumber(end_close));
  }

// Return TRUE to block new trading this tick. Existing exposure always passes
// through so that the time exit and framework risk controls remain reachable.
bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(_Period != PERIOD_M5 || !LF_IsRegisteredHost())
      return true;

   MqlDateTime utc_now;
   if(!LF_UtcParts(TimeCurrent(), utc_now))
      return true;

   // Card rollover blackout: 23:55 through 00:05 UTC.
   const int utc_minute = utc_now.hour * 60 + utc_now.min;
   if(utc_minute >= 23 * 60 + 55 || utc_minute <= 5)
      return true;

   // EntrySignal refreshes the pooled ATR once per closed M5 bar. Use only
   // cached state here; do not invoke an indicator reader on every tick.
   if(g_lf_cached_atr > 0.0 && LF_SpreadTooWide(g_lf_cached_atr))
      return true;

   return false;
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

   if(_Period != PERIOD_M5 || !LF_IsRegisteredHost())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Pooled indicator read occurs once per M5 bar behind the framework gate.
   g_lf_cached_atr = QM_ATR(_Symbol, PERIOD_M5, LF_ATR_PERIOD, 1);

   int configured_entry_minute = -1;
   if(!LF_ParseHHMM(InpEntryTime, configured_entry_minute))
      return false;

   // A closed M5 endpoint is tradable on the bar opening at that endpoint.
   // 15:31 therefore maps to the first bar after the 15:30 completed close.
   const int signal_end_minute = configured_entry_minute -
                                 (configured_entry_minute % 5);
   if(signal_end_minute <= LF_ROC_START_MINUTE_UTC)
      return false;

   const datetime current_bar_open = iTime(_Symbol, PERIOD_M5, 0); // perf-allowed: one current-bar timestamp behind QM_IsNewBar.
   if(current_bar_open <= 0)
      return false;

   MqlDateTime current_utc;
   if(!LF_UtcParts(current_bar_open, current_utc))
      return false;
   if(current_utc.day_of_week == 0 || current_utc.day_of_week == 6)
      return false;
   if(current_utc.hour * 60 + current_utc.min != signal_end_minute)
      return false;

   const int date_key = LF_DateKey(current_utc);
   if(date_key == g_lf_last_signal_date)
      return false;
   // Consume the single daily decision before every fallible data/order gate.
   g_lf_last_signal_date = date_key;

   double start_close = 0.0;
   double end_close = 0.0;
   if(!LF_ResolveEndpointCloses(date_key,
                                signal_end_minute,
                                start_close,
                                end_close))
      return false;

   const double roc_pct = ((end_close - start_close) / start_close) * 100.0;
   if(!MathIsValidNumber(roc_pct) || InpROCThreshold <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(roc_pct >= InpROCThreshold)
      side = QM_BUY;
   else if(roc_pct <= -InpROCThreshold)
      side = QM_SELL;
   else
      return false;

   if(LF_SpreadTooWide(g_lf_cached_atr))
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || !MathIsValidNumber(entry))
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, LF_STOP_PIPS);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, LF_TARGET_PIPS);
   if(sl <= 0.0 || tp <= 0.0 || !MathIsValidNumber(sl) || !MathIsValidNumber(tp))
      return false;
   if(side == QM_BUY && !(sl < entry && tp > entry))
      return false;
   if(side == QM_SELL && !(sl > entry && tp < entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY)
                ? StringFormat("london_fix_drift_buy_roc_%.5f", roc_pct)
                : StringFormat("london_fix_drift_sell_roc_%.5f", roc_pct);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card-locked baseline: fixed broker SL/TP only. The illustrative state
   // diagram supplies no BE or trailing trigger, so no SL mutation is added.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   int exit_minute = -1;
   if(!LF_ParseHHMM(InpExitTime, exit_minute))
      return false;

   MqlDateTime utc_now;
   if(!LF_UtcParts(TimeCurrent(), utc_now))
      return false;
   const int now_key = LF_DateKey(utc_now);
   const int now_minute = utc_now.hour * 60 + utc_now.min;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      MqlDateTime opened_utc;
      if(!LF_UtcParts((datetime)PositionGetInteger(POSITION_TIME), opened_utc))
         continue;

      const int opened_key = LF_DateKey(opened_utc);
      if(opened_key != now_key)
         return true; // stale survivor: close immediately on the next tick.
      if(now_minute >= exit_minute)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied from framework/templates/EA_Skeleton.mq5.
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
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
