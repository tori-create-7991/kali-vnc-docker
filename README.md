# kali-vnc-docker

Kali Linux (XFCE + VNC) をDockerコンテナで動かすための構成。
Colima上での運用を前提とする。自分の環境・CTF・学習用途のみ。他人環境へのpentestは対象外。

## 構成

- `setup.sh`: Colima + Docker CLIの新規セットアップスクリプト
- `kali-vnc/`: Kali Linux + VNCコンテナの定義(Dockerfile / entrypoint.sh / docker-compose.yml)

## 前提条件

- macOS (M4 MacBook Air / arm64 で動作確認)
- Homebrew インストール済み

## セットアップ手順

### 1. Colima + Dockerをセットアップする

```bash
./setup.sh
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
