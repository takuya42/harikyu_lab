# RevenueCatによる買い切りProの管理

## 実装と識別子

- SDK: `purchases_flutter`。購入・復元の実行主体をRevenueCatに一本化し、`in_app_purchase`は使用しません。
- 既存の商品ID: **`harikyu_lab_pro`**（変更しません）。非消耗型の買い切り商品です。
- Entitlementのidentifier: **`pro`**。Display Name「はりきゅうラボ Pro」とは別の値で、identifierとの完全一致が必要です。
- iOS Bundle ID: **`com.kono.harikyu-lab`**。
- Firebaseも同じBundle IDで登録したiOSアプリの`GoogleService-Info.plist`と`DefaultFirebaseOptions.ios`を使用します。FirebaseのアプリID・API Keyはダウンロードした設定に合わせ、旧アプリの設定でBundle IDだけを書き換えないでください。macOSのFirebase設定は別途扱います。
- 商品の取得は`Purchases.getProducts`の非サブスクリプション指定、購入は`Purchases.purchase`、復元は`Purchases.restorePurchases`です。現在の画面ではOfferings/Packagesを使わず商品IDで取得します。
- 上記はリポジトリで確認した値です。App Store Connect/RevenueCat Dashboardの実際の設定は未確認です。不一致があればコードの商品IDを変更せず、既存のApp Store商品とDashboardの紐付けを確認してください。

## Public SDK API Keyの設定

RevenueCat Dashboardの対象iOSアプリの**Public SDK API Key**（`appl_`で始まるもの）を使います。キーはまだ提供されておらず、コード内に実際の値はありません。Secret API Key（`sk_`）、App Store Connectの秘密鍵、Slack Webhook URLをアプリやGitに入れないでください。Public SDK API Keyはビルドに含まれる公開用途のキーです。

1. `config/revenuecat.example.json`を`config/revenuecat.local.json`へコピー。
2. `REVENUECAT_IOS_PUBLIC_SDK_KEY`へPublic SDK API Keyを設定。
3. デバッグ/リリースとも同じ設定ファイルを指定してビルドします。

```bash
flutter run --dart-define-from-file=config/revenuecat.local.json
flutter build ipa --dart-define-from-file=config/revenuecat.local.json
```

`config/revenuecat.local.json`はGit管理対象外です。CIでは同じ変数を`--dart-define`またはCIで生成した設定ファイルから渡してください。値を変えた後はホットリロードではなく再ビルドが必要です。

Androidにも提供する場合は、Google Play用RevenueCatアプリのPublic SDK API Key（`goog_`）を`REVENUECAT_ANDROID_PUBLIC_SDK_KEY`へ設定し、同じ既存商品IDの非消耗型商品をGoogle Play/RevenueCatにも設定してください。Androidのストア設定は未確認です。Web/デスクトップ向けのRevenueCat購入は今回の対象外で、既存Proの参照は継続します。

API Keyが空、対象プラットフォームと異なる、またはSDKの初期化が失敗した場合、アプリは起動を継続し、新規購入には利用不可のメッセージを表示します。既存Proフラグを消すことはありません。

iOSではFlutter依存導入後にmacOS上で`cd ios && pod install`を実行してRevenueCatのネイティブ依存を解決し、XcodeでRunnerのIn-App Purchase capabilityと署名を確認してください。iOSのPodfile.lockはLinux上では更新・検証していません。

## 起動と匿名ユーザー

`main()`でFirebase初期化後にRevenueCatを初期化します。`appUserID`を渡さず、SDKが永続化する匿名ユーザーを利用します。Firebaseのログイン/ログアウト時にもRevenueCatの`logIn`/`logOut`は呼びません。購入と復元にFirebaseログインは不要です。

起動後は`revenueCatProProvider`がCustomerInfoとその更新通知を読み取り、指定Entitlementが有効ならProとして扱います。購入画面ではストアの価格を表示します。購入の取り消しや承認待ちはPro購入成功として扱いません。

