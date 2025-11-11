# Spring Application Advisor Automated Upgrade Pipeline

This pipeline automatically checks for Spring Boot upgrades and best practice recommendations using Spring Application Advisor (SAA).

## What It Does

### Job 1: `check-for-upgrades`
Runs daily and:
1. Checks for available Spring Boot and dependency upgrades using `advisor upgrade-plan get`
2. If upgrades are available:
   - Creates a new branch with pattern `saa-upgrades-YYYYMMDD-HHMMSS`
   - Applies upgrades automatically using `advisor upgrade-plan apply`
   - Commits changes
   - Pushes branch to GitHub
   - **Creates a Pull Request** with upgrade details

### Job 2: `check-for-advice`
Runs daily after upgrades check and:
1. Checks for best practice recommendations using `advisor advice list`
2. If recommendations are available:
   - Creates or updates a GitHub Issue with advice details
   - Lists available recommendations (Java 21, security governance, etc.)
   - Provides instructions on how to apply them manually

## Setup Instructions

### 1. Create GitHub Personal Access Token

You need a GitHub token with `repo` scope to create PRs and issues.

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set description: "Concourse SAA Pipeline"
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
5. Click "Generate token"
6. **Copy the token** (you won't see it again!)

### 2. Configure Credentials

```bash
# Copy the template
cp ci/saa-credentials.yml.template ci/saa-credentials.yml

# Edit with your values
vi ci/saa-credentials.yml
```

Fill in:
- `git-username`: Your GitHub username
- `git-password`: Your GitHub Personal Access Token (same as above)
- `github-token`: Your GitHub Personal Access Token

### 3. Deploy the Pipeline

```bash
# Login to Concourse
fly -t local login -c http://localhost:8081 -u concourse -p secret

# Set the pipeline
fly -t local set-pipeline \
  -p saa-automation \
  -c ci/saa-upgrade-pipeline.yml \
  -l ci/saa-credentials.yml

# Unpause the pipeline
fly -t local unpause-pipeline -p saa-automation
```

### 4. Trigger Manually (Optional)

```bash
# Trigger upgrade check
fly -t local trigger-job -j saa-automation/check-for-upgrades

# Trigger advice check
fly -t local trigger-job -j saa-automation/check-for-advice
```

## Schedule

- **Trigger**: Daily at midnight (Europe/Brussels timezone)
- **Can be adjusted** by changing the `interval` in the `daily-trigger` resource

## Example PR

When upgrades are available, you'll get a PR like this:

```
Title: 🔄 Spring Application Advisor - Automated Upgrades

Body:
## Spring Application Advisor Upgrade Plan

This PR contains automated upgrades suggested by Spring Application Advisor.

### Upgrade Details
- Spring Boot: 3.5.6 → 3.6.0
- Spring Framework: 6.1.x → 6.2.x
- Dependencies updated for compatibility

### What's Changed
- Spring Boot and dependency upgrades
- Configuration updates for compatibility
- Code migrations if required

### Testing Required
- [ ] Review upgrade plan details
- [ ] Run tests locally
- [ ] Verify application behavior
- [ ] Check for breaking changes
```

## Example Issue (for Advice)

When recommendations are available:

```
Title: 💡 Spring Application Advisor - Best Practice Recommendations

Body:
## Spring Application Advisor Recommendations

Available advice:
- java-21: Upgrades to Java 21
- spring-governance-starter: Enforces cipher and TLS security
- tanzu: Generates manifest.yml for Tanzu platform

To apply: advisor advice apply <advice-name>
```

## Troubleshooting

### PR Creation Fails

**Error**: "Resource not accessible by integration"
- **Fix**: Make sure your GitHub token has `repo` scope

### Pipeline Not Triggering

**Check**:
```bash
fly -t local jobs -p saa-automation
fly -t local builds -j saa-automation/check-for-upgrades
```

### Manual Test Without PR

```bash
# In your project directory
advisor upgrade-plan get
advisor upgrade-plan apply --non-interactive
```

## Customization

### Change Schedule

Edit `ci/saa-upgrade-pipeline.yml`:

```yaml
- name: daily-trigger
  type: time
  source:
    interval: 12h  # Run every 12 hours
    # Or use specific times:
    # start: 9:00 AM
    # stop: 5:00 PM
    # days: [Monday, Wednesday, Friday]
```

### Disable Auto-Apply

To only check for upgrades without auto-applying, modify the task to skip `advisor upgrade-plan apply`.

## Links

- [Spring Application Advisor Docs](https://docs.vmware.com/en/Spring-Application-Advisor/)
- [Concourse Time Resource](https://github.com/concourse/time-resource)
- [GitHub CLI Docs](https://cli.github.com/manual/)
