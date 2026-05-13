variable "project_id" {
  type = string
}

variable "policy_name" {
  type    = string
  default = "edge-waf"
}

variable "rate_limit_rpm" {
  description = "Requests-per-minute per source IP before throttling."
  type        = number
  default     = 600
}

variable "owasp_rules" {
  description = "Preconfigured OWASP-style WAF rules."
  type = list(object({
    priority    = number
    action      = string
    expression  = string
    description = string
  }))
  default = [
    {
      priority    = 1100
      action      = "deny(403)"
      expression  = "evaluatePreconfiguredExpr('xss-v33-stable')"
      description = "OWASP XSS"
    },
    {
      priority    = 1200
      action      = "deny(403)"
      expression  = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      description = "OWASP SQLi"
    },
    {
      priority    = 1300
      action      = "deny(403)"
      expression  = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      description = "OWASP LFI"
    },
    {
      priority    = 1400
      action      = "deny(403)"
      expression  = "evaluatePreconfiguredExpr('rce-v33-stable')"
      description = "OWASP RCE"
    }
  ]
}
