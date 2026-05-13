###############################################################################
# Module: cloud-armor
# Edge WAF policy attached (via BackendConfig) to the LB-backed services. Adds
# the OWASP preconfigured rules and a default rate-limit.
###############################################################################

resource "google_compute_security_policy" "edge" {
  project = var.project_id
  name    = var.policy_name

  # Default rule: allow.
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }

  # Block known bad IPs from a Google-managed list.
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('crs-canary')"
      }
    }
    description = "Block known bad signatures (canary)"
  }

  # OWASP-style preconfigured rules.
  dynamic "rule" {
    for_each = var.owasp_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      match {
        expr {
          expression = rule.value.expression
        }
      }
      description = rule.value.description
    }
  }

  # Rate-limit by IP.
  rule {
    action   = "throttle"
    priority = 5000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_rpm
        interval_sec = 60
      }
    }
    description = "Per-IP rate limit"
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}
