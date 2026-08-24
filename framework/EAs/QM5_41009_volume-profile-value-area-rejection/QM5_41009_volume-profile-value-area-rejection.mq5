#property strict
#property version   "5.0"
#property description "QM5_41009 Volume Profile Value Area Rejection"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41009
// Volume Profile Value Area (VAH/VAL) Rejection Scalper
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41009;
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
input double InpValueAreaPct            = 70.0;   // Value Area volume percentile
input int    InpBufferTicks             = 4;      // Rejection buffer in ticks
input int    InpAtrPeriod               = 14;     // Stop loss ATR period
input double InpAtrSlMult               = 1.5;    // Stop loss ATR multiplier
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of M5 ATR(14)
input bool   InpEnableBreakEven         = true;   // Move to break-even at +1.0R
input int    InpBucketTicks             = 10;     // Volume profile bucket granularity in ticks
input double InpDailyRealizedLossHaltPct = 2.0;  // Halt entries at account daily realized loss
input double InpDailyHardStopPct        = 2.5;    // Flatten/halt at daily equity drawdown
input double InpTotalDrawdownStopPct    = 5.0;    // Flatten/halt from initial strategy equity
input double InpSlippageTicks           = 3.0;    // Maximum market-order deviation in ticks

#define STRATEGY_MAX_PROFILE_BUCKETS 1000000

// -----------------------------------------------------------------------------
// Cached Profile State
// -----------------------------------------------------------------------------

datetime g_profile_day   = 0;
bool     g_profile_valid = false;
double   g_prior_vah     = 0.0;
double   g_prior_val     = 0.0;
double   g_prior_poc     = 0.0;
double   g_initial_equity = 0.0;
datetime g_realized_cache_second = 0;
double   g_day_start_balance = 0.0;
double   g_daily_realized_loss_pct = 0.0;
bool     g_daily_realized_loss_valid = false;

bool Strategy_ValidateInputs()
{
   return (InpValueAreaPct >= 68.0 && InpValueAreaPct <= 72.0 &&
           InpBufferTicks >= 2 && InpBufferTicks <= 8 &&
           InpAtrPeriod >= 10 && InpAtrPeriod <= 30 &&
           InpAtrSlMult >= 1.0 && InpAtrSlMult <= 3.0 &&
           InpSpreadAtrMult >= 1.0 && InpSpreadAtrMult <= 3.0 &&
           InpBucketTicks >= 5 && InpBucketTicks <= 20 &&
           InpDailyRealizedLossHaltPct > 0.0 &&
           InpDailyHardStopPct > InpDailyRealizedLossHaltPct &&
           InpTotalDrawdownStopPct > InpDailyHardStopPct &&
           InpSlippageTicks > 0.0);
}

string Strategy_InitialEquityKey()
{
   return StringFormat("QM5_41009_INITIAL_EQUITY_%I64d_%d",
                       AccountInfoInteger(ACCOUNT_LOGIN), QM_FrameworkMagic());
}

bool Strategy_InitCapitalPreservation()
{
   const double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(current_equity <= 0.0)
      return false;

   if(MQLInfoInteger(MQL_TESTER) != 0)
   {
      g_initial_equity = current_equity;
      return true;
   }

   const string key = Strategy_InitialEquityKey();
   if(GlobalVariableCheck(key))
      g_initial_equity = GlobalVariableGet(key);
   else
   {
      g_initial_equity = current_equity;
      if(GlobalVariableSet(key, g_initial_equity) == 0)
         return false;
   }
   return (g_initial_equity > 0.0);
}

