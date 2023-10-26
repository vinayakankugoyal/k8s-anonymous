#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

### Delete non-standard bindings with subjects as system:anonymous, system:unauthenticated and system:authenticated.
for kind in "clusterrolebindings" "rolebindings"; do
    bad=$(
        kubectl get $kind -A -o json \
        | jq -c '.items[] | select((.subjects | length) > 0) | select(any(.subjects[]; .name == "system:anonymous" or .name == "system:unauthenticated" or .name == "system:authenticated"))' \
        | jq -c 'select(.metadata.name != "system:discovery" and .metadata.name != "system:basic-user" and .metadata.name != "system:public-info-viewer")'
    )
    for bad_binding in $(echo $bad | jq -c -r .metadata); do
        bad_binding_name=$(echo $bad_binding | jq -r -c .name)
        if [ "$kind" == "rolebindings" ]; then
            bad_binding_namespace=$(echo $bad_binding | jq -r -c .namespace)
            echo "deleting rolebinding $bad_binding_name in namespace $bad_binding_namespace"
            kubectl delete rolebinding $bad_binding_name -n $bad_binding_namespace
        else
            echo "deleting clusterrolebinding $bad_binding"
            kubectl delete clusterrolebinding $bad_binding
        fi
    done
done