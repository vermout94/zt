#cloud-config
package_update: true
packages:
  - mariadb-server

write_files:
  - path: /home/${admin_username}/.ssh/authorized_keys
    owner: ${admin_username}:${admin_username}
    append: true
    content: |
      ${admin_ssh_public_key}
      ${webvm_public_key}

runcmd:
  - sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
  - sudo sed -i 's/^skip-networking/#&/'           /etc/mysql/mariadb.conf.d/50-server.cnf
  - sudo systemctl enable --now mariadb
  - sudo systemctl restart mariadb
  - mysql -e "CREATE USER IF NOT EXISTS 'testuser'@'10.0.1.%' IDENTIFIED BY 'testpass';"
  - mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'testuser'@'10.0.1.%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