bool Strategy_UpdateDailyRealizedLoss()
{
   const datetime broker_now = TimeCurrent();
   if(g_realized_cache_second == broker_now && g_daily_realized_loss_valid)
      return true;

   const datetime day_start = BrokerDayStart(broker_now);
   if(!HistorySelect(day_start, broker_now))
   {
      g_daily_realized_loss_valid = false;
      return false;
   }

   double realized_net = 0.0;
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      realized_net += HistoryDealGetDouble(deal, DEAL_PROFIT);
      realized_net += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      realized_net += HistoryDealGetDouble(deal, DEAL_SWAP);
      realized_net += HistoryDealGetDouble(deal, DEAL_FEE);
   }

   const double day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - realized_net;
   if(day_start_balance <= 0.0)
   {
      g_daily_realized_loss_valid = false;
      return false;
   }

   g_day_start_balance = day_start_balance;
   g_daily_realized_loss_pct = MathMax(0.0, (-realized_net / day_start_balance) * 100.0);
   g_realized_cache_second = broker_now;
   g_daily_realized_loss_valid = true;
   return true;
}

bool Strategy_CapitalPreservationCheck()
{
   if(!QM_KillSwitchCheck())
      return false;
   if(!Strategy_UpdateDailyRealizedLoss())
      return false;
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0 || g_day_start_balance <= 0.0 || equity_now <= 0.0)
      return false;
   const double daily_drawdown_pct =
      MathMax(0.0, ((g_day_start_balance - equity_now) / g_day_start_balance) * 100.0);
   if(daily_drawdown_pct >= InpDailyHardStopPct)
   {
      QM_KillSwitchTrip(KS_DAILY_LOSS,
                        StringFormat("{\"day_start_balance\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_day_start_balance, equity_now,
                                     daily_drawdown_pct, InpDailyHardStopPct));
      return false;
   }
   const double total_drawdown_pct =
      MathMax(0.0, ((g_initial_equity - equity_now) / g_initial_equity) * 100.0);
   if(total_drawdown_pct >= InpTotalDrawdownStopPct)
   {
      QM_KillSwitchTrip("KS_TOTAL_DRAWDOWN",
                        StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_initial_equity, equity_now,
                                     total_drawdown_pct, InpTotalDrawdownStopPct));
      return false;
   }
   return true;
}

int Strategy_SlippageDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return -1;
   return (int)MathFloor((InpSlippageTicks * tick_size / point) + 1e-9);
}

