# Configuring AI Secrets in the SSD Helm Chart

This guide explains how to provide the secrets used by the AI services
(`ai-guardian-remediation` and `pentestgpt-wrapper`) securely.

> **SECURITY: never commit or push real tokens, passwords or credentials files
> to any repository.** Real values live only in a git-ignored local file or in a
> secret you manage yourself.

## Secrets managed by the chart

| Secret | Used by | Keys | Values key |
|---|---|---|---|
| `ai-guardian-remediation-secret` | ai-guardian-remediation (`envFrom`) | `CLAUDE_CODE_MODEL`, `REMEDIATION_AGENT`, `CLAUDE_CODE_OAUTH_TOKEN`, `DATABASE_URL` | `aiSecrets.airemediation` |
| `pentestgpt-secret` | pentestgpt-wrapper (env `CLAUDE_CODE_OAUTH_TOKEN`) | `CLAUDE_CODE_OAUTH_TOKEN` | `aiSecrets.pentestgpt` |


A secret is created only when its values are no longer the `REPLACE_ME`. With the
default values, no AI secret is created.

## Option A: let the chart create the secrets

### Step 1: Create a local values file

From the chart directory (`charts/ssd`):

```bash
cp ai-secrets.example.yaml ai-secrets.local.yaml
```

`ai-secrets.local.yaml` is git-ignored (`*.local.yaml`).

### Step 2: Fill in the real values

Edit `ai-secrets.local.yaml`:

```yaml
aiSecrets:
  airemediation:
    model: claude-sonnet-4-6
    agent: claude_code
    oauthToken: "<claude code oauth token>"
    databaseUrl: "postgresql://USER:PASSWORD@ssd-db:5432/DBNAME"
  pentestgpt:
    oauthToken: "<claude code oauth token>"
```

### Step 3: (Optional) Preview the rendered secrets

```bash
helm template ssd . -f ai-secrets.local.yaml \
  -s templates/ai-guardian/secret.yaml \
  -s templates/pentestgpt-wrapper/secrets.yaml
```

This prints secret contents, so do not paste the output anywhere shared.

### Step 4: Install or upgrade

```bash
helm upgrade --install ssd . -n <namespace> \
  -f ai-secrets.local.yaml
```

Add your usual `-f` files/flags as well (for example `--set installAimlSvcs=true`).

### Step 5: Verify

```bash
kubectl -n <namespace> get secret ai-guardian-remediation-secret pentestgpt-secret
kubectl -n <namespace> get pods | grep -E 'ai-guardian|pentestgpt'
```

If the install output shows a `WARNING: these AI secrets were NOT created`
message, the listed secrets still had placeholder values. Fix the values and
run Step 4 again.

## Option B: use secrets you manage yourself

Use this with kubectl, sealed-secrets, external-secrets, Vault, etc.

### Step 1: Create the secrets in the namespace

```bash
kubectl -n <namespace> create secret generic my-remediation-secret \
  --from-literal=CLAUDE_CODE_MODEL=claude-sonnet-4-6 \
  --from-literal=REMEDIATION_AGENT=claude_code \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN='<token>' \
  --from-literal=DATABASE_URL='postgresql://USER:PASSWORD@ssd-db:5432/DBNAME'

kubectl -n <namespace> create secret generic my-pentestgpt-secret \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN='<token>'

### Step 2: Point the chart at them

```bash
helm upgrade --install ssd . -n <namespace> \
  --set aiSecrets.airemediation.existingSecret=my-remediation-secret \
  --set aiSecrets.pentestgpt.existingSecret=my-pentestgpt-secret
```

When `existingSecret` is set, the chart creates nothing for that secret and the
deployment uses the name you give.

## Rotating a secret

1. Update the value in `ai-secrets.local.yaml` (or your own secret).
2. Run `helm upgrade` again (Option A). The deployments carry a
   `checksum/secret` annotation, so pods restart automatically when the chart-managed
   secrets change.
3. With Option B, restart the pods yourself:
   `kubectl -n <namespace> rollout restart deploy/<name>`.

## Notes

- Chart-created secrets carry `helm.sh/resource-policy: keep`, so
  `helm uninstall` leaves them in the cluster. Delete them manually if unwanted.
- The secret references in the deployments are `optional`, so the pods start
  even if a secret is missing, but the AI features will not work until it exists.
- Before pushing, run `git status` and confirm only `ai-secrets.example.yaml`
  (placeholders) is tracked, never `ai-secrets.local.yaml`.
- The original files in `/home/teja/Repositories/ssd/helm/` contain real
  values. Keep them out of git, and rotate the tokens if they were ever pushed.
