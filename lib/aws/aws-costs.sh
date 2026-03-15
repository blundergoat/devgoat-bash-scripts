#!/usr/bin/env bash
#
# aws-costs.sh - Cost Explorer summary plus a lightweight AWS inventory snapshot
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
  $0 YYYY-MM
  $0 YYYY-MM YYYY-MM
  $0 --start YYYY-MM [--end YYYY-MM]

Examples:
  $0
  $0 2026-01
  $0 2026-01 2026-03
  $0 --start 2026-01 --end 2026-03

Notes:
  - No arguments shows the previous month plus the current month to date.
  - Cost Explorer data is grouped by AWS service.
  - The resource inventory is descriptive; only ECS Fargate gets a direct estimate.
EOF
}

is_valid_month() {
    [[ "$1" =~ ^[0-9]{4}-(0[1-9]|1[0-2])$ ]]
}

next_month() {
    local year="${1:0:4}"
    local month="${1:5:2}"

    if [[ "$month" == "12" ]]; then
        printf '%04d-01\n' $((10#$year + 1))
    else
        printf '%04d-%02d\n' "$year" $((10#$month + 1))
    fi
}

last_day_of_month() {
    local year="$1"
    local month="$2"

    case "$month" in
        01|03|05|07|08|10|12) echo "31" ;;
        04|06|09|11) echo "30" ;;
        02)
            if (( (10#$year % 400 == 0) || (10#$year % 4 == 0 && 10#$year % 100 != 0) )); then
                echo "29"
            else
                echo "28"
            fi
            ;;
        *)
            echo "30"
            ;;
    esac
}

date_add_days() {
    local date_value="$1"
    local offset="$2"

    if date -d "$date_value $offset day" +%Y-%m-%d >/dev/null 2>&1; then
        date -d "$date_value $offset day" +%Y-%m-%d
    else
        local flag
        if (( offset >= 0 )); then
            flag="+${offset}d"
        else
            flag="${offset}d"
        fi
        date -j -f "%Y-%m-%d" "$date_value" -v"$flag" +%Y-%m-%d
    fi
}

repeat_rule() {
    printf '%*s' "$1" '' | tr ' ' '─'
}

run_cost_explorer() {
    local output

    if ! output=$(aws ce get-cost-and-usage "$@" --output json 2>&1); then
        echo -e "${RED}Error: Cost Explorer query failed${NC}"
        echo "$output"
        exit 1
    fi

    printf '%s\n' "$output"
}

START_MONTH=""
END_MONTH=""
POSITIONAL=()
HAS_MONTH_INPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --start)
            [[ -n "${2:-}" ]] || { echo -e "${RED}Error: --start requires YYYY-MM${NC}"; exit 1; }
            START_MONTH="$2"
            HAS_MONTH_INPUT=true
            shift 2
            ;;
        --end)
            [[ -n "${2:-}" ]] || { echo -e "${RED}Error: --end requires YYYY-MM${NC}"; exit 1; }
            END_MONTH="$2"
            HAS_MONTH_INPUT=true
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: unknown option '$1'${NC}"
            show_help
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
    echo -e "${RED}Error: expected at most 2 positional months${NC}"
    show_help
    exit 1
fi

if [[ ${#POSITIONAL[@]} -ge 1 && -z "$START_MONTH" ]]; then
    START_MONTH="${POSITIONAL[0]}"
    HAS_MONTH_INPUT=true
fi
if [[ ${#POSITIONAL[@]} -eq 2 && -z "$END_MONTH" ]]; then
    END_MONTH="${POSITIONAL[1]}"
    HAS_MONTH_INPUT=true
fi

if [[ -z "$START_MONTH" && -n "$END_MONTH" ]]; then
    START_MONTH="$END_MONTH"
    HAS_MONTH_INPUT=true
fi

if [[ -n "$START_MONTH" ]] && ! is_valid_month "$START_MONTH"; then
    echo -e "${RED}Error: invalid start month '$START_MONTH'${NC}"
    exit 1
fi

if [[ -n "$END_MONTH" ]] && ! is_valid_month "$END_MONTH"; then
    echo -e "${RED}Error: invalid end month '$END_MONTH'${NC}"
    exit 1
fi

require_unix
require_modern_bash
ensure_aws_cli
require_cmd jq "Install jq: https://jqlang.github.io/jq/download/"
require_cmd bc "Install bc via your package manager."
require_aws_auth

CURRENT_DATE="$(date +%Y-%m-%d)"
CURRENT_MONTH="${CURRENT_DATE:0:7}"

if [[ -z "$START_MONTH" ]]; then
    if [[ "${CURRENT_MONTH:5:2}" == "01" ]]; then
        START_MONTH="$(printf '%04d-12' $((10#${CURRENT_MONTH:0:4} - 1)))"
    else
        START_MONTH="$(printf '%04d-%02d' "${CURRENT_MONTH:0:4}" $((10#${CURRENT_MONTH:5:2} - 1)))"
    fi
fi

if [[ -z "$END_MONTH" ]]; then
    if [[ "$HAS_MONTH_INPUT" == false ]]; then
        END_MONTH="$CURRENT_MONTH"
    else
        END_MONTH="$START_MONTH"
    fi
fi

if [[ "$START_MONTH" > "$END_MONTH" ]]; then
    echo -e "${RED}Error: start month must be before or equal to end month${NC}"
    exit 1
fi

DISPLAY_START="${START_MONTH}-01"
API_START="$DISPLAY_START"

if [[ "$END_MONTH" == "$CURRENT_MONTH" ]]; then
    DISPLAY_END="$CURRENT_DATE"
    API_END="$(date_add_days "$CURRENT_DATE" 1)"
else
    DISPLAY_END="${END_MONTH}-$(last_day_of_month "${END_MONTH:0:4}" "${END_MONTH:5:2}")"
    API_END="$(next_month "$END_MONTH")-01"
fi

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  AWS Cost Summary${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${DIM}  Period: $DISPLAY_START -> $DISPLAY_END${NC}"
echo ""

echo -e "${BOLD}${CYAN}  COSTS BY SERVICE${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

costs_json="$(run_cost_explorer \
    --time-period "Start=$API_START,End=$API_END" \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE)"

mapfile -t months < <(
    jq -r '.ResultsByTime[].TimePeriod.Start' <<<"$costs_json" |
    cut -d'-' -f1-2 |
    awk '!seen[$0]++'
)

if [[ ${#months[@]} -eq 0 ]]; then
    echo -e "    ${DIM}No cost data returned for this period${NC}"
    echo ""
else
    table_width=$((42 + 12 * ${#months[@]}))
    header="  $(printf '%-42s' 'Service')"

    for month in "${months[@]}"; do
        header+="$(printf '%12s' "$month")"
    done

    echo -e "${BOLD}$header${NC}"
    echo -e "${DIM}  $(repeat_rule "$table_width")${NC}"

    declare -A service_costs
    declare -A service_seen
    declare -A service_totals
    declare -a all_services=()
    declare -a month_totals=()

    for _ in "${months[@]}"; do
        month_totals+=("0")
    done

    for month in "${months[@]}"; do
        while IFS='|' read -r service cost; do
            service="$(trim_trailing_whitespace "$(trim_leading_whitespace "$service")")"
            cost="$(trim_trailing_whitespace "$(trim_leading_whitespace "$cost")")"

            if [[ $(echo "$cost > 0.005" | bc -l) == "1" ]]; then
                service_costs["$service|$month"]="$cost"

                if [[ -z "${service_seen["$service"]:-}" ]]; then
                    service_seen["$service"]=1
                    all_services+=("$service")
                fi
            fi
        done < <(
            jq -r --arg month "$month" '
                .ResultsByTime[] |
                select(.TimePeriod.Start | startswith($month)) |
                .Groups[] |
                "\(.Keys[0])|\(.Metrics.BlendedCost.Amount)"
            ' <<<"$costs_json"
        )
    done

    for service in "${all_services[@]}"; do
        total=0
        for month in "${months[@]}"; do
            total="$(echo "$total + ${service_costs["$service|$month"]:-0}" | bc -l)"
        done
        service_totals["$service"]="$total"
    done

    mapfile -t sorted_services < <(
        for service in "${all_services[@]}"; do
            printf '%s|%s\n' "${service_totals["$service"]}" "$service"
        done | sort -t'|' -k1 -rn | cut -d'|' -f2
    )

    for service in "${sorted_services[@]}"; do
        display_name="$service"
        if [[ ${#display_name} -gt 40 ]]; then
            display_name="${display_name:0:37}..."
        fi

        row="  $(printf '%-42s' "$display_name")"
        month_idx=0

        for month in "${months[@]}"; do
            cost="${service_costs["$service|$month"]:-}"
            if [[ -n "$cost" ]]; then
                row+="$(printf '%12s' "$(printf '$%0.2f' "$cost")")"
                month_totals[$month_idx]="$(echo "${month_totals[$month_idx]} + $cost" | bc -l)"
            else
                row+="$(printf '%12s' "—")"
            fi
            month_idx=$((month_idx + 1))
        done

        echo "$row"
    done

    echo -e "${DIM}  $(repeat_rule "$table_width")${NC}"
    total_row="  $(printf '%-42s' 'TOTAL')"
    for month_idx in "${!months[@]}"; do
        total_row+="$(printf '%12s' "$(printf '$%0.2f' "${month_totals[$month_idx]}")")"
    done
    echo -e "${BOLD}$total_row${NC}"
    echo ""

    has_ec2_other=false
    for service in "${sorted_services[@]}"; do
        if [[ "$service" == "EC2 - Other" ]]; then
            has_ec2_other=true
            break
        fi
    done

    if [[ "$has_ec2_other" == true ]]; then
        echo -e "${BOLD}${CYAN}  EC2 - OTHER BREAKDOWN${NC}"
        echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

        ec2_other_json="$(run_cost_explorer \
            --time-period "Start=$API_START,End=$API_END" \
            --granularity MONTHLY \
            --metrics BlendedCost \
            --filter '{"Dimensions":{"Key":"SERVICE","Values":["EC2 - Other"]}}' \
            --group-by Type=DIMENSION,Key=USAGE_TYPE)"

        bd_header="  $(printf '%-42s' 'Usage Type')"
        for month in "${months[@]}"; do
            bd_header+="$(printf '%12s' "$month")"
        done
        echo -e "${DIM}$bd_header${NC}"

        declare -A breakdown_costs
        declare -A breakdown_seen
        declare -A breakdown_totals
        declare -a breakdown_names=()

        for month in "${months[@]}"; do
            while IFS='|' read -r raw_type cost; do
                raw_type="$(trim_trailing_whitespace "$(trim_leading_whitespace "$raw_type")")"
                cost="$(trim_trailing_whitespace "$(trim_leading_whitespace "$cost")")"

                if [[ $(echo "$cost > 0.005" | bc -l) != "1" ]]; then
                    continue
                fi

                name="$raw_type"
                if [[ "$name" =~ ^[A-Z0-9]{3,4}- ]]; then
                    name="${name#*-}"
                fi

                case "$name" in
                    NatGateway-Hours*) name="NAT Gateway (Hours)" ;;
                    NatGateway-Bytes*) name="NAT Gateway (Data)" ;;
                    EBS:VolumeUsage.*) name="EBS Volumes (${name#EBS:VolumeUsage.})" ;;
                    EBS:VolumeUsage) name="EBS Volumes (gp2)" ;;
                    EBS:Snapshot*) name="EBS Snapshots" ;;
                    *ElasticIP*) name="Elastic IPs" ;;
                    *DataTransfer*Out*) name="Data Transfer (Out)" ;;
                    *DataTransfer*In*) name="Data Transfer (In)" ;;
                    *DataTransfer*) name="Data Transfer" ;;
                    *PublicIPv4*) name="Public IPv4 Addresses" ;;
                esac

                existing="${breakdown_costs["$name|$month"]:-0}"
                breakdown_costs["$name|$month"]="$(echo "$existing + $cost" | bc -l)"

                if [[ -z "${breakdown_seen["$name"]:-}" ]]; then
                    breakdown_seen["$name"]=1
                    breakdown_names+=("$name")
                fi
            done < <(
                jq -r --arg month "$month" '
                    .ResultsByTime[] |
                    select(.TimePeriod.Start | startswith($month)) |
                    .Groups[] |
                    "\(.Keys[0])|\(.Metrics.BlendedCost.Amount)"
                ' <<<"$ec2_other_json"
            )
        done

        for name in "${breakdown_names[@]}"; do
            total=0
            for month in "${months[@]}"; do
                total="$(echo "$total + ${breakdown_costs["$name|$month"]:-0}" | bc -l)"
            done
            breakdown_totals["$name"]="$total"
        done

        mapfile -t sorted_breakdowns < <(
            for name in "${breakdown_names[@]}"; do
                printf '%s|%s\n' "${breakdown_totals["$name"]}" "$name"
            done | sort -t'|' -k1 -rn | cut -d'|' -f2
        )

        for name in "${sorted_breakdowns[@]}"; do
            display_name="$name"
            if [[ ${#display_name} -gt 40 ]]; then
                display_name="${display_name:0:37}..."
            fi

            row="  $(printf '%-42s' "  $display_name")"
            for month in "${months[@]}"; do
                cost="${breakdown_costs["$name|$month"]:-}"
                if [[ -n "$cost" && $(echo "$cost > 0.005" | bc -l) == "1" ]]; then
                    row+="$(printf '%12s' "$(printf '$%0.2f' "$cost")")"
                else
                    row+="$(printf '%12s' "—")"
                fi
            done
            echo -e "${DIM}$row${NC}"
        done

        echo ""
    fi
fi

echo -e "${BOLD}${CYAN}  RESOURCE INVENTORY${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

ecs_service_count=0
ecs_estimated_monthly=0

echo -e "${BOLD}  ECS Fargate Services${NC}"
clusters="$(aws ecs list-clusters --query 'clusterArns[*]' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$clusters")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    while IFS= read -r cluster_arn; do
        cluster_name="${cluster_arn##*/}"
        services="$(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[*]' --output json 2>/dev/null || echo '[]')"
        while IFS= read -r service_arn; do
            [[ -n "$service_arn" ]] || continue
            service_name="${service_arn##*/}"
            service_info="$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" \
                --query 'services[0].{running:runningCount,desired:desiredCount,taskDef:taskDefinition}' --output json 2>/dev/null || echo '{}')"
            task_def="$(jq -r '.taskDef // empty' <<<"$service_info")"
            [[ -n "$task_def" ]] || continue

            task_spec="$(aws ecs describe-task-definition --task-definition "$task_def" \
                --query 'taskDefinition.{cpu:cpu,memory:memory}' --output json 2>/dev/null || echo '{}')"
            cpu="$(jq -r '.cpu // 0' <<<"$task_spec")"
            mem="$(jq -r '.memory // 0' <<<"$task_spec")"
            desired="$(jq -r '.desired // 0' <<<"$service_info")"
            running="$(jq -r '.running // 0' <<<"$service_info")"

            cpu_units="$(echo "scale=2; $cpu / 1024" | bc)"
            mem_gb="$(echo "scale=2; $mem / 1024" | bc)"
            monthly_cost="$(printf '%.2f' "$(echo "($cpu_units * 0.04048 + $mem_gb * 0.004445) * 730 * $desired" | bc -l)")"

            echo -e "    ${cluster_name}/${service_name}  ${DIM}${cpu} CPU / ${mem} MB | ${running}/${desired} tasks | ~\$${monthly_cost}/mo${NC}"

            ecs_service_count=$((ecs_service_count + 1))
            ecs_estimated_monthly="$(echo "$ecs_estimated_monthly + $monthly_cost" | bc -l)"
        done < <(jq -r '.[]?' <<<"$services")
    done < <(jq -r '.[]?' <<<"$clusters")
fi

echo -e "${BOLD}  Application Load Balancers${NC}"
alb_json="$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].{name:LoadBalancerName,state:State.Code}' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$alb_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[] | "\(.name)|\(.state)"' <<<"$alb_json" | while IFS='|' read -r name state; do
        echo -e "    ${name}  ${DIM}(${state})${NC}"
    done
fi

echo -e "${BOLD}  WAF Web ACLs${NC}"
waf_json="$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[*].Name' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$waf_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[]?' <<<"$waf_json" | while IFS= read -r name; do
        echo -e "    ${name}"
    done
fi

echo -e "${BOLD}  RDS Instances${NC}"
rds_json="$(aws rds describe-db-instances --query 'DBInstances[*].{id:DBInstanceIdentifier,class:DBInstanceClass,engine:Engine,status:DBInstanceStatus}' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$rds_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[] | "\(.id)|\(.class)|\(.engine)|\(.status)"' <<<"$rds_json" | while IFS='|' read -r id class engine status; do
        echo -e "    ${id}  ${DIM}${class} (${engine}) | ${status}${NC}"
    done
fi

echo -e "${BOLD}  NAT Gateways${NC}"
nat_json="$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$nat_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[]?' <<<"$nat_json" | while IFS= read -r nat_id; do
        echo -e "    ${nat_id}"
    done
fi

echo -e "${BOLD}  Secrets Manager${NC}"
secrets_json="$(aws secretsmanager list-secrets --query 'SecretList[*].Name' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$secrets_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[]?' <<<"$secrets_json" | while IFS= read -r name; do
        echo -e "    ${name}"
    done
fi

echo -e "${BOLD}  S3 Buckets${NC}"
buckets_json="$(aws s3api list-buckets --query 'Buckets[*].Name' --output json 2>/dev/null || echo '[]')"
if [[ "$(jq 'length' <<<"$buckets_json")" -eq 0 ]]; then
    echo -e "    ${DIM}(none)${NC}"
else
    jq -r '.[]?' <<<"$buckets_json" | while IFS= read -r name; do
        echo -e "    ${name}"
    done
fi

echo ""
echo -e "${BOLD}${CYAN}  INVENTORY SUMMARY${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
printf "  %-28s %12s\n" "ECS services" "$ecs_service_count"
printf "  %-28s %12s\n" "Load balancers" "$(jq 'length' <<<"$alb_json")"
printf "  %-28s %12s\n" "Web ACLs" "$(jq 'length' <<<"$waf_json")"
printf "  %-28s %12s\n" "RDS instances" "$(jq 'length' <<<"$rds_json")"
printf "  %-28s %12s\n" "NAT gateways" "$(jq 'length' <<<"$nat_json")"
printf "  %-28s %12s\n" "Secrets" "$(jq 'length' <<<"$secrets_json")"
printf "  %-28s %12s\n" "Buckets" "$(jq 'length' <<<"$buckets_json")"
printf "  %-28s %12s\n" "ECS estimate" "$(printf '~$%0.2f/mo' "$ecs_estimated_monthly")"
echo ""
