# kali-vnc-docker

Kali Linux (XFCE + VNC) をDockerコンテナで動かすための構成。
Colima上での運用を前提とする。自分の環境・CTF・学習用途のみ。他人環境へのpentestは対象外。

## 構成

- `setup.sh`: Docker DesktopからColimaへの移行スクリプト(このマシン固有のセットアップ)
- `kali-vnc/`: Kali Linux + VNCコンテナの定義(Dockerfile / entrypoint.sh / docker-compose.yml)
- `kali-vnc/docker-compose.lab.yml` / `kali-vnc/lab/`: 攻撃検証練習用の脆弱ターゲット群(オプション、オーバーレイ)

## 前提条件

- macOS (M4 MacBook Air / arm64 で動作確認)
- Homebrew インストール済み
- Docker Desktopがインストール済みで `docker context ls` に `desktop-linux` が存在する(移行前提)

## セットアップ手順

### 1. Colimaへ移行する

```bash
./setup.sh
```

Docker Desktop併存方針を対話で確認される。非対話実行したい場合:

```bash
./setup.sh --stop-docker-desktop   # Docker Desktop.appを終了しColimaのみ運用(推奨)
./setup.sh --keep-docker-desktop   # Docker Desktopを残し手動でcontext切り替え
```

### 2. Kaliコンテナをビルド・起動する

```bash
cd kali-vnc
cp ../.env.example .env   # 固定パスワードを使いたい場合のみ編集
docker compose up -d --build
```

初回ビルドは `kali-linux-default` のダウンロード・展開があるため数分〜十数分かかる。

## 使い方

- **VNC接続**: macOS標準の「画面共有.app」で `vnc://localhost:5901` を開く(または `open vnc://localhost:5901`)
- **パスワード確認**: `docker compose logs kali | grep "Generated VNC password"`(初回起動時のみ表示、ランダム生成時)
- **シェルに入る**: `docker exec -it kali-vnc bash`
- **停止**: `docker compose down`(`kali-home` ボリュームは残るのでデータは消えない)
- **完全削除**: `docker compose down -v`(ボリュームごと削除、`/root` 配下のデータが消える点に注意)

## 攻撃検証ラボ(オプション)

nmap / hydra / sqlmap 等の攻撃検証を自分専用の閉域環境で練習するための脆弱ターゲット群。ホストへのポート公開は一切せず、kaliコンテナと同一の compose ネットワーク内でのみ到達可能。

```bash
cd kali-vnc
docker compose -f docker-compose.yml -f docker-compose.lab.yml up -d --build
```

- **`dvwa`**(`vulnerables/web-dvwa`): Web検証用。初回のみブラウザで `http://dvwa/setup.php` → 「Create / Reset Database」を実行してからログイン(`admin` / `password`)。意図的に極めて脆弱・パッチ未適用のイメージなので、`ports:` を追加してホストへ公開しないこと
- **`weak-target`**: 認証情報攻撃練習用の自作SSHターゲット。デフォルト認証情報は `labuser` / `password123`(コンテナ内非特権ユーザー、root昇格経路なし)
- どちらも意図的に使い捨て設計(`restart` ポリシー未設定)のため、Colima/ホスト再起動時に自動復活しない
- ラボ環境の停止: `docker compose -f docker-compose.yml -f docker-compose.lab.yml down`(dvwaのDBはコンテナ内のみでボリューム化していないため、down で消える)

## トラブルシューティング

| 症状 | 対応 |
|---|---|
| `colima status` が起動していない | `colima start --cpu 4 --memory 8 --disk 30 --arch aarch64` |
| `docker: command not found` またはDocker Desktopのdockerを掴んでいる | `docker context ls` でactive contextを確認し `docker context use colima` |
| VNC接続できない | `docker compose ps` でコンテナがUpか確認、`docker compose logs kali` でvncserverの起動ログを確認 |
| パスワードを忘れた | `docker compose down; docker volume rm kali-home; docker compose up -d --build` で作り直す(データも消える)。または `.env` に `VNC_PASSWORD` を設定して再起動すればパスワードのみ上書きされる |
| 画面が真っ黒/WMが立ち上がらない | `docker exec -it kali-vnc cat /root/.vnc/*.log` でXFCE起動ログを確認 |
| ディスク容量を変更したい | `colima delete` してから `setup.sh` を再実行(既存VMのディスクは後から拡張できない) |

## Not Doing

- Docker DesktopのGUI管理機能の完全代替は目指さない(CLI運用前提)
- 他人環境へのpentest実施は対象外
- `kali-linux-everything` 等のフルセットは入れない
- X11 forwarding、x11docker、colima-ui(管理GUI)は対象外
