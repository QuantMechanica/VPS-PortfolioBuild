#property strict
#property version   "5.0"
#property description "QM5_1409 Wyckoff Sign of Strength Phase D H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1409
// Wyckoff Sign-of-Strength (Phase D long-entry, H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1409_wyckoff-sign-of-strength-phase-d-h4.md
// Hank Pruden, The Three Skills of Top Trading (Wiley 2007) Ch. 5
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1409;
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
input int    strategy_fractal_wing_bars              = 2;
input int    strategy_tr_min_bars                    = 60;
input int    strategy_tr_max_bars                    = 240;
input int    strategy_tr_step_bars                   = 10;
input double strategy_tr_containment_pct             = 0.90;
input double strategy_tr_min_amplitude_atr          = 4.0;
input double strategy_tr_max_amplitude_atr          = 14.0;
input int    strategy_prior_trend_bars               = 60;
input double strategy_prior_trend_slope_atr          = -0.10;
input double strategy_tr_stability_slope_atr         = 0.05;
input int    strategy_spring_lookback_bars           = 4;
input double strategy_spring_atr_buffer              = 0.50;
input double strategy_sos_breakout_atr               = 0.40;
input double strategy_sos_body_atr                   = 1.00;
input double strategy_sos_close_upper_third          = 0.70;
input bool   strategy_volume_filter_enabled          = true;
input int    strategy_sos_volume_mean_bars           = 20;
input double strategy_sos_volume_mult                = 1.50;
input double strategy_sos_spread_atr                 = 1.40;
input int    strategy_lps_min_bars                   = 3;
input int    strategy_lps_max_bars                   = 10;
input double strategy_lps_low_band_min_atr           = -0.20;
input double strategy_lps_low_band_max_atr           = 1.00;
input double strategy_lps_shallowness_ratio          = 1.20;
input double strategy_lps_no_close_back_atr          = 0.40;
input double strategy_lps_reversal_ratio             = 0.60;
input double strategy_tp_measured_move_mult          = 1.20;
input double strategy_tp1_measured_move_pct          = 0.60;
input double strategy_tp1_close_fraction             = 0.50;
input double strategy_failure_exit_atr               = 0.50;
input int    strategy_time_stop_bars                 = 60;
input double strategy_sl_atr_buffer                  = 0.40;
input double strategy_sl_cap_atr                     = 3.00;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 200;
input double strategy_macro_atr_buffer               = 2.00;
input int    strategy_reuse_guard_bars               = 80;
input bool   strategy_spread_filter_enabled          = true;
input double strategy_spread_max_atr                 = 0.25;

int      g_h_atr_h4 = INVALID_HANDLE;
int      g_h_sma_d1 = INVALID_HANDLE;
int      g_h_atr_d1 = INVALID_HANDLE;

bool     g_new_bar = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_active_high_band = 0.0;
double   g_active_measured_move = 0.0;
datetime g_active_entry_bar_time = 0;
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
      g_h_atr_d1 = iATR(_Symbol, PERIOD_D1, strategy_atr_period);
      if(g_h_sma_d1 == INVALID_HANDLE || g_h_atr_d1 == INVALID_HANDLE)
      {
         PrintFormat("QM5_%d: failed to create D1 macro handles", qm_ea_id);
         return false;
      }
   }
   return true;
}

void Strategy_ReleaseIndicators()
{
   if(g_h_atr_h4 != INVALID_HANDLE) { IndicatorRelease(g_h_atr_h4); g_h_atr_h4 = INVALID_HANDLE; }
   if(g_h_sma_d1 != INVALID_HANDLE) { IndicatorRelease(g_h_sma_d1); g_h_sma_d1 = INVALID_HANDLE; }
   if(g_h_atr_d1 != INVALID_HANDLE) { IndicatorRelease(g_h_atr_d1); g_h_atr_d1 = INVALID_HANDLE; }
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
   if(!HistorySelect(now - 120 * 24 * 60 * 60, now)) return false;

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

bool Strategy_MacroBias(const double atr_h4)
{
   if(!strategy_macro_bias_enabled) return true;
   if(g_h_sma_d1 == INVALID_HANDLE || g_h_atr_d1 == INVALID_HANDLE) return true;

   double ma_val[1];
   double atr_d1[1];
   if(CopyBuffer(g_h_sma_d1, 0, 1, 1, ma_val) < 1) return false;
   if(CopyBuffer(g_h_atr_d1, 0, 1, 1, atr_d1) < 1) return false;

   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, d1_rates) < 1) return false;

   // close > SMA(200, D1) - 2.0 * ATR(14, D1)
   return (d1_rates[0].close > (ma_val[0] - strategy_macro_atr_buffer * atr_d1[0]));
}

