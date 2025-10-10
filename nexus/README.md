# Nexus Repository Manager Setup

This directory contains configuration for running Nexus Repository Manager with a Tanzu Enterprise Java repository mirror.

## Quick Start

### 1. Create Credentials File

Copy the credentials template and add your Tanzu credentials:

```bash
cp nexus/credentials.env.template nexus/credentials.env
```

Edit `nexus/credentials.env` and replace the placeholder values with your actual Tanzu credentials:
- `TANZU_REPO_USERNAME`: Your Tanzu username
- `TANZU_REPO_PASSWORD`: Your Tanzu password

**Important**: The `credentials.env` file is in `.gitignore` and will not be committed to version control.

### 2. Start Nexus

```bash
docker-compose up -d nexus
```

Nexus will be available at: **http://localhost:8082**

The initial startup takes about 2-3 minutes. You can check the logs:

```bash
docker-compose logs -f nexus
```

### 3. Configure Tanzu Repository Mirror

Run the setup script to configure the Tanzu Enterprise Java repository:

```bash
./nexus/scripts/setup-tanzu-repo.sh
```

This script will:
- Wait for Nexus to be ready
- Create a proxy repository for Tanzu Enterprise Java
- Add the repository to the maven-public group
- Display configuration instructions for your Maven builds

## Using Nexus in Your Builds

### Option 1: Update pom.xml (Project-Specific)

Add these sections to your `pom.xml`:

```xml
<repositories>
  <repository>
    <id>nexus</id>
    <url>http://localhost:8082/repository/maven-public/</url>
  </repository>
</repositories>

<pluginRepositories>
  <pluginRepository>
    <id>nexus</id>
    <url>http://localhost:8082/repository/maven-public/</url>
  </pluginRepository>
</pluginRepositories>
```

### Option 2: Maven Settings (Global Mirror - Recommended)

Create or edit `~/.m2/settings.xml`:

```xml
<settings>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8082/repository/maven-public/</url>
    </mirror>
  </mirrors>
</settings>
```

## Accessing Nexus UI

1. Navigate to **http://localhost:8082**
2. Click "Sign In" in the top right
3. Default credentials:
   - Username: `admin`
   - Password: Get from container with:
     ```bash
     docker exec $(docker ps -qf "name=nexus") cat /nexus-data/admin.password
     ```
4. Follow the setup wizard to change the password (optional)

## Managing Nexus

### Stop Nexus

```bash
docker-compose stop nexus
```

### Remove Nexus (Including Data)

```bash
docker-compose down -v
```

**Warning**: This will delete all cached artifacts. To preserve the cache, omit the `-v` flag.

### View Logs

```bash
docker-compose logs -f nexus
```

## Rollback Instructions

If you need to remove the Nexus setup completely:

```bash
# Stop and remove Nexus container and volume
docker-compose down -v

# Remove Nexus configuration from docker-compose.yml
git restore docker-compose.yml

# Remove Nexus directory
rm -rf nexus/

# Restore .gitignore
git restore .gitignore
```

Or simply use git to revert all changes:

```bash
git checkout docker-compose.yml .gitignore
git clean -fd nexus/
```

## Troubleshooting

### Nexus won't start

Check available disk space:
```bash
df -h
```

Nexus requires at least 1GB of free space.

### Can't access Nexus UI

Verify the container is running:
```bash
docker-compose ps nexus
```

Check the health status:
```bash
docker inspect $(docker ps -qf "name=nexus") | grep -A 5 Health
```

### Tanzu repository not working

1. Verify your credentials in `nexus/credentials.env`
2. Check the repository configuration in Nexus UI:
   - Go to Settings (gear icon) → Repositories
   - Find "tanzu-enterprise-maven"
   - Verify the remote URL and authentication

### Clear cache and start fresh

```bash
docker-compose down
docker volume rm blue-green-demo_nexus-data
docker-compose up -d nexus
./nexus/scripts/setup-tanzu-repo.sh
```

## File Structure

```
nexus/
├── README.md                      # This file
├── credentials.env.template       # Template for credentials (committed)
├── credentials.env                # Your actual credentials (NOT committed)
└── scripts/
    └── setup-tanzu-repo.sh        # Automated setup script
```
