#!/usr/bin/env bash
#
# aws-security.sh - Security posture scan for common AWS services
#

set -euo pipefail

# ---- CONFIGURATION ----
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_aws-common.sh"

show_help() {
    cat << EOF
Usage:
  $0

Runs a read-only AWS security review covering WAF, security groups, IAM,
S3 public access blocks, RDS public exposure, EBS encryption, secrets
rotation, and CloudTrail logging.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: unknown option '$1'${NC}"
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Error: unexpected argument '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

require_unix
ensure_aws_cli
require_cmd jq "Install jq: https://jqlang.github.io/jq/download/"
require_cmd bc "Install bc via your package manager."
require_aws_auth

FINDINGS_FILE=$(mktemp)
trap 'rm -f "$FINDINGS_FILE"' EXIT

add_finding() {
    local level="$1" resource="$2" rtype="$3" message="$4"
    echo "${level}|${resource}|${rtype}|${message}" >> "$FINDINGS_FILE"
}

verdict() {
    local level="$1" message="$2"
    case "$level" in
        ok)    echo -e "      ${GREEN}✓ $message${NC}" ;;
        warn)  echo -e "      ${YELLOW}⚠ $message${NC}" ;;
        alert) echo -e "      ${RED}✗ $message${NC}" ;;
        info)  echo -e "      ${DIM}ℹ $message${NC}" ;;
    esac
}

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  AWS Security Scan${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${DIM}  Region: ${AWS_DEFAULT_REGION:-$AWS_REGION}${NC}"
echo ""

# ═════════════════════════════════════════════════════════════
# WAF ANALYSIS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  WAF WEB ACLs${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

waf_list=$(aws wafv2 list-web-acls --scope REGIONAL --output json 2>/dev/null || echo '{"WebACLs":[]}')
waf_count=$(echo "$waf_list" | jq '.WebACLs | length')

if [[ "$waf_count" -eq 0 ]]; then
    echo ""
    verdict "alert" "No WAF configured — web applications have no WAF protection"
    add_finding "alert" "WAF" "WAF" "No WAF configured"
else
    while IFS='|' read -r waf_name waf_arn waf_id; do
        echo ""
        echo -e "    ${BOLD}$waf_name${NC}"

        resource_arns=$(aws wafv2 list-resources-for-web-acl --web-acl-arn "$waf_arn" --output json 2>/dev/null)
        resource_count=$(echo "$resource_arns" | jq '.ResourceArns | length')
        if [[ "$resource_count" -eq 0 ]]; then
            verdict "alert" "Not associated with any resource — orphaned WAF (~\$8/mo wasted)"
            add_finding "alert" "$waf_name" "WAF" "Orphaned WAF (~\$8/mo wasted)"
        else
            verdict "ok" "Protecting $resource_count resource(s)"
            echo "$resource_arns" | jq -r '.ResourceArns[]' | while read -r res_arn; do
                echo -e "      ${DIM}  → $(echo "$res_arn" | rev | cut -d'/' -f1 | rev)${NC}"
            done
        fi

        acl_detail=$(aws wafv2 get-web-acl --name "$waf_name" --scope REGIONAL --id "$waf_id" --output json 2>/dev/null)
        rule_count=$(echo "$acl_detail" | jq '.WebACL.Rules | length')

        if [[ "$rule_count" -eq 0 ]]; then
            verdict "alert" "No rules configured — all traffic allowed through"
            add_finding "alert" "$waf_name" "WAF" "No rules configured"
        else
            managed_groups=$(echo "$acl_detail" | jq -r '
                .WebACL.Rules[]
                | select(.Statement.ManagedRuleGroupStatement != null)
                | "\(.Statement.ManagedRuleGroupStatement.VendorName)/\(.Statement.ManagedRuleGroupStatement.Name)"
            ' 2>/dev/null)
            if [[ -n "$managed_groups" ]]; then
                managed_count="$(printf '%s\n' "$managed_groups" | grep -c .)"
            else
                managed_count=0
            fi
            custom_count=$((rule_count - managed_count))
            rate_rules=$(echo "$acl_detail" | jq '[.WebACL.Rules[] | select(.Statement.RateBasedStatement != null)] | length')

            echo -e "      ${DIM}Rules: $rule_count total ($managed_count managed, $custom_count custom${rate_rules:+, $rate_rules rate-based})${NC}"

            if [[ -n "$managed_groups" ]]; then
                echo -e "      ${DIM}Managed rule groups:${NC}"
                echo "$managed_groups" | while read -r group; do
                    echo -e "        ${GREEN}✓${NC} $group"
                done
            else
                verdict "info" "No AWS managed rule groups — consider AWSManagedRulesCommonRuleSet"
                add_finding "info" "$waf_name" "WAF" "No managed rule groups"
            fi

            if [[ "$rate_rules" -eq 0 ]]; then
                verdict "info" "No rate-based rules — consider adding rate limiting"
                add_finding "info" "$waf_name" "WAF" "No rate-based rules"
            fi
        fi

        # Traffic stats (last 24h)
        now_ts=$(date -u +%Y-%m-%dT%H:%M:%S 2>/dev/null)
        day_ago_ts=$(date -u -d "24 hours ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%S 2>/dev/null)

        if [[ -n "$now_ts" && -n "$day_ago_ts" ]]; then
            blocked=$(aws cloudwatch get-metric-statistics \
                --namespace AWS/WAFV2 --metric-name BlockedRequests \
                --start-time "$day_ago_ts" --end-time "$now_ts" \
                --period 86400 --statistics Sum \
                --dimensions "Name=WebACL,Value=$waf_name" "Name=Rule,Value=ALL" \
                --output json 2>/dev/null | jq '[.Datapoints[].Sum] | add // 0')
            allowed=$(aws cloudwatch get-metric-statistics \
                --namespace AWS/WAFV2 --metric-name AllowedRequests \
                --start-time "$day_ago_ts" --end-time "$now_ts" \
                --period 86400 --statistics Sum \
                --dimensions "Name=WebACL,Value=$waf_name" "Name=Rule,Value=ALL" \
                --output json 2>/dev/null | jq '[.Datapoints[].Sum] | add // 0')

            blocked_int=$(printf '%.0f' "$blocked")
            allowed_int=$(printf '%.0f' "$allowed")
            total=$((blocked_int + allowed_int))

            printf "      %-22s %30s blocked / %s allowed (24h)\n" "Traffic" "$blocked_int" "$allowed_int"
            if [[ "$total" -gt 0 ]]; then
                block_pct=$(echo "scale=1; $blocked_int * 100 / $total" | bc)
                printf "      %-22s %44s%%\n" "Block rate" "$block_pct"
            fi
        fi

        # Cost breakdown: $5/ACL + $1/rule + $0.60/million requests
        cost_acl="5.00"
        cost_rules=$(echo "scale=2; $rule_count * 1" | bc)
        if [[ -n "${total:-}" && "$total" -gt 0 ]]; then
            cost_requests=$(echo "scale=2; $total * 30 / 1000000 * 0.60" | bc)
        else
            cost_requests="0.00"
        fi
        cost_total=$(echo "scale=2; $cost_acl + $cost_rules + $cost_requests" | bc)

        echo ""
        echo -e "      ${BOLD}Cost Breakdown${NC}"
        printf "      %-22s %44s\n" "Web ACL" "\$$cost_acl/mo"
        printf "      %-22s %44s\n" "Rules ($rule_count)" "\$$cost_rules/mo"
        printf "      %-22s %44s\n" "Request processing" "~\$$cost_requests/mo"
        echo -e "      ${DIM}$(printf '─%.0s' {1..52})${NC}"
        printf "      ${BOLD}%-22s %44s${NC}\n" "Estimated total" "~\$$cost_total/mo"
        add_finding "info" "$waf_name" "WAF" "Estimated cost: ~\$$cost_total/mo"
    done < <(echo "$waf_list" | jq -r '.WebACLs[] | "\(.Name)|\(.ARN)|\(.Id)"')
fi

echo ""

# ═════════════════════════════════════════════════════════════
# SECURITY GROUPS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  SECURITY GROUPS (open ingress)${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

open_sgs=$(aws ec2 describe-security-groups \
    --filters "Name=ip-permission.cidr,Values=0.0.0.0/0" \
    --query 'SecurityGroups[*].{id:GroupId,name:GroupName,desc:Description,perms:IpPermissions}' \
    --output json 2>/dev/null)
open_sg_count=$(echo "$open_sgs" | jq 'length')

if [[ "$open_sg_count" -eq 0 ]]; then
    echo ""
    verdict "ok" "No security groups with 0.0.0.0/0 ingress"
else
    echo ""
    for i in $(seq 0 $((open_sg_count - 1))); do
        sg_id=$(echo "$open_sgs" | jq -r ".[$i].id")
        sg_name=$(echo "$open_sgs" | jq -r ".[$i].name")
        sg_desc=$(echo "$open_sgs" | jq -r ".[$i].desc")

        echo -e "    ${BOLD}$sg_name${NC} ($sg_id)"
        echo -e "    ${DIM}$sg_desc${NC}"

        echo "$open_sgs" | jq -r --argjson idx "$i" '
            .[$idx].perms[] |
            select(
                (.IpRanges[]?.CidrIp == "0.0.0.0/0") or
                (.Ipv6Ranges[]?.CidrIpv6 == "::/0")
            ) |
            "\(.FromPort // -1)|\(.ToPort // -1)"
        ' 2>/dev/null | sort -u | while IFS='|' read -r from_port to_port; do
            if [[ "$from_port" == "-1" ]]; then
                port_label="ALL TRAFFIC"; level="alert"
            elif [[ "$from_port" == "$to_port" ]]; then
                port_label="$from_port"
                case "$from_port" in
                    22)   port_label="22 (SSH)"; level="alert" ;;
                    3389) port_label="3389 (RDP)"; level="alert" ;;
                    3306) port_label="3306 (MySQL)"; level="alert" ;;
                    5432) port_label="5432 (PostgreSQL)"; level="alert" ;;
                    80)   port_label="80 (HTTP)"; level="warn" ;;
                    443)  port_label="443 (HTTPS)"; level="warn" ;;
                    *)    level="warn" ;;
                esac
            else
                port_label="$from_port-$to_port"; level="warn"
            fi
            verdict "$level" "Port $port_label open to 0.0.0.0/0"
            add_finding "$level" "$sg_name ($sg_id)" "SG" "Port $port_label open to 0.0.0.0/0"
        done
        echo ""
    done