bool Strategy_FitLinearRegression(const MqlRates &rates[], const int start_shift, const int count, double &out_slope)
{
   out_slope = 0.0;
   if(count < 2 || start_shift < 0 || start_shift + count > ArraySize(rates))
      return false;

   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < count; ++i)
   {
      const int idx = start_shift + count - 1 - i;
      const double y = rates[idx].close;
      const double x = (double)i;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
   }
   const double denom = (double)count * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12) return false;
   out_slope = ((double)count * sum_xy - sum_x * sum_y) / denom;
   return true;
}

bool Strategy_AnalyzeTradingRange(const MqlRates &rates[],
                                 const int tr_end_shift,
                                 const int tr_len,
                                 const double atr,
                                 double &out_low_band,
                                 double &out_high_band,
                                 bool &out_spring_found)
{
   out_low_band = 0.0;
   out_high_band = 0.0;
   out_spring_found = false;

   if(tr_len < strategy_tr_min_bars || tr_end_shift < 0 || tr_end_shift + tr_len + strategy_prior_trend_bars > ArraySize(rates))
      return false;

   double closes[];
   double highs[];
   double lows[];
   ArrayResize(closes, tr_len);
   ArrayResize(highs, tr_len);
   ArrayResize(lows, tr_len);

   for(int i = 0; i < tr_len; ++i)
   {
      const int idx = tr_end_shift + i;
      closes[i] = rates[idx].close;
      highs[i] = rates[idx].high;
      lows[i] = rates[idx].low;
   }

   ArraySort(highs);
   ArraySort(lows);

   // Drop highest 5% and lowest 5% wicks to form robust quantile bounds
   const int trim_cnt = (int)MathFloor(0.05 * tr_len);
   const int high_top20_idx = (int)MathFloor(0.80 * (tr_len - 1));
   const int low_bot20_idx = (int)MathFloor(0.20 * (tr_len - 1));

   const double high_band = highs[high_top20_idx];
   const double low_band = lows[low_bot20_idx];

   if(high_band <= low_band) return false;

   // 1. Range amplitude: 4.0 <= (high_band - low_band)/ATR <= 14.0
   const double amp_atr = (high_band - low_band) / atr;
   if(amp_atr < strategy_tr_min_amplitude_atr || amp_atr > strategy_tr_max_amplitude_atr)
      return false;

   // 2. Range containment: >= 90% of bar closes inside [low_band, high_band]
   int inside_cnt = 0;
   for(int i = 0; i < tr_len; ++i)
   {
      if(closes[i] >= low_band && closes[i] <= high_band)
         inside_cnt++;
   }
   if((double)inside_cnt / (double)tr_len < strategy_tr_containment_pct)
      return false;

   // 3. Prior-trend gate: slope over 60 bars before trading range <= -0.10 * ATR per bar
   double pre_slope = 0.0;
   if(!Strategy_FitLinearRegression(rates, tr_end_shift + tr_len, strategy_prior_trend_bars, pre_slope))
      return false;
   if(pre_slope / atr > strategy_prior_trend_slope_atr)
      return false;

   // 4. Range stability: abs(slope_LR) inside range <= 0.05 * ATR per bar
   double in_slope = 0.0;
   if(!Strategy_FitLinearRegression(rates, tr_end_shift, tr_len, in_slope))
      return false;
   if(MathAbs(in_slope) / atr > strategy_tr_stability_slope_atr)
      return false;

   // 5. Spring or test occurred inside trading range
   // At some point inside TR, close <= low_band - 0.5 * ATR, followed by close back inside range within 4 bars
   const double spring_thresh = low_band - strategy_spring_atr_buffer * atr;
   for(int i = tr_len - 1; i >= strategy_spring_lookback_bars; --i)
   {
      const int idx = tr_end_shift + i;
      if(rates[idx].close <= spring_thresh)
      {
         // check if closed back inside range within 4 bars
         bool recovered = false;
         for(int k = 1; k <= strategy_spring_lookback_bars; ++k)
         {
            if(i - k >= 0)
            {
               const int rec_idx = tr_end_shift + (i - k);
               if(rates[rec_idx].close >= low_band)
               {
                  recovered = true;
                  break;
               }
            }
         }
         if(recovered)
         {
            out_spring_found = true;
            break;
         }
      }
   }
   if(!out_spring_found) return false;

   out_low_band = low_band;
   out_high_band = high_band;
   return true;
}

