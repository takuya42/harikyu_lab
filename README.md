# はりきゅうラボ

鍼灸師国家試験対策用の Flutter アプリです。問題はアプリに同梱せず、公開した Google スプレッドシートの CSV から直接取得します。取得に成功したデータは端末にキャッシュされ、次回起動時にはキャッシュをすぐに表示してからバックグラウンドで最新版へ同期します。同期に失敗した場合も、保存済みのキャッシュを継続して利用します。

## Google スプレッドシートの設定

### 1. 問題シートを作成する

1 行目に、次の列名を設定してください。

| id | subject | category | question | choice1 | choice2 | choice3 | choice4 | answer | explanation | image |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| q001 | 経絡経穴概論 | 基礎 | 十二経脈のうち、手の太陰経はどれか。 | 心包経 | 肺経 | 腎経 | 胃経 | 2 | 手の太陰経は肺経です。 | https://example.com/image.png |

- `id`、`question`、`choice1`〜`choice4`、`answer` は必須です。ただし、CSV リポジトリ経由では `id` が空の場合に行番号から ID を補完します。
- `id` は問題ごとに重複しない値にしてください。
- `answer` は正解の選択肢番号 `1`〜`4`（半角・全角）または `A`〜`D` で指定します（0 始まりではありません）。`correctAnswer` も利用できます。
- `subject`、`category`、`explanation`、`image` は省略できます。
- 模擬試験 CSV では、`問題文`、`選択肢1`〜`選択肢4`、`正解`、`解説`、`カテゴリ`、`科目`、`画像` という日本語ヘッダーも利用できます。`option1`〜`option4` や snake_case のヘッダーにも対応しています。
- セル内のカンマ、改行、ダブルクォートを含む標準的な CSV も読み込めます。
- 不正な行がある場合は、CSV 上の行番号、ヘッダー、`category`、`question`、`answer`、行の全値、および不足・不正項目をデバッグログへ出力します。

### 2. CSV として公開する

1. スプレッドシートで **ファイル → 共有 → ウェブに公開**を開きます。
2. 各カテゴリのシートが持つ `gid` を URL から控えます。
3. スプレッドシートを「リンクを知っている全員が閲覧可」にします。
4. アプリはカテゴリごとに次の URL を組み立てます。

```text
https://docs.google.com/spreadsheets/d/<spreadsheetId>/export?format=csv&gid=<gid>
```

シートを公開するため、個人情報や非公開情報は記載しないでください。

### 3. Spreadsheet ID と gid を設定する

Spreadsheet ID と各カテゴリの gid は `lib/core/constants/question_sheet_constants.dart` で一元管理します。各シートの実際の値を `questionSheetGids` に設定してください。

```bash
flutter run
```

リリースビルドでも同じ指定が必要です。

```bash
flutter build appbundle
```

ビルド時の `--dart-define` 指定は不要です。

## データ更新とキャッシュ

- 問題画面の初回利用時はスプレッドシートを取得し、成功後に端末へキャッシュします。
- キャッシュがある場合は先にキャッシュを表示し、同時に最新の CSV を取得します。
- 最新データの取得と検証に成功すると、表示とキャッシュを更新します。
- 通信エラーや不正な CSV の場合は既存キャッシュを維持します。
- シートの列構成を変更した場合は、上記の必須列を残してください。

## 開発

```bash
flutter pub get
flutter analyze
flutter test
```