fi

echo ""

# ═════════════════════════════════════════════════════════════
# IAM USERS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  IAM USERS${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

iam_users=$(aws iam list-users --query 'Users[*].UserName' --output json 2>/dev/null || echo '[]')
user_count=$(echo "$iam_users" | jq 'length')
no_mfa_count=0
old_key_count=0

if [[ "$user_count" -eq 0 ]]; then
    echo -e "    ${DIM}No IAM users found${NC}"
else
    printf "    ${BOLD}%-25s %-8s %-15s %-10s${NC}\n" "User" "MFA" "Key Age" "Status"
    echo -e "    ${DIM}$(printf '─%.0s' {1..60})${NC}"

    for user in $(echo "$iam_users" | jq -r '.[]'); do
        mfa_devices=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices | length(@)' --output text 2>/dev/null || echo "0")
        if [[ "$mfa_devices" -gt 0 ]]; then
            mfa_status="${GREEN}Yes${NC}"
        else
            mfa_status="${RED}No${NC}"
            no_mfa_count=$((no_mfa_count + 1))
        fi

        key_info=$(aws iam list-access-keys --user-name "$user" --output json 2>/dev/null)
        active_keys=$(echo "$key_info" | jq '[.AccessKeyMetadata[] | select(.Status == "Active")] | length')

        if [[ "$active_keys" -eq 0 ]]; then
            printf "    %-25s %b     %-15s %-10s\n" "$user" "$mfa_status" "—" "—"
        else
            first=true
            echo "$key_info" | jq -r '.AccessKeyMetadata[] | select(.Status == "Active") | "\(.AccessKeyId)|\(.CreateDate)"' | while IFS='|' read -r key_id created; do
                created_epoch=$(date -d "$created" +%s 2>/dev/null || echo "0")
                now_epoch=$(date +%s)
                if [[ "$created_epoch" -gt 0 ]]; then
                    age_days=$(( (now_epoch - created_epoch) / 86400 ))
                else
                    age_days=0
                fi

                age_color="" age_status="OK"
                if [[ "$age_days" -gt 365 ]]; then
                    age_color="$RED"; age_status="CRITICAL"
                elif [[ "$age_days" -gt 90 ]]; then
                    age_color="$YELLOW"; age_status="Rotate"
                fi

                if $first; then
                    printf "    %-25s %b     ${age_color}%-15s %-10s${NC}\n" "$user" "$mfa_status" "${age_days}d" "$age_status"
                    first=false
                else
                    printf "    %-25s %-8s ${age_color}%-15s %-10s${NC}\n" "" "" "${age_days}d" "$age_status"
                fi
            done
        fi
    done

    echo ""
    if [[ "$no_mfa_count" -gt 0 ]]; then
        verdict "alert" "$no_mfa_count user(s) without MFA enabled"
        add_finding "alert" "IAM" "IAM" "$no_mfa_count user(s) without MFA enabled"
    else
        verdict "ok" "All users have MFA enabled"
    fi
