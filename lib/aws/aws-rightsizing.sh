#!/usr/bin/env bash
#
# aws-rightsizing.sh - Rightsizing review across common AWS resources
#

set -euo pipefail

# ---- CONFIGURATION ----
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CPU_LOW="${CPU_LOW:-20}"
CPU_HIGH="${CPU_HIGH:-80}"
MEM_LOW="${MEM_LOW:-20}"
MEM_HIGH="${MEM_HIGH:-80}"
STORAGE_HIGH="${STORAGE_HIGH:-80}"
CONN_LOW="${CONN_LOW:-5}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_aws-common.sh"

show_help() {
    cat << EOF
Usage:
  $0
  $0 14
  $0 --days 30

Examples:
  $0
  $0 14
  $0 --days 30

Environment overrides:
  CPU_LOW, CPU_HIGH, MEM_LOW, MEM_HIGH, STORAGE_HIGH, CONN_LOW
EOF
}

DAYS="7"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --days)
            [[ -n "${2:-}" ]] || { echo -e "${RED}Error: --days requires a value${NC}"; exit 1; }
            DAYS="$2"
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

if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
    echo -e "${RED}Error: expected at most one positional day count${NC}"
    exit 1
fi

if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
    DAYS="${POSITIONAL[0]}"
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || (( DAYS < 1 || DAYS > 90 )); then
    echo -e "${RED}Error: days must be an integer between 1 and 90${NC}"
    exit 1
fi

require_unix
require_modern_bash
ensure_aws_cli
require_cmd jq "Install jq: https://jqlang.github.io/jq/download/"
require_cmd bc "Install bc via your package manager."
require_aws_auth

START_TIME=$(date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
# Period in seconds: use 1-hour intervals for <= 7 days, 6-hour for longer
if [[ "$DAYS" -le 7 ]]; then
    PERIOD=3600
else
    PERIOD=21600
fi

# Helper: get a CloudWatch metric statistic
get_metric() {
    local namespace="$1" metric="$2" stat="$3" dim_name="$4" dim_value="$5"
    local dim_name2="${6:-}" dim_value2="${7:-}"

    local dimensions="Name=$dim_name,Value=$dim_value"
    if [[ -n "$dim_name2" ]]; then
        dimensions+=" Name=$dim_name2,Value=$dim_value2"
    fi

    aws cloudwatch get-metric-statistics \
        --namespace "$namespace" \
        --metric-name "$metric" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period "$PERIOD" \
        --statistics "$stat" \
        --dimensions $dimensions \
        --output json 2>/dev/null
}

extract_stat() {
    local json="$1" stat="$2"
    echo "$json" | jq -r "[.Datapoints[].$stat] | if length == 0 then null else (add / length) end // empty" 2>/dev/null
}

extract_max() {
    local json="$1" stat="$2"
    echo "$json" | jq -r "[.Datapoints[].$stat] | if length == 0 then null else max end // empty" 2>/dev/null
}

extract_min() {
    local json="$1" stat="$2"
    echo "$json" | jq -r "[.Datapoints[].$stat] | if length == 0 then null else min end // empty" 2>/dev/null
}

datapoint_count() {
    local json="$1"
    echo "$json" | jq '.Datapoints | length' 2>/dev/null
}

print_bar() {
    local value="$1" max="$2" label="$3" unit="${4:-%}"
    local pct
    if [[ "$max" == "0" || -z "$max" ]]; then
        pct=0
    else
        pct=$(echo "scale=0; $value * 100 / $max" | bc)
    fi

    local bar_width=30
    local filled=$(echo "scale=0; $pct * $bar_width / 100" | bc)
    if [[ "$filled" -gt "$bar_width" ]]; then filled=$bar_width; fi

    local bar=""
    local color="$GREEN"
    if [[ "$pct" -gt "$CPU_HIGH" ]]; then color="$RED"
    elif [[ "$pct" -gt "$CPU_LOW" ]]; then color="$YELLOW"
    fi

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<bar_width; i++)); do bar+="░"; done

    printf "      %-22s ${color}%s${NC} %6.1f%s\n" "$label" "$bar" "$value" "$unit"
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
echo -e "${BOLD}${BLUE}  AWS Rightsizing Advisor${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${DIM}  Period: last $DAYS days ($START_TIME → $END_TIME)${NC}"
echo -e "${DIM}  Thresholds: CPU/Mem low <${CPU_LOW}% | high >${CPU_HIGH}% | Storage >${STORAGE_HIGH}%${NC}"
echo ""

