# はりきゅうラボ

鍼灸師国家試験の学習用Flutterアプリです。問題データは、公開されたGoogleスプレッドシートのCSVから起動時に取得します。

## 問題データの設定

既定では次の公開CSVを使用します。

```text
https://docs.google.com/spreadsheets/d/e/2PACX-1vTSyFXi-NgrS9YokHo5i183yOzt-c-7L00tR4qN4plO-ezWOcn_dpgrxgFXGXhGjILIMuJ0h0qViTCB/pub?output=csv
```

シートの1行目には、以下の列名を設定してください。

```text
id,subject,category,question,choice1,choice2,choice3,choice4,answer,explanation,image
```

`answer` は正解の選択肢番号（`1`〜`4`）または選択肢本文、`image` は画像URLです。画像が不要な行は `image` を空にします。

### 起動

```bash
flutter pub get
flutter run
```

別の公開CSVを利用する場合は、コンパイル時環境変数で上書きできます。

```bash
flutter run \
  --dart-define=QUESTIONS_SHEET_CSV_URL='https://example.com/questions.csv'
```

アプリ起動時にCSVが取得され、端末のSharedPreferencesへキャッシュされます。通信に失敗した場合は最後に取得できたキャッシュを表示します。シートの編集を公開CSVへ反映した後、「一問一答」画面を下に引っ張ると最新データを強制取得できます。

## 品質チェック

```bash
flutter analyze
flutter test
```
