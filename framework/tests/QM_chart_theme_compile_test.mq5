#property strict
#property version "1.0"

//+------------------------------------------------------------------+
//| Compile-smoke for QM_ChartTheme.mqh.                             |
//| References every exported constant + helper so a missing token   |
//| or a signature drift fails the compile (PASS = 0 errors / 0 warn)|
//+------------------------------------------------------------------+
#include <QM/QM_ChartTheme.mqh>

int OnInit()
  {
   // Reference every colour token so the compiler must resolve them.
   const color surface[] = {QM_THEME_BG, QM_THEME_PANEL, QM_THEME_BORDER, QM_THEME_GRID};
   const color text[]    = {QM_THEME_TEXT, QM_THEME_MUTED};
   const color pnl[]      = {QM_THEME_PROFIT, QM_THEME_LOSS, QM_THEME_ACCENT};
   if(ArraySize(surface) != 4 || ArraySize(text) != 2 || ArraySize(pnl) != 3)
      return INIT_FAILED;

   // Typography tokens.
   const string f  = QM_THEME_FONT;
   const string fm = QM_THEME_FONT_MONO;
   if(StringLen(f) == 0 || StringLen(fm) == 0)
      return INIT_FAILED;
   if(QM_THEME_FONT_SIZE_TITLE <= QM_THEME_FONT_SIZE_NORMAL ||
      QM_THEME_FONT_SIZE_NORMAL < QM_THEME_FONT_SIZE_SMALL)
      return INIT_FAILED;

   // Helper: sign -> colour mapping.
   if(QM_ThemePnlColor(10.0) != QM_THEME_PROFIT ||
      QM_ThemePnlColor(-10.0) != QM_THEME_LOSS ||
      QM_ThemePnlColor(0.0)  != QM_THEME_MUTED)
      return INIT_FAILED;

   // Helper is guarded internally; safe to invoke in a compile smoke.
   QM_ThemeApplyChart(ChartID());

   Print("QM_CHART_THEME_COMPILE_TEST_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }
