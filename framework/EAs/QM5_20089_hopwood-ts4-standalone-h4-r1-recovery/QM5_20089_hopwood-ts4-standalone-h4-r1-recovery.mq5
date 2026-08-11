#property strict
#property version   "5.0"
#property description "QM5_20089 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20089
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20089;
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
input int    strategy_dmi_period        = 14;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_channel_period    = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_atr_tp_mult       = 2.0;
input double strategy_psar_step         = 0.02;
input double strategy_psar_max          = 0.2;
input int    strategy_cooldown_bars     = 6;
input int    strategy_timestop_bars     = 24;
input double strategy_range_gate_mult   = 0.4;
input double strategy_spread_gate_mult  = 0.35;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // 1. Check if we already have an open position for this magic
   if(QM_EntryHasOpenPosition(QM_FrameworkMagic(), _Symbol))
      return false;

   // 2. Closed bar values (shift 1)
   const double close_1 = iClose(_Symbol, PERIOD_H4, 1);
   const double high_1 = iHigh(_Symbol, PERIOD_H4, 1);
   const double low_1 = iLow(_Symbol, PERIOD_H4, 1);
   
   const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_H4, strategy_dmi_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_H4, strategy_dmi_period, 1);
   
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_hist = macd_main - macd_sig;

   const int hh_idx = iHighest(_Symbol, PERIOD_H4, MODE_HIGH, strategy_channel_period, 2);
   const int ll_idx = iLowest(_Symbol, PERIOD_H4, MODE_LOW, strategy_channel_period, 2);
   if(hh_idx < 0 || ll_idx < 0)
      return false;
   const double hhv = iHigh(_Symbol, PERIOD_H4, hh_idx);
   const double llv = iLow(_Symbol, PERIOD_H4, ll_idx);

   // 3. Regime Filter: EMA(200, D1) slope
   const double ema_curr = QM_EMA(_Symbol, PERIOD_D1, 200, 1);
   const double ema_prev = QM_EMA(_Symbol, PERIOD_D1, 200, 2);
   const double ema_slope = ema_curr - ema_prev;

   // 4. Spread filter
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr_val = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(spread > strategy_spread_gate_mult * atr_val)
      return false;

   // 5. Minimum bar-range gate
   const double bar_range = high_1 - low_1;
   if(bar_range <= strategy_range_gate_mult * atr_val)
      return false;

   // Determine buy vs sell signal
   bool is_buy = (plus_di > minus_di) && (macd_hist > 0.0) && (close_1 > hhv) && (ema_slope > 0.0);
   bool is_sell = (plus_di < minus_di) && (macd_hist < 0.0) && (close_1 < llv) && (ema_slope < 0.0);

   if(!is_buy && !is_sell)
      return false;

   QM_OrderType type = is_buy ? QM_BUY : QM_SELL;

   // 6. Cooldown filter
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const datetime from_time = now - (datetime)(strategy_cooldown_bars * 4 * 3600); // 6 H4 bars = 24 hours
   if(HistorySelect(from_time, now))
   {
      const int deals = HistoryDealsTotal();
      for(int i = deals - 1; i >= 0; --i)
      {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0) continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
         if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         
         ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
         if(deal_type == DEAL_TYPE_BUY && type == QM_BUY)
            return false;
         if(deal_type == DEAL_TYPE_SELL && type == QM_SELL)
            return false;
      }
   }

   // 7. Open request setup
   req.type = type;
   req.price = 0.0; // Market entry
   req.reason = is_buy ? "TS4_BUY" : "TS4_SELL";
   
   // Set initial stop loss (1.5 * ATR from entry)
   const double entry_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl = is_buy ? (entry_price - strategy_atr_sl_mult * atr_val) : (entry_price + strategy_atr_sl_mult * atr_val);
   req.tp = 0.0; // Dynamic TP

   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_vol = PositionGetDouble(POSITION_VOLUME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);

      // Estimate the entry ATR from current SL (fallback to current ATR if SL is not set or 0)
      double entry_atr = 0.0;
      if(current_sl > 0.0)
         entry_atr = MathAbs(entry_price - current_sl) / strategy_atr_sl_mult;
      if(entry_atr <= 0.0)
         entry_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

      // 1. T1 Target check: 2.0 * ATR from entry
      const double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool t1_reached = is_buy ? (current_bid >= entry_price + strategy_atr_tp_mult * entry_atr)
                               : (current_ask <= entry_price - strategy_atr_tp_mult * entry_atr);

      // 2. Check if we already moved to Break Even (to prevent re-running T1 logic)
      const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool already_moved_be = is_buy ? (current_sl >= entry_price - 1e-5)
                                     : (current_sl > 0.0 && current_sl <= entry_price + 1e-5);

      if(t1_reached && !already_moved_be)
      {
         // Partial close: close 50%
         double half_vol = current_vol * 0.5;
         double normalized_half = QM_TM_NormalizeVolume(_Symbol, half_vol);
         if(normalized_half > 0.0)
         {
            QM_TM_PartialClose(ticket, normalized_half, QM_EXIT_PARTIAL);
         }
         
         // Move SL to break-even plus spread
         double new_sl = is_buy ? (entry_price + spread) : (entry_price - spread);
         QM_TM_MoveSL(ticket, new_sl, "TS4_T1_BE_spread");
      }

      // 3. PSAR Trail (only after T1 BE has been established)
      if(already_moved_be)
      {
         const double sar = QM_SAR(_Symbol, PERIOD_H4, strategy_psar_step, strategy_psar_max, 1);
         if(is_buy)
         {
            if(sar > current_sl)
               QM_TM_MoveSL(ticket, sar, "TS4_PSAR_trail");
         }
         else
         {
            if(current_sl > 0.0 && sar < current_sl)
               QM_TM_MoveSL(ticket, sar, "TS4_PSAR_trail");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // 1. Time-stop check: 24 H4 bars
      const int bars_passed = iBarShift(_Symbol, PERIOD_H4, entry_time, false);
      if(bars_passed >= strategy_timestop_bars)
         return true;

      // 2. Opposite-signal check (evaluated on closed H4 bar)
      const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_H4, strategy_dmi_period, 1);
      const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_H4, strategy_dmi_period, 1);
      
      const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double macd_sig = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double macd_hist = macd_main - macd_sig;

      const double close_1 = iClose(_Symbol, PERIOD_H4, 1);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const int ll_idx = iLowest(_Symbol, PERIOD_H4, MODE_LOW, strategy_channel_period, 2);
         if(ll_idx >= 0)
         {
            const double llv = iLow(_Symbol, PERIOD_H4, ll_idx);
            if((plus_di < minus_di) || (macd_hist < 0.0) || (close_1 < llv))
               return true;
         }
      }
      else
      {
         const int hh_idx = iHighest(_Symbol, PERIOD_H4, MODE_HIGH, strategy_channel_period, 2);
         if(hh_idx >= 0)
         {
            const double hhv = iHigh(_Symbol, PERIOD_H4, hh_idx);
            if((plus_di > minus_di) || (macd_hist > 0.0) || (close_1 > hhv))
               return true;
         }
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
