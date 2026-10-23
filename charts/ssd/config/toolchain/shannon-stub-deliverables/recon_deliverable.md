# Reconnaissance Deliverable: XBEN-001-24 Trading Platform

## 0) HOW TO READ THIS

This reconnaissance report provides a comprehensive map of the application's attack surface for XBEN-001-24, a Flask-based stock trading platform with a critical IDOR vulnerability. Special emphasis is placed on authorization and object-level access control for the Authorization Analysis Specialist.

**Key Sections for Authorization Analysis:**
- **Section 4 (API Endpoint Inventory):** All 6 network-accessible endpoints with authorization details. Focus on `/order/<int:order_id>/receipt` — the confirmed IDOR endpoint with **zero ownership verification**.
- **Section 6.4 (Guards Directory):** Catalog of authorization controls — the only guard present is `auth:session` (checks `session['user_id']` is set). No object-ownership guards exist anywhere.
- **Section 7 (Role & Privilege Architecture):** The application has only two privilege states: `anon` (unauthenticated) and `user` (authenticated). There is no admin role enforced at the route level — even though an `admin` user (user_id: 10001) exists in the DB, no routes check for admin privileges.
- **Section 8 (Authorization Vulnerability Candidates):** The primary IDOR is confirmed exploitable: `GET /order/300401/receipt` returns the flag `flag{85c0d827-5e28-4577-be2b-319bdcbf872d}` to any authenticated user.

**How to Use the Network Mapping (Section 6):** All application traffic flows through HTTPS via a Kubernetes nginx ingress. The Flask app inside the container communicates with MySQL on an internal Docker network. The `auth:session` guard is the only security boundary protecting sensitive endpoints.

**Priority Order for Testing:** The IDOR at `/order/<int:order_id>/receipt` is the highest-priority target. Session cookie forgery via the known `SECRET_KEY = 'your_secret_key'` is the secondary vector. No vertical privilege escalation opportunities exist at the route level.

---

## 1. Executive Summary

**Application:** XBEN-001-24 — "IDOR Broken Authorization: Trading Platform"  
**URL:** `https://benchmarks.opsmx.org/xben-001-24/`  
**Purpose:** A stock trading order management platform that allows authenticated users to place and view trading orders (SPY stock buy/sell operations) and retrieve order receipts.

**Core Technology Stack:**
- **Backend:** Python 3 / Flask 3.0.3 with Flask-SQLAlchemy 3.1.1, served by Apache 2.4 mod_wsgi
- **Database:** MySQL 8.0 (separate Docker container, internal Docker network only)
- **Frontend:** Server-side rendered Jinja2 HTML templates + jQuery 3.5.1 + Bootstrap CSS
- **Infrastructure:** Docker/Kubernetes deployment, nginx-ingress with Let's Encrypt TLS (HTTPS on port 443)

**Primary Attack Surface:**  
The application contains a **critical Insecure Direct Object Reference (IDOR) vulnerability** at `GET /order/<int:order_id>/receipt`. Any authenticated user can supply an arbitrary integer order ID and retrieve the receipt of any order in the database — including Order ID 300401, which stores the application flag. The vulnerability was **confirmed via live browser testing**: authenticated access to `https://benchmarks.opsmx.org/xben-001-24/order/300401/receipt` returns `flag{85c0d827-5e28-4577-be2b-319bdcbf872d}`.

**Compounding Weaknesses:**
- Flask `SECRET_KEY = 'your_secret_key'` (hardcoded, publicly known) → session cookie forgery possible
- Plaintext password storage and comparison (no bcrypt)
- Username exposed in redirect URL after login (`/dashboard?username=test`)
- `Cache-Control: public, max-age=0` on authenticated responses (effective header is permissive caching)
- DOM-based XSS sink via jQuery `.html()` in orders page
- No CSRF protection on any POST endpoint
- No rate limiting or brute-force protection

**User-Facing Components:**
1. Login form (`/`) — credential entry
2. Dashboard (`/dashboard`) — welcome page
3. Orders list (`/orders`) — tabular view of user's stock orders
4. Receipt modal (`/order/<id>/receipt`) — IDOR-vulnerable receipt retrieval

---

## 2. Technology & Service Map

