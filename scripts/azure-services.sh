#!/usr/bin/env bash

set -Eeuo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-devops-project}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-urlshortener-pf9nt4-aks}"
POSTGRES_SERVER_NAME="${POSTGRES_SERVER_NAME:-urlshortener-pf9nt4-postgres}"
K8S_NAMESPACE="${K8S_NAMESPACE:-url-shortener}"
K8S_DEPLOYMENT="${K8S_DEPLOYMENT:-url-shortener}"
K8S_SERVICE="${K8S_SERVICE:-url-shortener}"

usage() {
    cat <<EOF
Usage: $0 <start|stop|status>

Controls the Azure services that are worth stopping for this deployment:
  - AKS cluster:              ${AKS_CLUSTER_NAME}
  - PostgreSQL flexible server: ${POSTGRES_SERVER_NAME}

Environment overrides:
  AZURE_RESOURCE_GROUP, AKS_CLUSTER_NAME, POSTGRES_SERVER_NAME,
  K8S_NAMESPACE, K8S_DEPLOYMENT, K8S_SERVICE
EOF
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command '$1' is not installed or not on PATH." >&2
        exit 1
    fi
}

ensure_azure_login() {
    if ! az account show >/dev/null 2>&1; then
        echo "Error: Azure CLI is not logged in. Run 'az login' first." >&2
        exit 1
    fi
}

postgres_state() {
    az postgres flexible-server show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --query state \
        --output tsv
}

aks_power_state() {
    az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --query powerState.code \
        --output tsv
}

wait_for_postgres() {
    local expected="$1"
    local state

    echo "Waiting for PostgreSQL to become ${expected}..."
    for _ in {1..60}; do
        state="$(postgres_state)"
        if [[ "$state" == "$expected" ]]; then
            echo "PostgreSQL is ${state}."
            return 0
        fi
        printf '  current state: %s\r' "$state"
        sleep 10
    done

    echo
    echo "Error: PostgreSQL did not reach '${expected}' in time." >&2
    exit 1
}

wait_for_aks() {
    local expected="$1"
    local state

    echo "Waiting for AKS to become ${expected}..."
    for _ in {1..60}; do
        state="$(aks_power_state)"
        if [[ "$state" == "$expected" ]]; then
            echo "AKS is ${state}."
            return 0
        fi
        printf '  current state: %s\r' "$state"
        sleep 10
    done

    echo
    echo "Error: AKS did not reach '${expected}' in time." >&2
    exit 1
}

start_services() {
    local pg_state aks_state

    pg_state="$(postgres_state)"
    if [[ "$pg_state" == "Ready" ]]; then
        echo "PostgreSQL is already Ready."
    else
        echo "Starting PostgreSQL flexible server ${POSTGRES_SERVER_NAME}..."
        az postgres flexible-server start \
            --resource-group "$RESOURCE_GROUP" \
            --name "$POSTGRES_SERVER_NAME" \
            --output none
        wait_for_postgres "Ready"
    fi

    aks_state="$(aks_power_state)"
    if [[ "$aks_state" == "Running" ]]; then
        echo "AKS is already Running."
    else
        echo "Starting AKS cluster ${AKS_CLUSTER_NAME}..."
        az aks start \
            --resource-group "$RESOURCE_GROUP" \
            --name "$AKS_CLUSTER_NAME" \
            --output none
        wait_for_aks "Running"
    fi

    if command -v kubectl >/dev/null 2>&1; then
        az aks get-credentials \
            --resource-group "$RESOURCE_GROUP" \
            --name "$AKS_CLUSTER_NAME" \
            --overwrite-existing \
            --output none

        echo "Kubernetes service status:"
        kubectl get deployment "$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" || true
        kubectl get service "$K8S_SERVICE" -n "$K8S_NAMESPACE" || true
    fi
}

stop_services() {
    local aks_state pg_state

    aks_state="$(aks_power_state)"
    if [[ "$aks_state" == "Stopped" ]]; then
        echo "AKS is already Stopped."
    else
        echo "Stopping AKS cluster ${AKS_CLUSTER_NAME}..."
        az aks stop \
            --resource-group "$RESOURCE_GROUP" \
            --name "$AKS_CLUSTER_NAME" \
            --output none
        wait_for_aks "Stopped"
    fi

    pg_state="$(postgres_state)"
    if [[ "$pg_state" == "Stopped" ]]; then
        echo "PostgreSQL is already Stopped."
    else
        echo "Stopping PostgreSQL flexible server ${POSTGRES_SERVER_NAME}..."
        az postgres flexible-server stop \
            --resource-group "$RESOURCE_GROUP" \
            --name "$POSTGRES_SERVER_NAME" \
            --output none
        wait_for_postgres "Stopped"
    fi
}

show_status() {
    echo "Azure status:"
    az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --query "{name:name,powerState:powerState.code,provisioningState:provisioningState,kubernetesVersion:kubernetesVersion}" \
        --output table

    az postgres flexible-server show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --query "{name:name,state:state,version:version,fqdn:fullyQualifiedDomainName}" \
        --output table

    if command -v kubectl >/dev/null 2>&1 && [[ "$(aks_power_state)" == "Running" ]]; then
        echo
        echo "Kubernetes status:"
        kubectl get pods,service -n "$K8S_NAMESPACE" || true
    fi
}

main() {
    if [[ $# -ne 1 ]]; then
        usage
        exit 1
    fi

    require_command az
    ensure_azure_login

    case "$1" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        status)
            show_status
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
