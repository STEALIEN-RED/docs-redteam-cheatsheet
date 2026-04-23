# 프로토콜별 펜테스트

포트 스캔 후 발견된 서비스에 대한 프로토콜별 공격 가이드.

---

## 포트 / 프로토콜 레퍼런스

| 포트 | 프로토콜 | 설명 | 링크 |
|------|---------|------|------|
| 21 | FTP | 파일 전송 프로토콜 | [FTP](ftp.md) |
| 22 | SSH | Secure Shell | [SSH](ssh.md) |
| 25/465/587 | SMTP | 메일 전송 | [SMTP](smtp.md) |
| 53 | DNS | 도메인 네임 서비스 | [DNS](dns.md) |
| 80/443 | HTTP/HTTPS | 웹 서비스 | [HTTP](http.md) |
| 88 | Kerberos | 인증 프로토콜 | [Kerberos](kerberos.md) |
| 110/995 | POP3 | 메일 수신 | - |
| 111 | RPCbind | RPC 포트 매핑 | [RPC](rpc.md) |
| 135 | MSRPC | Microsoft RPC | [RPC](rpc.md) |
| 139/445 | SMB | 파일/프린터 공유 | [SMB](smb.md) |
| 161/162 | SNMP | 네트워크 관리 | [SNMP](snmp.md) |
| 389/636 | LDAP/LDAPS | directory 서비스 | [LDAP](ldap.md) |
| 1433 | MSSQL | Microsoft SQL Server | [MSSQL](mssql.md) |
| 1521 | Oracle | Oracle DB | - |
| 2049 | NFS | 네트워크 파일 시스템 | [NFS](nfs.md) |
| 3306 | MySQL | MySQL/MariaDB | [MySQL](mysql.md) |
| 3389 | RDP | Remote Desktop | [RDP](rdp.md) |
| 5432 | PostgreSQL | PostgreSQL DB | - |
| 5985/5986 | WinRM | Windows 원격 관리 | [WinRM](winrm.md) |
| 6379 | Redis | Redis DB | - |
| 8080/8443 | HTTP Proxy | 웹 proxy/관리 페이지 | [HTTP](http.md) |
| 27017 | MongoDB | MongoDB | - |

---

## 기본 워크플로우

```text
1. Nmap 스캔 → 열린 포트 확인
2. 서비스 버전 확인 → 알려진 취약점 검색
3. Anonymous/Default 인증 시도
4. 열거 (사용자, 공유, 설정 등)
5. Brute Force (최후 수단, 주의 필요)
6. 공격 벡터 활용
```

### 모든 포트에 공통으로 확인할 사항

```bash
# 서비스 버전 확인
nmap -sV -sC -p PORT TARGET

# 해당 버전의 알려진 취약점 검색
searchsploit SERVICE VERSION

# NSE 스크립트로 상세 열거
nmap --script="SERVICE-*" -p PORT TARGET
```