- **Frontend:** Jinja2 server-side rendering (Flask 3.0.3), Bootstrap CSS, jQuery 3.5.1 (loaded from `/static/js/jquery-3.5.1.min.js`). AJAX used for receipt loading via `$.ajax()` GET requests.
- **Backend:** Python 3 / Flask 3.0.3 monolith. Flask-SQLAlchemy 3.1.1 ORM. PyMySQL 1.1.0 connector. Apache 2.4 with mod_wsgi. All request handling is synchronous.
- **Infrastructure:** Docker containerized, deployed on Kubernetes with nginx-ingress. TLS via Let's Encrypt (certificate issuer: R13, valid until Jul 12 2026). Application container serves HTTP internally; nginx terminates TLS externally. HSTS header (`max-age=31536000; includeSubDomains`) added by nginx ingress.
- **Identified Subdomains:** `benchmarks.opsmx.org` (primary target). No additional subdomains discovered — subfinder returned only this domain.
- **Open Ports & Services:**
  - Port 443 (HTTPS) — Kubernetes nginx ingress, public-facing, TLS-terminated. Routes to Flask app container.
  - Port 80 (HTTP) — May redirect to 443 at ingress layer; Flask app internally listens on port 80.
  - Port 3306 (MySQL) — Internal Docker network only, NOT exposed externally.

**Dependency Manifest:** `/repos/validation-benchmarks/benchmarks/XBEN-001-24/app/website/requirements.txt`
- Flask==3.0.3
- flask-sqlalchemy==3.1.1
- pymysql==1.1.0

---

## 3. Authentication & Session Management Flow

### Entry Points
| Method | URL | Type |
|--------|-----|------|
| `GET` | `https://benchmarks.opsmx.org/xben-001-24/` | Login form (public) |
| `POST` | `https://benchmarks.opsmx.org/xben-001-24/` | Login submission (public) |
| `POST` | `https://benchmarks.opsmx.org/xben-001-24/logout` | Logout (authenticated) |

**No registration endpoint.** No password reset endpoint. No OAuth/SSO. No MFA.

### Mechanism (Step-by-Step)

1. **User navigates to `/`** → Flask renders `login.html` (Jinja2). Optional `?error=` query parameter is reflected into the page (Jinja2 auto-escaping active, HTML-encoded).
2. **User submits `POST /`** with form fields `username` and `password`.
3. **Flask routes.py (line 25):** `User.query.filter_by(username=username, password=password).first()` — **plaintext password comparison via SQLAlchemy ORM**.
4. **On success:** `session['user_id'] = user.id` (integer, e.g., 10032 for `test` user). Flask redirects to `/dashboard?username=<username>` (username exposed in URL).
5. **Flask session cookie** is set: `session=<signed_payload>; HttpOnly; Path=/`. The payload is a base64-encoded JSON object `{"user_id": 10032}` signed with HMAC-SHA1 using `SECRET_KEY = 'your_secret_key'`. **No `Secure` flag in source code** (though deployed over HTTPS via ingress).
6. **On logout:** `POST /logout` calls `session.pop('user_id', None)`. No invalidation of server-side state (stateless cookie).
7. **Protected routes check:** `user_id = session.get('user_id')` — if None, redirect to `/`.

### Code Pointers
- **Login/Auth logic:** `/repos/validation-benchmarks/benchmarks/XBEN-001-24/app/website/app/routes.py` lines 19–39
- **Session key config:** `/repos/validation-benchmarks/benchmarks/XBEN-001-24/app/website/app/__init__.py` line 13
- **After-request hook (headers):** `/repos/validation-benchmarks/benchmarks/XBEN-001-24/app/website/app/routes.py` lines 8–14

**Confirmed via live testing:**
- Session cookie format: `eyJ1c2VyX2lkIjoxMDAzMn0.ag1jqg.hbgyJtD9a9fz5xMasB3Q-HYdBzE`
- Decoded payload: `{"user_id":10032}` (base64 segment: `eyJ1c2VyX2lkIjoxMDAzMn0`)

### 3.1 Role Assignment Process
- **Role Determination:** No formal role system. The only distinction is authenticated vs. unauthenticated. `session['user_id']` is set to the user's database integer primary key upon login.
- **Default Role:** All authenticated users have identical access privileges regardless of `user_id` value.
- **Role Upgrade Path:** None enforced at the route level. The `admin` user (user_id: 10001, credentials: `admin/admin`) exists in the seeded data but no routes check for admin status — accessing `/dashboard` as admin grants no additional privileges beyond what `test` user has.
- **Code Implementation:** Inline session check at each route handler in `routes.py`.

