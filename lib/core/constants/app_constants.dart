abstract final class AppConstants {
  static const appName = 'はりきゅうラボ';
  static const subtitle = '鍼灸師 国家試験対策';
  static const horizontalPadding = 24.0;
  static const cardRadius = 20.0;
  static const controlRadius = 16.0;
  static const pageMaxWidth = 1100.0;
  static const fastAnimation = Duration(milliseconds: 220);
  static const standardAnimation = Duration(milliseconds: 280);
  static const questionsSheetCsvUrl = String.fromEnvironment(
    'QUESTIONS_SHEET_CSV_URL',
    defaultValue:
        'https://docs.google.com/spreadsheets/d/e/2PACX-1vTSyFXi-NgrS9YokHo5i183yOzt-c-7L00tR4qN4plO-ezWOcn_dpgrxgFXGXhGjILIMuJ0h0qViTCB/pub?output=csv',
  );
}
