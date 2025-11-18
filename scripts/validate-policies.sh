#!/bin/bash

set -e

echo "=========================================="
echo "Network Policies Validation Script"
echo "=========================================="
echo ""

echo "Retrieving pod names..."
UI_POD=$(kubectl get pods -n presentation -l component=ui -o jsonpath='{.items[0].metadata.name}')
API_POD=$(kubectl get pods -n business -l component=api -o jsonpath='{.items[0].metadata.name}')
DB_POD=$(kubectl get pods -n persistence -l component=database -o jsonpath='{.items[0].metadata.name}')

echo "UI Pod:       $UI_POD"
echo "API Pod:      $API_POD"
echo "Database Pod: $DB_POD"
echo ""

ALLOWED_PASSED=0
ALLOWED_FAILED=0
BLOCKED_PASSED=0
BLOCKED_FAILED=0

echo "=========================================="
echo "PART 1: Allowed Traffic (Should Succeed)"
echo "=========================================="
echo ""

echo "Test 1.1: UI -> API (presentation -> business)"
echo "Testing connection from $UI_POD to api-service.business:8080..."
if kubectl exec -n presentation $UI_POD -- nc -z -w 3 api-service.business 8080 > /dev/null 2>&1; then
    echo "Result: SUCCESS - Connection allowed"
    ALLOWED_PASSED=$((ALLOWED_PASSED + 1))
else
    echo "Result: FAILED - Connection blocked (unexpected)"
    ALLOWED_FAILED=$((ALLOWED_FAILED + 1))
fi
echo ""

echo "Test 1.2: API -> Database (business -> persistence)"
echo "Testing connection from $API_POD to database-service.persistence:5432..."
if kubectl exec -n business $API_POD -- nc -z -w 3 database-service.persistence 5432 > /dev/null 2>&1; then
    echo "Result: SUCCESS - Connection allowed"
    ALLOWED_PASSED=$((ALLOWED_PASSED + 1))
else
    echo "Result: FAILED - Connection blocked (unexpected)"
    ALLOWED_FAILED=$((ALLOWED_FAILED + 1))
fi
echo ""

echo "=========================================="
echo "PART 2: Blocked Traffic (Should Fail)"
echo "=========================================="
echo ""

echo "Test 2.1: Database -> API (reverse flow violation)"
echo "Testing connection from $DB_POD to api-service.business:8080..."
if kubectl exec -n persistence $DB_POD -- nc -z -w 3 api-service.business 8080 > /dev/null 2>&1; then
    echo "Result: FAILED - Connection allowed (security violation)"
    BLOCKED_FAILED=$((BLOCKED_FAILED + 1))
else
    echo "Result: SUCCESS - Connection blocked correctly"
    BLOCKED_PASSED=$((BLOCKED_PASSED + 1))
fi
echo ""

echo "Test 2.2: UI -> Database (layer jumping violation)"
echo "Testing connection from $UI_POD to database-service.persistence:5432..."
if kubectl exec -n presentation $UI_POD -- nc -z -w 3 database-service.persistence 5432 > /dev/null 2>&1; then
    echo "Result: FAILED - Connection allowed (security violation)"
    BLOCKED_FAILED=$((BLOCKED_FAILED + 1))
else
    echo "Result: SUCCESS - Connection blocked correctly"
    BLOCKED_PASSED=$((BLOCKED_PASSED + 1))
fi
echo ""

echo "Test 2.3: API -> UI (reverse flow violation)"
echo "Testing connection from $API_POD to ui-service.presentation:80..."
if kubectl exec -n business $API_POD -- nc -z -w 3 ui-service.presentation 80 > /dev/null 2>&1; then
    echo "Result: FAILED - Connection allowed (security violation)"
    BLOCKED_FAILED=$((BLOCKED_FAILED + 1))
else
    echo "Result: SUCCESS - Connection blocked correctly"
    BLOCKED_PASSED=$((BLOCKED_PASSED + 1))
fi
echo ""

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""
echo "Allowed Traffic Tests:"
echo "  Passed: $ALLOWED_PASSED/2"
echo "  Failed: $ALLOWED_FAILED/2"
echo ""
echo "Blocked Traffic Tests:"
echo "  Passed: $BLOCKED_PASSED/3"
echo "  Failed: $BLOCKED_FAILED/3"
echo ""

TOTAL_PASSED=$((ALLOWED_PASSED + BLOCKED_PASSED))
TOTAL_TESTS=$((ALLOWED_PASSED + ALLOWED_FAILED + BLOCKED_PASSED + BLOCKED_FAILED))

if [ $TOTAL_PASSED -eq $TOTAL_TESTS ]; then
    echo "Overall Result: ALL TESTS PASSED ($TOTAL_PASSED/$TOTAL_TESTS)"
    echo "Network policies are correctly configured."
    exit 0
else
    echo "Overall Result: SOME TESTS FAILED ($TOTAL_PASSED/$TOTAL_TESTS)"
    echo "Please review network policy configuration."
    exit 1
fi
