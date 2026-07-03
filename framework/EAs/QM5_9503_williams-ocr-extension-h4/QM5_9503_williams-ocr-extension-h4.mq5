#property strict
#property version   "5.0"
#property description "QM5_9503 Williams OCR Extension H4"

#include <QM/QM_Common.mqh>

// QM5_9503 - Larry Williams OCR extension-confirmation continuation on H4.
// The setup bar is a wide-body OCR bar in the SMA(50) trend direction. The next
// closed H4 bar must extend through the setup extreme; entry is at the following
// H4 open with fixed structure stop, projected target, and time stop.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9503;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input int    strategy_sma_period          = 50;
input double strategy_ocr_ratio_min       = 0.85;
input double strategy_range_atr_mult      = 1.50;
input double strategy_extension_atr_mult  = 0.10;
input double strategy_sl_atr_buffer       = 0.30;
input double strategy_tp_range_mult       = 1.50;
input double strategy_spread_atr_mult     = 0.20;
input int    strategy_time_stop_h4_bars   = 12;

const int RATES_NEEDED = 4;

int Strategy_SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "AUDUSD.DWX") return 3;
   if(_Symbol == "USDCAD.DWX") return 4;
   if(_Symbol == "USDCHF.DWX") return 5;
   if(_Symbol == "NZDUSD.DWX") return 6;
   if(_Symbol == "XAUUSD.DWX") return 7;
   if(_Symbol == "XTIUSD.DWX") return 8;
   if(_Symbol == "GDAXI.DWX")  return 9;
   if(_Symbol == "NDX.DWX")    return 10;
   if(_Symbol == "WS30.DWX")   return 11;
   if(_Symbol == "UK100.DWX")  return 12;
   return -1;
  }

bool Strategy_ValidInputs()
  {
   return (strategy_atr_period > 0 &&
           strategy_sma_period > 0 &&
           strategy_ocr_ratio_min > 0.0 &&
           strategy_ocr_ratio_min <= 1.0 &&
           strategy_range_atr_mult > 0.0 &&
           strategy_extension_atr_mult >= 0.0 &&
           strategy_sl_atr_buffer >= 0.0 &&
           strategy_tp_range_mult > 0.0 &&
           strategy_spread_atr_mult > 0.0 &&
           strategy_time_stop_h4_bars > 0);
  }

bool Strategy_HaveOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || atr <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return false;
   return true;
  }

double Strategy_OCRRatio(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return MathAbs(bar.close - bar.open) / MathMax(range, 1e-9);
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const int slot = Strategy_SymbolSlot();
   if(slot < 0)
      return true;
   if(slot != qm_magic_slot_offset)
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

   if(!Strategy_ValidInputs())
      return false;
   if(Strategy_HaveOpenPosition())
      return false;

   const int slot = Strategy_SymbolSlot();
   if(slot < 0 || slot != qm_magic_slot_offset)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, RATES_NEEDED, rates); // perf-allowed: bounded OCR setup/extension window; EntrySignal is called only after QM_IsNewBar().
   if(copied < RATES_NEEDED)
      return false;

   const MqlRates extension_bar = rates[0]; // t+1: must extend through setup extreme
   const MqlRates setup_bar = rates[1];     // t: OCR setup bar
   const MqlRates prior_bar = rates[2];     // t-1: conflict guard

   const double setup_range = setup_bar.high - setup_bar.low;
   if(setup_bar.high <= 0.0 || setup_bar.low <= 0.0 ||
      extension_bar.high <= 0.0 || extension_bar.low <= 0.0 ||
      prior_bar.high <= 0.0 || prior_bar.low <= 0.0 ||
      setup_range <= 0.0)
      return false;

   const double atr_prior = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 3);
   const double atr_setup = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 2);
   const double atr_entry = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double sma_setup = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 2, PRICE_CLOSE);
   if(atr_prior <= 0.0 || atr_setup <= 0.0 || atr_entry <= 0.0 || sma_setup <= 0.0)
      return false;

   if(Strategy_OCRRatio(setup_bar) < strategy_ocr_ratio_min)
      return false;
   if(setup_range < strategy_range_atr_mult * atr_prior)
      return false;
   if(!Strategy_SpreadAllowed(atr_entry))
      return false;

   const double prior_ocr = Strategy_OCRRatio(prior_bar);
   const bool prior_bear_ocr = (prior_ocr >= strategy_ocr_ratio_min && prior_bar.close < prior_bar.open);
   const bool prior_bull_ocr = (prior_ocr >= strategy_ocr_ratio_min && prior_bar.close > prior_bar.open);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(setup_bar.close > setup_bar.open && setup_bar.close > sma_setup && !prior_bear_ocr)
     {
      const bool extended = (extension_bar.high > setup_bar.high + strategy_extension_atr_mult * atr_setup);
      const bool closed_positive = (extension_bar.close > setup_bar.close);
      if(!extended || !closed_positive)
         return false;

      const double sl_raw = setup_bar.low - strategy_sl_atr_buffer * atr_entry;
      const double tp_raw = extension_bar.close + strategy_tp_range_mult * setup_range;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "WILLIAMS_OCR_EXTENSION_LONG";
      req.symbol_slot = slot;
      return true;
     }

   if(setup_bar.close < setup_bar.open && setup_bar.close < sma_setup && !prior_bull_ocr)
     {
      const bool extended = (extension_bar.low < setup_bar.low - strategy_extension_atr_mult * atr_setup);
      const bool closed_positive = (extension_bar.close < setup_bar.close);
      if(!extended || !closed_positive)
         return false;

      const double sl_raw = setup_bar.high + strategy_sl_atr_buffer * atr_entry;
      const double tp_raw = extension_bar.close - strategy_tp_range_mult * setup_range;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
      if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "WILLIAMS_OCR_EXTENSION_SHORT";
      req.symbol_slot = slot;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0 || strategy_time_stop_h4_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 &&
         now >= opened + (long)(strategy_time_stop_h4_bars + 1) * h4_seconds)
         return true;
     }

   return false;
  }

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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9503_williams-ocr-extension-h4\"}");
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

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
