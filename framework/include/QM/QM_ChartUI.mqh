#ifndef QM_CHARTUI_MQH
#define QM_CHARTUI_MQH

#include "..\\QM_Branding.mqh"
#include "QM_Logger.mqh"

enum QM_ChartUICorner
  {
   QM_CHARTUI_TOP_LEFT = 0,
   QM_CHARTUI_TOP_RIGHT,
   QM_CHARTUI_BOTTOM_LEFT,
   QM_CHARTUI_BOTTOM_RIGHT
  };

input bool            qm_chartui_enabled = true;
input QM_ChartUICorner qm_chartui_corner = QM_CHARTUI_TOP_LEFT;

bool      g_qm_chartui_initialized          = false;
long      g_qm_chartui_chart_id             = 0;
int       g_qm_chartui_ea_id                = 0;
string    g_qm_chartui_slug                 = "";
datetime  g_qm_chartui_last_event_time      = 0;
string    g_qm_chartui_last_event           = "INIT";
string    g_qm_chartui_last_payload_summary = "{}";

int       g_qm_chartui_width                = 720;
int       g_qm_chartui_height               = 200;
int       g_qm_chartui_margin               = 16;
int       g_qm_chartui_compact_height       = 28;

string QM_ChartUIObjectName(const string suffix)
  {
   return StringFormat("QM5_UI_%04d_%s", g_qm_chartui_ea_id, suffix);
  }

ENUM_BASE_CORNER QM_ChartUICornerToMT5(const QM_ChartUICorner corner)
  {
   switch(corner)
     {
      case QM_CHARTUI_TOP_RIGHT:
         return CORNER_RIGHT_UPPER;
      case QM_CHARTUI_BOTTOM_LEFT:
         return CORNER_LEFT_LOWER;
      case QM_CHARTUI_BOTTOM_RIGHT:
         return CORNER_RIGHT_LOWER;
      case QM_CHARTUI_TOP_LEFT:
      default:
         return CORNER_LEFT_UPPER;
     }
  }

bool QM_ChartUIEnsureRect(const string suffix,
                          const int x,
                          const int y,
                          const int w,
                          const int h,
                          const color bg,
                          const color border)
  {
   const string name = QM_ChartUIObjectName(suffix);
   if(ObjectFind(g_qm_chartui_chart_id, name) < 0)
     {
      if(!ObjectCreate(g_qm_chartui_chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
     }

   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_CORNER, QM_ChartUICornerToMT5(qm_chartui_corner));
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_COLOR, border);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_HIDDEN, true);
   return true;
  }

bool QM_ChartUIEnsureLabel(const string suffix,
                           const int x,
                           const int y,
                           const string text,
                           const color fg,
                           const int font_size = 9,
                           const string font_name = QM_FONT_SANS)
  {
   const string name = QM_ChartUIObjectName(suffix);
   if(ObjectFind(g_qm_chartui_chart_id, name) < 0)
     {
      if(!ObjectCreate(g_qm_chartui_chart_id, name, OBJ_LABEL, 0, 0, 0))
         return false;
     }

   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_CORNER, QM_ChartUICornerToMT5(qm_chartui_corner));
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_COLOR, fg);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(g_qm_chartui_chart_id, name, OBJPROP_FONT, font_name);
   ObjectSetString(g_qm_chartui_chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(g_qm_chartui_chart_id, name, OBJPROP_HIDDEN, true);
   return true;
  }

void QM_ChartUIDelete(const string suffix)
  {
   ObjectDelete(g_qm_chartui_chart_id, QM_ChartUIObjectName(suffix));
  }

void QM_ChartUIClearTileObjects()
  {
   string names[] =
     {
      "tile_risk","tile_risk_t","tile_risk_v1","tile_risk_v2",
      "tile_open","tile_open_t","tile_open_v1","tile_open_v2",
      "tile_today","tile_today_t","tile_today_v1","tile_today_v2",
      "tile_magic","tile_magic_t","tile_magic_v1","tile_magic_v2",
      "tile_news","tile_news_t","tile_news_v1","tile_news_v2",
      "tile_ks","tile_ks_t","tile_ks_v1","tile_ks_v2",
      "status","last","compact","compact_text"
     };

   for(int i = 0; i < ArraySize(names); ++i)
      QM_ChartUIDelete(names[i]);
  }

