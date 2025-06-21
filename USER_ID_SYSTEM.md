# TalkOne UserID システム

## UserID の決定方法

### Firebase Anonymous Authentication
TalkOneアプリでは、Firebase Anonymous Authentication を使用してユーザーIDを生成しています。

- **決定時期**: アプリ初回起動時（main.dart の Firebase 初期化処理）
- **生成方法**: `FirebaseAuth.instance.signInAnonymously()` により自動生成
- **ユニーク性**: 端末ごとにユニークなUID（28文字のランダム文字列）
- **永続性**: アプリをアンインストールするまで同じIDを保持

### 実装詳細

```dart
// main.dart での初期化
if (FirebaseAuth.instance.currentUser == null) {
  await FirebaseAuth.instance.signInAnonymously();
}

// UserProfileService での利用
String? get _userId => _auth.currentUser?.uid;
```

### Firebase Firestore 構造
```
userProfiles/
  ├── {firebase_uid_1}/     // 例: "xYz9mK3nP8qR2tU5..."
  │   ├── nickname: "ユーザー1"
  │   ├── rating: 1000
  │   ├── themeIndex: 0
  │   └── ...
  └── {firebase_uid_2}/     // 例: "aBc4dE7fG1hI9jK..."
      ├── nickname: "ユーザー2"
      ├── rating: 1200
      └── ...
```

### デバッグ表示
ホーム画面下部（メニューバー上）に短縮UserIDを表示：
- フォーマット: `User: 先頭4文字...末尾4文字`
- 例: `User: xYz9...jK5m`

### 注意事項
- 匿名認証のため、アプリ再インストール時は新しいUIDが生成される
- 複数端末で同じUserIDを共有することはできない
- Firebase Consoleで個別のユーザー情報を確認可能