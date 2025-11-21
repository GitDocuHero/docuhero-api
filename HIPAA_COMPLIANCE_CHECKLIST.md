# HIPAA Compliance Checklist for DocuHero
**Project:** docu-hero (GCP Project ID: docu-hero, Project Number: 945625270994)
**Assessment Date:** 2025-11-21
**Status:** ⚠️ NOT COMPLIANT - Multiple critical gaps identified

---

## Executive Summary

DocuHero is currently **NOT HIPAA compliant**. This document outlines critical security gaps and provides a prioritized action plan to achieve compliance with the Health Insurance Portability and Accountability Act (HIPAA) Security Rule.

### Critical Issues Found:
- ❌ No encryption at rest for Cloud SQL
- ❌ SSL/TLS not enforced for database connections
- ❌ Automated backups disabled
- ❌ No Business Associate Agreement (BAA) with Google Cloud
- ❌ Publicly accessible services (allUsers has access)
- ❌ No VPC Service Controls or Private Service Connect
- ❌ No data loss prevention (DLP) scanning
- ❌ No audit log retention policy beyond defaults
- ❌ Overly permissive IAM roles
- ❌ No application-level encryption for PHI
- ❌ No audit trail for PHI access
- ❌ Missing security headers and input validation

---

## HIPAA Requirements Overview

HIPAA requires covered entities and business associates to implement:
1. **Administrative Safeguards** - Policies, procedures, and training
2. **Physical Safeguards** - Physical access controls
3. **Technical Safeguards** - Access controls, audit controls, integrity controls, transmission security

---

## 🔴 CRITICAL PRIORITY (Must fix before handling ANY PHI)

### 1. Sign Business Associate Agreement (BAA) with Google Cloud
**HIPAA Requirement:** 45 CFR § 164.308(b)(1)
**Current Status:** ❌ Not in place
**Risk Level:** CRITICAL - Cannot process PHI without BAA

**Action Items:**
- [ ] Contact Google Cloud sales to execute BAA
- [ ] Request BAA through: https://cloud.google.com/security/compliance/hipaa
- [ ] Document BAA execution date and terms
- [ ] Review covered services (Cloud Run, Cloud SQL, Secret Manager must be covered)

**Estimated Time:** 1-2 weeks (Google process)
**Cost Impact:** None (free with eligible accounts)

---

### 2. Enable Customer-Managed Encryption Keys (CMEK)
**HIPAA Requirement:** 45 CFR § 164.312(a)(2)(iv) - Encryption at Rest
**Current Status:** ❌ Using Google-managed keys only
**Risk Level:** CRITICAL

**Action Items:**
- [ ] Enable Cloud KMS API
- [ ] Create KMS keyring in us-east1
- [ ] Create encryption keys for:
  - [ ] Cloud SQL database encryption
  - [ ] Secret Manager secrets
  - [ ] Cloud Storage buckets (if used)
  - [ ] Container Registry images
- [ ] Configure automatic key rotation (90 days recommended)
- [ ] Grant necessary permissions to service accounts
- [ ] Re-encrypt existing Cloud SQL instance with CMEK
- [ ] Document key management procedures

**Commands to Execute:**
```bash
# Enable Cloud KMS
gcloud services enable cloudkms.googleapis.com --project=docu-hero

# Create keyring
gcloud kms keyrings create docuhero-keyring --location=us-east1 --project=docu-hero

# Create encryption key for Cloud SQL
gcloud kms keys create cloudsql-key \
  --keyring=docuhero-keyring \
  --location=us-east1 \
  --purpose=encryption \
  --rotation-period=90d \
  --next-rotation-time=$(date -u -d "+90 days" +%Y-%m-%dT%H:%M:%SZ) \
  --project=docu-hero

# Grant Cloud SQL service account access
gcloud kms keys add-iam-policy-binding cloudsql-key \
  --keyring=docuhero-keyring \
  --location=us-east1 \
  --member="serviceAccount:service-945625270994@gcp-sa-cloud-sql.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
  --project=docu-hero
```