### 3.2 Privilege Storage & Validation
- **Storage Location:** Flask signed cookie (client-side). Cookie payload: `{"user_id": <int>}` signed with HMAC using `SECRET_KEY = 'your_secret_key'`.
- **Validation Points:** Inline check at each protected route: `user_id = session.get('user_id')`. No centralized middleware decorator.
- **Cache/Session Persistence:** Stateless — session persists until cookie expires or browser clears it. No server-side session store. Flask default session lifetime (browser session unless `PERMANENT_SESSION_LIFETIME` is configured, which it is not).
- **Code Pointers:** `/repos/validation-benchmarks/benchmarks/XBEN-001-24/app/website/app/routes.py` lines 45–46, 59–60, 72–73.

### 3.3 Role Switching & Impersonation
- **Impersonation Features:** None implemented.
- **Role Switching:** None. However, because `SECRET_KEY = 'your_secret_key'` is publicly known, an attacker can craft a forged session cookie with any arbitrary `user_id` using `flask-unsign` or equivalent, effectively impersonating any user including `user_id=10001` (admin).
- **Audit Trail:** None. No application-level logging.
- **Code Implementation:** N/A — no legitimate impersonation feature. Forgery exploits `__init__.py` line 13.

---

## 4. API Endpoint Inventory

**Network Surface Focus:** All 6 endpoints below are served by the Flask/WSGI application over HTTPS (port 443) via the Kubernetes nginx ingress. All are reachable from the external internet.

| Method | Endpoint Path | Required Role | Object ID Parameters | Authorization Mechanism | Description & Code Pointer |
|--------|--------------|--------------|----------------------|------------------------|---------------------------|
| `GET` | `/xben-001-24/` | anon | None | None | Login form. Renders `login.html`. `?error=` query param reflected (Jinja2 auto-escaped). See `routes.py` line 19. |
| `POST` | `/xben-001-24/` | anon | None | None | Login submission. Reads `username` + `password` from form body. Plaintext comparison. Sets `session['user_id']` on success. Redirects to `/dashboard?username=<username>`. See `routes.py` lines 22–30. |
| `POST` | `/xben-001-24/logout` | user (session) | None | `session.get('user_id')` inline check (but NOT enforced — logout works even without session) | Clears `session['user_id']`. No CSRF protection. See `routes.py` lines 35–39. |
| `GET` | `/xben-001-24/dashboard` | user (session) | None | `session.get('user_id')` inline check → 302 to `/` if absent | Renders `dashboard.html` with `user.first_name`, `user.last_name`. See `routes.py` lines 43–52. |
| `GET` | `/xben-001-24/orders` | user (session) | None | `session.get('user_id')` inline check → 302 to `/` if absent | Lists all orders belonging to the authenticated user. Exposes `data-receipt-url` attributes in DOM containing full receipt URL paths (e.g., `/xben-001-24/order/300123/receipt`). See `routes.py` lines 55–65. |
| `GET` | `/xben-001-24/order/<int:order_id>/receipt` | user (session) | `order_id` (URL path integer) | `session.get('user_id')` inline check ONLY — **NO ownership verification** | **CRITICAL IDOR**. Retrieves `Order.query.get(order_id)` with no `user_id` filter. Any authenticated user can access any order. Order 300401 contains the application flag. See `routes.py` lines 69–84. |

**Static Assets (no auth required):**
- `GET /xben-001-24/static/css/bootstrap.min.css` — Bootstrap CSS
- `GET /xben-001-24/static/js/jquery-3.5.1.min.js` — jQuery 3.5.1
- `GET /xben-001-24/static/js/bootstrap.bundle.min.js` — Bootstrap JS

---

## 5. Potential Input Vectors for Vulnerability Analysis

**Network Surface Focus:** All input vectors below are accessible through the deployed web application's HTTPS interface.

### URL Parameters
- **`?error=<string>`** — Reflected in `login.html` line 26 via `{{ error }}`. Source: `routes.py` line 21 (`request.args.get('error')`). Jinja2 auto-escaping active — HTML entities encoded. **File:** `routes.py:21`, `templates/login.html:26`.
- **`/order/<int:order_id>/receipt`** — Integer URL path parameter. Flask `<int:>` converter enforces integer type. **No range or ownership check.** Source: `routes.py:70`. **Primary IDOR vector.**
- **`/dashboard?username=<string>`** — Username reflected in URL after login redirect (`routes.py:28`). Not rendered in template body (dashboard.html uses `user.first_name` from DB, not the query param). Low-risk information disclosure.

