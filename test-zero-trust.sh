#!/bin/bash

# Zero Trust Prototype Test Script
# Run from Web VM (SSH into it via Azure Firewall DNAT)

echo "=== Zero Trust Test Plan: $(date) ==="

# 1. Check NGINX web server locally
echo "[1] Testing local web server (NGINX)..."
curl -s http://localhost | grep -i nginx && echo "NGINX is running." || echo "NGINX check failed."

# 2. Ping database VM (should NOT work, ICMP is blocked by design)
echo "[2] Testing ping to DB VM (10.0.2.4)..."
ping -c 2 10.0.2.4 > /dev/null && echo "Ping reachable (unexpected)" || echo "Ping blocked (expected)."

# 3. Test MariaDB SQL connection (should work)
echo "[3] Testing MariaDB connectivity from Web → DB..."
mysql -h 10.0.2.4 -u testuser -ptestpass -e "SHOW DATABASES;" && echo "MariaDB connection successful." || echo "MariaDB connection failed."

# 4. Test SSH to DB VM (should fail - blocked by NSG)
echo "[4] Testing SSH from Web → DB VM (should be blocked)..."
timeout 5 nc -zv 10.0.2.4 22 && echo "SSH to DB VM succeeded (unexpected)" || echo "SSH to DB VM blocked (expected)"

# 5. Test DNS resolution
echo "[5] Testing DNS resolution..."
dig www.microsoft.com +short || echo "DNS resolution failed"

echo "=== Test Plan Complete ==="