**Estimated Time:** 4-8 hours
**Cost Impact:** ~$0.06/key/month + ~$0.03/10k operations

---

### 3. Enable and Enforce SSL/TLS for Cloud SQL
**HIPAA Requirement:** 45 CFR § 164.312(e)(1) - Transmission Security
**Current Status:** ❌ SSL not required (sslMode: ALLOW_UNENCRYPTED_AND_ENCRYPTED)
**Risk Level:** CRITICAL

**Action Items:**
- [ ] Enable automated backups FIRST (prevents data loss during update)
- [ ] Update Cloud SQL to require SSL connections
- [ ] Generate and distribute client certificates
- [ ] Update DATABASE_URL to use SSL parameters
- [ ] Update Cloud Run to use SSL connection
- [ ] Test connectivity with SSL enforcement
- [ ] Document certificate rotation procedures

**Commands to Execute:**
```bash
# Enable SSL requirement
gcloud sql instances patch docuhero-db \
  --require-ssl \
  --project=docu-hero

# Create client certificate for Cloud Run service account
gcloud sql ssl-certs create hero-api-cert \
  /tmp/hero-api-cert.pem \
  --instance=docuhero-db \
  --project=docu-hero

# Update DATABASE_URL secret with SSL parameters
# Format: postgresql://user:pass@/dbname?host=/cloudsql/PROJECT:REGION:INSTANCE&sslmode=require
```

**Estimated Time:** 2-4 hours
**Cost Impact:** None

---

### 4. Enable Automated Backups with Retention
**HIPAA Requirement:** 45 CFR § 164.308(a)(7)(ii)(A) - Data Backup Plan
**Current Status:** ❌ Backups disabled (enabled: false)
**Risk Level:** CRITICAL

**Action Items:**
- [ ] Enable automated daily backups
- [ ] Set backup retention to 30 days minimum (recommend 90 days)
- [ ] Enable point-in-time recovery (transaction logs)
- [ ] Set transaction log retention to 7 days minimum
- [ ] Test backup restoration procedure
- [ ] Document backup and recovery procedures
- [ ] Schedule regular backup restoration tests (quarterly)

**Commands to Execute:**
```bash
# Enable automated backups
gcloud sql instances patch docuhero-db \
  --backup-start-time=02:00 \
  --retained-backups-count=90 \
  --retained-transaction-log-days=7 \
  --enable-point-in-time-recovery \
  --project=docu-hero
```

**Estimated Time:** 1-2 hours
**Cost Impact:** ~$0.08/GB/month for backup storage

---

### 5. Implement Access Controls and API Authentication
**HIPAA Requirement:** 45 CFR § 164.312(a)(1) - Access Control
**Current Status:** ⚠️ API lacks authentication (but public access correctly removed)
**Risk Level:** CRITICAL

**Understanding Web App Security:**
- **Frontend (hero-ui)**: Should remain publicly accessible so users can load login/signup pages
- **Backend (hero-api)**: Must require authentication for all PHI-related endpoints
- **Protection Model**: API validates JWT tokens; frontend cannot access PHI without valid credentials

**Current Configuration:**
- ✅ hero-api: Public access removed (403 Forbidden)
- ✅ hero-ui: Public access enabled (users can load pages)

**Action Items:**
- [✅] Remove allUsers from hero-api IAM policy (COMPLETED)
- [✅] Keep hero-ui publicly accessible for login/signup pages (COMPLETED)
- [ ] Implement authentication middleware in API:
  - [ ] JWT-based authentication
  - [ ] Session management with secure cookies
  - [ ] Rate limiting per user
  - [ ] Password hashing (bcrypt/argon2)
- [ ] Implement authorization checks for PHI access
- [ ] Configure CORS policies strictly (whitelist frontend domain)
- [ ] Add API Gateway for centralized authentication (optional)
- [ ] Implement Cloud Armor for DDoS protection
- [ ] Implement IP allowlisting if needed (optional)