datetime BrokerDayStart(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

datetime PreviousTradingDayStart(const datetime today_start)
{
   datetime d = today_start - 86400;
   for(int i = 0; i < 7; ++i)
   {
      MqlDateTime dt;
      TimeToStruct(d, dt);
      if(dt.day_of_week >= 1 && dt.day_of_week <= 5)
         return BrokerDayStart(d);
      d -= 86400;
   }
   return today_start - 86400;
}

bool BuildPriorProfile(const datetime today_start,
                       double &out_vah, double &out_val, double &out_poc)
{
   out_vah = out_val = out_poc = 0.0;

   const datetime prior_start = PreviousTradingDayStart(today_start);
   const datetime prior_end   = prior_start + 86400;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double bucket = point * (double)InpBucketTicks;
   if(bucket <= 0.0)
      return false;

   const int total_bars = Bars(_Symbol, PERIOD_CURRENT); // perf-allowed: gated to once per broker-day profile calculation
   if(total_bars <= 0)
      return false;

   double day_low = 0.0, day_high = 0.0;
   bool have_range = false;
   int bars_scanned = 0;
   const int scan_cap = 400;

   for(int s = 1; s <= scan_cap && s < total_bars; ++s)
   {
      const datetime bt = iTime(_Symbol, PERIOD_CURRENT, s); // perf-allowed: gated to once per broker-day profile calculation
      if(bt == 0) break;
      if(bt >= prior_end) continue;
      if(bt < prior_start) break;

      const double hi = iHigh(_Symbol, PERIOD_CURRENT, s); // perf-allowed: gated to once per broker-day profile calculation
      const double lo = iLow(_Symbol, PERIOD_CURRENT, s);  // perf-allowed: gated to once per broker-day profile calculation
      if(hi <= 0.0 || lo <= 0.0) continue;

      if(!have_range)
      {
         day_high = hi;
         day_low = lo;
         have_range = true;
      }
      else
      {
         if(hi > day_high) day_high = hi;
         if(lo < day_low) day_low = lo;
      }
      bars_scanned++;
   }

   if(!have_range || bars_scanned <= 0 || day_high <= day_low)
      return false;

   const double raw_bucket_count = (day_high - day_low) / bucket;
   if(!MathIsValidNumber(raw_bucket_count) ||
      raw_bucket_count < 0.0 ||
      raw_bucket_count >= STRATEGY_MAX_PROFILE_BUCKETS)
      return false;
   const int n_buckets = (int)raw_bucket_count + 1;
   if(n_buckets <= 0 || n_buckets > STRATEGY_MAX_PROFILE_BUCKETS)
      return false;

   double vol[];
   if(ArrayResize(vol, n_buckets) != n_buckets)
      return false;
   ArrayInitialize(vol, 0.0);

   double total_vol = 0.0;
   for(int s = 1; s <= scan_cap && s < total_bars; ++s)
   {
      const datetime bt = iTime(_Symbol, PERIOD_CURRENT, s); // perf-allowed: gated to once per broker-day profile calculation
      if(bt == 0) break;
      if(bt >= prior_end) continue;
      if(bt < prior_start) break;

      const double hi = iHigh(_Symbol, PERIOD_CURRENT, s); // perf-allowed: gated to once per broker-day profile calculation
      const double lo = iLow(_Symbol, PERIOD_CURRENT, s);  // perf-allowed: gated to once per broker-day profile calculation
      const double tv = (double)iVolume(_Symbol, PERIOD_CURRENT, s); // perf-allowed: gated to once per broker-day profile calculation
      if(hi <= 0.0 || lo <= 0.0 || tv <= 0.0) continue;

      int b_lo = (int)((lo - day_low) / bucket);
      int b_hi = (int)((hi - day_low) / bucket);
      if(b_lo < 0) b_lo = 0;
      if(b_hi > n_buckets - 1) b_hi = n_buckets - 1;
      if(b_hi < b_lo) b_hi = b_lo;

      const int span = (b_hi - b_lo) + 1;
      const double share = tv / (double)span;
      for(int b = b_lo; b <= b_hi; ++b)
      {
         if(b >= ArraySize(vol)) continue;
         vol[b] += share;
         total_vol += share;
      }
   }

   if(total_vol <= 0.0)
      return false;

   int poc_idx = 0;
   double poc_vol = vol[0];
   for(int b = 1; b < n_buckets; ++b)
   {
      if(vol[b] > poc_vol)
      {
         poc_vol = vol[b];
         poc_idx = b;
      }
   }

   const double target_vol = total_vol * (InpValueAreaPct / 100.0);
   if(poc_idx < 0 || poc_idx >= ArraySize(vol))
      return false;
   double captured = vol[poc_idx];
   int lo_idx = poc_idx;
   int hi_idx = poc_idx;

   for(int iter = 0; iter < n_buckets && captured < target_vol; ++iter)
   {
      const bool can_down = (lo_idx > 0 && lo_idx - 1 < ArraySize(vol));
      const bool can_up   = (hi_idx < n_buckets - 1 && hi_idx + 1 < ArraySize(vol));
      if(!can_down && !can_up)
         break;

      const double vol_down = can_down ? vol[lo_idx - 1] : -1.0;
      const double vol_up   = can_up   ? vol[hi_idx + 1] : -1.0;

      if(vol_up >= vol_down && can_up)
      {
         hi_idx++;
         if(hi_idx < 0 || hi_idx >= ArraySize(vol)) break;
         captured += vol[hi_idx];
      }
      else if(can_down)
      {
         lo_idx--;
         if(lo_idx < 0 || lo_idx >= ArraySize(vol)) break;
         captured += vol[lo_idx];
      }
      else if(can_up)
      {
         hi_idx++;
         if(hi_idx < 0 || hi_idx >= ArraySize(vol)) break;
         captured += vol[hi_idx];
      }
   }

   out_poc = day_low + (poc_idx + 0.5) * bucket;
   out_val = day_low + lo_idx * bucket;
   out_vah = day_low + (hi_idx + 1) * bucket;

   return (out_vah > out_val);
}

void AdvanceState_OnNewBar()
{
   const datetime broker_now = TimeCurrent();
   const datetime day_start  = BrokerDayStart(broker_now);

   if(day_start != g_profile_day)
   {
      double vah, val, poc;
      g_profile_valid = BuildPriorProfile(day_start, vah, val, poc);
      if(g_profile_valid)
      {
         g_prior_vah = vah;
         g_prior_val = val;
         g_prior_poc = poc;
      }
      g_profile_day = day_start;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!Strategy_UpdateDailyRealizedLoss())
      return true;
   if(g_daily_realized_loss_pct >= InpDailyRealizedLossHaltPct)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, 14, 1);
      if(atr > 0.0 && (ask - bid) > InpSpreadAtrMult * atr)
         return true;
   }

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   if((dt.hour == 23 && dt.min >= 55) || (dt.hour == 0 && dt.min < 5))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_profile_valid)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: single closed bar read behind QM_IsNewBar
   const double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: single closed bar read behind QM_IsNewBar
   const double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: single closed bar read behind QM_IsNewBar
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: single closed bar read behind QM_IsNewBar
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buffer = InpBufferTicks * point;

   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod, 1);
   if(atr <= 0.0)
      return false;

   // Long: Low probed <= VAL + buffer and Close > VAL and bullish candle (Close > Open)
   if(low1 <= g_prior_val + buffer && close1 > g_prior_val && close1 > open1)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - InpAtrSlMult * atr;
      if(g_prior_poc <= ask)
         return false;
      req.tp = g_prior_poc;
      req.reason = "VA_REJECTION_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short: High probed >= VAH - buffer and Close < VAH and bearish candle (Close < Open)
   if(high1 >= g_prior_vah - buffer && close1 < g_prior_vah && close1 < open1)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + InpAtrSlMult * atr;
      if(g_prior_poc >= bid)
         return false;
      req.tp = g_prior_poc;
      req.reason = "VA_REJECTION_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   if(!InpEnableBreakEven)
      return;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0 || open_price <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double init_risk = MathAbs(open_price - current_sl);
         if(init_risk > 0.0 && (bid - open_price) >= init_risk && current_sl < open_price)
         {
            QM_TM_MoveSL(ticket, open_price + 2.0 * point, "BE_1R");
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double init_risk = MathAbs(current_sl - open_price);
         if(init_risk > 0.0 && (open_price - ask) >= init_risk && (current_sl > open_price || current_sl == 0.0))
         {
            QM_TM_MoveSL(ticket, open_price - 2.0 * point, "BE_1R");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M5,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "V5 framework Friday-close safety override; approved card declares no Friday rule"))
      return INIT_FAILED;

   const int deviation_points = Strategy_SlippageDeviationPoints();
   if(deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id, qm_news_mode_legacy, deviation_points,
                     qm_stress_reject_probability, qm_news_temporal,
                     qm_news_compliance, QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), 0.0, 0.0, 1.0))
      return INIT_FAILED;
   if(!Strategy_InitCapitalPreservation())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41009\",\"ea\":\"volume-profile-value-area-rejection\"}");
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

   if(!Strategy_CapitalPreservationCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;

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

   if(Strategy_NoTradeFilter()) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_IsNewBar())
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();

      QM_EntryRequest req;
      ZeroMemory(req);
      if(Strategy_EntrySignal(req))
      {
         ulong out_ticket = 0;
         QM_TM_OpenPosition(req, out_ticket);
      }
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
