#property strict
#property version   "5.0"
#property description "QM5_1354 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1354
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1354;
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
input int    strategy_trend_cci_period    = 34;
input int    strategy_turbo_cci_period    = 6;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 1.8;
input double strategy_tp_atr_mult         = 2.5;
input int    strategy_time_stop_bars      = 48;
input double strategy_spread_mult         = 1.5;

// --- Closed-bar state ---
double g_trend_cci[7] = {0.0};
double g_turbo_cci[4] = {0.0};
double g_atr_1 = 0.0;
double g_spread_ema = 0.0;

int  g_bars_in_trade = 0;
bool g_tp1_taken = false;
bool g_buy_suppressed = false;
bool g_sell_suppressed = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

void AdvanceState_OnNewBar()
{
   for(int i = 1; i <= 6; i++)
   {
      g_trend_cci[i] = QM_CCI(_Symbol, PERIOD_H1, strategy_trend_cci_period, i, PRICE_TYPICAL);
   }
   for(int i = 1; i <= 3; i++)
   {
      g_turbo_cci[i] = QM_CCI(_Symbol, PERIOD_H1, strategy_turbo_cci_period, i, PRICE_TYPICAL);
   }
   g_atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);

   const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_now  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double raw_sprd = (ask_now > 0.0 && bid > 0.0 && ask_now > bid)
                           ? (ask_now - bid) : 0.0;
   g_spread_ema = (g_spread_ema <= 0.0)
                  ? raw_sprd
                  : 0.095 * raw_sprd + 0.905 * g_spread_ema;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      g_bars_in_trade++;
   else
   {
      g_bars_in_trade = 0;
      g_tp1_taken = false;
   }

   // Reset suppression when TrendCCI flips sign
   if(g_trend_cci[1] < 0)
      g_buy_suppressed = false;
   if(g_trend_cci[1] > 0)
      g_sell_suppressed = false;
}

bool Strategy_NoTradeFilter()
{
   if(Bars(_Symbol, PERIOD_H1) < strategy_trend_cci_period + 10) // perf-allowed: O(1) bar count for warmup
      return true;

   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask_now > 0.0 && bid > 0.0 && ask_now > bid && g_spread_ema > 0.0)
   {
      if((ask_now - bid) > strategy_spread_mult * g_spread_ema)
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < 6 || dt.hour >= 22)
      return false;

   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_now = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask_now <= 0.0 || bid_now <= 0.0)
      return false;

   // Check BUY
   if(!g_buy_suppressed)
   {
      bool bull_trend = true;
      for(int i = 1; i <= 6; i++)
      {
         if(g_trend_cci[i] <= 0.0) { bull_trend = false; break; }
      }
      if(bull_trend)
      {
         if(g_turbo_cci[3] > 100.0 && g_turbo_cci[2] <= 0.0 && g_turbo_cci[1] > 0.0 && g_turbo_cci[1] > g_turbo_cci[2])
         {
            const double sl = ask_now - strategy_sl_atr_mult * g_atr_1;
            const double tp = ask_now + strategy_tp_atr_mult * g_atr_1;
            if(sl > 0.0 && sl < ask_now)
            {
               req.type = QM_BUY;
               req.price = 0.0;
               req.sl = sl;
               req.tp = tp;
               req.reason = "WOODIE_CCI_ZLR_BUY";
               req.symbol_slot = qm_magic_slot_offset;
               req.expiration_seconds = 0;
               g_buy_suppressed = true;
               return true;
            }
         }
      }
   }

   // Check SELL
   if(!g_sell_suppressed)
   {
      bool bear_trend = true;
      for(int i = 1; i <= 6; i++)
      {
         if(g_trend_cci[i] >= 0.0) { bear_trend = false; break; }
      }
      if(bear_trend)
      {
         if(g_turbo_cci[3] < -100.0 && g_turbo_cci[2] >= 0.0 && g_turbo_cci[1] < 0.0 && g_turbo_cci[1] < g_turbo_cci[2])
         {
            const double sl = bid_now + strategy_sl_atr_mult * g_atr_1;
            const double tp = bid_now - strategy_tp_atr_mult * g_atr_1;
            if(sl > bid_now)
            {
               req.type = QM_SELL;
               req.price = 0.0;
               req.sl = sl;
               req.tp = tp;
               req.reason = "WOODIE_CCI_ZLR_SELL";
               req.symbol_slot = qm_magic_slot_offset;
               req.expiration_seconds = 0;
               g_sell_suppressed = true;
               return true;
            }
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   if(g_tp1_taken)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return;

   bool should_close_half = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_turbo_cci[1] > 250.0)
         should_close_half = true;
      else if(type == POSITION_TYPE_SELL && g_turbo_cci[1] < -250.0)
         should_close_half = true;

      if(should_close_half)
      {
         const double vol = PositionGetDouble(POSITION_VOLUME);
         const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * 0.5);
         if(close_vol > 0.0)
         {
            QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);
            g_tp1_taken = true;
         }
      }
      break;
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;

   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_trend_cci[1] < 0.0)
         return true;
      if(type == POSITION_TYPE_SELL && g_trend_cci[1] > 0.0)
         return true;
      break;
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
   
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_1354\",\"slug\":\"woodie-cci-dual-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

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

   if(!is_new_bar) return;
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