**Commands Already Executed:**
```bash
# ✅ Remove public access from API only
gcloud run services remove-iam-policy-binding hero-api \
  --region=us-east1 \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project=docu-hero

# Note: hero-ui remains public so users can access login page
```

**Estimated Time:** 16-24 hours (application changes)
**Cost Impact:** Cloud Armor ~$20/month + $0.75/million requests

---

## 🟠 HIGH PRIORITY (Complete within 30 days)

### 6. Implement Comprehensive Audit Logging
**HIPAA Requirement:** 45 CFR § 164.312(b) - Audit Controls
**Current Status:** ⚠️ Basic Cloud Audit Logs enabled, but no application-level PHI access logs
**Risk Level:** HIGH

**Action Items:**
- [ ] Extend Cloud Audit Log retention to 7 years
- [ ] Enable Data Access audit logs for all services
- [ ] Create dedicated log sink for HIPAA audit logs
- [ ] Export logs to BigQuery for long-term storage and analysis
- [ ] Implement application-level audit logging for:
  - [ ] PHI creation
  - [ ] PHI read access (who, what, when)
  - [ ] PHI modifications
  - [ ] PHI deletions
  - [ ] Authentication attempts (success/failure)
  - [ ] Authorization failures
  - [ ] Configuration changes
- [ ] Set up log-based alerting for suspicious activity
- [ ] Create audit log review procedures
- [ ] Document log retention policy

**Commands to Execute:**
```bash
# Create audit log export to BigQuery
bq mk --dataset --location=us-east1 docu-hero:hipaa_audit_logs

gcloud logging sinks create hipaa-audit-export \
  bigquery.googleapis.com/projects/docu-hero/datasets/hipaa_audit_logs \
  --log-filter='logName:"cloudaudit.googleapis.com" OR protoPayload.metadata."@type"="type.googleapis.com/google.cloud.audit.AuditLog"' \
  --project=docu-hero

# Enable Data Access logs
gcloud projects get-iam-policy docu-hero > /tmp/policy.yaml
# Edit policy.yaml to add Data Access audit config
gcloud projects set-iam-policy docu-hero /tmp/policy.yaml
```

**Estimated Time:** 8-12 hours
**Cost Impact:** BigQuery storage ~$0.02/GB/month + query costs

---

### 7. Implement VPC Service Controls
**HIPAA Requirement:** 45 CFR § 164.312(a)(2)(i) - Network Segmentation
**Current Status:** ❌ No VPC, services in shared environment
**Risk Level:** HIGH

**Action Items:**
- [ ] Enable Compute Engine API
- [ ] Create VPC network for DocuHero
- [ ] Create private subnet for Cloud SQL
- [ ] Configure Private Service Connect for Cloud SQL
- [ ] Configure Serverless VPC Access for Cloud Run
- [ ] Remove public IP from Cloud SQL
- [ ] Set up VPC Service Controls perimeter
- [ ] Configure egress/ingress rules
- [ ] Enable VPC Flow Logs
- [ ] Document network architecture

**Commands to Execute:**
```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com --project=docu-hero

# Create VPC network
gcloud compute networks create docuhero-vpc \
  --subnet-mode=custom \
  --project=docu-hero

# Create subnet
gcloud compute networks subnets create docuhero-subnet \
  --network=docuhero-vpc \
  --region=us-east1 \
  --range=10.0.0.0/24 \
  --enable-flow-logs \
  --project=docu-hero

# Create VPC connector for Cloud Run
gcloud compute networks vpc-access connectors create docuhero-connector \
  --network=docuhero-vpc \
  --region=us-east1 \
  --range=10.8.0.0/28 \
  --project=docu-hero
```

**Estimated Time:** 6-10 hours
**Cost Impact:** VPC connector ~$45/month + VPC costs

---

### 8. Implement Role-Based Access Control (RBAC)
**HIPAA Requirement:** 45 CFR § 164.308(a)(4) - Information Access Management
**Current Status:** ⚠️ Overly permissive (compute service account has Editor role)
**Risk Level:** HIGH

