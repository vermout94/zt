#cloud-config
##
##  WebVM bootstrap for Zero‑Trust demo
##

package_update: true
package_upgrade: true
packages:
  - nginx
  - mysql-client-core-8.0
  - jq
  - netcat
  - curl
  - ca-certificates
  - dnsutils

write_files:
  # ------------------------------------------------------------
  # Zero‑Trust validation helper (runs as the admin user)
  # ------------------------------------------------------------
  - path: /home/${admin_username}/zero-trust-test.sh
    permissions: "0777"
    owner: root:root
    content: |
      #!/usr/bin/env bash
      # ========= Zero Trust Validation (WebVM) =========
      # Saves its own log into the invoking user's $HOME

      LOG="$HOME/zero_trust_validation.log"
      exec >"$LOG" 2>&1
      FAIL=0

      # Static values injected by Terraform at render time
      DB_IP="${db_ip}"
      FW_PUB_IP="${fw_pub_ip}"
      FW_PRIV_IP="${fw_priv_ip}"

      echo "==== Zero Trust Validation START ===="

      # 1) Micro‑segmentation (NSG + Firewall rules)
      echo "[1] Micro‑segmentation"
      if nc -z -w2 "$DB_IP" 3306; then
        echo "MySQL reachable on 3306 (expected)"
      else
        echo "MySQL unreachable on 3306"
        FAIL=1
      fi

      if nc -z -w2 "$DB_IP" 22; then
        echo "SSH open on DB (should be blocked)"
        FAIL=1
      else
        echo "SSH closed on DB (expected)"
      fi
      echo

      # 2) Forced‑tunnel egress (policy verification rather than IP check)
      echo "[2] Forced‑tunnel egress"
      
      # Allowed destination – should SUCCEED
      if curl -fsSL --max-time 5 https://www.google.com >/dev/null 2>&1; then
        echo "Outbound to allowed FQDN https://www.google.com succeeded (expected)"
      else
        echo "Outbound to allowed FQDN https://www.google.com FAILED"
        FAIL=1
      fi
      
      # Blocked destination – should FAIL
      if curl -fsSL --max-time 5 https://ifconfig.me >/dev/null 2>&1; then
        echo "Outbound to disallowed FQDN https://ifconfig.me succeeded (should be blocked)"
        FAIL=1
      else
        echo "Outbound to disallowed FQDN https://ifconfig.me correctly blocked"
      fi
      echo

      # 3) DNS proxy on Firewall
      echo "[3] DNS proxy on FW"
      DNS_RES=$(dig +short microsoft.com @"$FW_PRIV_IP")
      if [[ -n "$DNS_RES" ]]; then
        echo "DNS resolution via FW succeeded ($DNS_RES) (expected)"
      else
        echo "DNS via FW failed"
        FAIL=1
      fi
      echo

      # 4) Controlled APT repository reachability
      echo "[4] Controlled apt repo"
      if sudo apt-get update >/dev/null 2>&1; then
        echo "apt-get update successful (expected)"
      else
        echo "apt-get update failed"
        FAIL=1
      fi
      echo

      # 5) Identity pillar (AAD login) – manual hint only
      echo "[5] Identity access"
      echo "AAD login is enabled for this VM. Test manually with: az ssh vm ..."

      # Final headline
      if [[ $FAIL -eq 0 ]]; then
        echo "==== Zero Trust Validation PASS ===="
      else
        echo "==== Zero Trust Validation FAIL ===="
      fi

runcmd:
  # Enable and start Nginx immediately
  - systemctl enable --now nginx
  # Execute the validation script once as the admin user
  - su - ${admin_username} -c "/home/${admin_username}/zero-trust-test.sh"