double QM_ChartUIOpenPnL(const long magic)
  {
   double pnl = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(magic > 0 && pos_magic != magic)
         continue;

      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

int QM_ChartUIOpenCount(const long magic)
  {
   int count = 0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(magic > 0 && pos_magic != magic)
         continue;

      ++count;
     }
   return count;
  }

double QM_ChartUITodayPnL(const long magic, int &out_trades)
  {
   out_trades = 0;

   MqlDateTime ts;
   TimeToStruct(TimeCurrent(), ts);
   ts.hour = 0;
   ts.min = 0;
   ts.sec = 0;
   const datetime day_start = StructToTime(ts);
   const datetime now = TimeCurrent();

   if(!HistorySelect(day_start, now))
      return 0.0;

   double pnl = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      const long deal_magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(magic > 0 && deal_magic != magic)
         continue;

      const long entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      ++out_trades;
     }

   return pnl;
  }

string QM_ChartUISignedMoney(const double value)
  {
   if(value > 0.0)
      return StringFormat("+$%.2f", value);
   if(value < 0.0)
      return StringFormat("-$%.2f", MathAbs(value));
   return "$0.00";
  }

string QM_ChartUISignedPercent(const double value)
  {
   if(value > 0.0)
      return StringFormat("+%.2f %%", value);
   if(value < 0.0)
      return StringFormat("-%.2f %%", MathAbs(value));
   return "0.00 %";
  }

color QM_ChartUIPnLColor(const double value)
  {
   if(value > 0.0)
      return QM_CLR_PASS;
   if(value < 0.0)
      return QM_CLR_FAIL;
   return QM_CLR_TEXT_MUTED;
  }

bool QM_ChartUIRenderHeader(const int panel_w)
  {
   if(!QM_ChartUIEnsureRect("header", g_qm_chartui_margin, g_qm_chartui_margin, panel_w, 30, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2))
      return false;

   const string slug_text = StringFormat("QM5_%04d_%s", g_qm_chartui_ea_id, g_qm_chartui_slug);
   const string ts_utc = TimeToString(TimeGMT(), TIME_SECONDS) + " UTC";

   if(!QM_ChartUIEnsureLabel("header_quant", g_qm_chartui_margin + 10, g_qm_chartui_margin + 8, "Quant", QM_CLR_TEXT, 10, QM_FONT_SANS))
      return false;
   if(!QM_ChartUIEnsureLabel("header_mech", g_qm_chartui_margin + 48, g_qm_chartui_margin + 8, "Mechanica", QM_CLR_EMERALD, 10, QM_FONT_SANS))
      return false;
   if(!QM_ChartUIEnsureLabel("header_slug", g_qm_chartui_margin + 160, g_qm_chartui_margin + 8, slug_text, QM_CLR_TEXT_DIM, 9, QM_FONT_MONO))
      return false;
   if(!QM_ChartUIEnsureLabel("header_clock", g_qm_chartui_margin + panel_w - 96, g_qm_chartui_margin + 8, ts_utc, QM_CLR_TEXT_MUTED, 9, QM_FONT_MONO))
      return false;

   return true;
  }

bool QM_ChartUIRenderCompact(const int panel_w)
  {
   const long magic = g_qm_logger_magic;
   const double open_pnl = QM_ChartUIOpenPnL(magic);

   string ks_state = "ARMED";
   if(open_pnl < 0.0 && MathAbs(open_pnl) >= AccountInfoDouble(ACCOUNT_BALANCE) * 0.03)
      ks_state = "TRIGGERED";

   const string text = StringFormat("QM5 | Risk %.2f%% | P/L %s | KS %s", 0.0, QM_ChartUISignedMoney(open_pnl), ks_state);

   if(!QM_ChartUIEnsureRect("compact", g_qm_chartui_margin, g_qm_chartui_margin + 32, panel_w, g_qm_chartui_compact_height, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2))
      return false;

   return QM_ChartUIEnsureLabel("compact_text", g_qm_chartui_margin + 8, g_qm_chartui_margin + 38, text, (ks_state == "TRIGGERED") ? QM_CLR_FAIL : QM_CLR_TEXT_DIM, 9, QM_FONT_MONO);
  }

