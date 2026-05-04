# 🏗️ RepairDesk Infrastructure

> Infrastructure as Code for the [RepairDesk](https://github.com/Ejoh-Hosea/RepairDesk-full-stack-app.git) application.
> Provisioned with Terraform. Deployed via GitHub Actions. Destroyed with one command.

---

## 🔗 Two-Repo Architecture

This project follows the **GitOps separation of concerns** pattern:

| Repo                             | Purpose                                                          |
| -------------------------------- | ---------------------------------------------------------------- |
| **repairdesk-infra** (this repo) | All AWS infrastructure — Terraform + CI/CD pipeline + Dockerfile |
| **repair-dashboard** (app repo)  | Application code — React frontend + Node.js backend              |

At deploy time, GitHub Actions checks out **both repos** — it uses the Dockerfile from this repo and the source code from the app repo. They are completely independent.

```
repairdesk-infra                repair-dashboard
(this repo)                     (app repo)
     │                               │
     └──── GitHub Actions ───────────┘
                  │
                  ├── docker build (Dockerfile from infra, code from app)
                  ├── push image → ECR → deploy to ECS
                  ├── npm run build (client/ from app)
                  └── sync → S3 → invalidate CloudFront
```

---

## 📐 Infrastructure Architecture

<p align="center">
  <img src="./repairdesk_architecture.png" alt="RepairDesk AWS Architecture" width="900"/>
</p>

---

## ⚠️ Cost Warning — Read Before Starting

This is **not fully free tier**. For a 3–5 day demo expect **$3–6 total**.
Destroy immediately after screenshots.

| Service              | Free?              | Cost if left running |
| -------------------- | ------------------ | -------------------- |
| ECS Fargate 0.25vCPU | ❌                 | ~$0.01/hr            |
| NAT Gateway          | ❌                 | ~$0.045/hr           |
| ALB                  | ✅ first 12 months | $0.008/hr after      |
| Route 53 Hosted Zone | ❌                 | $0.50/month          |
| S3, CloudFront, ACM  | ✅                 | negligible           |
| Secrets Manager      | ✅ 30-day trial    | $0.40/secret after   |

**Destroy everything:** `cd terraform && terraform destroy -auto-approve`

---

## 📋 Prerequisites

```bash
# Install Terraform
# Mac:
brew install terraform
# Windows: https://developer.hashicorp.com/terraform/downloads

# Install AWS CLI
# Mac:
brew install awscli
# Windows: https://aws.amazon.com/cli/

# Install Docker Desktop
# https://www.docker.com/products/docker-desktop/

# Verify versions
terraform --version   # must be >= 1.6.0
aws --version
docker --version
```

---

## 🚀 Setup — Step by Step

### STEP 1 — Create AWS Account & IAM User

1. Sign up at **https://aws.amazon.com** (free)
2. In the AWS Console go to **IAM → Users → Create user**
3. Name it `terraform-admin`
4. Attach policy: **AdministratorAccess**
5. Go to **Security credentials → Create access key → CLI**
6. Download the CSV — you need these two values

---

### STEP 2 — Configure AWS CLI

```bash
aws configure
# Paste your values:
# AWS Access Key ID:     from CSV
# AWS Secret Access Key: from CSV
# Default region:        us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
# Should print your account ID and username
```

---

### STEP 3 — MongoDB Atlas Free Cluster

1. Sign up at **https://cloud.mongodb.com**
2. Create a free **M0** cluster
3. **Database Access → Add New Database User**
   - Username: `repairapp`
   - Password: something strong — save it
   - Role: Read and write to any database
4. **Network Access → Add IP Address → Allow Access from Anywhere** (`0.0.0.0/0`)
   - Required because ECS Fargate uses dynamic IPs
5. **Database → Connect → Drivers → Node.js 5.5+**
6. Copy the connection string — looks like:
   ```
   mongodb+srv://repairapp:<password>@cluster.abc.mongodb.net/?retryWrites=true&w=majority
   ```
7. Replace `<password>` with your actual password and add the database name:
   ```
   mongodb+srv://repairapp:YOURPASSWORD@cluster.abc.mongodb.net/repair-dashboard?retryWrites=true&w=majority&appName=repair-cluster
   ```

---

### STEP 4 — Clone this repo and configure Terraform

```bash
git clone https://github.com/Ejoh-Hosea/RepairDesk-full-stack-app.git
cd terraform

# Create your variables file from the example
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform/terraform.tfvars` and fill in your 3 values:

```hcl
domain_name = "yourdomain.com"     # Your actual GoDaddy domain
mongo_uri   = "mongodb+srv://..."  # Connection string from Step 3
jwt_secret  = "..."                # Generate below
```

Generate your JWT secret:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Leave everything else — `aws_region`, `environment`, `project`, `app_image = "placeholder"` — exactly as the example shows.

---

### STEP 5 — Run Terraform

```bash
cd terraform

# Initialize — download AWS provider (run once)
terraform init

# Run apply — this will pause partway through, which is expected (see note below)
terraform apply -auto-approve
```

> ⚠️ **Expected behaviour — Terraform will hang here:**
>
> ```
> aws_acm_certificate_validation.api: Still creating... [02m00s elapsed]
> aws_acm_certificate_validation.frontend: Still creating... [02m00s elapsed]
> ```
>
> This is normal. ACM is waiting for your domain's DNS to resolve through
> Route 53 — but GoDaddy is still in control. **Press Ctrl+C to cancel.**
> Terraform will print "Interrupt received" and exit cleanly — that is fine.
> Nothing is broken. Continue to Step 6.

After cancelling, get your nameservers:

```bash
terraform output nameservers
```

You'll see 4 values like:

```
"ns-111.awsdns-11.com",
"ns-222.awsdns-22.net",
"ns-333.awsdns-33.org",
"ns-444.awsdns-44.co.uk",
```

---

### STEP 6 — Update GoDaddy nameservers then re-run Terraform

**Update GoDaddy first:**

1. Log into **GoDaddy → My Products → DNS** on your domain
2. **Nameservers → Change → I'll use my own nameservers**
3. Paste the 4 `ns-xxx.awsdns-xxx` values from the output above
4. Save

**Wait for DNS propagation** — takes 15 minutes to 2 hours.
Check at **https://dnschecker.org** → search your domain → NS tab.
When all locations show the `awsdns` nameservers you are ready.

**Re-run Terraform:**

```bash
terraform apply -auto-approve
```

This time ACM certificate validation will complete in 2-5 minutes because
Route 53 is now authoritative for your domain. The full apply takes 8-12 minutes.

When complete you'll see:

```
ecr_repository_url          = "123456789.dkr.ecr.us-east-1.amazonaws.com/repairdesk-backend"
ecs_cluster_name            = "repairdesk-cluster"
ecs_service_name            = "repairdesk-service"
s3_bucket_name              = "repairdesk-frontend-prod"
cloudfront_distribution_id  = "E1ABCDEF123456"
frontend_url                = "https://yourdomain.com"
api_url                     = "https://api.yourdomain.com"
github_actions_access_key_id = "AKIA..."
```

Save these outputs — you need them in the next steps.

---

### STEP 7 — Build and push the Docker image

```bash
# Go back to the root of this infra repo
cd ..

# Set your ECR URL from Step 5 output
ECR_URL="123456789.dkr.ecr.us-east-1.amazonaws.com/repairdesk-backend"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Clone the app repo
git clone https://github.com/Ejoh-Hosea/RepairDesk-full-stack-app.git app

# Build Docker image
# -f = Dockerfile from THIS infra repo
# ./app/server = source code from the app repo
docker build \
  -f Dockerfile \
  -t $ECR_URL:latest \
  ./app/server

# Push to ECR
docker push $ECR_URL:latest
```

---

### STEP 8 — Deploy to ECS

```bash
# Force ECS to pull the new image
aws ecs update-service \
  --cluster repairdesk-cluster \
  --service repairdesk-service \
  --force-new-deployment

# Wait for it to stabilize (~2–3 minutes)
aws ecs wait services-stable \
  --cluster repairdesk-cluster \
  --services repairdesk-service

echo "✅ Backend is live"
```

Verify:

```bash
curl https://api.yourdomain.com/api/health
# Expected: {"success":true,"status":"ok","timestamp":"..."}
```

---

### STEP 9 — Build and deploy the React frontend

```bash
# Build React (using the cloned app repo from Step 7)
cd app/client
npm install
VITE_API_URL=https://api.yourdomain.com npm run build
cd ../..

# Set your values from Step 5 output
S3_BUCKET="repairdesk-frontend-prod"
CF_ID="E1ABCDEF123456"

# Upload to S3
aws s3 sync app/client/dist/ s3://$S3_BUCKET --delete \
  --cache-control "public, max-age=31536000, immutable"

aws s3 cp app/client/dist/index.html s3://$S3_BUCKET/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront so users see the new build
aws cloudfront create-invalidation \
  --distribution-id $CF_ID \
  --paths "/*"

echo "✅ Frontend is live at https://yourdomain.com"
```

---

STEP 10 --- Seed the Database
Before running the seed script, you must provide the required
environment variables locally.

> ⚠️ Even if you defined values in Terraform (`terraform.tfvars`), they
> are **NOT available locally**.\
> You must create a `.env` file for the backend.

---

1. Navigate to the server

```bash
cd app/server
npm install
```

---

2. Create a `.env` file
   Create a file at:
   app/server/.env
   Add the following:

```env
MONGO_URI=your_atlas_connection_string
JWT_SECRET=your_jwt_secret
NODE_ENV=development
```

> 💡 You can copy values from your `terraform.tfvars`, but they must be
> placed here for local scripts.

---

3. Run the seed script

```bash
npm run seed
cd ../..
```

---

✅ What this does
Creates admin user: `admin` / `admin123`
Inserts 10 sample repairs with realistic dates for charts

---

---

### STEP 11 — Set up GitHub Actions (automated future deploys)

Get your CI/CD credentials:

```bash
cd terraform
terraform output github_actions_access_key_id
terraform output -raw github_actions_secret_access_key
```

Go to **this repo on GitHub → Settings → Secrets and variables → Actions**
and add these secrets:

| Secret                       | Value                                              |
| ---------------------------- | -------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`          | from output above                                  |
| `AWS_SECRET_ACCESS_KEY`      | from output above                                  |
| `APP_REPO`                   | `yourusername/repair-dashboard`                    |
| `APP_REPO_TOKEN`             | GitHub PAT with `repo` read scope — see below      |
| `DOMAIN_NAME`                | `yourdomain.com`                                   |
| `S3_BUCKET_NAME`             | from `terraform output s3_bucket_name`             |
| `CLOUDFRONT_DISTRIBUTION_ID` | from `terraform output cloudfront_distribution_id` |

**Creating the APP_REPO_TOKEN (GitHub Personal Access Token):**

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → check `repo` scope → Generate
3. Copy the token → paste as `APP_REPO_TOKEN` secret

**Future deploys:**
GitHub → Actions → Deploy to AWS → Run workflow → Run workflow

---

## 🗑️ Destroy Everything

When you're done — screenshots taken, LinkedIn posted:

```bash
# Empty S3 first (Terraform can't destroy non-empty buckets)
aws s3 rm s3://repairdesk-frontend-prod --recursive

# Destroy all AWS resources (~10–15 minutes)
cd terraform
terraform destroy -auto-approve
```

Check the AWS Console to confirm nothing remains. Route 53 hosted zone may show
a $0.50 charge for the current month — delete it manually if needed.

---

## 🔧 Troubleshooting

**ECS task failing to start**

```bash
# View live logs
aws logs tail /ecs/repairdesk --follow
```

Most common cause: wrong `MONGO_URI` in Secrets Manager or Atlas not allowing `0.0.0.0/0`.

**`terraform apply` fails waiting for certificate validation**

- DNS hasn't propagated yet from Step 6
- Check https://dnschecker.org — wait until NS records show Route 53 values
- Run `terraform apply` again — it picks up where it left off

**CloudFront showing old content**

```bash
aws cloudfront create-invalidation --distribution-id YOUR_CF_ID --paths "/*"
```

**ECS service shows 0/1 running tasks**

```bash
aws ecs describe-services \
  --cluster repairdesk-cluster \
  --services repairdesk-service \
  --query 'services[0].events[:5]'
```

**GitHub Actions: cannot checkout app repo**

- Verify `APP_REPO` secret is in format `username/repair-dashboard`
- Verify `APP_REPO_TOKEN` has `repo` scope and hasn't expired

---

## 🗂️ File Structure

```
repairdesk-infra/
├── .github/
│   └── workflows/
│       └── deploy.yml              ← CI/CD pipeline
├── terraform/
│   ├── main.tf                     ← Provider config
│   ├── variables.tf                ← Input variables
│   ├── outputs.tf                  ← Values after apply
│   ├── terraform.tfvars.example    ← Template — safe to commit
│   ├── vpc.tf                      ← VPC, subnets, IGW, NAT
│   ├── security.tf                 ← Security groups
│   ├── alb.tf                      ← Load balancer + target group
│   ├── ecr.tf                      ← Container registry
│   ├── ecs.tf                      ← Fargate cluster + service
│   ├── frontend.tf                 ← S3 + CloudFront
│   ├── dns.tf                      ← Route 53 + ACM certs
│   ├── secrets.tf                  ← Secrets Manager
│   ├── cloudwatch.tf               ← Logs + alarms
│   └── iam.tf                      ← Roles + GitHub Actions user
├── Dockerfile                      ← Node.js multi-stage build
├── diagram.py                      ← Architecture diagram generator
├── repairdesk_architecture.png     ← Generated — commit this
├── .gitignore                      ← Excludes tfvars, tfstate, .terraform/
└── README.md                       ← This file
```

---

## 🔑 Key Technical Decisions

**Why two repos?**
Application code and infrastructure have different change rates, different
owners, and different deployment triggers. This is the GitOps pattern — infra
is version-controlled separately, pulls the app at deploy time.

**Why ECS Fargate over EC2?**
No servers to manage. Pay per second of CPU/memory used. 0.25 vCPU / 512MB
is the cheapest Fargate config and still looks production-grade on a resume.

**Why Secrets Manager over .env files?**
ECS pulls secrets at runtime — nothing sensitive in the Docker image, GitHub,
or CloudWatch logs. `recovery_window_in_days = 0` allows clean destroy/recreate.

**Why ACM certs in two regions?**
CloudFront only accepts certificates from `us-east-1`. The ALB cert lives in
your primary region. This is a common AWS interview question.

**Why a single NAT Gateway?**
HA best practice is one per AZ. For a portfolio demo the cost saving
(~$0.045/hr) is worth the tradeoff. Documented here so you can explain it.

---

## 🇨🇦 Note on Canadian Data Residency

This infrastructure is deployed in `us-east-1` (N. Virginia). For production
use in Quebec, consider `ca-central-1` (Montreal) to comply with Quebec's
**Law 25 / Bill 64** data residency requirements. The Terraform region variable
makes this a one-line change.