findings_count=0

# ═════════════════════════════════════════════════════════════
# RDS INSTANCES
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  RDS INSTANCES${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

rds_instances=$(aws rds describe-db-instances --output json 2>/dev/null || echo '{"DBInstances":[]}')
rds_count=$(echo "$rds_instances" | jq '.DBInstances | length')

if [[ "$rds_count" -eq 0 ]]; then
    echo -e "    ${DIM}No RDS instances found${NC}"
else
    while IFS='|' read -r id class engine version storage max_storage multi_az storage_type status; do
        echo ""
        echo -e "    ${BOLD}$id${NC}  ($class, $engine $version, ${storage}GB $storage_type)"
        echo -e "    ${DIM}Status: $status | Multi-AZ: $multi_az | Max storage: $max_storage${NC}"

        # CPU utilization
        cpu_json=$(get_metric "AWS/RDS" "CPUUtilization" "Average" "DBInstanceIdentifier" "$id")
        cpu_avg=$(extract_stat "$cpu_json" "Average")
        cpu_max_json=$(get_metric "AWS/RDS" "CPUUtilization" "Maximum" "DBInstanceIdentifier" "$id")
        cpu_max=$(extract_max "$cpu_max_json" "Maximum")

        if [[ -n "$cpu_avg" ]]; then
            print_bar "$cpu_avg" 100 "CPU avg"
            if [[ -n "$cpu_max" ]]; then
                printf "      %-22s %44.1f%s\n" "CPU peak" "$cpu_max" "%"
            fi
            cpu_int=$(echo "$cpu_avg" | cut -d'.' -f1)
            if [[ "$cpu_int" -lt "$CPU_LOW" ]]; then
                verdict "warn" "CPU avg ${cpu_avg}% — instance may be over-provisioned"
                findings_count=$((findings_count + 1))
            elif [[ "$cpu_int" -gt "$CPU_HIGH" ]]; then
                verdict "alert" "CPU avg ${cpu_avg}% — consider upgrading instance class"
                findings_count=$((findings_count + 1))
            else
                verdict "ok" "CPU utilization is healthy"
            fi
        fi

        # Freeable memory
        mem_json=$(get_metric "AWS/RDS" "FreeableMemory" "Average" "DBInstanceIdentifier" "$id")
        mem_avg=$(extract_stat "$mem_json" "Average")
        if [[ -n "$mem_avg" ]]; then
            mem_mb=$(echo "scale=0; $mem_avg / 1048576" | bc)
            # Estimate total memory by instance class
            case "$class" in
                db.t4g.micro|db.t3.micro)   total_mem_mb=1024 ;;
                db.t4g.small|db.t3.small)   total_mem_mb=2048 ;;
                db.t4g.medium|db.t3.medium) total_mem_mb=4096 ;;
                db.t4g.large|db.t3.large)   total_mem_mb=8192 ;;
                db.r6g.large|db.r5.large)   total_mem_mb=16384 ;;
                *)                          total_mem_mb=0 ;;
            esac
            if [[ "$total_mem_mb" -gt 0 ]]; then
                used_mb=$((total_mem_mb - mem_mb))
                mem_pct=$(echo "scale=1; $used_mb * 100 / $total_mem_mb" | bc)
                print_bar "$mem_pct" 100 "Memory used" "%"
                printf "      %-22s %39s / %s\n" "" "${used_mb}MB used" "${total_mem_mb}MB total"
                mem_pct_int=$(echo "$mem_pct" | cut -d'.' -f1)
                if [[ "$mem_pct_int" -lt "$MEM_LOW" ]]; then
                    verdict "warn" "Memory usage ${mem_pct}% — could downsize instance"
                    findings_count=$((findings_count + 1))
                elif [[ "$mem_pct_int" -gt "$MEM_HIGH" ]]; then
                    verdict "alert" "Memory usage ${mem_pct}% — consider upgrading"
                    findings_count=$((findings_count + 1))
                else
                    verdict "ok" "Memory utilization is healthy"
                fi
            else
                printf "      %-22s %40s MB free\n" "Freeable memory" "$mem_mb"
            fi
        fi

        # Storage usage
        storage_json=$(get_metric "AWS/RDS" "FreeStorageSpace" "Average" "DBInstanceIdentifier" "$id")
        storage_avg=$(extract_stat "$storage_json" "Average")
        if [[ -n "$storage_avg" ]]; then
            free_gb=$(echo "scale=1; $storage_avg / 1073741824" | bc)
            used_gb=$(echo "scale=1; $storage - $free_gb" | bc)
            storage_pct=$(echo "scale=1; $used_gb * 100 / $storage" | bc)
            print_bar "$storage_pct" 100 "Storage used" "%"
            printf "      %-22s %38s / %sGB\n" "" "${used_gb}GB used" "$storage"
            storage_int=$(echo "$storage_pct" | cut -d'.' -f1)
            if [[ "$storage_int" -gt "$STORAGE_HIGH" ]]; then
                verdict "alert" "Storage ${storage_pct}% full — consider expanding"
                findings_count=$((findings_count + 1))
            elif [[ "$storage_int" -lt 10 ]]; then
                verdict "warn" "Storage only ${storage_pct}% used — allocated storage may be excessive"
                findings_count=$((findings_count + 1))
            else
                verdict "ok" "Storage utilization is healthy"
            fi
        fi

        # Database connections
        conn_json=$(get_metric "AWS/RDS" "DatabaseConnections" "Average" "DBInstanceIdentifier" "$id")
        conn_avg=$(extract_stat "$conn_json" "Average")
        conn_max_json=$(get_metric "AWS/RDS" "DatabaseConnections" "Maximum" "DBInstanceIdentifier" "$id")
        conn_max=$(extract_max "$conn_max_json" "Maximum")
        if [[ -n "$conn_avg" ]]; then
            printf "      %-22s %40.1f avg, %.0f peak\n" "DB connections" "$conn_avg" "${conn_max:-0}"
            conn_int=$(echo "$conn_avg" | cut -d'.' -f1)
            if [[ "$conn_int" -lt "$CONN_LOW" && "$conn_int" -gt 0 ]]; then
                verdict "info" "Low connection count — typical for small workloads"
            elif [[ "$conn_int" -eq 0 ]]; then
                verdict "warn" "Zero connections — is this database in use?"
                findings_count=$((findings_count + 1))
            fi
        fi

        # Read/Write IOPS
        read_json=$(get_metric "AWS/RDS" "ReadIOPS" "Average" "DBInstanceIdentifier" "$id")
        write_json=$(get_metric "AWS/RDS" "WriteIOPS" "Average" "DBInstanceIdentifier" "$id")
        read_avg=$(extract_stat "$read_json" "Average")
        write_avg=$(extract_stat "$write_json" "Average")
        if [[ -n "$read_avg" && -n "$write_avg" ]]; then
            printf "      %-22s %40.1f read, %.1f write\n" "IOPS (avg)" "$read_avg" "$write_avg"
        fi

        # Read/Write Latency
        rlat_json=$(get_metric "AWS/RDS" "ReadLatency" "Average" "DBInstanceIdentifier" "$id")
        wlat_json=$(get_metric "AWS/RDS" "WriteLatency" "Average" "DBInstanceIdentifier" "$id")
        rlat_avg=$(extract_stat "$rlat_json" "Average")
        wlat_avg=$(extract_stat "$wlat_json" "Average")
        if [[ -n "$rlat_avg" && -n "$wlat_avg" ]]; then
            rlat_ms=$(echo "scale=2; $rlat_avg * 1000" | bc)
            wlat_ms=$(echo "scale=2; $wlat_avg * 1000" | bc)
            printf "      %-22s %38s ms read, %s ms write\n" "Latency (avg)" "$rlat_ms" "$wlat_ms"
            rlat_check=$(echo "$rlat_ms > 20" | bc)
            wlat_check=$(echo "$wlat_ms > 20" | bc)
            if [[ "$rlat_check" -eq 1 || "$wlat_check" -eq 1 ]]; then
                verdict "alert" "High latency detected — check IOPS limits or storage type"
                findings_count=$((findings_count + 1))
            fi
        fi

        # Rightsizing suggestion
        if [[ -n "$cpu_avg" ]]; then
            cpu_int=$(echo "$cpu_avg" | cut -d'.' -f1)
            if [[ "$cpu_int" -lt "$CPU_LOW" && "$class" != "db.t4g.micro" && "$class" != "db.t3.micro" ]]; then
                case "$class" in
                    db.t4g.small|db.t3.small)     suggest="db.t4g.micro (~\$12/mo)" ;;
                    db.t4g.medium|db.t3.medium)   suggest="db.t4g.small (~\$24/mo)" ;;
                    db.t4g.large|db.t3.large)     suggest="db.t4g.medium (~\$48/mo)" ;;
                    db.r6g.large|db.r5.large)     suggest="db.r6g.medium or db.t4g.large" ;;
                    *)                            suggest="one size smaller" ;;
                esac
                verdict "warn" "SUGGESTION: Downsize to $suggest"
            elif [[ "$cpu_int" -lt "$CPU_LOW" && ("$class" == "db.t4g.micro" || "$class" == "db.t3.micro") ]]; then
                verdict "ok" "Already smallest instance — no further downsizing available"
            fi
        fi
    done < <(echo "$rds_instances" | jq -r '.DBInstances[] | "\(.DBInstanceIdentifier)|\(.DBInstanceClass)|\(.Engine)|\(.EngineVersion)|\(.AllocatedStorage)|\(.MaxAllocatedStorage // "n/a")|\(.MultiAZ)|\(.StorageType)|\(.DBInstanceStatus)"')
