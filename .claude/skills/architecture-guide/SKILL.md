---
name: architecture-guide
description: このプロジェクトのアーキテクチャ・設計規約・置き場所についての質問に答えるときに使う。トリガー例:「◯◯はどこに置く？」「AppState に何を入れていい？」「Policy って何？」「なぜ UseCase は protocol じゃないの？」「定数はどこで管理？」。コードを書く作業は add-feature、レビューは review-architecture を使う。
---

# アーキテクチャ・リファレンス

## 一言で

**MVVM + 軽い UseCase 層 + Repository パターン**（DI は swift-dependencies）。
見た目は MVVM + UseCase、規律はクリーンアーキテクチャ — 厳格なのは**依存方向**と**注入点**だけ。

## 層の対応と「誰が何を持てるか」

| 一般名 | ここでの名前 | 持てる依存 |
|---|---|---|
| View | `View` | **なし**（State を生成するだけ） |
| ViewModel | `State`（`@MainActor @Observable`） | **UseCase のみ** |
| UseCase | `UseCase`（具体 struct・`callAsFunction`） | `@Dependency` で生サービス/リポジトリ（**唯一の場所**） |
| Repository/Service 抽象 | `Core/Services`・`Core/Repositories` の protocol | —（Foundation のみ） |
| データ層実装 | `Infrastructure/` | 実 I/O |

依存の向き: `Features ──▶ Core ◀── Infrastructure`（両者とも Core に向かう＝DIP）。App/DI だけが両者を結線する。

## Q&A

### Policy（Core/Policy）には何を置く？
「入力 → 判断」の**純粋関数だけ**。例: 検出結果→重大度分類（`SeverityPolicy`）、分類基準（`SeverityRules`）。
置かないもの: I/O、対応の実行（「high なら通知」は UseCase）、UI。
判断ルール（複合判定・エスカレーション等）が増えたら Policy 行き。フレームワークなしで全網羅テストできるのが Policy の価値。

### AppState に入れていいもの / ダメなもの
入れてよい条件（**全部**満たすこと): ①複数画面が観る ②アプリ全体スコープ ③可変の観測状態 ④真実の源は依存側にあり、ここは投影。
3秒判定フロー:
- I/O をする？ → **依存(DI)**。AppState ではない
- 1画面だけ？ → **その機能の State**
- 業務ルール？ → **Policy / UseCase**
- 永続の真実の源？ → **Repository**（AppState は投影だけ)
- どれでもない「複数画面が観る横断状態」→ **AppState**

AppState が UserDefaults を直接触るのは NG。値の公開＝AppState、保存＝Repository(DI) に委譲。
「状態(観る)」と「依存(する)」を混ぜない — 可変状態を `DependencyValues` に入れない。

### 使い回す固定値はどこで管理？
| 種類 | 場所 |
|---|---|
| ドメインの閾値・判定定数 | `Core/Policy/SeverityRules` |
| 識別子・キー名（localize 不要） | `Support/Constants/Const.swift` |
| 色・フォント | `Support/Theme/`（`extension Color` / `extension Font`） |
| ボタンスタイル・装飾 | `Support/Theme/Styles/`・`Modifiers/` |
| ユーザー向け文字列 | String Catalog（`Const` に書かない） |

境目: **ドメインの意味を持つ数値は Core/Policy**、見た目・識別子は Support。

### なぜ UseCase は protocol にしない？
差し替える必要がないから。差し替え境界（I/O）は既に protocol 化されていて、テストは `withDependencies` で**中の依存**を差し替えて本物の UseCase を検証する。UseCase は「差し替える対象」ではなく「テストされる対象」。DIP は「差し替えが要る境界」を抽象化する原則であり、全部を protocol にすることではない。

### API 通信基盤（APIClient）はどこに置く？
- ドメイン境界（`MediaUploader` 等）＝ `Core/Services` の protocol。UseCase が依存するのは**これだけ**
- 汎用 HTTP 基盤（URLSession ラッパ・エンコード・認証）＝ `Infrastructure/Network` の**内部道具**。Core にも DependencyValues にも載せない
- 実装名は `URLSessionBackendClient` のように「具体技術＋protocol 名」。REST は API 様式の名前であって通信手段ではない

### swift-dependencies の 3値と context
| 実行文脈 | 解決される値 |
|---|---|
| アプリ実行 | `liveValue` |
| Xcode Preview | `previewValue`（自動検知・withDependencies 不要） |
| テスト | `testValue`（Unimplemented＝上書き忘れの安全網） |

**注意**: `@Dependency` は「その型を生成した時点」の context を捕捉する。テストでは対象（UseCase/State）を `withDependencies { } operation: { }` の**中で生成**すること。

### 新しい依存・機能を足す手順は？
→ スキル `add-feature` を使う（3点セット: Core protocol → Infra 実装 → DI 登録3値）。

## 深掘りが必要なとき

このリポジトリの `README.md`（アーキ全体像・DI 設計・テスト方針）を読む。設計判断の経緯は git log のコミットメッセージに残っている。
