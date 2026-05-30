#property strict
#property version   "5.0"
#property description "QM5_10308 HFT Pairs Z-Score Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10308;
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
input ENUM_TIMEFRAMES strategy_tf                  = PERIOD_M5;
input int    strategy_formation_bars               = 17280;
input int    strategy_z_bars                       = 5760;
input double strategy_min_corr                     = 0.80;
input double strategy_entry_z                      = 2.0;
input double strategy_exit_z                       = 0.25;
input double strategy_stop_z                       = 3.5;
input int    strategy_max_hold_bars                = 24;
input int    strategy_atr_period                   = 14;
input double strategy_atr_sl_mult                  = 2.0;
input int    strategy_session_start_hour           = 13;
input int    strategy_session_start_minute         = 0;
input int    strategy_session_minutes              = 180;
input int    strategy_no_entry_last_minutes        = 30;
input double strategy_max_cost_fraction            = 0.20;

double   g_last_z = 0.0;
double   g_last_spread_sd = 0.0;
double   g_last_corr = 0.0;
bool     g_pair_state_ready = false;

string Strategy_PeerSymbol()
  {
   if(_Symbol == "EURUSD.DWX") return "GBPUSD.DWX";
   if(_Symbol == "GBPUSD.DWX") return "EURUSD.DWX";
   if(_Symbol == "AUDUSD.DWX") return "NZDUSD.DWX";
   if(_Symbol == "NZDUSD.DWX") return "AUDUSD.DWX";
   if(_Symbol == "SP500.DWX")  return "NDX.DWX";
   if(_Symbol == "NDX.DWX")    return "SP500.DWX";
   if(_Symbol == "XAUUSD.DWX") return "XAGUSD.DWX";
   if(_Symbol == "XAGUSD.DWX") return "XAUUSD.DWX";
   return "";
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InSession(const datetime t, const bool allow_last_block)
  {
   const int minute = Strategy_MinuteOfDay(t);
   const int start = strategy_session_start_hour * 60 + strategy_session_start_minute;
   const int end = start + strategy_session_minutes;
   const int entry_end = end - strategy_no_entry_last_minutes;
   if(allow_last_block)
      return (minute >= start && minute < end);
   return (minute >= start && minute < entry_end);
  }

bool Strategy_CurrentPosition(ulong &ticket, datetime &opened)
  {
   ticket = 0;
   opened = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = pos_ticket;
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_CalcZ(double &z, double &sd, double &corr)
  {
   z = 0.0;
   sd = 0.0;
   corr = 0.0;

   const string peer = Strategy_PeerSymbol();
   if(peer == "")
      return false;
   SymbolSelect(peer, true);

   const int bars = MathMax(strategy_formation_bars, strategy_z_bars) + 1;
   if(strategy_formation_bars < 50 || strategy_z_bars < 20 || strategy_z_bars > strategy_formation_bars)
      return false;

   double a[];
   double b[];
   ArraySetAsSeries(a, true);
   ArraySetAsSeries(b, true);
   if(CopyClose(_Symbol, strategy_tf, 1, bars, a) < bars)
      return false;
   if(CopyClose(peer, strategy_tf, 1, bars, b) < bars)
      return false;

   const int n = strategy_formation_bars;
   const int oldest = n - 1;
   if(a[oldest] <= 0.0 || b[oldest] <= 0.0)
      return false;

   double sum_ra = 0.0;
   double sum_rb = 0.0;
   double sum_ra2 = 0.0;
   double sum_rb2 = 0.0;
   double sum_rarb = 0.0;
   int rn = 0;
   for(int i = oldest - 1; i >= 0; --i)
     {
      if(a[i + 1] <= 0.0 || b[i + 1] <= 0.0)
         return false;
      const double ra = (a[i] / a[i + 1]) - 1.0;
      const double rb = (b[i] / b[i + 1]) - 1.0;
      sum_ra += ra;
      sum_rb += rb;
      sum_ra2 += ra * ra;
      sum_rb2 += rb * rb;
      sum_rarb += ra * rb;
      ++rn;
     }
   const double cov_r = sum_rarb - (sum_ra * sum_rb / rn);
   const double var_ra = sum_ra2 - (sum_ra * sum_ra / rn);
   const double var_rb = sum_rb2 - (sum_rb * sum_rb / rn);
   if(var_ra <= 0.0 || var_rb <= 0.0)
      return false;
   corr = cov_r / MathSqrt(var_ra * var_rb);

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_y2 = 0.0;
   for(int i = oldest; i >= 0; --i)
     {
      const double x = (a[i] / a[oldest]) - 1.0;
      const double y = (b[i] / b[oldest]) - 1.0;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_y2 += y * y;
     }
   const double beta_den = sum_y2 - (sum_y * sum_y / n);
   if(beta_den <= 0.0)
      return false;
   const double beta = (sum_xy - (sum_x * sum_y / n)) / beta_den;

   const int zn = strategy_z_bars;
   double sum_s = 0.0;
   double sum_s2 = 0.0;
   for(int i = zn - 1; i >= 0; --i)
     {
      const double x = (a[i] / a[oldest]) - 1.0;
      const double y = (b[i] / b[oldest]) - 1.0;
      const double s = x - beta * y;
      sum_s += s;
      sum_s2 += s * s;
     }
   const double mean = sum_s / zn;
   const double var_s = (sum_s2 - (sum_s * sum_s / zn)) / (zn - 1);
   if(var_s <= 0.0)
      return false;
   sd = MathSqrt(var_s);

   const double current_spread = ((a[0] / a[oldest]) - 1.0) -
                                 beta * ((b[0] / b[oldest]) - 1.0);
   z = (current_spread - mean) / sd;
   return true;
  }

bool Strategy_SpreadCostOK(const double abs_z, const double sd)
  {
   const string peer = Strategy_PeerSymbol();
   if(peer == "" || abs_z <= 0.0 || sd <= 0.0)
      return false;

   const double bid_a = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_a = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_b = SymbolInfoDouble(peer, SYMBOL_BID);
   const double ask_b = SymbolInfoDouble(peer, SYMBOL_ASK);
   if(bid_a <= 0.0 || ask_a <= 0.0 || bid_b <= 0.0 || ask_b <= 0.0)
      return false;

   const double cost = ((ask_a - bid_a) / bid_a) + ((ask_b - bid_b) / bid_b);
   const double expected = abs_z * sd;
   return (cost <= expected * strategy_max_cost_fraction);
  }

void Strategy_AdvanceState()
  {
   double z;
   double sd;
   double corr;
   g_pair_state_ready = Strategy_CalcZ(z, sd, corr);
   if(!g_pair_state_ready)
      return;

   g_last_z = z;
   g_last_spread_sd = sd;
   g_last_corr = corr;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return !Strategy_InSession(TimeCurrent(), false);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket;
   datetime opened;
   if(Strategy_CurrentPosition(ticket, opened))
      return false;

   if(!g_pair_state_ready)
      return false;

   if(g_last_corr < strategy_min_corr)
      return false;
   if(!Strategy_SpreadCostOK(MathAbs(g_last_z), g_last_spread_sd))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_last_z >= strategy_entry_z)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "HFT_PAIRS_Z_SHORT_PRIMARY";
      return (req.sl > bid);
     }

   if(g_last_z <= -strategy_entry_z)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "HFT_PAIRS_Z_LONG_PRIMARY";
      return (req.sl > 0.0 && req.sl < ask);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   datetime opened;
   if(!Strategy_CurrentPosition(ticket, opened))
      return false;
   if(!g_pair_state_ready)
      return false;

   if(MathAbs(g_last_z) <= strategy_exit_z && g_last_spread_sd > 0.0)
      return true;
   if(MathAbs(g_last_z) >= strategy_stop_z && g_last_spread_sd > 0.0)
      return true;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_tf);
   if(hold_seconds > 0 && TimeCurrent() - opened >= hold_seconds)
      return true;

   const int start = strategy_session_start_hour * 60 + strategy_session_start_minute;
   const int first_hour_end = start + 60;
   const int opened_minute = Strategy_MinuteOfDay(opened);
   if(opened_minute >= start && opened_minute < first_hour_end &&
      !Strategy_InSession(TimeCurrent(), true))
      return true;

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10308_hft_pairs_z\"}");
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

   const bool is_new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   if(is_new_bar)
     {
      Strategy_AdvanceState();
      QM_EquityStreamOnNewBar();
     }

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

   QM_EntryRequest req;
   if(is_new_bar && Strategy_EntrySignal(req))
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
