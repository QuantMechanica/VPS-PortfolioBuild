#property strict
#property version   "5.0"
#property description "QM5_1410 Bressert Dual-Cycle Oscillator H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1410
// Bressert Dual-Cycle Oscillator (H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1410_bressert-dual-cycle-oscillator-h4.md
// Walter Bressert: The Power of Oscillator/Cycle Combinations (1991)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1410;
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
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_H4;
input int    strategy_atr_period                     = 14;
input int    strategy_dss_short_n                    = 8;
input int    strategy_dss_short_m                    = 3;
input int    strategy_dss_long_n                     = 21;
input int    strategy_dss_long_m                     = 7;
input double strategy_timing_band_oversold           = 30.0;
input double strategy_timing_band_overbought         = 70.0;
input double strategy_timing_band_mid                = 50.0;
input double strategy_sl_atr_mult                    = 1.50;
input double strategy_tp1_atr_mult                   = 1.50;
input double strategy_tp1_close_fraction             = 0.50;
input double strategy_tp_cap_atr_mult                = 4.00;
input int    strategy_time_stop_bars                 = 30;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 50;
input int    strategy_reuse_guard_bars               = 6;
input bool   strategy_spread_filter_enabled          = true;
input double strategy_spread_max_atr                 = 0.25;

int      g_h_atr_h4 = INVALID_HANDLE;
int      g_h_sma_d1 = INVALID_HANDLE;

bool     g_tp1_done = false;
datetime g_pattern_block_until = 0;

double Strategy_NormalizePrice(const double price)
{
   return QM_StopRulesNormalizePrice(_Symbol, price);
}

bool Strategy_InitIndicators()
{
   g_h_atr_h4 = iATR(_Symbol, strategy_tf, strategy_atr_period);
   if(g_h_atr_h4 == INVALID_HANDLE)
   {
      PrintFormat("QM5_%d: failed to create H4 ATR handle", qm_ea_id);
      return false;
   }
   if(strategy_macro_bias_enabled)
   {
      g_h_sma_d1 = iMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 0, MODE_SMA, PRICE_CLOSE);
      if(g_h_sma_d1 == INVALID_HANDLE)
      {
         PrintFormat("QM5_%d: failed to create D1 SMA handle", qm_ea_id);
         return false;
      }
   }
   return true;
}

void Strategy_ReleaseIndicators()
{
   if(g_h_atr_h4 != INVALID_HANDLE) { IndicatorRelease(g_h_atr_h4); g_h_atr_h4 = INVALID_HANDLE; }
   if(g_h_sma_d1 != INVALID_HANDLE) { IndicatorRelease(g_h_sma_d1); g_h_sma_d1 = INVALID_HANDLE; }
}

bool Strategy_SelectOurPosition(ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ticket = cand;
      return true;
   }
   return false;
}

bool Strategy_ReuseGuardActive()
{
   if(g_pattern_block_until > 0 && TimeCurrent() < g_pattern_block_until)
      return true;

   if(strategy_reuse_guard_bars <= 0) return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 30 * 24 * 60 * 60, now)) return false;

   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   datetime last_deal_time = 0;
   for(int i = total - 1; i >= 0; --i)
   {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
      {
         const datetime dtime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(dtime > last_deal_time) last_deal_time = dtime;
         break;
      }
   }
   if(last_deal_time > 0)
   {
      const int bars_since = iBarShift(_Symbol, strategy_tf, last_deal_time, false);
      if(bars_since >= 0 && bars_since < strategy_reuse_guard_bars)
         return true;
   }
   return false;
}

bool Strategy_SpreadAcceptable(const double atr)
{
   if(!strategy_spread_filter_enabled) return true;
   if(atr <= 0.0) return false;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   return (spread <= strategy_spread_max_atr * atr);
}

bool Strategy_MacroBias(const double close_price, bool &long_allowed, bool &short_allowed)
{
   long_allowed = true;
   short_allowed = true;
   if(!strategy_macro_bias_enabled || g_h_sma_d1 == INVALID_HANDLE)
      return true;

   double sma_val[1];
   if(CopyBuffer(g_h_sma_d1, 0, 1, 1, sma_val) < 1)
      return false;

   long_allowed = (close_price > sma_val[0]);
   short_allowed = (close_price < sma_val[0]);
   return true;
}

