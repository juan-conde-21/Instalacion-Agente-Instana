#!/usr/bin/env bash
set -euo pipefail

API="/opt/instana-demo/instana-api"

usage() {
    echo
    echo "INSTANA RETAIL LAB - DEMO CONTROL"
    echo
    echo "Usage:"
    echo "  $0 status"
    echo "  $0 fault"
    echo "  $0 observe"
    echo "  $0 recover"
    echo "  $0 runbook"
    echo
}

ACTION="${1:-}"

case "${ACTION}" in

    status)
        exec "${API}/06-demo-status.sh"
        ;;

    fault)
        echo
        echo "========================================================"
        echo " INJECTING BUSINESS FAILURE"
        echo "========================================================"
        echo
        exec "${API}/07-demo-fault.sh"
        ;;

    observe)
        exec "${API}/08-demo-observe.sh"
        ;;

    recover)
        echo
        echo "========================================================"
        echo " RECOVERING BUSINESS FLOW"
        echo "========================================================"
        echo
        exec "${API}/09-demo-recover.sh"
        ;;

    runbook)
        exec "${API}/10-demo-runbook.sh"
        ;;

    *)
        usage
        exit 2
        ;;

esac
