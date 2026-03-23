# Security Code Review Guidelines
# Source: Adapted from ghostsecurity/skills
# Committed to bug-hunter-d33 for security-focused reviews

## Overview
Security-focused code review guidelines for identifying vulnerabilities in application code.

## Critical Vectors

### Authentication & Authorization
- **Missing auth checks** - Endpoints without authentication
- **Broken access control** - IDOR (Insecure Direct Object Reference)
- **Session management** - Weak session tokens, missing expiration
- **JWT issues** - None algorithm, weak signing, missing validation

### Injection Vulnerabilities
- **SQL injection** - Unparameterized queries, string concatenation
- **Command injection** - Passing user input to exec/system
- **XSS** - Unescaped output in HTML, missing CSP
- **NoSQL injection** - Unsanitized MongoDB queries
- **LDAP injection** - Unescaped LDAP filters

### Data Exposure
- **Hardcoded secrets** - API keys, passwords in code
- **Sensitive data logging** - PII, passwords in logs
- **Information disclosure** - Stack traces, debug info in production
- **Insecure storage** - Plaintext passwords, weak encryption

### Input Validation
- **Missing validation** - No bounds checking on inputs
- **Type confusion** - Accepting unexpected types
- **File upload risks** - No extension validation, path traversal
- **Open redirects** - User-controlled redirect URLs

### Dependency & Supply Chain
- **Vulnerable dependencies** - Known CVEs in packages
- **Typosquatting** - Malicious package names
- **Unpinned versions** - Floating versions in lock files

## Language-Specific Patterns

### JavaScript/TypeScript
```javascript
// DANGER: SQL injection
db.query(`SELECT * FROM users WHERE id = ${userId}`)

// SAFE: Parameterized query
db.query('SELECT * FROM users WHERE id = ?', [userId])
```

### Python
```python
# DANGER: Command injection
os.system(f"ping {user_input}")

# SAFE: Use subprocess with list
subprocess.run(["ping", user_input], check=True)
```

### Go
```go
// DANGER: Path traversal
http.ServeFile(w, r, "/uploads/"+filename)

// SAFE: Validate and sanitize path
filepath.Join("/uploads", filepath.Clean(filename))
```

## Bug Hunter Security Focus

When `ghost-scan-code` context is provided, prioritize:
1. **Injection points** - Any user input reaching queries/commands
2. **Auth bypasses** - Missing or weak authentication
3. **Data leaks** - Sensitive info in responses/logs
4. **Misconfigurations** - CORS, headers, TLS settings
5. **Dependency issues** - Check package versions for CVEs

## Severity Mapping

| Finding | Severity | Example |
|---------|----------|---------|
| SQL injection | 🔴 Critical | Unparameterized query with user input |
| Hardcoded secret | 🔴 Critical | API key in source code |
| XSS | 🔴 Critical | Unescaped output in HTML |
| Missing auth | 🔴 Critical | Admin endpoint without check |
| Weak validation | 🟡 Warning | No length limits on inputs |
| Info disclosure | 🟡 Warning | Verbose error messages |
| Outdated dependency | 🟡 Warning | Known CVE in package |
| Missing CSP header | 🟢 Note | Security headers absent |