fi

echo ""

# ═════════════════════════════════════════════════════════════
# ECS FARGATE TASKS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  ECS FARGATE SERVICES${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

clusters=$(aws ecs list-clusters --query 'clusterArns[*]' --output json 2>/dev/null || echo '[]')
while IFS= read -r cluster_arn; do
    cluster_name=$(echo "$cluster_arn" | rev | cut -d'/' -f1 | rev)
    services=$(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[*]' --output json 2>/dev/null || echo '[]')

    while IFS= read -r service_arn; do
        service_name=$(echo "$service_arn" | rev | cut -d'/' -f1 | rev)
        service_info=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" \
            --query 'services[0].{desired:desiredCount,running:runningCount,taskDef:taskDefinition}' --output json 2>/dev/null)
        task_def=$(echo "$service_info" | jq -r '.taskDef')
        desired=$(echo "$service_info" | jq -r '.desired')
        running=$(echo "$service_info" | jq -r '.running')
        task_spec=$(aws ecs describe-task-definition --task-definition "$task_def" \
            --query 'taskDefinition.{cpu:cpu,memory:memory,containers:containerDefinitions[*].name}' --output json 2>/dev/null)
        cpu=$(echo "$task_spec" | jq -r '.cpu')
        mem=$(echo "$task_spec" | jq -r '.memory')
        containers=$(echo "$task_spec" | jq -r '.containers | join(", ")')

        cpu_vcpu=$(echo "scale=2; $cpu / 1024" | bc)
        mem_gb=$(echo "scale=2; $mem / 1024" | bc)
        # Fargate us-east-1 Linux/x86 pricing (2026-01)
        monthly_cost=$(printf '%.2f' "$(echo "($cpu_vcpu * 0.04048 + $mem_gb * 0.004445) * 730 * $desired" | bc -l)")

        echo ""
        echo -e "    ${BOLD}${cluster_name}/${service_name}${NC}"
        echo -e "    ${DIM}Containers: $containers | Tasks: $running/$desired running | ${cpu} CPU (${cpu_vcpu} vCPU) / ${mem}MB (${mem_gb}GB) | ~\$${monthly_cost}/mo${NC}"

        # CPU utilization
        ecs_cpu_json=$(get_metric "AWS/ECS" "CPUUtilization" "Average" "ClusterName" "$cluster_name" "ServiceName" "$service_name")
        ecs_cpu_avg=$(extract_stat "$ecs_cpu_json" "Average")
        ecs_cpu_max_json=$(get_metric "AWS/ECS" "CPUUtilization" "Maximum" "ClusterName" "$cluster_name" "ServiceName" "$service_name")
        ecs_cpu_max=$(extract_max "$ecs_cpu_max_json" "Maximum")
        points=$(datapoint_count "$ecs_cpu_json")

        if [[ -n "$ecs_cpu_avg" && "$points" -gt 0 ]]; then
            print_bar "$ecs_cpu_avg" 100 "CPU avg"
            if [[ -n "$ecs_cpu_max" ]]; then
                printf "      %-22s %44.1f%s\n" "CPU peak" "$ecs_cpu_max" "%"
            fi
            ecs_cpu_int=$(echo "$ecs_cpu_avg" | cut -d'.' -f1)
            if [[ "$ecs_cpu_int" -lt "$CPU_LOW" ]]; then
                verdict "warn" "CPU avg ${ecs_cpu_avg}% — task may be over-provisioned"
                findings_count=$((findings_count + 1))
            elif [[ "$ecs_cpu_int" -gt "$CPU_HIGH" ]]; then
                verdict "alert" "CPU avg ${ecs_cpu_avg}% — consider adding more CPU or tasks"
                findings_count=$((findings_count + 1))
            else
                verdict "ok" "CPU utilization is healthy"
            fi
        else
            verdict "info" "No CPU metrics available (service may be newly deployed)"
        fi

        # Memory utilization
        ecs_mem_json=$(get_metric "AWS/ECS" "MemoryUtilization" "Average" "ClusterName" "$cluster_name" "ServiceName" "$service_name")
        ecs_mem_avg=$(extract_stat "$ecs_mem_json" "Average")
        ecs_mem_max_json=$(get_metric "AWS/ECS" "MemoryUtilization" "Maximum" "ClusterName" "$cluster_name" "ServiceName" "$service_name")
        ecs_mem_max=$(extract_max "$ecs_mem_max_json" "Maximum")

        if [[ -n "$ecs_mem_avg" ]]; then
            used_mem_mb=$(echo "scale=0; $ecs_mem_avg * $mem / 100" | bc)
            print_bar "$ecs_mem_avg" 100 "Memory avg"
            printf "      %-22s %37s MB / %s MB\n" "" "${used_mem_mb}" "$mem"
            if [[ -n "$ecs_mem_max" ]]; then
                printf "      %-22s %44.1f%s\n" "Memory peak" "$ecs_mem_max" "%"
            fi
            ecs_mem_int=$(echo "$ecs_mem_avg" | cut -d'.' -f1)
            if [[ "$ecs_mem_int" -lt "$MEM_LOW" ]]; then
                verdict "warn" "Memory avg ${ecs_mem_avg}% — could reduce memory allocation"
                findings_count=$((findings_count + 1))
            elif [[ "$ecs_mem_int" -gt "$MEM_HIGH" ]]; then
                verdict "alert" "Memory avg ${ecs_mem_avg}% — consider increasing memory"
                findings_count=$((findings_count + 1))
            else
                verdict "ok" "Memory utilization is healthy"
            fi
        fi

        # Fargate rightsizing suggestion
        if [[ -n "$ecs_cpu_avg" && -n "$ecs_mem_avg" ]]; then
            ecs_cpu_int=$(echo "$ecs_cpu_avg" | cut -d'.' -f1)
            ecs_mem_int=$(echo "$ecs_mem_avg" | cut -d'.' -f1)
            ecs_cpu_peak_int=$(echo "${ecs_cpu_max:-0}" | cut -d'.' -f1)
            ecs_mem_peak_int=$(echo "${ecs_mem_max:-0}" | cut -d'.' -f1)

            if [[ "$ecs_cpu_int" -lt "$CPU_LOW" && "$ecs_mem_int" -lt "$MEM_LOW" && "$cpu" != "256" ]]; then
                # Suggest downsizing — find valid Fargate combo
                case "${cpu}" in
                    4096)  suggest="2048 CPU / $(echo "scale=0; $mem / 2" | bc) MB" ;;
                    2048)  suggest="1024 CPU / $(echo "scale=0; $mem / 2" | bc) MB" ;;
                    1024)  suggest="512 CPU / $(echo "scale=0; $mem / 2" | bc) MB" ;;
                    512)   suggest="256 CPU / 512 MB" ;;
                    *)     suggest="one size smaller" ;;
                esac
                new_cpu_vcpu=$(echo "scale=2; $cpu / 2 / 1024" | bc)
                new_mem_gb=$(echo "scale=2; $mem / 2 / 1024" | bc)
                new_cost=$(printf '%.2f' "$(echo "($new_cpu_vcpu * 0.04048 + $new_mem_gb * 0.004445) * 730 * $desired" | bc -l)")
                savings=$(printf '%.2f' "$(echo "$monthly_cost - $new_cost" | bc -l)")
                verdict "warn" "SUGGESTION: Downsize to $suggest (~\$${new_cost}/mo, save \$${savings}/mo)"
            elif [[ "$ecs_cpu_int" -lt "$CPU_LOW" && "$ecs_mem_int" -lt "$MEM_LOW" && "$cpu" == "256" ]]; then
                verdict "ok" "Already smallest Fargate size — no further downsizing"
            elif [[ "$ecs_cpu_peak_int" -gt 90 || "$ecs_mem_peak_int" -gt 90 ]]; then
                verdict "alert" "SUGGESTION: Peaks near limit — consider upsizing or adding tasks"
            fi
        fi
    done < <(jq -r '.[]' <<<"$services")