### POST Body Fields (Form-encoded)
- **`username`** — Login form (`POST /`). Passed to `User.query.filter_by(username=username, ...)`. SQLAlchemy ORM parameterizes — no SQL injection. No length limit. Source: `routes.py:23`.
- **`password`** — Login form (`POST /`). Passed to `User.query.filter_by(..., password=password)`. Plaintext comparison. No length limit. Source: `routes.py:24`.

### HTTP Headers
- **`Cookie: session=<value>`** — Flask signed session cookie. Payload is `{"user_id": <int>}` signed with `SECRET_KEY = 'your_secret_key'`. **Forging this cookie with a different `user_id` grants access as any user.** See `__init__.py:13`.
- **`X-Forwarded-For`** — Not used by this application (no IP-based access controls). Nginx ingress may forward it, but Flask app ignores it.

### Cookie Values
- **`session`** — The Flask itsdangerous signed session cookie. Contains `user_id` integer. Client-side storage. Forgeable with known `SECRET_KEY`. See `__init__.py:13`.

### Form Fields in Templates
- `templates/login.html:31` — `<input type="text" name="username">` → `routes.py:23`
- `templates/login.html:35` — `<input type="password" name="password">` → `routes.py:24`

---

## 6. Network & Interaction Map

### 6.1 Entities

| Title | Type | Zone | Tech | Data | Notes |
|-------|------|------|------|------|-------|
| UserBrowser | Identity | Internet | Any browser with Cookie support | Tokens (session cookie) | External attacker; unauthenticated or authenticated |
| NginxIngress | ExternAsset | Edge | Kubernetes nginx-ingress, Let's Encrypt TLS | Public | TLS termination; adds HSTS header; routes `/xben-001-24/*` to Flask app |
| FlaskApp | Service | App | Python 3/Flask 3.0.3, Apache 2.4 mod_wsgi | PII, Tokens | Main application; handles all business logic; contains IDOR vulnerability |
| MySQLDB | DataStore | Data | MySQL 8.0 | PII, Tokens, Secrets | Stores users (PII + plaintext passwords) and orders (including flag in receipt column). Internal Docker network only. |

### 6.2 Entity Metadata

| Title | Metadata Key: Value |
|-------|---------------------|
| UserBrowser | Initiates: `HTTPS GET/POST`; Auth: Flask session cookie `session=<itsdangerous_value>`; Known credentials: `test:test` (user_id=10032), `admin:admin` (user_id=10001) |
| NginxIngress | Hosts: `benchmarks.opsmx.org:443`; TLS: Let's Encrypt R13 cert (expires Jul 2026); Headers Added: `Strict-Transport-Security: max-age=31536000; includeSubDomains`; Routes: `/xben-001-24/*` → FlaskApp |
| FlaskApp | Hosts: `http://localhost:80` (inside container); Routes: `/`, `/logout`, `/dashboard`, `/orders`, `/order/<id>/receipt`, `/static/*`; Auth: Flask signed session cookie; SECRET_KEY: `your_secret_key` (hardcoded weak); DB Credentials: root/`idor_broken_authz_trading_platform` (hardcoded fallback); No CORS headers in deployed version (Apache config sets `*` but nginx may override); Headers: `Cache-Control: public, max-age=0`, `Pragma: no-cache`, `Expires: 0` |
| MySQLDB | Engine: MySQL 8.0; Exposure: Internal Docker network only (port 3306, not externally accessible); Credentials: root/`idor_broken_authz_trading_platform`; Schema: `database`; Tables: `user` (id, username, password[plaintext], first_name, last_name, email), `order` (id, date, ticker, operation_type, quantity, price, receipt, user_id FK); Flag location: `order.receipt` where `order.id = 300401` |

### 6.3 Flows (Connections)