void Strategy_CalculateDSS(const MqlRates &rates[],
                           const int total_bars,
                           const int n,
                           const int m,
                           double &dss_out[])
{
   ArrayResize(dss_out, total_bars);
   ArrayInitialize(dss_out, 50.0);

   if(total_bars < 2 * n + 2 * m + 10)
      return;

   double k1[];
   ArrayResize(k1, total_bars);
   ArrayInitialize(k1, 50.0);

   // Stage 1: Stochastic %K
   for(int i = total_bars - n; i >= 0; --i)
   {
      double h_max = rates[i].high;
      double l_min = rates[i].low;
      for(int j = 1; j < n; ++j)
      {
         if(rates[i + j].high > h_max) h_max = rates[i + j].high;
         if(rates[i + j].low < l_min) l_min = rates[i + j].low;
      }
      const double diff = h_max - l_min;
      if(diff > 1e-12)
         k1[i] = 100.0 * (rates[i].close - l_min) / diff;
      else
         k1[i] = 50.0;
   }

   // EMA smoothing of K1 -> K1_smooth
   double k1_smooth[];
   ArrayResize(k1_smooth, total_bars);
   ArrayInitialize(k1_smooth, 50.0);
   const double alpha = 2.0 / (double)(m + 1);

   const int k1_start = total_bars - n;
   k1_smooth[k1_start] = k1[k1_start];
   for(int i = k1_start - 1; i >= 0; --i)
   {
      k1_smooth[i] = alpha * k1[i] + (1.0 - alpha) * k1_smooth[i + 1];
   }

   // Stage 2: Stochastic %K on K1_smooth -> K2
   double k2[];
   ArrayResize(k2, total_bars);
   ArrayInitialize(k2, 50.0);

   const int k2_start = k1_start - n;
   for(int i = k2_start; i >= 0; --i)
   {
      double h_max = k1_smooth[i];
      double l_min = k1_smooth[i];
      for(int j = 1; j < n; ++j)
      {
         if(k1_smooth[i + j] > h_max) h_max = k1_smooth[i + j];
         if(k1_smooth[i + j] < l_min) l_min = k1_smooth[i + j];
      }
      const double diff = h_max - l_min;
      if(diff > 1e-12)
         k2[i] = 100.0 * (k1_smooth[i] - l_min) / diff;
      else
         k2[i] = 50.0;
   }

   // EMA smoothing of K2 -> DSS
   const int dss_start = k2_start;
   dss_out[dss_start] = k2[dss_start];
   for(int i = dss_start - 1; i >= 0; --i)
   {
      dss_out[i] = alpha * k2[i] + (1.0 - alpha) * dss_out[i + 1];
   }
}

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_ticket))
      return false;

   if(Strategy_ReuseGuardActive())
      return false;

   double atr_val[1];
   if(CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_val) < 1)
      return false;
   const double atr = atr_val[0];
   if(atr <= 0.0) return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   const int needed_bars = 120;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates);
   if(copied < needed_bars) return false;

   double dss_short[];
   double dss_long[];
   Strategy_CalculateDSS(rates, copied, strategy_dss_short_n, strategy_dss_short_m, dss_short);
   Strategy_CalculateDSS(rates, copied, strategy_dss_long_n, strategy_dss_long_m, dss_long);

   bool long_allowed = false, short_allowed = false;
   if(!Strategy_MacroBias(rates[1].close, long_allowed, short_allowed))
      return false;

   // --------------------------------------------------------------------------
   // LONG SETUP (at shift 1 close):
   // 1. Short-cycle setup: DSS_short <= 30 for at least 2 of prior 3 bars (1..3)
   // 2. Short-cycle bullish cross: DSS_short[1] > DSS_short[2] AND DSS_short[2] <= DSS_short[3]
   // 3. Intermediate alignment: DSS_long[1] <= 50 AND DSS_long[1] > DSS_long[4]
   // 4. Price momentum: close[1] > close[4]
   // 5. Macro bias: close[1] > SMA(50, D1)
   // --------------------------------------------------------------------------
   int os_count = 0;
   for(int b = 1; b <= 3; ++b)
   {
      if(dss_short[b] <= strategy_timing_band_oversold)
         os_count++;
   }

   const bool long_short_setup = (os_count >= 2);
   const bool long_short_cross = (dss_short[1] > dss_short[2] && dss_short[2] <= dss_short[3]);
   const bool long_inter_align = (dss_long[1] <= strategy_timing_band_mid && dss_long[1] > dss_long[4]);
   const bool long_price_momo  = (rates[1].close > rates[4].close);

   if(long_allowed && long_short_setup && long_short_cross && long_inter_align && long_price_momo)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      const double sl = ask - strategy_sl_atr_mult * atr;
      const double tp = ask + strategy_tp_cap_atr_mult * atr; // capped upper objective; managed by TP1 / oscillator TP2

      req.type = QM_BUY;
      req.price = Strategy_NormalizePrice(ask);
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "DSS_DUAL_CYCLE_BUY";
      req.symbol_slot = qm_magic_slot_offset;

      g_tp1_done = false;
      g_pattern_block_until = rates[0].time + strategy_reuse_guard_bars * PeriodSeconds(strategy_tf);
      return true;
   }

   // --------------------------------------------------------------------------
   // SHORT SETUP (at shift 1 close):
   // 1. Short-cycle setup: DSS_short >= 70 for at least 2 of prior 3 bars (1..3)
   // 2. Short-cycle bearish cross: DSS_short[1] < DSS_short[2] AND DSS_short[2] >= DSS_short[3]
   // 3. Intermediate alignment: DSS_long[1] >= 50 AND DSS_long[1] < dss_long[4]
   // 4. Price momentum: close[1] < close[4]
   // 5. Macro bias: close[1] < SMA(50, D1)
   // --------------------------------------------------------------------------
   int ob_count = 0;
   for(int b = 1; b <= 3; ++b)
   {
      if(dss_short[b] >= strategy_timing_band_overbought)
         ob_count++;
   }

   const bool short_short_setup = (ob_count >= 2);
   const bool short_short_cross = (dss_short[1] < dss_short[2] && dss_short[2] >= dss_short[3]);
   const bool short_inter_align = (dss_long[1] >= strategy_timing_band_mid && dss_long[1] < dss_long[4]);
   const bool short_price_momo  = (rates[1].close < rates[4].close);

   if(short_allowed && short_short_setup && short_short_cross && short_inter_align && short_price_momo)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      const double sl = bid + strategy_sl_atr_mult * atr;
      const double tp = bid - strategy_tp_cap_atr_mult * atr;

      req.type = QM_SELL;
      req.price = Strategy_NormalizePrice(bid);
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "DSS_DUAL_CYCLE_SELL";
      req.symbol_slot = qm_magic_slot_offset;

      g_tp1_done = false;
      g_pattern_block_until = rates[0].time + strategy_reuse_guard_bars * PeriodSeconds(strategy_tf);
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
   {
      g_tp1_done = false;
      return;
   }

   double atr_val[1];
   if(CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_val) < 1) return;
   const double atr = atr_val[0];
   if(atr <= 0.0) return;

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);

   // 1. Partial close at TP1 (1.5 * ATR) + move SL to Break-Even
   if(!g_tp1_done)
   {
      bool tp1_hit = false;
      if(pos_type == POSITION_TYPE_BUY && current_price >= open_price + strategy_tp1_atr_mult * atr)
         tp1_hit = true;
      else if(pos_type == POSITION_TYPE_SELL && current_price <= open_price - strategy_tp1_atr_mult * atr)
         tp1_hit = true;

      if(tp1_hit)
      {
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         const double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double close_vol = MathFloor((current_volume * strategy_tp1_close_fraction) / lot_step) * lot_step;
         if(close_vol >= min_lot && (current_volume - close_vol) >= min_lot)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(QM_FrameworkMagic());
            if(trade.PositionClosePartial(ticket, close_vol))
            {
               g_tp1_done = true;
               const double be_sl = Strategy_NormalizePrice(open_price);
               if(pos_type == POSITION_TYPE_BUY && (be_sl > current_sl || current_sl == 0.0))
                  trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
               else if(pos_type == POSITION_TYPE_SELL && (be_sl < current_sl || current_sl == 0.0))
                  trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
            }
         }
         else
         {
            g_tp1_done = true;
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(pos_time <= 0) return false;

   const int bars_open = iBarShift(_Symbol, strategy_tf, pos_time, false);

   // 1. Time-stop: 30 H4 bars after entry
   if(bars_open >= strategy_time_stop_bars)
   {
      PrintFormat("QM5_%d: Time-stop exit triggered after %d bars", qm_ea_id, bars_open);
      return true;
   }

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

   const int needed_bars = 120;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates) < needed_bars)
      return false;

   double dss_short[];
   double dss_long[];
   Strategy_CalculateDSS(rates, needed_bars, strategy_dss_short_n, strategy_dss_short_m, dss_short);
   Strategy_CalculateDSS(rates, needed_bars, strategy_dss_long_n, strategy_dss_long_m, dss_long);

   // 2. TP2 — Oscillator-exit: close when DSS_short >= 70 (Long) / DSS_short <= 30 (Short)
   if(pos_type == POSITION_TYPE_BUY && dss_short[1] >= strategy_timing_band_overbought)
   {
      PrintFormat("QM5_%d: Oscillator exit TP2 triggered (DSS_short %G >= 70)", qm_ea_id, dss_short[1]);
      return true;
   }
   if(pos_type == POSITION_TYPE_SELL && dss_short[1] <= strategy_timing_band_oversold)
   {
      PrintFormat("QM5_%d: Oscillator exit TP2 triggered (DSS_short %G <= 30)", qm_ea_id, dss_short[1]);
      return true;
   }

   // 3. Pattern-failure hard exit: both cycles turning back against us AND in loss
   if(pos_type == POSITION_TYPE_BUY)
   {
      if(dss_short[1] < dss_short[3] && dss_long[1] < dss_long[3] && rates[1].close < open_price)
      {
         PrintFormat("QM5_%d: Pattern-failure exit triggered (cycles falling in loss)", qm_ea_id);
         return true;
      }
   }
   else if(pos_type == POSITION_TYPE_SELL)
   {
      if(dss_short[1] > dss_short[3] && dss_long[1] > dss_long[3] && rates[1].close > open_price)
      {
         PrintFormat("QM5_%d: Pattern-failure exit triggered (cycles rising in loss)", qm_ea_id);
         return true;
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

   if(!Strategy_InitIndicators())
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Strategy_ReleaseIndicators();
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
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

