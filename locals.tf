locals {
  webvm_private_key     = file("${path.module}/id_rsa_azure")
  webvm_private_key_b64 = base64encode(local.webvm_private_key)
  webvm_public_key      = file("${path.module}/id_rsa_azure.pub")
  # dynamic IPs we want to inject
  db_ip      = azurerm_network_interface.db_nic.private_ip_address
  fw_pub_ip  = azurerm_public_ip.fw_public_ip.ip_address
  fw_priv_ip = azurerm_firewall.firewall.ip_configuration[0].private_ip_address

  # render cloud‑init for WebVM
  webvm_cloudinit = templatefile("${path.module}/scripts/webvm-cloudinit.tpl", {
    db_ip                 = local.db_ip
    fw_pub_ip             = local.fw_pub_ip
    fw_priv_ip            = local.fw_priv_ip
    admin_username        = var.admin_username
    webvm_private_key     = local.webvm_private_key
    webvm_private_key_b64 = local.webvm_private_key_b64
    webvm_public_key      = local.webvm_public_key
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.workspace_id
  })

  # render cloud‑init for DBVM
  dbvm_cloudinit = templatefile(
    "${path.module}/scripts/mariadb-cloudinit.tpl",
    { admin_username       = var.admin_username
      admin_ssh_public_key = var.admin_ssh_public_key
      webvm_public_key     = local.webvm_public_key
    }
  )
}