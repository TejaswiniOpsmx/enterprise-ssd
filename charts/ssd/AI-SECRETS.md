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
| `claude-credentials` | pentestgpt-wrapper (mounted at `/home/pentester/.claude`) | `.credentials.json` | `aiSecrets.claudeCredentials` |

A secret is created only when its values are no longer the `REPLACE_ME`
placeholder (or, for `claude-credentials`, when the JSON is provided). With the
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

### Step 3: Locate the Claude credentials file

The `claude-credentials` secret is passed as a file, not in the values file:

```bash
ls -l $HOME/.claude/.credentials.json
```

### Step 4: (Optional) Preview the rendered secrets

```bash
helm template ssd . -f ai-secrets.local.yaml \
  --set-file aiSecrets.claudeCredentials.json=$HOME/.claude/.credentials.json \
  -s templates/ai-guardian/secret.yaml \
  -s templates/pentestgpt-wrapper/secrets.yaml
```

This prints secret contents, so do not paste the output anywhere shared.

### Step 5: Install or upgrade

```bash
helm upgrade --install ssd . -n <namespace> \
  -f ai-secrets.local.yaml \
  --set-file aiSecrets.claudeCredentials.json=$HOME/.claude/.credentials.json
```

Add your usual `-f` files/flags as well (for example `--set installAimlSvcs=true`).

### Step 6: Verify

```bash
kubectl -n <namespace> get secret ai-guardian-remediation-secret pentestgpt-secret claude-credentials
kubectl -n <namespace> get pods | grep -E 'ai-guardian|pentestgpt'
```

If the install output shows a `WARNING: these AI secrets were NOT created`
message, the listed secrets still had placeholder values. Fix the values and
run Step 5 again.

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

kubectl -n <namespace> create secret generic my-claude-credentials \
  --from-file=.credentials.json=$HOME/.claude/.credentials.json
```

### Step 2: Point the chart at them

```bash
helm upgrade --install ssd . -n <namespace> \
  --set aiSecrets.airemediation.existingSecret=my-remediation-secret \
  --set aiSecrets.pentestgpt.existingSecret=my-pentestgpt-secret \
  --set aiSecrets.claudeCredentials.existingSecret=my-claude-credentials
```

When `existingSecret` is set, the chart creates nothing for that secret and the
deployment uses the name you give.

## supplychain-api endpoints (`aigAddress`, `ssdApiMcp`, `ssdVuln`)

These are written into the `supplychain-api` secret (`app-config.yaml`).

| Key | Values key | Default |
|---|---|---|
| `ssdVuln` | `supplychainapi.ssdVuln` (URL only) | `https://ssd.oss.opsmx.net` |
| `aigAddress` | `supplychainapi.aigAddress` | `http://ai-guardian-api.<release namespace>.svc.cluster.local:8080` |
| `ssdApiMcp` | `supplychainapi.ssdApiMcp` | `http://ssd-api-mcp:8080` |

The final `ssdVuln` value is `https://<user>:<password>@ssd.oss.opsmx.net`.
**Never put the credentials in the URL in a values file.** The chart rejects a URL
containing `user:pass@`. Put them in `ai-secrets.local.yaml`:

```yaml
aiSecrets:
  supplychainApi:
    ssdVulnUsername: "opsmxuser"
    ssdVulnPassword: "<password>"
```

The chart URL-encodes both values, adds them to the URL and quotes the result, so
special characters (`@ : # "`) cannot break the config. Set both or neither.
The result lives only in the `supplychain-api` Secret, and pods restart on change
through the existing `checksum/secret` annotation. This key cannot use
`existingSecret`, because it is one entry in the generated `app-config.yaml`.

## toolchain `ossSvc`

The final value is `https://<user>:<password>@ssd.oss.opsmx.net`. Because it holds a
password, the `tool-chain` config is now rendered as a **Secret** (it was a
ConfigMap) and mounted at the same path, `/tools/config/tool-chain.yaml`.
The URL is `toolchain.ossSvc` (default `https://ssd.oss.opsmx.net`, credentials
are rejected there). The credentials go in `ai-secrets.local.yaml`:

```yaml
aiSecrets:
  toolchain:
    ossSvcUsername: "opsmxuser"
    ossSvcPassword: "<password>"
```

They are URL-encoded and quoted like `ssdVuln`. Set both or neither.

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