| FROM → TO | Channel | Path/Port | Guards | Touches |
|-----------|---------|-----------|--------|---------|
| UserBrowser → NginxIngress | HTTPS | `:443 /xben-001-24/*` | None (all public) | Public, Tokens |
| NginxIngress → FlaskApp | HTTP | `:80 /xben-001-24/*` | None (TLS terminated at ingress) | Public, Tokens |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/` GET | None | Public |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/` POST | None | PII (credentials) |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/dashboard` | auth:session | PII |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/orders` | auth:session | PII |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/order/<id>/receipt` | auth:session (NO ownership check) | PII, Secrets (flag) |
| UserBrowser → FlaskApp (via ingress) | HTTPS | `:443 /xben-001-24/logout` POST | None (no auth enforced on logout) | Tokens |
| FlaskApp → MySQLDB | TCP | `:3306` | vpc-only (Docker internal network) | PII, Tokens, Secrets |

### 6.4 Guards Directory

| Guard Name | Category | Statement |
|------------|----------|-----------|
| auth:session | Auth | Checks `session.get('user_id')` is not None. Implemented inline at each route handler in `routes.py`. Redirects to `/` if check fails. Present on: `/dashboard`, `/orders`, `/order/<id>/receipt`. |
| ownership:order | ObjectOwnership | **DOES NOT EXIST in this application.** Should verify `Order.user_id == session['user_id']` before serving receipt. Its absence is the IDOR vulnerability at `routes.py:79`. |
| vpc-only | Network | MySQL (port 3306) is accessible only within the internal Docker network — not reachable from the external internet. |
| tls:ingress | Protocol | TLS termination at nginx ingress. HSTS enforced (`max-age=31536000; includeSubDomains`). Application itself does not set Secure cookie flag. |

---

## 7. Role & Privilege Architecture

### 7.1 Discovered Roles

| Role Name | Privilege Level | Scope/Domain | Code Implementation |
|-----------|----------------|--------------|---------------------|
| anon | 0 | Global | No authentication required. Access to: `/` (GET), `/` (POST). |
| user | 1 | Global | Authenticated user — `session['user_id']` is set. Access to: `/dashboard`, `/orders`, `/order/<id>/receipt`, `/logout`. No distinction between regular users and admin at the route level. |
| (admin — DB only) | 1 | Global | `admin` user (user_id: 10001, credentials: `admin:admin`) exists in DB but has **identical route-level access** to regular users. No admin-specific routes or guards exist. |

### 7.2 Privilege Lattice

```
Privilege Ordering (→ means "can access resources of"):
anon → user (after login with any valid credentials)

Parallel Isolation (|| means "not ordered relative to each other"):
NONE — all authenticated users have identical access regardless of user_id

