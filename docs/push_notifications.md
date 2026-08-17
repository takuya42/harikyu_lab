# iPhone プッシュ通知の運用設定

アプリは Firebase Auth のログイン状態とは無関係に FCM を初期化し、取得した
トークンを `harikyu_lab_all` Topic に登録します。

## Xcode / Apple Developer で必要な設定

1. `ios/Runner.xcworkspace` を Xcode で開き、Runner target の **Signing &
   Capabilities** で正しい Team と Bundle Identifier を確認します。
2. **Push Notifications** capability が表示されることを確認します。
3. **Background Modes** の **Remote notifications** が有効であることを確認します。
4. Apple Developer の **Certificates, Identifiers & Profiles > Keys** で新しい Key を
   作り、**Apple Push Notifications service (APNs)** を有効にします。
5. 一度だけダウンロードできる `.p8` ファイルを保管し、画面に表示される Key ID
   と Apple Developer Membership 画面の Team ID を控えます。
6. 実機用 Provisioning Profile に Push Notifications entitlement が含まれることを
   確認します。シミュレーターではなく実機で検証してください。

リポジトリには `aps-environment` entitlement と `remote-notification` background
mode を追加済みです。Xcode 上の capability 表示と署名プロファイルが一致することを
必ず確認してください。App Store 用署名では provisioning profile により本番 APNs
environment が適用されます。

## Firebase Console で必要な設定

1. Firebase Console の **プロジェクトの設定 > Cloud Messaging** を開きます。
2. 対象 iOS アプリの **APNs Authentication Key** に `.p8` をアップロードします。
3. Apple Developer で控えた **Key ID** と **Team ID** を入力して保存します。
4. Firebase に登録した Bundle ID と Xcode の Bundle Identifier が一致することを
   確認します。

## Firebase Console からテスト送信する方法

1. 通知許可を与えた実機でアプリを一度起動します。初回起動後、APNs/FCM トークンが
   取得されると `harikyu_lab_all` に自動登録されます。
2. Firebase Console の **Messaging** で新しいキャンペーン（Firebase Notification
   messages）を作成し、通知タイトルと本文を入力します。
3. ターゲットで **Topic** を選択し、`harikyu_lab_all` を指定して送信します。
4. アプリが foreground、background、終了状態のそれぞれで alert / badge / sound と
   タップ後の通常起動を確認します。Topic 登録の反映には少し時間がかかる場合が
   あります。

単一端末だけを確認する場合は、Firebase Console の「テスト メッセージを送信」に
端末の FCM registration token を指定できます。トークンは機密情報として扱い、公開
ログやソースコードには保存しないでください。
