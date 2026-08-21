#property strict
#property version   "5.0"
#property description "QM5_41011 Tokyo-to-London Interbank Flow Handover Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41011
// Tokyo-to-London Interbank Flow Handover Breakout
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41011;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    InpRangeStartHourUTC       = 6;      // Handover pre-range start hour UTC (06:00)
input int    InpRangeStartMinUTC        = 0;      // Handover pre-range start minute UTC
input int    InpRangeEndHourUTC         = 6;      // Handover pre-range end hour UTC (06:45)
input int    InpRangeEndMinUTC          = 45;     // Handover pre-range end minute UTC
input int    InpEntryStartHourUTC       = 7;      // Entry window start hour UTC (07:00)
input int    InpEntryStartMinUTC        = 0;      // Entry window start minute UTC
input int    InpEntryEndHourUTC         = 7;      // Entry window end hour UTC (07:30)
input int    InpEntryEndMinUTC          = 30;     // Entry window end minute UTC
input int    InpTimeStopHourUTC         = 12;     // Daily position time-stop exit hour UTC (12:00)
input double InpBufferPips              = 2.0;    // Breakout entry buffer in pips
input double InpMinAtrPips              = 10.0;   // Minimum ATR in pips (filter)
input int    InpAtrPeriod               = 14;     // Volatility filter ATR period
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of M15 ATR(14)
input double InpRrMultiplier            = 2.0;    // Take profit risk-reward multiplier (1:2.0)

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per closed bar)
// -----------------------------------------------------------------------------
double g_cached_range_high = 0.0;
double g_cached_range_low  = 0.0;
int    g_cached_range_day  = -1;
bool   g_cached_traded     = false;
double g_cached_atr_1      = 0.0;
double g_cached_close_1    = 0.0;

void AdvanceState_OnNewBar()
{
   g_cached_atr_1 = QM_ATR(_Symbol, PERIOD_M15, InpAtrPeriod, 1);
   g_cached_close_1 = iClose(_Symbol, PERIOD_M15, 1);

   const datetime b_time = iTime(_Symbol, PERIOD_M15, 1);
   const datetime u_time = QM_BrokerToUTC(b_time);
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   // Daily reset on new day
   if(u_dt.day != g_cached_range_day)
   {
      g_cached_range_day  = u_dt.day;
      g_cached_range_high = 0.0;
      g_cached_range_low  = 0.0;
      g_cached_traded     = false;
   }

   // At 07:00 UTC, compute the 06:00-06:45 UTC pre-range (3 closed M15 bars: 06:00, 06:15, 06:30)
   if(u_dt.hour == InpEntryStartHourUTC && u_dt.min == InpEntryStartMinUTC)
   {
      double highest_h = 0.0;
      double lowest_l  = 99999999.0;
      for(int s = 1; s <= 3; ++s)
      {
         const double h = iHigh(_Symbol, PERIOD_M15, s);
         const double l = iLow(_Symbol, PERIOD_M15, s);
         if(h > highest_h) highest_h = h;
         if(l < lowest_l && l > 0.0) lowest_l = l;
      }
      if(highest_h > 0.0 && lowest_l < 99999999.0 && highest_h > lowest_l)
      {
         g_cached_range_high = highest_h;
         g_cached_range_low  = lowest_l;
      }
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && g_cached_atr_1 > 0.0)
   {
      if((ask - bid) > InpSpreadAtrMult * g_cached_atr_1)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day < 5) // 23:55 to 00:05 GMT rollover blackout
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_cached_traded || g_cached_range_high <= 0.0 || g_cached_range_low <= 0.0 || g_cached_atr_1 <= 0.0)
      return false;

   const datetime b_time = iTime(_Symbol, PERIOD_M15, 1);
   const datetime u_time = QM_BrokerToUTC(b_time);
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   const int bar_minute_utc = u_dt.hour * 60 + u_dt.min;
   const int entry_start_utc = InpEntryStartHourUTC * 60 + InpEntryStartMinUTC;
   const int entry_end_utc   = InpEntryEndHourUTC * 60 + InpEntryEndMinUTC;

   // Only trade within [07:00, 07:30] UTC entry window
   if(bar_minute_utc < entry_start_utc || bar_minute_utc >= entry_end_utc)
      return false;

   const double min_atr_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpMinAtrPips * 10.0));
   if(min_atr_dist > 0.0 && g_cached_atr_1 < min_atr_dist)
      return false;

   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpBufferPips * 10.0));
   const double range_midpoint = (g_cached_range_high + g_cached_range_low) * 0.5;

   // Long breakout: Close[1] > RangeHigh + Buffer
   if(g_cached_close_1 > (g_cached_range_high + buffer_dist))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = range_midpoint;
      if(ask - sl < 0.5 * g_cached_atr_1) sl = ask - 0.5 * g_cached_atr_1;
      if(ask - sl > 4.0 * g_cached_atr_1) sl = ask - 4.0 * g_cached_atr_1;

      const double sl_dist = ask - sl;
      if(sl_dist <= 0.0) return false;

      const double tp = ask + InpRrMultiplier * sl_dist;

      req.type               = QM_BUY;
      req.price              = ask;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "41011_handover_buy";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_cached_traded        = true;
      return true;
   }

   // Short breakout: Close[1] < RangeLow - Buffer
   if(g_cached_close_1 < (g_cached_range_low - buffer_dist))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = range_midpoint;
      if(sl - bid < 0.5 * g_cached_atr_1) sl = bid + 0.5 * g_cached_atr_1;
      if(sl - bid > 4.0 * g_cached_atr_1) sl = bid + 4.0 * g_cached_atr_1;

      const double sl_dist = sl - bid;
      if(sl_dist <= 0.0) return false;

      const double tp = bid - InpRrMultiplier * sl_dist;

      req.type               = QM_SELL;
      req.price              = bid;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "41011_handover_sell";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_cached_traded        = true;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const datetime u_time = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   // Time Stop: Close all open positions at or after 12:00 GMT (UTC)
   if(u_dt.hour >= InpTimeStopHourUTC)
      return true;

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, PERIOD_M15)) return;
   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
