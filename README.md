# はりきゅうラボ

鍼灸師国家試験対策用の Flutter アプリです。問題はアプリに同梱せず、公開した Google スプレッドシートの CSV から直接取得します。取得に成功したデータは端末にキャッシュされ、次回起動時にはキャッシュをすぐに表示してからバックグラウンドで最新版へ同期します。同期に失敗した場合も、保存済みのキャッシュを継続して利用します。

## Google スプレッドシートの設定

### 1. 問題シートを作成する

1 行目に、次の列名を**表記どおり**設定してください。

| id | question | choice1 | choice2 | choice3 | choice4 | correctAnswer | explanation | category |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| q001 | 十二経脈のうち、手の太陰経はどれか。 | 心包経 | 肺経 | 腎経 | 胃経 | 2 | 手の太陰経は肺経です。 | 経絡経穴概論 |

- `id`、`question`、`choice1`〜`choice4`、`correctAnswer` は必須です。
- `id` は問題ごとに重複しない値にしてください。
- `correctAnswer` は正解の選択肢番号を `1`〜`4` で指定します（0 始まりではありません）。
- `explanation` と `category` は省略できます。
- セル内のカンマ、改行、ダブルクォートを含む標準的な CSV も読み込めます。

### 2. CSV として公開する

1. スプレッドシートで **ファイル → 共有 → ウェブに公開**を開きます。
2. 「ドキュメント全体」ではなく、問題が入ったシートを選択します。
3. 形式に **カンマ区切りの値（.csv）**を選び、「公開」を押します。
4. 発行された URL を控えます。URL は通常、次の形式です。

```text
https://docs.google.com/spreadsheets/d/e/公開ID/pub?gid=シートID&single=true&output=csv
```

「リンクを知っている全員を閲覧者」にした共有用 URL ではなく、上記手順で発行した `output=csv` の公開 URL を使用してください。公開 URL を知っている人はデータを閲覧できるため、個人情報や非公開情報は記載しないでください。

### 3. アプリへ URL を渡す

URL はソースコードへ保存せず、ビルドまたは実行時に `--dart-define` で指定します。

```bash
flutter run --dart-define=QUESTIONS_SHEET_CSV_URL='https://docs.google.com/spreadsheets/d/e/公開ID/pub?gid=シートID&single=true&output=csv'
```

リリースビルドでも同じ指定が必要です。

```bash
flutter build appbundle --dart-define=QUESTIONS_SHEET_CSV_URL='https://docs.google.com/spreadsheets/d/e/公開ID/pub?gid=シートID&single=true&output=csv'
```

URL 未設定かつ端末にキャッシュがない場合、問題画面には取得エラーと再試行ボタンが表示されます。

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