**Action Items:**
- [ ] Apply principle of least privilege to all service accounts
- [ ] Remove Editor role from compute service account (945625270994-compute@developer.gserviceaccount.com)
- [ ] Create custom IAM roles for specific purposes
- [ ] Implement separate service accounts for:
  - [ ] Cloud Run API service
  - [ ] Cloud Run UI service
  - [ ] Cloud Build
  - [ ] Database access
- [ ] Document all IAM roles and permissions
- [ ] Implement regular access reviews (quarterly)
- [ ] Enable Cloud Asset Inventory for IAM tracking

**Commands to Execute:**
```bash
# Remove overly permissive Editor role
gcloud projects remove-iam-policy-binding docu-hero \
  --member="serviceAccount:945625270994-compute@developer.gserviceaccount.com" \
  --role="roles/editor"

# Grant minimum required permissions
gcloud projects add-iam-policy-binding docu-hero \
  --member="serviceAccount:945625270994-compute@developer.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

**Estimated Time:** 4-6 hours
**Cost Impact:** None

---

### 9. Implement Data Loss Prevention (DLP)
**HIPAA Requirement:** 45 CFR § 164.308(a)(1)(ii)(B) - Risk Management
**Current Status:** ❌ No DLP scanning
**Risk Level:** HIGH

**Action Items:**
- [ ] Enable Cloud DLP API
- [ ] Create DLP inspection templates for:
  - [ ] Patient names
  - [ ] SSN
  - [ ] Medical record numbers
  - [ ] Dates of service
  - [ ] Email addresses
  - [ ] Phone numbers
- [ ] Configure DLP to scan:
  - [ ] Database (periodic scans)
  - [ ] Logs
  - [ ] Cloud Storage (if used)
- [ ] Set up alerts for DLP findings
- [ ] Implement remediation procedures

**Commands to Execute:**
```bash
# Enable DLP API
gcloud services enable dlp.googleapis.com --project=docu-hero

# Create DLP inspection template (via Console or API)
# Configure scanning jobs
```

**Estimated Time:** 6-8 hours
**Cost Impact:** ~$1 per GB scanned

---

### 10. Upgrade Cloud SQL Instance
**HIPAA Requirement:** Infrastructure Resilience
**Current Status:** ⚠️ db-f1-micro (shared CPU, 0.6GB RAM)
**Risk Level:** MEDIUM-HIGH

**Action Items:**
- [ ] Upgrade to dedicated CPU instance (db-custom or db-standard)
- [ ] Enable high availability (HA) configuration
- [ ] Configure read replicas for performance (optional)
- [ ] Document scaling procedures

**Commands to Execute:**
```bash
# Upgrade to dedicated instance with HA
gcloud sql instances patch docuhero-db \
  --tier=db-custom-2-8192 \
  --availability-type=REGIONAL \
  --project=docu-hero
