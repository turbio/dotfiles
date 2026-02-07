# =============================================================================
# OCI Resources - backle, cackle
# =============================================================================

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "main" {
  compartment_id = var.oci_tenancy_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "vcn-20220811-1636"
  dns_label      = "vcn08111642"
  is_ipv6enabled = true
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "Internet Gateway vcn-20220811-1636"
  enabled        = true
}

resource "oci_core_route_table" "main" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "Default Route Table for vcn-20220811-1636"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  route_rules {
    destination       = "::/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "Default Security List for vcn-20220811-1636"

  # Egress: Allow all outbound (IPv4)
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Egress: Allow all outbound (IPv6)
  egress_security_rules {
    destination      = "::/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Ingress: Allow all (IPv4)
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "all"
    stateless   = false
  }

  # Ingress: Allow all (IPv6)
  ingress_security_rules {
    source      = "::/0"
    source_type = "CIDR_BLOCK"
    protocol    = "all"
    stateless   = false
  }

  # SSH
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # DNS (UDP)
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "17" # UDP
    stateless   = true

    udp_options {
      min = 53
      max = 53
    }
  }

  # ICMP - Fragmentation needed
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "1" # ICMP
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # ICMP - From VCN
  ingress_security_rules {
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "1" # ICMP
    stateless   = false

    icmp_options {
      type = 3
    }
  }

  # ICMPv6 - Allow all (needed for IPv6 neighbor discovery, etc.)
  ingress_security_rules {
    source      = "::/0"
    source_type = "CIDR_BLOCK"
    protocol    = "58" # ICMPv6
    stateless   = false
  }
}

resource "oci_core_subnet" "main" {
  compartment_id             = var.oci_tenancy_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.0.0/24"
  ipv6cidr_block             = cidrsubnet(oci_core_vcn.main.ipv6cidr_blocks[0], 8, 0)
  display_name               = "subnet-20251120-0141"
  dns_label                  = "subnet11200142"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false
}

# -----------------------------------------------------------------------------
# Get availability domain
# -----------------------------------------------------------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# -----------------------------------------------------------------------------
# ARM64 image for VM.Standard.A1.Flex
# -----------------------------------------------------------------------------
data "oci_core_images" "arm64" {
  compartment_id           = var.oci_tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# -----------------------------------------------------------------------------
# Compute Instance: backle
# -----------------------------------------------------------------------------
resource "oci_core_instance" "backle" {
  compartment_id      = var.oci_tenancy_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.A1.Flex"
  display_name        = "backle"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.arm64.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    display_name     = "backle"
    hostname_label   = "backle"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      name          = "Compute Instance Monitoring"
      desired_state = "ENABLED"
    }
  }

  # Prevent recreation when importing existing instances
  lifecycle {
    ignore_changes = [
      source_details,
      metadata,
      defined_tags,
      agent_config,
    ]
  }
}

# -----------------------------------------------------------------------------
# Compute Instance: cackle
# -----------------------------------------------------------------------------
resource "oci_core_instance" "cackle" {
  compartment_id      = var.oci_tenancy_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.A1.Flex"
  display_name        = "cackle"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.arm64.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    display_name     = "cackle"
    hostname_label   = "cackle"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      name          = "Compute Instance Monitoring"
      desired_state = "ENABLED"
    }
  }

  # Prevent recreation when importing existing instances
  lifecycle {
    ignore_changes = [
      source_details,
      metadata,
      defined_tags,
      agent_config,
    ]
  }
}

# -----------------------------------------------------------------------------
# IPv6 addresses for existing instances
# -----------------------------------------------------------------------------

# Look up the VNIC attachments to get VNIC IDs
data "oci_core_vnic_attachments" "backle" {
  compartment_id = var.oci_tenancy_ocid
  instance_id    = oci_core_instance.backle.id
}

data "oci_core_vnic_attachments" "cackle" {
  compartment_id = var.oci_tenancy_ocid
  instance_id    = oci_core_instance.cackle.id
}

resource "oci_core_ipv6" "backle" {
  vnic_id = data.oci_core_vnic_attachments.backle.vnic_attachments[0].vnic_id
}

resource "oci_core_ipv6" "cackle" {
  vnic_id = data.oci_core_vnic_attachments.cackle.vnic_attachments[0].vnic_id
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "backle_public_ip" {
  value = oci_core_instance.backle.public_ip
}

output "backle_private_ip" {
  value = oci_core_instance.backle.private_ip
}

output "backle_ipv6" {
  value = oci_core_ipv6.backle.ip_address
}

output "cackle_public_ip" {
  value = oci_core_instance.cackle.public_ip
}

output "cackle_private_ip" {
  value = oci_core_instance.cackle.private_ip
}

output "cackle_ipv6" {
  value = oci_core_ipv6.cackle.ip_address
}