## 既存購入者の移行

移行中のPro判定は以下のORです。

1. RevenueCatの`entitlements.active['pro']`が有効。
2. 従来のSharedPreferencesの`pro_entitlement_v1`がtrue。
3. ログイン中のFirestoreの`users/{uid}.plan`が`pro`。

既存のキー名・Firestore情報は変更せず、RevenueCatの未設定、通信失敗、空の復元結果を理由に消去しません。ログイン中で端末側のPro情報がない場合は、Firestore判定前に無料状態を通知しません。

既存ユーザーには同じAppleアカウントで**「購入を復元」**を実行してもらいます。ボタンはPro利用中にも表示し、RevenueCatの`restorePurchases`で既存App Storeの非消耗型購入を取り込みます。起動時に認証ダイアログを伴う復元を自動実行したり、再購入を要求したりはしません。ローカルフラグだけからRevenueCatに架空の購入履歴を作ることもしません。

購入/復元で対象Entitlementが確認できた場合、従来どおり端末にProを保存し、ログイン中はFirestoreにも同期します。Firestore同期に失敗しても購入と端末のPro状態は維持します。アプリを再インストールして端末フラグがなくなった場合は「購入を復元」または従来のFirestore Proを使用します。

移行優先で既存フラグを残すため、RevenueCatで権利が失効しても端末/FirestoreのProがtrueならProを維持します。返金等に合わせて既存フラグを失効させる処理は今回追加しません。無料ユーザーの1日5回答制限と通常のFirebase Messagingは変更しません。

## RevenueCat Dashboardで必要な設定

1. 既存のApp Storeアプリ（上記Bundle ID）を登録/選択し、App Store Connect連携に必要な認証情報をDashboard側に設定します。認証情報はモバイルアプリに入れません。
2. Product catalogへ既存の`harikyu_lab_pro`を非消耗型商品として登録/取り込みます。新規の別商品IDへ置き換えないでください。
3. Entitlementの**identifier**を`pro`として作成/確認し、上記商品を紐付けます。購入成功だけではなく、このEntitlementの有効性をコードで確認します。現実のidentifierが違う場合はリリース前に確認してください。
4. Restoration/transfer behaviorは、再インストール後の匿名ユーザーによる復元を許可する設定にします。今回の匿名運用では、必要に応じて **Transfer to new App User ID** を選択して、既存購入者での復元を検証してください。Keep with original App User ID等の移行を拒否する設定は避けます。
5. Integrationsから公式Slack連携を追加し、対象ワークスペース/チャンネルへ接続します。買い切り購入イベントとSandbox通知の扱いを確認します。アプリやFirebase FunctionsからSlack/FCMへ通知するコードは追加していません。

公式資料:
- https://www.revenuecat.com/docs/getting-started/installation/flutter
- https://www.revenuecat.com/docs/migrating-to-revenuecat/migrating-existing-subscriptions
- https://www.revenuecat.com/docs/getting-started/restoring-purchases
- https://www.revenuecat.com/docs/integrations/third-party-integrations/slack

## リリース前の実機確認

Public SDK API Key、Dashboard設定、Appleの購入環境がないためクラウドで実決済・移行復元・Slack通知は検証できません。設定後、Sandbox/TestFlightで以下を確認してください。

- 未ログインで新規の買い切り購入 → RevenueCatの対象Entitlementが有効 → Proの回答制限解除 → Sandbox設定に応じたSlack通知。
- SDK導入前に同じ商品を購入したAppleアカウントで、Pro状態を保持したまま「購入を復元」し、RevenueCatへ履歴を取り込めること。
- 再インストール後の復元、Firebaseログイン/ログアウト、キャンセル、通信失敗、無料ユーザーの6回答目の拒否。
- 通常のFCM通知が引き続き動作すること。