```

**Estimated Time:** 2-3 hours
**Cost Impact:** ~$100-200/month (significant increase from f1-micro)

---

## 🟡 MEDIUM PRIORITY (Complete within 60 days)

### 11. Implement Application-Level Security
**HIPAA Requirement:** Multiple technical safeguards
**Current Status:** ❌ Minimal security implementation
**Risk Level:** MEDIUM

**Action Items:**

#### API Security (src/index.ts)
- [ ] Implement authentication middleware (JWT, OAuth2, or SAML)
- [ ] Add authorization checks for all endpoints
- [ ] Implement rate limiting (helmet-ratelimit)
- [ ] Add security headers (helmet.js):
  ```javascript
  - X-Frame-Options: DENY
  - X-Content-Type-Options: nosniff
  - Strict-Transport-Security: max-age=31536000
  - Content-Security-Policy
  - X-XSS-Protection: 1; mode=block
  ```
- [ ] Implement input validation (joi or zod)
- [ ] Add request sanitization (xss-clean)
- [ ] Implement CORS properly (not '*')
- [ ] Add request logging with correlation IDs
- [ ] Implement session management with secure cookies
- [ ] Add CSRF protection
- [ ] Implement timeout for database connections
- [ ] Add circuit breakers for external dependencies

#### Database Security (Prisma)
- [ ] Implement field-level encryption for PHI:
  - [ ] Patient names
  - [ ] SSN/identifiers
  - [ ] Medical record numbers
  - [ ] Address information
  - [ ] Contact information
- [ ] Use parameterized queries (Prisma does this by default, verify)
- [ ] Implement row-level security
- [ ] Add soft deletes for PHI (never hard delete)
- [ ] Implement data retention policies
- [ ] Add database connection pooling with limits

#### Monitoring & Alerting
- [ ] Set up Cloud Monitoring dashboards
- [ ] Configure alerting for:
  - [ ] Failed authentication attempts (>5 in 5 min)
  - [ ] Unusual data access patterns
  - [ ] Service downtime
  - [ ] High error rates
  - [ ] Database connection issues
  - [ ] Backup failures
- [ ] Implement health checks with detailed status
- [ ] Set up uptime monitoring

**Estimated Time:** 24-40 hours
**Cost Impact:** Cloud Monitoring ~$5-15/month

---

### 12. Implement Data Encryption in Transit (End-to-End)
**HIPAA Requirement:** 45 CFR § 164.312(e)(1)
**Current Status:** ⚠️ TLS to Cloud Run, but need verification
**Risk Level:** MEDIUM

**Action Items:**
- [ ] Verify TLS 1.2+ is enforced on Cloud Run
- [ ] Configure minimum TLS version
- [ ] Disable weak cipher suites
- [ ] Implement HSTS headers
- [ ] Set up certificate monitoring
- [ ] Document encryption in transit architecture

**Commands to Execute:**
```bash
# Cloud Run enforces TLS 1.2+ by default, verify configuration
gcloud run services describe hero-api --region=us-east1 --format="yaml(spec)" --project=docu-hero
```

**Estimated Time:** 2-4 hours
**Cost Impact:** None

---

### 13. Implement Secrets Rotation
**HIPAA Requirement:** 45 CFR § 164.308(a)(5)(ii)(D) - Password Management
**Current Status:** ⚠️ Secrets exist but no rotation policy
**Risk Level:** MEDIUM

**Action Items:**
- [ ] Implement automatic secret rotation for:
  - [ ] Database passwords (90 days)
  - [ ] API keys (90 days)
  - [ ] Service account keys (90 days)
  - [ ] Encryption keys (automated via CMEK)
- [ ] Document secret rotation procedures
- [ ] Test rotation procedures
- [ ] Set up alerts for expiring secrets
- [ ] Use Secret Manager versioning

**Estimated Time:** 6-8 hours
**Cost Impact:** Minimal

---

### 14. Implement Disaster Recovery Plan
**HIPAA Requirement:** 45 CFR § 164.308(a)(7)(ii)(B) - Disaster Recovery Plan
**Current Status:** ❌ No documented DR plan
**Risk Level:** MEDIUM

**Action Items:**
- [ ] Document RTO (Recovery Time Objective) - recommend 4 hours
- [ ] Document RPO (Recovery Point Objective) - recommend 15 minutes
- [ ] Create runbook for disaster recovery scenarios:
  - [ ] Database corruption
  - [ ] Regional outage
  - [ ] Security breach
  - [ ] Data loss
- [ ] Test backup restoration quarterly
- [ ] Document and test failover procedures
- [ ] Create multi-region backup strategy
- [ ] Set up Cloud SQL replica in different region (optional)

**Estimated Time:** 8-12 hours
**Cost Impact:** Cross-region replica ~$50-100/month (optional)

---

### 15. Implement Security Scanning and Vulnerability Management
**HIPAA Requirement:** 45 CFR § 164.308(a)(1)(ii)(A) - Risk Analysis
**Current Status:** ❌ No automated scanning
**Risk Level:** MEDIUM

**Action Items:**
- [ ] Enable Container Analysis for Docker images
- [ ] Set up dependency scanning (npm audit, Snyk, or Dependabot)
- [ ] Configure Web Security Scanner
- [ ] Implement SAST (Static Application Security Testing)
- [ ] Implement DAST (Dynamic Application Security Testing)
- [ ] Schedule regular penetration testing (annually)
- [ ] Create vulnerability remediation SLA
- [ ] Document patching procedures

**Estimated Time:** 6-10 hours
**Cost Impact:** Snyk or similar ~$50-100/month

---

## 🟢 LOW PRIORITY (Complete within 90 days)

### 16. Administrative Safeguards

**Action Items:**
- [ ] Create HIPAA Security Officer role
- [ ] Develop comprehensive security policies:
  - [ ] Access control policy
  - [ ] Password policy
  - [ ] Incident response policy
  - [ ] Breach notification procedures
  - [ ] Data retention policy
  - [ ] Acceptable use policy
- [ ] Implement workforce training program
- [ ] Create workforce member agreements
- [ ] Implement termination procedures
- [ ] Conduct risk assessments (annually)
- [ ] Create contingency planning documentation

**Estimated Time:** 40-60 hours
**Cost Impact:** Training materials ~$500-2000

---

### 17. Implement Minimum Necessary Standard
**HIPAA Requirement:** 45 CFR § 164.502(b)
**Current Status:** ❌ Not implemented
**Risk Level:** LOW-MEDIUM

**Action Items:**
- [ ] Implement role-based data access
- [ ] Create user permission levels:
  - [ ] Admin (full access)
  - [ ] Provider (patient data access)
  - [ ] Agency (limited access)
  - [ ] Billing (financial only)
- [ ] Implement field-level permissions
- [ ] Log all data access with justification
- [ ] Create data access request workflow

**Estimated Time:** 12-16 hours
**Cost Impact:** None

---

### 18. Physical Safeguards Documentation
**HIPAA Requirement:** 45 CFR § 164.310
**Current Status:** ⚠️ Rely on GCP physical security (covered under BAA)
**Risk Level:** LOW

**Action Items:**
- [ ] Document reliance on GCP physical security
- [ ] Review GCP data center certifications
- [ ] Document workstation security requirements
- [ ] Create device security policy (for any devices accessing PHI)
- [ ] Implement workstation auto-lock
- [ ] Document media disposal procedures

**Estimated Time:** 4-6 hours
**Cost Impact:** None

---

### 19. Implement Patient Rights Procedures
**HIPAA Requirement:** 45 CFR § 164.524, 164.526
**Current Status:** ❌ Not implemented
**Risk Level:** LOW

**Action Items:**
- [ ] Create procedure for patients to:
  - [ ] Request access to their PHI
  - [ ] Request amendments to their PHI
  - [ ] Request accounting of disclosures
  - [ ] Request restrictions on uses/disclosures
- [ ] Implement data export functionality
- [ ] Document response timeframes (30 days for access requests)
- [ ] Create forms and workflows

**Estimated Time:** 8-12 hours
**Cost Impact:** None

---

### 20. Implement Security Incident Response
**HIPAA Requirement:** 45 CFR § 164.308(a)(6)
**Current Status:** ❌ No formal incident response plan
**Risk Level:** MEDIUM

**Action Items:**
- [ ] Create incident response team
- [ ] Develop incident response plan:
  - [ ] Detection procedures
  - [ ] Containment procedures
  - [ ] Eradication procedures
  - [ ] Recovery procedures
  - [ ] Post-incident review
- [ ] Create breach notification procedures (within 60 days)
- [ ] Document incident reporting chain
- [ ] Conduct incident response drills (semi-annually)
- [ ] Create incident log

**Estimated Time:** 12-16 hours
**Cost Impact:** None

---

## Testing & Validation

### Pre-Production Checklist
Before handling real PHI, verify:
- [ ] BAA signed with Google Cloud
- [ ] CMEK implemented and tested
- [ ] SSL/TLS enforced and tested
- [ ] Automated backups enabled and tested
- [ ] Audit logging functioning and tested
- [ ] Authentication implemented and tested
- [ ] Authorization checks functioning
- [ ] Application security headers present
- [ ] DLP scanning configured
- [ ] Penetration test completed
- [ ] Security policies documented
- [ ] Staff trained on HIPAA requirements
- [ ] Incident response plan tested

### Compliance Validation
- [ ] Internal security audit
- [ ] Third-party security assessment
- [ ] Penetration testing
- [ ] Vulnerability scanning
- [ ] Compliance gap analysis
- [ ] Risk assessment documentation

---

## Cost Summary

### One-Time Costs
| Item | Estimated Cost |
|------|----------------|
| Third-party security audit | $5,000 - $15,000 |
| Penetration testing | $3,000 - $10,000 |
| HIPAA training materials | $500 - $2,000 |
| Security tooling setup | $1,000 - $3,000 |
| **Total One-Time** | **$9,500 - $30,000** |

### Recurring Monthly Costs
| Item | Current | With HIPAA Compliance |
|------|---------|---------------------|
| Cloud SQL (f1-micro → custom-2) | ~$10 | ~$150 |
| CMEK | $0 | ~$5 |
| Automated Backups | $0 | ~$20 |
| VPC Connector | $0 | ~$45 |
| Cloud Armor | $0 | ~$25 |
| DLP Scanning | $0 | ~$10 |
| Security Tooling (Snyk, etc.) | $0 | ~$75 |
| Additional logging/monitoring | $0 | ~$10 |
| **Total Monthly** | **~$10** | **~$340** |

### Annual Costs
- Compliance audit: $5,000 - $10,000
- Penetration testing: $3,000 - $10,000
- Staff training updates: $500 - $1,000
- **Total Annual:** ~$8,500 - $21,000

---

## Timeline Summary

### Phase 1: Critical (Weeks 1-4)
1. Sign BAA with Google Cloud
2. Enable CMEK encryption
3. Enforce SSL/TLS
4. Enable automated backups
5. Remove public access
6. Implement authentication

### Phase 2: High Priority (Weeks 5-8)
7. Extend audit logging
8. Implement VPC Service Controls
9. Apply RBAC principles
10. Enable DLP
11. Upgrade Cloud SQL instance

### Phase 3: Medium Priority (Weeks 9-16)
12. Application-level security hardening
13. Secrets rotation
14. Disaster recovery plan
15. Security scanning

### Phase 4: Administrative (Weeks 17-24)
16. Policies and procedures
17. Training program
18. Compliance testing and validation

---

## Compliance Maintenance

### Daily
- Monitor security alerts
- Review failed authentication attempts

### Weekly
- Review audit logs for anomalies
- Check backup success status
- Review access logs for unusual patterns

### Monthly
- Review IAM permissions
- Update security patches
- Review incident logs
- Generate compliance reports

### Quarterly
- Test backup restoration
- Conduct access reviews
- Update risk assessment
- Review and update security policies
- Conduct incident response drills

### Annually
- Comprehensive security audit
- Penetration testing
- HIPAA training refresher
- Risk assessment update
- Policy review and updates

---

## Resources

### HIPAA References
- HIPAA Security Rule: https://www.hhs.gov/hipaa/for-professionals/security/index.html
- HIPAA Breach Notification Rule: https://www.hhs.gov/hipaa/for-professionals/breach-notification/index.html

### Google Cloud HIPAA Resources
- GCP HIPAA Compliance: https://cloud.google.com/security/compliance/hipaa
- BAA Request: https://cloud.google.com/terms/service-terms
- HIPAA Implementation Guide: https://cloud.google.com/architecture/hipaa-implementation-guide

### Industry Standards
- NIST Cybersecurity Framework: https://www.nist.gov/cyberframework
- CIS Controls: https://www.cisecurity.org/controls

---

## Approval and Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Security Officer | | | |
| Privacy Officer | | | |
| Technical Lead | | | |
| Executive Sponsor | | | |

---

**Document Version:** 1.0
**Last Updated:** 2025-11-21
**Next Review Date:** 2025-12-21
**Owner:** Security Officer
