#property strict
#property version   "5.0"
#property description "QM5_11903 Lawler S/D Zone Retest + 20-DMA (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11903
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11903;
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
input int    strategy_dma_period        = 20;
input int    strategy_dma_slope_bars    = 10;
input int    strategy_atr_period        = 14;
input double strategy_erc_atr_mult      = 2.0;
input int    strategy_zone_min_candles  = 1;
input int    strategy_zone_max_candles  = 10;
input int    strategy_zone_validity     = 240;
input double strategy_target_rr         = 3.0;
input int    strategy_time_stop_bars    = 480;
input double strategy_sl_buffer_pips    = 5.0;
input double strategy_entry_buffer_pips = 1.0;

// State variables for Zone tracking
bool   g_has_active_zone = false;
int    g_zone_type       = 0; // 1 = Demand (Buy), -1 = Supply (Sell)
double g_zone_high       = 0.0;
double g_zone_low        = 0.0;
int    g_zone_age_bars   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool IsERC(int shift, double atr)
{
   double high = iHigh(_Symbol, PERIOD_H1, shift);
   double low  = iLow(_Symbol, PERIOD_H1, shift);
   return ((high - low) >= (strategy_erc_atr_mult * atr));
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   const double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Ask for long, but we use it as generic price here
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   
   if(close1 <= 0.0 || atr1 <= 0.0) return false;

   // 1. Manage existing zone
   if(g_has_active_zone)
   {
      g_zone_age_bars++;
      
      // Check if zone is stale
      if(g_zone_age_bars > strategy_zone_validity)
      {
         g_has_active_zone = false;
      }
      // Check if price violated the far side of the zone (invalidating it)
      else if (g_zone_type == 1 && close1 < g_zone_low) g_has_active_zone = false;
      else if (g_zone_type == -1 && close1 > g_zone_high) g_has_active_zone = false;
      
      // If zone is still active, check for entry trigger
      if(g_has_active_zone)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         if(g_zone_type == 1) // Demand
         {
            double entry_level = g_zone_high - (strategy_entry_buffer_pips * 10 * point);
            // Limit order logic: price must retrace down to the upper edge
            if (iLow(_Symbol, PERIOD_H1, 1) <= entry_level && iClose(_Symbol, PERIOD_H1, 1) > g_zone_low)
            {
               g_has_active_zone = false; // Consume zone
               req.type = QM_BUY;
               req.price = 0.0; // Market entry to simulate limit fill
               req.sl = g_zone_low - (strategy_sl_buffer_pips * 10 * point);
               double risk = entry_level - req.sl;
               req.tp = entry_level + (risk * strategy_target_rr);
               req.reason = "LAWLER_DEMAND_ZONE_RETEST";
               req.symbol_slot = qm_magic_slot_offset;
               return true;
            }
         }
         else if(g_zone_type == -1) // Supply
         {
            double entry_level = g_zone_low + (strategy_entry_buffer_pips * 10 * point);
            if (iHigh(_Symbol, PERIOD_H1, 1) >= entry_level && iClose(_Symbol, PERIOD_H1, 1) < g_zone_high)
            {
               g_has_active_zone = false; // Consume zone
               req.type = QM_SELL;
               req.price = 0.0;
               req.sl = g_zone_high + (strategy_sl_buffer_pips * 10 * point);
               double risk = req.sl - entry_level;
               req.tp = entry_level - (risk * strategy_target_rr);
               req.reason = "LAWLER_SUPPLY_ZONE_RETEST";
               req.symbol_slot = qm_magic_slot_offset;
               return true;
            }
         }
      }
      
      // If we have an active zone, we don't look for new ones until this one is consumed or expires
      if (g_has_active_zone) return false;
   }

   // 2. Scan for NEW zones
   // We look back from bar 1. The sequence is: Base (1-10 bars) -> Breakout ERC (1 bar).
   // Let's assume bar 1 is the ERC.
   if(!IsERC(1, atr1)) return false;

   // If bar 1 is an ERC, scan bars 2 through 11 for the base
   int base_start = 2;
   int base_end = -1;
   
   for(int len = strategy_zone_min_candles; len <= strategy_zone_max_candles; len++)
   {
      bool is_base = true;
      for(int i = 0; i < len; i++)
      {
         int shift = base_start + i;
         double h = iHigh(_Symbol, PERIOD_H1, shift);
         double l = iLow(_Symbol, PERIOD_H1, shift);
         double base_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
         
         if ((h - l) >= base_atr)
         {
            is_base = false;
            break;
         }
      }
      
      if(is_base)
      {
         // We found a base sequence of length `len`
         base_end = base_start + len - 1;
         break;
      }
   }
   
   if(base_end == -1) return false; // No valid base found before the ERC

   // Determine base High and Low
   double b_high = 0.0;
   double b_low = 999999.0;
   for(int i = base_start; i <= base_end; i++)
   {
      double h = iHigh(_Symbol, PERIOD_H1, i);
      double l = iLow(_Symbol, PERIOD_H1, i);
      if(h > b_high) b_high = h;
      if(l < b_low) b_low = l;
   }

   // Determine breakout direction
   double sma_current = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1);
   double sma_past = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1 + strategy_dma_slope_bars);

   if(sma_current <= 0.0 || sma_past <= 0.0) return false;

   bool is_bullish_break = (close1 > b_high);
   bool is_bearish_break = (close1 < b_low);

   if(is_bullish_break && sma_current > sma_past)
   {
      g_has_active_zone = true;
      g_zone_type = 1;
      g_zone_high = b_high;
      g_zone_low = b_low;
      g_zone_age_bars = 0;
   }
   else if(is_bearish_break && sma_current < sma_past)
   {
      g_has_active_zone = true;
      g_zone_type = -1;
      g_zone_high = b_high;
      g_zone_low = b_low;
      g_zone_age_bars = 0;
   }

   return false; // Zone established, but entry happens on retest (handled in step 1 on future bars)
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop
      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      // Trend invalidation exit
      double sma_current = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1);
      double sma_past = QM_SMA(_Symbol, PERIOD_H1, strategy_dma_period, 1 + strategy_dma_slope_bars);
      
      if(sma_current > 0.0 && sma_past > 0.0)
      {
         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY && sma_current < sma_past) return true;
         if(ptype == POSITION_TYPE_SELL && sma_current > sma_past) return true;
      }
   }
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
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

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