fi

echo ""

# ═════════════════════════════════════════════════════════════
# S3 PUBLIC ACCESS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  S3 PUBLIC ACCESS BLOCKS${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

s3_buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output json 2>/dev/null || echo '[]')
not_blocked_count=0

for bucket in $(echo "$s3_buckets" | jq -r '.[]' 2>/dev/null); do
    pab=$(aws s3api get-public-access-block --bucket "$bucket" 2>/dev/null || echo '{}')
    block_acls=$(echo "$pab" | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls // false')
    block_policy=$(echo "$pab" | jq -r '.PublicAccessBlockConfiguration.BlockPublicPolicy // false')
    ignore_acls=$(echo "$pab" | jq -r '.PublicAccessBlockConfiguration.IgnorePublicAcls // false')
    restrict=$(echo "$pab" | jq -r '.PublicAccessBlockConfiguration.RestrictPublicBuckets // false')

    if [[ "$block_acls" == "true" && "$block_policy" == "true" && "$ignore_acls" == "true" && "$restrict" == "true" ]]; then
        echo -e "    ${GREEN}✓${NC}  $bucket"
    else
        echo -e "    ${YELLOW}⚠${NC}  $bucket — ${YELLOW}partially open${NC}"
        not_blocked_count=$((not_blocked_count + 1))
    fi
done

echo ""
if [[ "$not_blocked_count" -gt 0 ]]; then
    verdict "warn" "$not_blocked_count bucket(s) without full public access blocks"
    add_finding "warn" "S3" "S3" "$not_blocked_count bucket(s) without full public access blocks"
else
    verdict "ok" "All buckets have public access fully blocked"
fi

echo ""

# ═════════════════════════════════════════════════════════════
# RDS PUBLIC ACCESS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  RDS PUBLIC ACCESSIBILITY${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

public_rds=$(aws rds describe-db-instances \
    --query 'DBInstances[?PubliclyAccessible==`true`].DBInstanceIdentifier' \
    --output json 2>/dev/null)
public_rds_count=$(echo "$public_rds" | jq 'length')

if [[ "$public_rds_count" -eq 0 ]]; then
    verdict "ok" "No publicly accessible RDS instances"
else
    for db_id in $(echo "$public_rds" | jq -r '.[]'); do
        verdict "alert" "$db_id is publicly accessible"
    done
    add_finding "alert" "RDS" "RDS" "$public_rds_count publicly accessible database(s)"
fi

echo ""

# ═════════════════════════════════════════════════════════════
# EBS ENCRYPTION
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  EBS ENCRYPTION${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

unencrypted_ebs=$(aws ec2 describe-volumes \
    --filters "Name=encrypted,Values=false" \
    --query 'Volumes[*].{id:VolumeId,size:Size,type:VolumeType}' \
    --output json 2>/dev/null)
unencrypted_count=$(echo "$unencrypted_ebs" | jq 'length')

if [[ "$unencrypted_count" -eq 0 ]]; then
    verdict "ok" "All EBS volumes are encrypted"
else
    for i in $(seq 0 $((unencrypted_count - 1))); do
        vol_id=$(echo "$unencrypted_ebs" | jq -r ".[$i].id")
        vol_size=$(echo "$unencrypted_ebs" | jq -r ".[$i].size")
        vol_type=$(echo "$unencrypted_ebs" | jq -r ".[$i].type")
        verdict "warn" "$vol_id — $vol_type ${vol_size}GB — not encrypted"
    done
    add_finding "warn" "EBS" "EBS" "$unencrypted_count unencrypted EBS volume(s)"
fi

echo ""

# ═════════════════════════════════════════════════════════════
# SECRETS MANAGER ROTATION
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  SECRETS MANAGER ROTATION${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

secrets=$(aws secretsmanager list-secrets --output json 2>/dev/null || echo '{"SecretList":[]}')
secret_count=$(echo "$secrets" | jq '.SecretList | length')
no_rotation_count=0
if [[ "$secret_count" -eq 0 ]]; then
    echo -e "    ${DIM}No secrets found${NC}"
else
    while IFS='|' read -r name rotation_enabled last_rotated; do
        if [[ "$rotation_enabled" != "true" ]]; then
            echo -e "    ${YELLOW}⚠${NC}  $name — ${YELLOW}No auto-rotation${NC}"
            no_rotation_count=$((no_rotation_count + 1))
        else
            echo -e "    ${GREEN}✓${NC}  $name — Auto-rotation"
        fi
    done < <(echo "$secrets" | jq -r '.SecretList[] | "\(.Name)|\(.RotationEnabled // false)|\(.LastRotatedDate // "null")"')

    echo ""
    if [[ "$no_rotation_count" -gt 0 ]]; then
        verdict "info" "$no_rotation_count secret(s) without automatic rotation"
        add_finding "info" "Secrets Manager" "Secrets" "$no_rotation_count secret(s) without automatic rotation"
    fi
fi

echo ""

# ═════════════════════════════════════════════════════════════
# CLOUDTRAIL
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  CLOUDTRAIL${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
echo ""

trails=$(aws cloudtrail describe-trails --output json 2>/dev/null || echo '{"trailList":[]}')
trail_count=$(echo "$trails" | jq '.trailList | length')

if [[ "$trail_count" -eq 0 ]]; then
    verdict "alert" "No CloudTrail trails configured — API activity is not being logged"
    add_finding "alert" "CloudTrail" "CloudTrail" "No CloudTrail trails"
else
    for i in $(seq 0 $((trail_count - 1))); do
        trail_name=$(echo "$trails" | jq -r ".trailList[$i].Name")
        is_multi=$(echo "$trails" | jq -r ".trailList[$i].IsMultiRegionTrail")
        has_log_group=$(echo "$trails" | jq -r ".trailList[$i].CloudWatchLogsLogGroupArn // \"none\"")
        s3_bucket=$(echo "$trails" | jq -r ".trailList[$i].S3BucketName")

        status=$(aws cloudtrail get-trail-status --name "$trail_name" --output json 2>/dev/null)
        is_logging=$(echo "$status" | jq -r '.IsLogging')

        echo -e "    ${BOLD}$trail_name${NC}"
        if [[ "$is_logging" == "true" ]]; then
            verdict "ok" "Logging is active"
        else
            verdict "alert" "Logging is DISABLED"
            add_finding "alert" "$trail_name" "CloudTrail" "Logging is disabled"
        fi

        if [[ "$is_multi" == "true" ]]; then
            verdict "ok" "Multi-region trail"
        else
            verdict "info" "Single-region trail — consider multi-region"
            add_finding "info" "$trail_name" "CloudTrail" "Single-region trail"
        fi

        if [[ "$has_log_group" == "none" ]]; then
            verdict "warn" "No CloudWatch Logs integration"
            add_finding "warn" "$trail_name" "CloudTrail" "No CloudWatch Logs integration"
        fi

        echo -e "      ${DIM}S3: $s3_bucket${NC}"
    done
fi

echo ""

# ═════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

alert_count=$(grep -c '^alert|' "$FINDINGS_FILE" 2>/dev/null || true)
warn_count=$(grep -c '^warn|' "$FINDINGS_FILE" 2>/dev/null || true)
info_count=$(grep -c '^info|' "$FINDINGS_FILE" 2>/dev/null || true)
total_findings=$((alert_count + warn_count + info_count))

if [[ "$total_findings" -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}  No security issues found!${NC}"
elif [[ "$alert_count" -gt 0 ]]; then
    echo -e "${BOLD}${RED}  $total_findings findings ($alert_count critical, $warn_count warnings, $info_count info)${NC}"
else
    echo -e "${BOLD}${YELLOW}  $total_findings findings ($warn_count warnings, $info_count info)${NC}"
fi
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [[ -s "$FINDINGS_FILE" ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}  FINDINGS SUMMARY${NC}"
    echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
    for level in alert warn info; do
        grep "^${level}|" "$FINDINGS_FILE" 2>/dev/null | while IFS='|' read -r lvl resource rtype message; do
            case "$lvl" in
                alert) icon="${RED}✗${NC}" ;;
                warn)  icon="${YELLOW}⚠${NC}" ;;
                info)  icon="${DIM}ℹ${NC}" ;;
            esac
            echo -e "    $icon  ${BOLD}$resource${NC} ($rtype): $message"
        done
    done
fi

echo ""
