#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== NotchBlock Test Suite ==="
t=0; p=0
for f in TimeBlockTests.swift StatisticsTests.swift PetStateTests.swift PetProtocolTests.swift PetConfigTests.swift PetPreferencesTests.swift; do
  echo "--- $f ---"
  swift "$f" 2>&1 && p=$((p+1))
  t=$((t+1)); echo ""
done
echo "=== $p/$t test suites passed ==="
exit $((t - p))