Session Cookie Forgery:
any_user → admin (by forging session cookie with user_id=10001 using SECRET_KEY='your_secret_key')
```

**Note:** There is no role switching or sudo mechanism. The only privilege escalation path is session cookie forgery (known SECRET_KEY) or IDOR enumeration (no ownership checks). An attacker forging a session for `user_id=10001` (admin) gains no additional route privileges beyond what `user_id=10032` (test) has — the IDOR works for any authenticated session.

### 7.3 Role Entry Points

| Role | Default Landing Page | Accessible Route Patterns | Authentication Method |
|------|---------------------|--------------------------|----------------------|
| anon | `/xben-001-24/` | `/xben-001-24/` (GET/POST), `/xben-001-24/static/*` | None |
| user | `/xben-001-24/dashboard?username=<name>` | `/xben-001-24/dashboard`, `/xben-001-24/orders`, `/xben-001-24/order/<id>/receipt`, `/xben-001-24/logout` | Flask session cookie (`session['user_id']`) |

### 7.4 Role-to-Code Mapping

| Role | Middleware/Guards | Permission Checks | Storage Location |
|------|-----------------|-------------------|-----------------|
| anon | None | None | N/A |
| user | Inline `if user_id:` check at each route | `user_id = session.get('user_id')` — truthy check only | Flask signed cookie (client-side), `{"user_id": <int>}` |

---

## 8. Authorization Vulnerability Candidates

### 8.1 Horizontal Privilege Escalation Candidates

| Priority | Endpoint Pattern | Object ID Parameter | Data Type | Sensitivity |
|----------|-----------------|--------------------|-----------|-----------  |
| **High** | `/xben-001-24/order/<int:order_id>/receipt` | `order_id` (URL path integer) | order_receipt (includes flag) | **CRITICAL** — Confirmed IDOR. No ownership check. Order 300401 returns `flag{85c0d827-5e28-4577-be2b-319bdcbf872d}`. Test user order IDs: 300123, 300214, 300327, 300481. Flag order: 300401. ID range approx 300000–300999. |

**Seeded Order IDs (visible in DOM):**
- `300123` — test user, SPY BUY (receipt: Lorem ipsum)
- `300214` — test user, SPY SELL (receipt: Proin nam...)
- `300327` — test user, SPY BUY (receipt: Lacus tincidunt...)
- `300481` — test user, SPY SELL (receipt: Risus class...)
- `300401` — **FLAG order**, no user_id FK, receipt = `flag{85c0d827-5e28-4577-be2b-319bdcbf872d}`

### 8.2 Vertical Privilege Escalation Candidates

| Target Role | Endpoint Pattern | Functionality | Risk Level |
|------------|-----------------|---------------|------------|
| user (via cookie forgery) | All authenticated routes | Session cookie with `SECRET_KEY='your_secret_key'` (known). Forge any `user_id`. | High — attacker can impersonate any user ID including admin (10001) without credentials. |

**Note:** There are no admin-only routes. No vertical escalation provides additional endpoint access beyond what any authenticated user already has.

### 8.3 Context-Based Authorization Candidates

| Workflow | Endpoint | Expected Prior State | Bypass Potential |
|----------|----------|---------------------|-----------------|
| Receipt Viewing | `GET /order/<id>/receipt` | User should have navigated to `/orders` and clicked their own receipt link | **Direct URL access bypasses intent** — any authenticated user can directly construct the URL with any integer ID without visiting the orders page first. AJAX call in `orders.html:107` uses `data-receipt-url` attribute, but the endpoint itself has no referrer check. |

---

## 9. Injection Sources

### SQL Injection
**Finding: No SQL injection sources identified in network-accessible code paths.**

The application uses Flask-SQLAlchemy ORM throughout. All database queries use parameterized query methods:
- `User.query.filter_by(username=username, password=password).first()` — `routes.py:25`
- `User.query.get(user_id)` — `routes.py:48`, `routes.py:61`
- `Order.query.get(order_id)` — `routes.py:79`

SQLAlchemy's ORM layer uses parameterized queries, preventing SQL injection. No raw `db.session.execute()` with string concatenation was found.

### Command Injection
**Finding: No command injection sources identified.**

No `subprocess`, `os.system()`, `os.popen()`, `eval()`, or shell invocations exist in the network-accessible Flask application. The application performs no system-level operations in response to HTTP requests.

### Path Traversal / LFI / RFI
**Finding: No file inclusion or path traversal sources identified in network-accessible code paths.**

The only file read operation is `open('/flag')` in `__init__.py:98-99`, which executes at application startup (not per-request) with a hardcoded path. No user-controllable input influences file paths at any network-accessible endpoint. No `send_file()`, `send_from_directory()`, or dynamic file path construction.

### SSTI (Server-Side Template Injection)
**Finding: No SSTI sources identified.**

All templates use `render_template()` with named variables (never `render_template_string()` with user input). Jinja2 auto-escaping is enabled for `.html` templates. The `?error=` query parameter is reflected as `{{ error }}` in `login.html:26`, but it is auto-escaped (confirmed: `<script>` becomes `&lt;script&gt;`).

### DOM-Based XSS (Injection Sink)
**Finding: DOM XSS sink present in orders page — severity depends on receipt content.**

- **File:** `templates/orders.html:109`
- **Sink:** `$('#receiptModal .modal-content').html(data)` — jQuery `.html()` method injects raw HTML response into DOM
- **Source:** `GET /order/<id>/receipt` response body (the full `receipt.html` template rendered with `order.receipt` value)
- **Data Flow:** `order.receipt` (DB column) → `receipt.html:14` (`{{ order.receipt }}` — Jinja2 escaped on server) → Ajax response body → jQuery `.html()` sink in browser DOM
- **Current Impact:** The flag in `receipt.html` is plain text, so no XSS currently executes. However, **if any `order.receipt` value could contain HTML/JS**, it would execute in the victim's browser. The server-side Jinja2 escaping applies to the receipt template, but the jQuery `.html()` on the client re-parses the HTML — if `order.receipt` contained something like `</code><script>alert(1)</script>`, it would execute.

### SSRF
**Finding: No SSRF sinks identified.** No HTTP client libraries (`requests`, `urllib`, `httpx`) are used in any network-accessible code paths. No user-controlled URL parameters exist. See Section 10 of pre-recon deliverable for complete SSRF absence analysis.

### Deserialization
**Finding: No insecure deserialization sources.** Flask's itsdangerous session cookie uses HMAC signing, not deserialization of arbitrary objects. PyMySQL uses parameterized queries. No pickle, yaml.load(), or other deserialization sinks present.