bool Strategy_CheckSOS(const MqlRates &rates[],
                      const int sos_shift,
                      const double high_band,
                      const double atr)
{
   if(sos_shift < 0 || sos_shift + strategy_sos_volume_mean_bars >= ArraySize(rates))
      return false;

   const MqlRates bar = rates[sos_shift];
   // 6. Range-break: close > high_band + 0.4 * ATR
   if(bar.close <= high_band + strategy_sos_breakout_atr * atr)
      return false;

   // 7. Bar magnitude: (close - open)/ATR >= 1.0 AND (close - low)/(high - low) >= 0.70
   if((bar.close - bar.open) / atr < strategy_sos_body_atr)
      return false;
   const double range = bar.high - bar.low;
   if(range <= 0.0) return false;
   if((bar.close - bar.low) / range < strategy_sos_close_upper_third)
      return false;

   // 8. Volume expansion: tick_volume >= 1.50 * mean(20 prior bars)
   if(strategy_volume_filter_enabled)
   {
      long vol_sum = 0;
      for(int i = 1; i <= strategy_sos_volume_mean_bars; ++i)
         vol_sum += rates[sos_shift + i].tick_volume;
      const double avg_vol = (double)vol_sum / (double)strategy_sos_volume_mean_bars;
      if(avg_vol > 0.0 && (double)bar.tick_volume < strategy_sos_volume_mult * avg_vol)
         return false;
   }

   // 9. Spread expansion: (high - low)/ATR >= 1.4
   if(range / atr < strategy_sos_spread_atr)
      return false;

   return true;
}

