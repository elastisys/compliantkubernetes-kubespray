#!/bin/bash

if [[ -z "$CK8S_APPS_PIPELINE" ]]; then
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
echo -n "Testing if rook is ready up to 5 times..."
for i in {1..5}
  do
    echo -n " ${i}"
    failure=0
    if ! bash "${here}/../test-rook.sh" "$1" &> /dev/null; then
      failure=1
    fi
    # If no failures, we are ready to move on
    if [ ${failure} -eq 0 ]; then
      echo
      echo "Rook tests passed - running again to produce output"
      bash "${here}/../test-rook.sh" "$1"
      exit 0
    fi
    sleep 60
done
echo
echo "Rook test failed 5 times - running again to produce output"
bash "${here}/../test-rook.sh" "$1" --logging-enabled
exit 1