done < <(jq -r '.[]' <<<"$clusters")

echo ""

# ═════════════════════════════════════════════════════════════
# APPLICATION LOAD BALANCERS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  APPLICATION LOAD BALANCERS${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

albs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`]' --output json 2>/dev/null || echo '[]')
alb_count=$(echo "$albs" | jq 'length')

for i in $(seq 0 $((alb_count - 1))); do
    alb_name=$(echo "$albs" | jq -r ".[$i].LoadBalancerName")
    alb_arn=$(echo "$albs" | jq -r ".[$i].LoadBalancerArn")
    alb_arn_suffix=$(echo "$alb_arn" | sed 's|.*loadbalancer/||')

    echo ""
    echo -e "    ${BOLD}$alb_name${NC}"

    # Request count
    req_json=$(get_metric "AWS/ApplicationELB" "RequestCount" "Sum" "LoadBalancer" "$alb_arn_suffix")
    req_total=0
    req_points=$(datapoint_count "$req_json")
    if [[ "$req_points" -gt 0 ]]; then
        req_total=$(echo "$req_json" | jq '[.Datapoints[].Sum] | add // 0' 2>/dev/null)
        req_per_day=$(echo "scale=0; $req_total / $DAYS" | bc)
        req_per_min=$(echo "scale=1; $req_per_day / 1440" | bc)
        printf "      %-22s %30s total (%s/day, %s/min)\n" "Requests (${DAYS}d)" "$req_total" "$req_per_day" "$req_per_min"
    fi

    # 5xx errors
    err_json=$(get_metric "AWS/ApplicationELB" "HTTPCode_Target_5XX_Count" "Sum" "LoadBalancer" "$alb_arn_suffix")
    err_points=$(datapoint_count "$err_json")
    if [[ "$err_points" -gt 0 ]]; then
        err_total=$(echo "$err_json" | jq '[.Datapoints[].Sum] | add // 0' 2>/dev/null)
        if [[ $(echo "$err_total > 0" | bc) -eq 1 && $(echo "$req_total > 0" | bc) -eq 1 ]]; then
            err_pct=$(echo "scale=3; $err_total * 100 / $req_total" | bc)
            printf "      %-22s %30s (%.3f%%)\n" "5xx errors (${DAYS}d)" "$err_total" "$err_pct"
            err_check=$(echo "$err_pct > 1" | bc)
            if [[ "$err_check" -eq 1 ]]; then
                verdict "alert" "Error rate ${err_pct}% — investigate application health"
                findings_count=$((findings_count + 1))
            fi
        else
            printf "      %-22s %44s\n" "5xx errors (${DAYS}d)" "0"
        fi
    else
        printf "      %-22s %44s\n" "5xx errors (${DAYS}d)" "0"
    fi

    # Response time
    resp_json=$(get_metric "AWS/ApplicationELB" "TargetResponseTime" "Average" "LoadBalancer" "$alb_arn_suffix")
    resp_avg=$(extract_stat "$resp_json" "Average")
    resp_max_json=$(get_metric "AWS/ApplicationELB" "TargetResponseTime" "Maximum" "LoadBalancer" "$alb_arn_suffix")
    resp_max=$(extract_max "$resp_max_json" "Maximum")
    if [[ -n "$resp_avg" ]]; then
        resp_ms=$(printf "%.1f" "$(echo "$resp_avg * 1000" | bc)")
        resp_max_ms=$(printf "%.1f" "$(echo "${resp_max:-0} * 1000" | bc)")
        printf "      %-22s %38s ms avg, %s ms peak\n" "Response time" "$resp_ms" "$resp_max_ms"
        resp_check=$(echo "$resp_ms > 1000" | bc)
        if [[ "$resp_check" -eq 1 ]]; then
            verdict "alert" "Avg response time >1s — investigate performance"
            findings_count=$((findings_count + 1))
        fi
    fi

    # Active connections
    conn_json=$(get_metric "AWS/ApplicationELB" "ActiveConnectionCount" "Average" "LoadBalancer" "$alb_arn_suffix")
    conn_avg=$(extract_stat "$conn_json" "Average")
    if [[ -n "$conn_avg" ]]; then
        printf "      %-22s %40.1f avg\n" "Active connections" "$conn_avg"
    fi

    # Cost assessment
    req_total_int=$(echo "$req_total" | cut -d'.' -f1)
    if [[ "$req_total_int" -lt 1000 ]]; then
        verdict "warn" "Very low traffic ($req_total requests in ${DAYS}d) — ALB costs ~\$16/mo regardless"
        findings_count=$((findings_count + 1))
    elif [[ "$req_total_int" -lt 10000 ]]; then
        verdict "info" "Low traffic — ALB base cost dominates"
    else
        verdict "ok" "Traffic levels justify ALB"
    fi
done

echo ""

# ═════════════════════════════════════════════════════════════
# NAT GATEWAY
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  NAT GATEWAYS${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

nat_gws=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].{id:NatGatewayId,subnet:SubnetId,state:State}' --output json 2>/dev/null || echo '[]')
nat_count=$(echo "$nat_gws" | jq 'length')

if [[ "$nat_count" -eq 0 ]]; then
    echo -e "    ${DIM}No NAT gateways found${NC}"
else
    for i in $(seq 0 $((nat_count - 1))); do
        nat_id=$(echo "$nat_gws" | jq -r ".[$i].id")
        echo ""
        echo -e "    ${BOLD}$nat_id${NC}  ${DIM}(~\$32/mo base + \$0.045/GB)${NC}"

        # Bytes processed
        bytes_out_json=$(get_metric "AWS/NATGateway" "BytesOutToDestination" "Sum" "NatGatewayId" "$nat_id")
        bytes_in_json=$(get_metric "AWS/NATGateway" "BytesInFromDestination" "Sum" "NatGatewayId" "$nat_id")
        bytes_out=$(echo "$bytes_out_json" | jq '[.Datapoints[].Sum] | add // 0' 2>/dev/null)
        bytes_in=$(echo "$bytes_in_json" | jq '[.Datapoints[].Sum] | add // 0' 2>/dev/null)

        bytes_out_gb=$(echo "scale=2; $bytes_out / 1073741824" | bc)
        bytes_in_gb=$(echo "scale=2; $bytes_in / 1073741824" | bc)
        data_cost=$(echo "scale=2; ($bytes_out_gb + $bytes_in_gb) * 0.045" | bc)

        printf "      %-22s %38s GB out, %s GB in\n" "Data processed (${DAYS}d)" "$bytes_out_gb" "$bytes_in_gb"
        printf "      %-22s %43s\n" "Data cost (${DAYS}d)" "\$${data_cost}"

        # Active connections
        nat_conn_json=$(get_metric "AWS/NATGateway" "ActiveConnectionCount" "Average" "NatGatewayId" "$nat_id")
        nat_conn=$(extract_stat "$nat_conn_json" "Average")
        if [[ -n "$nat_conn" ]]; then
            printf "      %-22s %40.0f avg\n" "Active connections" "$nat_conn"
        fi

        total_gb=$(echo "scale=2; $bytes_out_gb + $bytes_in_gb" | bc)
        if [[ $(echo "$total_gb < 1" | bc) -eq 1 ]]; then
            verdict "warn" "Very low data transfer — NAT GW costs \$32/mo minimum"
            verdict "info" "Consider VPC endpoints for S3/DynamoDB to reduce NAT traffic"
            findings_count=$((findings_count + 1))
        fi
    done
fi

echo ""

# ═════════════════════════════════════════════════════════════
# EC2 INSTANCES (non-Fargate)
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  EC2 INSTANCES${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

ec2_instances=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].{id:InstanceId,type:InstanceType,state:State.Name,name:Tags[?Key==`Name`].Value|[0],launch:LaunchTime}' \
    --output json 2>/dev/null | jq 'flatten')
ec2_count=$(echo "$ec2_instances" | jq 'length')

if [[ "$ec2_count" -eq 0 ]]; then
    echo -e "    ${DIM}No EC2 instances found (good — using Fargate)${NC}"
else
    for i in $(seq 0 $((ec2_count - 1))); do
        ec2_id=$(echo "$ec2_instances" | jq -r ".[$i].id")
        ec2_type=$(echo "$ec2_instances" | jq -r ".[$i].type")
        ec2_state=$(echo "$ec2_instances" | jq -r ".[$i].state")
        ec2_name=$(echo "$ec2_instances" | jq -r ".[$i].name // \"(unnamed)\"")
        ec2_launch=$(echo "$ec2_instances" | jq -r ".[$i].launch")

        echo ""
        echo -e "    ${BOLD}$ec2_name${NC} ($ec2_id, $ec2_type, $ec2_state)"
        echo -e "    ${DIM}Launched: $ec2_launch${NC}"

        if [[ "$ec2_state" == "stopped" ]]; then
            verdict "warn" "Instance is stopped — still paying for EBS volumes"
            verdict "info" "Consider terminating if no longer needed"
            findings_count=$((findings_count + 1))
            continue
        fi

        ec2_cpu_json=$(get_metric "AWS/EC2" "CPUUtilization" "Average" "InstanceId" "$ec2_id")
        ec2_cpu_avg=$(extract_stat "$ec2_cpu_json" "Average")
        if [[ -n "$ec2_cpu_avg" ]]; then
            print_bar "$ec2_cpu_avg" 100 "CPU avg"
            ec2_cpu_int=$(echo "$ec2_cpu_avg" | cut -d'.' -f1)
            if [[ "$ec2_cpu_int" -lt "$CPU_LOW" ]]; then
                verdict "warn" "CPU avg ${ec2_cpu_avg}% — instance is under-utilized"
                findings_count=$((findings_count + 1))
            fi
        fi

        # Network
        net_in_json=$(get_metric "AWS/EC2" "NetworkIn" "Average" "InstanceId" "$ec2_id")
        net_out_json=$(get_metric "AWS/EC2" "NetworkOut" "Average" "InstanceId" "$ec2_id")
        net_in=$(extract_stat "$net_in_json" "Average")
        net_out=$(extract_stat "$net_out_json" "Average")
        if [[ -n "$net_in" && -n "$net_out" ]]; then
            net_in_kb=$(echo "scale=1; $net_in / 1024" | bc)
            net_out_kb=$(echo "scale=1; $net_out / 1024" | bc)
            printf "      %-22s %35s KB/s in, %s KB/s out\n" "Network (avg)" "$net_in_kb" "$net_out_kb"
        fi
    done
fi

echo ""

# ═════════════════════════════════════════════════════════════
# CLOUDWATCH LOG GROUPS
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}  CLOUDWATCH LOG GROUPS${NC}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"

log_groups=$(aws logs describe-log-groups --query 'logGroups[?storedBytes > `0`].{name:logGroupName,bytes:storedBytes,retention:retentionInDays}' --output json 2>/dev/null || echo '[]')
log_count=$(echo "$log_groups" | jq 'length')

if [[ "$log_count" -gt 0 ]]; then
    echo ""
    printf "    ${BOLD}%-50s %10s %10s${NC}\n" "Log Group" "Size" "Retention"
    echo -e "    ${DIM}$(printf '%*s' 70 '' | tr ' ' '─')${NC}"

    while IFS='|' read -r name bytes retention; do
        size_mb=$(echo "scale=1; $bytes / 1048576" | bc)
        if [[ $(echo "$size_mb > 1024" | bc) -eq 1 ]]; then
            size_display="$(echo "scale=1; $size_mb / 1024" | bc) GB"
        else
            size_display="${size_mb} MB"
        fi
        printf "    %-50s %10s %8s d\n" "$name" "$size_display" "$retention"
    done < <(echo "$log_groups" | jq -r 'sort_by(-.bytes) | .[] | "\(.name)|\(.bytes)|\(.retention // "never")"')

    total_bytes=$(echo "$log_groups" | jq '[.[].bytes] | add')
    total_mb=$(echo "scale=1; $total_bytes / 1048576" | bc)
    total_cost=$(echo "scale=2; $total_mb * 0.03 / 1024" | bc)
    echo ""
    printf "    %-50s %10s\n" "Total stored" "${total_mb} MB"
    printf "    %-50s %10s\n" "Storage cost" "~\$${total_cost}/mo"

    # Check for groups without retention
    no_retention=$(aws logs describe-log-groups --query 'logGroups[?!retentionInDays].logGroupName' --output json 2>/dev/null | jq 'length')
    if [[ "$no_retention" -gt 0 ]]; then
        verdict "warn" "$no_retention log groups have no retention policy (logs kept forever)"
        findings_count=$((findings_count + 1))
    fi
fi

echo ""

# ═════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
if [[ "$findings_count" -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}  No issues found — infrastructure looks well-sized!${NC}"
elif [[ "$findings_count" -lt 4 ]]; then
    echo -e "${BOLD}${YELLOW}  $findings_count findings — minor optimisation opportunities${NC}"
else
    echo -e "${BOLD}${RED}  $findings_count findings — review recommendations above${NC}"
fi
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