bool Strategy_CheckLPS(const MqlRates &rates[],
                      const int lps_shift,
                      const int sos_shift,
                      const double high_band,
                      const double atr)
{
   if(lps_shift < 1 || sos_shift <= lps_shift) return false;
   const int separation = sos_shift - lps_shift;
   if(separation < strategy_lps_min_bars || separation > strategy_lps_max_bars)
      return false;

   const MqlRates lps_bar = rates[lps_shift];
   const MqlRates sos_bar = rates[sos_shift];

   // 10. Pullback depth: low[t_LPS] >= high_band - 0.2*ATR AND low[t_LPS] <= high_band + 1.0*ATR
   if(lps_bar.low < high_band + strategy_lps_low_band_min_atr * atr ||
      lps_bar.low > high_band + strategy_lps_low_band_max_atr * atr)
      return false;

   // 11. Pullback shallowness: (close[t_SOS] - low[t_LPS]) / (close[t_SOS] - high_band) <= 1.2
   const double breakout_height = sos_bar.close - high_band;
   if(breakout_height <= 0.0) return false;
   if((sos_bar.close - lps_bar.low) / breakout_height > strategy_lps_shallowness_ratio)
      return false;

   // 12. No close back into range: no close between t_SOS+1 and t_LPS-1 below high_band - 0.4*ATR
   const double no_close_thresh = high_band - strategy_lps_no_close_back_atr * atr;
   for(int s = sos_shift - 1; s > lps_shift; --s)
   {
      if(rates[s].close < no_close_thresh)
         return false;
   }

   // 13. Reversal bar at LPS: close > open AND (close - low)/(high - low) >= 0.60
   if(lps_bar.close <= lps_bar.open) return false;
   const double lps_range = lps_bar.high - lps_bar.low;
   if(lps_range <= 0.0) return false;
   if((lps_bar.close - lps_bar.low) / lps_range < strategy_lps_reversal_ratio)
      return false;

   return true;
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

   if(!Strategy_MacroBias(atr))
      return false;

   const int needed_bars = strategy_tr_max_bars + strategy_prior_trend_bars + strategy_lps_max_bars + 20;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates);
   if(copied < needed_bars) return false;

   // The candidate LPS bar just completed at shift 1
   const int lps_shift = 1;

   // Search for valid SOS bar at shift in [lps_shift + strategy_lps_min_bars, lps_shift + strategy_lps_max_bars]
   for(int sos_shift = lps_shift + strategy_lps_min_bars; sos_shift <= lps_shift + strategy_lps_max_bars; ++sos_shift)
   {
      // Test different TR lengths
      for(int tr_len = strategy_tr_min_bars; tr_len <= strategy_tr_max_bars; tr_len += strategy_tr_step_bars)
      {
         const int tr_end_shift = sos_shift + 1;
         double low_band = 0.0, high_band = 0.0;
         bool spring_found = false;

         if(!Strategy_AnalyzeTradingRange(rates, tr_end_shift, tr_len, atr, low_band, high_band, spring_found))
            continue;

         if(!Strategy_CheckSOS(rates, sos_shift, high_band, atr))
            continue;

         if(!Strategy_CheckLPS(rates, lps_shift, sos_shift, high_band, atr))
            continue;

         // All 13 Wyckoff gates PASS!
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0) return false;

         // SL calculation: min(low[t_LPS-2..t_LPS]) - 0.4 * ATR
         double min_lps_low = rates[lps_shift].low;
         if(rates[lps_shift + 1].low < min_lps_low) min_lps_low = rates[lps_shift + 1].low;
         if(rates[lps_shift + 2].low < min_lps_low) min_lps_low = rates[lps_shift + 2].low;

         double initial_sl = min_lps_low - strategy_sl_atr_buffer * atr;
         if(ask - initial_sl > strategy_sl_cap_atr * atr)
            initial_sl = ask - strategy_sl_cap_atr * atr;

         // TP calculation: entry + 1.2 * (high_band - low_band)
         const double measured_move = high_band - low_band;
         const double full_tp = ask + strategy_tp_measured_move_mult * measured_move;

         req.type = QM_BUY;
         req.price = Strategy_NormalizePrice(ask);
         req.sl = Strategy_NormalizePrice(initial_sl);
         req.tp = Strategy_NormalizePrice(full_tp);
         req.reason = "SOS_LPS";
         req.symbol_slot = qm_magic_slot_offset;

         g_active_tp1_price = Strategy_NormalizePrice(ask + strategy_tp1_measured_move_pct * measured_move);
         g_tp1_done = false;
         g_active_high_band = high_band;
         g_active_measured_move = measured_move;
         g_active_entry_bar_time = rates[0].time;
         g_pattern_block_until = rates[0].time + strategy_reuse_guard_bars * PeriodSeconds(strategy_tf);

         return true;
      }
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

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);

   // 1. Partial close at 60% of measured-move (TP1)
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price >= g_active_tp1_price)
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
            // Move SL to Break-Even
            const double be_sl = Strategy_NormalizePrice(open_price);
            if(be_sl > current_sl)
            {
               trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else
      {
         g_tp1_done = true;
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   double atr_val[1];
   if(CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_val) < 1) return false;
   const double atr = atr_val[0];

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_tf, 1, 1, rates) < 1) return false;

   // 1. Pattern-failure hard exit: if any H4 close after entry goes below high_band - 0.5 * ATR
   if(g_active_high_band > 0.0 && rates[0].close < (g_active_high_band - strategy_failure_exit_atr * atr))
   {
      PrintFormat("QM5_%d: Pattern failure exit triggered (close %G < %G)",
                  qm_ea_id, rates[0].close, g_active_high_band - strategy_failure_exit_atr * atr);
      return true;
   }

   // 2. Time-stop: 60 H4 bars after entry
   const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(pos_time > 0)
   {
      const int bars_open = iBarShift(_Symbol, strategy_tf, pos_time, false);
      if(bars_open >= strategy_time_stop_bars)
      {
         PrintFormat("QM5_%d: Time-stop exit triggered after %d bars", qm_ea_id, bars_open);
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
