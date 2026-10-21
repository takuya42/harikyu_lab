# RevenueCat 購入通知（開発者端末専用）

`revenueCatWebhook` は RevenueCat の POST Webhook を受信し、開発者 iPhone の
FCM registration token に直接通知します。Topic や一般ユーザーには送信しません。
Flutter の購入処理・Pro 判定・無料回答制限の変更は不要です。

| イベント | 通知 |
| --- | --- |
| INITIAL_PURCHASE | する |
| NON_RENEWING_PURCHASE（買い切り） | する |
| RENEWAL | REVENUECAT_NOTIFY_RENEWALS=true の場合のみ |
| CANCELLATION その他 | しない |

タイトルは `🎉 新しい課金がありました`、本文は
`はりきゅうラボ Proが購入されました！` です。
RevenueCat TEST イベントは通知しません。SANDBOX の購入イベントも上表に従います。
この Webhook は通知専用で、購入権限の付与・取り消しは行いません。

## 初回設定・デプロイ

Node.js 22 と Firebase CLI を使用します。Firebase プロジェクトは `harikyu-lab`。
以下は管理者が実行する手順で、この変更では本番デプロイしていません。

1. Firebase Secret Manager に Authorization Header の期待値全体（例：`Bearer ` と
   十分にランダムな文字列）と、開発者 iPhone の FCM Token を対話入力します。
   値をコマンド引数、Git、ログ、Flutter の dart-define に書かないでください。

   ```bash
   firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTHORIZATION --project harikyu-lab
   firebase functions:secrets:set DEVELOPER_FCM_TOKEN --project harikyu-lab
   ```

2. `functions/.env.harikyu-lab` に非機密設定
   `REVENUECAT_NOTIFY_RENEWALS=false` を設定します（未指定時も false）。更新通知が
   必要なときだけ true に変更し再デプロイします。Secret 値はこのファイルに置きません。

3. リポジトリのルートから依存関係を導入・検証して、追加 Function だけをデプロイします。

   ```bash
   cd functions
   npm install
   npm run lint
   npm test
   cd ..
   firebase deploy --only functions:revenueCatWebhook --project harikyu-lab
   ```

4. RevenueCat Dashboard の Webhook に、デプロイ結果の HTTPS URL と手順1と完全一致する
   Authorization Header を登録します。通知対象イベントが送信対象に含まれることを
   確認します。iPhone 側は既存の APNs/FCM 設定と通知許可が必要です。
   Token 更新時は Secret を更新し Function を再デプロイします。

## 重複防止と障害時の注意

Firestore コレクション `revenuecat_notification_events` のドキュメント ID は
RevenueCat `event.id` の SHA-256 です。本文に元の `event_id`、イベント種別、状態と
作成日時を保存します。トランザクションで送信前に確保するため、同じ ID の再送・
同時受信でも通知送信は1回です。FCM 送信は再実行され得るトランザクションの外で行います。
記録に TTL は設定せず、重複防止が必要な限り削除しないでください。
クライアントからこのコレクションへの読み書きは許可せず、既存 Firestore rules が
広い権限を与えていないかデプロイ前に確認してください。Admin SDK は rules を迂回します。

状態は `sending` → `sent`、送信または送信後記録の障害時は
`delivery_uncertain` です。エラー時は HTTP 500、既存 ID は HTTP 200 で返します。
送信中のプロセス終了や FCM 障害では「未配信」と「送信済み」を確実に区別できないため、
重複防止を優先して既存 ID を自動再送しません。`sending` のまま残った記録や
`delivery_uncertain` は管理者が Functions/FCM の運用情報と照合してください。
手動で記録を削除して再処理すると二重通知の可能性があります。
FCM 受付成功は iPhone への表示完了を保証しません。

## テスト

`cd functions && npm test`。Firestore トランザクションと FCM をテスト用に置き換え、
購入2種、更新設定、対象外イベント、不正認証、不正データ、同時重複、障害時の挙動、
既存アカウント削除 Function のエクスポートと未認証拒否を確認します。
実 Firestore・FCM・実機への配信テストは含みません。デプロイ後は Sandbox で買い切り購入し、
開発者 iPhone の受信と、同一 event.id の再送で通知が増えないことを確認してください。
