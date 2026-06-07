#property strict
#property version   "5.0"
#property description "QM5_11183 Freqtrade Strategy005 Volume Spike SMA Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11183;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    buy_volumeAVG                = 150;
input double buy_volume_spike_mult        = 4.0;
input double buy_rsi                      = 26.0;
input double buy_fastd                    = 1.0;
input double buy_fishRsiNorma             = 5.0;
input int    strategy_sma_period          = 40;
input int    strategy_rsi_period          = 14;
input int    strategy_stoch_k             = 5;
input int    strategy_stoch_d             = 3;
input int    strategy_stoch_slow          = 3;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_di_period           = 14;
input double sell_rsi                     = 74.0;
input double sell_minusDI                 = 4.0;
input double strategy_stop_loss_pct       = 10.0;
input int    strategy_max_spread_points   = 0;

double Strategy_FisherRsiNorm(const double rsi_value)
  {
   const double clipped = MathMax(0.0, MathMin(100.0, rsi_value));
   const double scaled = 0.1 * (clipped - 50.0);
   const double expv = MathExp(2.0 * scaled);
   if(expv <= 0.0)
      return 50.0;
   const double fisher = (expv - 1.0) / (expv + 1.0);
   return 50.0 * (fisher + 1.0);
  }

bool Strategy_LoadClosedRates(MqlRates &rates[], const int required_bars)
  {
   if(required_bars <= 0)
      return false;

   ArrayResize(rates, required_bars);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, required_bars, rates); // perf-allowed: Strategy_EntrySignal is called only after the skeleton QM_IsNewBar() gate.
   return (copied == required_bars);
  }

bool Strategy_GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      return true;
     }

   return false;
  }

double Strategy_RoiThresholdPct(const long hold_seconds)
  {
   const long hold_minutes = hold_seconds / 60;
   if(hold_minutes < 20)
      return 5.0;
   if(hold_minutes < 40)
      return 4.0;
   if(hold_minutes < 80)
      return 3.0;
   if(hold_minutes < 1440)
      return 2.0;
   return 1.0;
  }

// No Trade Filter (time, spread, news): framework handles time/news/Friday;
// this hook adds the card's M5 chart guard and optional spread cap.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points <= 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: closed-bar volume spike below SMA40 with stochastic, RSI, and
// normalized Fisher RSI filters. Long-only, next-bar market entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(buy_volumeAVG < 1 || buy_volume_spike_mult <= 0.0 ||
      strategy_sma_period < 1 || strategy_rsi_period < 1 ||
      strategy_stoch_k < 1 || strategy_stoch_d < 1 || strategy_stoch_slow < 1 ||
      strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 || strategy_di_period < 1 ||
      strategy_stop_loss_pct <= 0.0)
      return false;

   ulong existing_ticket = 0;
   if(Strategy_GetOurPosition(existing_ticket))
      return false;

   const int required = MathMax(buy_volumeAVG, 2);
   MqlRates rates[];
   if(!Strategy_LoadClosedRates(rates, required))
      return false;

   const int current = required - 1;
   const double close_last = rates[current].close;
   const long volume_last = rates[current].tick_volume;
   if(close_last <= 0.00000200 || volume_last <= 0)
      return false;

   double volume_sum = 0.0;
   for(int i = required - buy_volumeAVG; i < required; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;
      volume_sum += (double)rates[i].tick_volume;
     }
   const double volume_avg = volume_sum / (double)buy_volumeAVG;
   if(volume_avg <= 0.0 || (double)volume_last <= volume_avg * buy_volume_spike_mult)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_period, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double fastk = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double fastd = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   if(sma <= 0.0 || rsi <= 0.0)
      return false;

   const double fisher_norm = Strategy_FisherRsiNorm(rsi);
   if(close_last >= sma)
      return false;
   if(fastd <= fastk)
      return false;
   if(rsi <= buy_rsi)
      return false;
   if(fastd <= buy_fastd)
      return false;
   if(fisher_norm >= buy_fishRsiNorma)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = NormalizeDouble(entry * (1.0 - strategy_stop_loss_pct / 100.0), _Digits);
   req.tp = NormalizeDouble(entry * 1.05, _Digits);
   if(req.sl <= 0.0 || req.tp <= 0.0 || req.sl >= entry || req.tp <= entry)
      return false;

   req.reason = "FT005_VOLUME_SMA_REVERSAL_LONG";
   return true;
  }

// Trade Management: source minimal ROI ladder; no trailing, pyramiding, grid,
// or martingale logic.
void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(open_price <= 0.0 || bid <= 0.0)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double profit_pct = 100.0 * (bid - open_price) / open_price;
      if(profit_pct >= Strategy_RoiThresholdPct((long)(now - open_time)))
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Trade Close: source rsi-macd-minusdi sell branch.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(ticket))
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_di_period, 1);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   return (rsi_prev <= sell_rsi &&
           rsi_now > sell_rsi &&
           macd_main < 0.0 &&
           minus_di > sell_minusDI);
  }

// News Filter Hook: callable for P8; central two-axis news filter remains the
// authority for this card's high-impact blackout.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11183_ft005-vol-sma\"}");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