bool QM_ChartUIRenderTiles()
  {
   const int tile_w = 220;
   const int tile_h = 44;
   const int row1 = g_qm_chartui_margin + 40;
   const int row2 = g_qm_chartui_margin + 93;
   const int c1 = g_qm_chartui_margin + 10;
   const int c2 = g_qm_chartui_margin + 250;
   const int c3 = g_qm_chartui_margin + 490;

   const long magic = g_qm_logger_magic;
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double risk_cap = balance * 0.03;
   const double open_pnl = QM_ChartUIOpenPnL(magic);
   const double open_pnl_pct = (balance > 0.0) ? (open_pnl / balance) * 100.0 : 0.0;

   int today_trades = 0;
   const double today_pnl = QM_ChartUITodayPnL(magic, today_trades);

   string news_mode_label = "ACTIVE";
   string news_detail = "[calendar loaded]";
   color news_color = QM_CLR_PASS;
   if(g_qm_chartui_last_event == "SETUP_DATA_MISSING")
     {
      news_mode_label = "SETUP_DATA_MISSING";
      news_detail = "[calendar missing]";
      news_color = QM_CLR_FAIL;
     }

   string ks_state = "ARMED";
   color ks_color = QM_CLR_TEXT_MUTED;
   if(today_pnl < 0.0 && MathAbs(today_pnl) >= risk_cap)
     {
      ks_state = "TRIGGERED";
      ks_color = QM_CLR_FAIL;
     }

   if(!QM_ChartUIEnsureRect("tile_risk", c1, row1, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_risk_t", c1 + 8, row1 + 5, "RISK", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_risk_v1", c1 + 8, row1 + 19, "0.00 %", QM_CLR_PASS, 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_risk_v2", c1 + 8, row1 + 31, StringFormat("$%.2f cap", risk_cap), QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   if(!QM_ChartUIEnsureRect("tile_open", c2, row1, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_open_t", c2 + 8, row1 + 5, "OPEN P/L", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_open_v1", c2 + 8, row1 + 19, QM_ChartUISignedMoney(open_pnl), QM_ChartUIPnLColor(open_pnl), 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_open_v2", c2 + 8, row1 + 31, QM_ChartUISignedPercent(open_pnl_pct), QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   if(!QM_ChartUIEnsureRect("tile_today", c3, row1, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_today_t", c3 + 8, row1 + 5, "TODAY", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_today_v1", c3 + 8, row1 + 19, QM_ChartUISignedMoney(today_pnl), QM_ChartUIPnLColor(today_pnl), 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_today_v2", c3 + 8, row1 + 31, StringFormat("%d trades", today_trades), QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   if(!QM_ChartUIEnsureRect("tile_magic", c1, row2, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_magic_t", c1 + 8, row2 + 5, "MAGIC", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_magic_v1", c1 + 8, row2 + 19, StringFormat("%I64d", magic), QM_CLR_TEXT, 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_magic_v2", c1 + 8, row2 + 31, StringFormat("%d open", QM_ChartUIOpenCount(magic)), QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   if(!QM_ChartUIEnsureRect("tile_news", c2, row2, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_news_t", c2 + 8, row2 + 5, "NEWS MODE", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_news_v1", c2 + 8, row2 + 19, news_mode_label, news_color, 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_news_v2", c2 + 8, row2 + 31, news_detail, QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   if(!QM_ChartUIEnsureRect("tile_ks", c3, row2, tile_w, tile_h, QM_CLR_SURFACE_1, QM_CLR_SURFACE_2)) return false;
   if(!QM_ChartUIEnsureLabel("tile_ks_t", c3 + 8, row2 + 5, "KILL SWITCH", QM_CLR_TEXT_MUTED, 8, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("tile_ks_v1", c3 + 8, row2 + 19, ks_state, ks_color, 10, QM_FONT_MONO)) return false;
   if(!QM_ChartUIEnsureLabel("tile_ks_v2", c3 + 8, row2 + 31, "3.00% daily cap", QM_CLR_TEXT_DIM, 8, QM_FONT_MONO)) return false;

   const bool at_on = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   const string status_text = StringFormat("STATUS: AutoTrading %s | NewsFilter %s | Calendar %s",
                                           at_on ? "ON" : "OFF",
                                           (news_color == QM_CLR_FAIL) ? "ERROR" : "ACTIVE",
                                           (news_color == QM_CLR_FAIL) ? "MISSING" : "OK");

   const string last_time = (g_qm_chartui_last_event_time > 0) ? TimeToString(g_qm_chartui_last_event_time, TIME_SECONDS) : TimeToString(TimeCurrent(), TIME_SECONDS);
   const string last_text = StringFormat("LAST: %s %s %s", last_time, g_qm_chartui_last_event, g_qm_chartui_last_payload_summary);

   if(!QM_ChartUIEnsureLabel("status", g_qm_chartui_margin + 10, g_qm_chartui_margin + 150, status_text, QM_CLR_TEXT_DIM, 9, QM_FONT_SANS)) return false;
   if(!QM_ChartUIEnsureLabel("last", g_qm_chartui_margin + 10, g_qm_chartui_margin + 168, last_text, QM_CLR_TEXT_MUTED, 9, QM_FONT_MONO)) return false;

   return true;
  }

bool QM_ChartUI_Init(const int chartui_ea_id, const string slug)
  {
   g_qm_chartui_chart_id = ChartID();
   g_qm_chartui_ea_id = chartui_ea_id;
   g_qm_chartui_slug = slug;
   g_qm_chartui_last_event_time = TimeCurrent();
   g_qm_chartui_last_event = "INIT";
   g_qm_chartui_last_payload_summary = "{}";
   g_qm_chartui_initialized = true;

   if(!qm_chartui_enabled)
      return true;

   QM_LogEvent(QM_INFO, "CHART_UI_INIT", StringFormat("{\"ea_id\":%d,\"slug\":\"%s\"}", chartui_ea_id, QM_LoggerEscapeJson(slug)));
   QM_ChartUI_Refresh();
   return true;
  }

void QM_ChartUI_OnEvent(const string event_name, const string payload_summary)
  {
   g_qm_chartui_last_event_time = TimeCurrent();
   g_qm_chartui_last_event = event_name;
   g_qm_chartui_last_payload_summary = payload_summary;
  }

void QM_ChartUI_Refresh()
  {
   if(!g_qm_chartui_initialized || !qm_chartui_enabled)
      return;

   const long chart_width = ChartGetInteger(g_qm_chartui_chart_id, CHART_WIDTH_IN_PIXELS, 0);
   const bool compact = (chart_width > 0 && chart_width < 720);
   const int panel_w = compact ? MathMax((int)chart_width - (g_qm_chartui_margin * 2), 260) : g_qm_chartui_width;
   const int panel_h = compact ? g_qm_chartui_compact_height : g_qm_chartui_height;

   if(!QM_ChartUIEnsureRect("panel", g_qm_chartui_margin, g_qm_chartui_margin, panel_w, panel_h, QM_CLR_SURFACE_0, QM_CLR_SURFACE_2))
      return;

   if(!QM_ChartUIRenderHeader(panel_w))
      return;

   QM_ChartUIClearTileObjects();

   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      ChartRedraw(g_qm_chartui_chart_id);
      return;
     }

   if(compact)
      QM_ChartUIRenderCompact(panel_w);
   else
      QM_ChartUIRenderTiles();

   ChartRedraw(g_qm_chartui_chart_id);
  }

void QM_ChartUI_Shutdown()
  {
   if(!g_qm_chartui_initialized)
      return;

   if(qm_chartui_enabled)
     {
      string names[] =
        {
         "panel","header","header_quant","header_mech","header_slug","header_clock",
         "tile_risk","tile_risk_t","tile_risk_v1","tile_risk_v2",
         "tile_open","tile_open_t","tile_open_v1","tile_open_v2",
         "tile_today","tile_today_t","tile_today_v1","tile_today_v2",
         "tile_magic","tile_magic_t","tile_magic_v1","tile_magic_v2",
         "tile_news","tile_news_t","tile_news_v1","tile_news_v2",
         "tile_ks","tile_ks_t","tile_ks_v1","tile_ks_v2",
         "status","last","compact","compact_text"
        };

      for(int i = 0; i < ArraySize(names); ++i)
         QM_ChartUIDelete(names[i]);

      ChartRedraw(g_qm_chartui_chart_id);
     }

   QM_LogEvent(QM_INFO, "CHART_UI_SHUTDOWN", StringFormat("{\"ea_id\":%d,\"slug\":\"%s\"}", g_qm_chartui_ea_id, QM_LoggerEscapeJson(g_qm_chartui_slug)));
   g_qm_chartui_initialized = false;
  }

#endif // QM_CHARTUI_MQH
