resource "aws_cloudfront_origin_access_control" "origin_access_control_01" {
  name                              = "${var.bucket_name}.s3.${var.region}.amazonaws.com"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "distribution_01" {
  aliases             = [var.domain_name]
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  wait_for_deployment = true
  comment             = "${upper(var.environment)} - CloudFront Distribution for ${var.domain_name}"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy
    target_origin_id       = var.bucket_name
    viewer_protocol_policy = "redirect-to-https"

    # Add custom headers for IP restriction validation if needed
    dynamic "function_association" {
      for_each = var.environment == "dev" ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.ip_restriction_01[0].arn
      }
    }
  }

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.origin_access_control_01.id
    origin_id                = var.bucket_name
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  # Custom error responses
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
  }
}

# CloudFront Function to restrict access by IP for dev environment
resource "aws_cloudfront_function" "ip_restriction_01" {
  count = var.environment == "dev" ? 1 : 0

  name    = "ip-restriction-${var.environment}"
  runtime = "cloudfront-js-1.0"
  comment = "Function to restrict access based on IP rules in ${upper(var.environment)}"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var clientIP = event.viewer.ip;
    
    // Configuration
    var config = {
        allowedIPs: ${jsonencode(var.allowed_ips)},
        allowedCIDRs: ${jsonencode(var.allowed_cidrs)},
        debugMode: ${var.debug_mode ? "true" : "false"},
        denyMessage: 'Access denied: Your IP is not allowed to access this resource'
    };
    
    // Verify client access
    var accessResult = verifyAccess(clientIP, config);
    
    // If access is denied, return 403
    if (!accessResult.allowed) {
        if (config.debugMode) {
            console.log('Access denied for IP: ' + clientIP + ' - Reason: ' + accessResult.reason);
        }
        
        return {
            statusCode: 403,
            statusDescription: 'Forbidden',
            body: config.denyMessage
        };
    }
    
    // Access allowed, proceed with the request
    return request;
}

// Function to verify if an IP has access
function verifyAccess(ip, config) {
    // First check exact IP matches
    if (config.allowedIPs.includes(ip)) {
        return { allowed: true, reason: "IP in allowlist" };
    }
    
    // Then check CIDR ranges if defined
    if (config.allowedCIDRs && config.allowedCIDRs.length > 0) {
        for (var i = 0; i < config.allowedCIDRs.length; i++) {
            if (ipInCIDR(ip, config.allowedCIDRs[i])) {
                return { allowed: true, reason: "IP in allowed CIDR range" };
            }
        }
    }
    
    return { allowed: false, reason: "IP not in any allowed list" };
}

// Function to check if an IP is in a CIDR range
function ipInCIDR(ip, cidr) {
    try {
        var parts = cidr.split('/');
        var baseIP = parts[0];
        var prefix = parseInt(parts[1], 10);
        
        // Convert IP addresses to numeric format
        var baseIPNum = ipToNumber(baseIP);
        var testIPNum = ipToNumber(ip);
        
        // Calculate the bit mask
        var mask = ~(Math.pow(2, (32 - prefix)) - 1);
        
        // Compare the first prefix bits
        return (baseIPNum & mask) === (testIPNum & mask);
    } catch (e) {
        return false;
    }
}

// Convert IP to numeric value
function ipToNumber(ip) {
    var octets = ip.split('.');
    return ((parseInt(octets[0], 10) << 24) +
            (parseInt(octets[1], 10) << 16) +
            (parseInt(octets[2], 10) << 8) +
            parseInt(octets[3], 10)) >>> 0;
}
EOF

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [code, comment]

  }
}


data "aws_iam_policy_document" "cloudfront_oac_access" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = ["${var.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.distribution_01.arn]
    }
  }
}
