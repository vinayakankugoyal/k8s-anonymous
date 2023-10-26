#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

function validate_bindings() {
    name=$1
    want_subjects=$2
    want_rules=$3

    binding=$(
        kubectl get clusterrolebinding $name -o json
    )

    binding_role=$(
        echo $binding | jq -c -r .roleRef.name
    )

    if [ "$binding_role" != "$name" ]; then
        echo $'\u274c' "clusterrolebinding $name has unexpected roleRef"
        echo "want: $name; got: $binding_role"
    fi

    binding_subjects=$(
        echo $binding | jq -c -r .subjects
    )

    if [ "$binding_subjects" != "$want_subjects" ]; then
        echo $'\u274c' "clusterrolebinding $name has unexpected subjects"
        echo "want: $want_subjects"
        echo "got: $binding_subjects"
    fi

    echo $'\u2714' "$name clusterrolebinding is valid"

    rules=$(
        kubectl get clusterrole $name -o json | jq -c -r .rules
    )

    if [ "$rules" != "$want_rules" ]; then
        echo $'\u274c' "clusterrole $name has unexpected rules"
        echo "want: $want_rules"
        echo "got: $rules"
    fi

    echo $'\u2714' "$name clusterrole is valid"
}

### Validate system:discovery
validate_bindings "system:discovery" \
    '[{"apiGroup":"rbac.authorization.k8s.io","kind":"Group","name":"system:authenticated"}]' \
    '[{"nonResourceURLs":["/api","/api/*","/apis","/apis/*","/healthz","/livez","/openapi","/openapi/*","/readyz","/version","/version/"],"verbs":["get"]}]'

### Validate system:basic-user.
version=$(kubectl version -o json | jq -r -c .serverVersion.minor)
if [ $version -lt 27 ]; then
    validate_bindings "system:basic-user" \
    '[{"apiGroup":"rbac.authorization.k8s.io","kind":"Group","name":"system:authenticated"}]' \
    '[{"apiGroups":["authorization.k8s.io"],"resources":["selfsubjectaccessreviews","selfsubjectrulesreviews"],"verbs":["create"]}]'
else
    validate_bindings "system:basic-user" \
    '[{"apiGroup":"rbac.authorization.k8s.io","kind":"Group","name":"system:authenticated"}]' \
    '[{"apiGroups":["authorization.k8s.io"],"resources":["selfsubjectaccessreviews","selfsubjectrulesreviews"],"verbs":["create"]},{"apiGroups":["authentication.k8s.io"],"resources":["selfsubjectreviews"],"verbs":["create"]}]'
fi

### Validate system:public-info-viewer.
validate_bindings "system:public-info-viewer" \
    '[{"apiGroup":"rbac.authorization.k8s.io","kind":"Group","name":"system:authenticated"},{"apiGroup":"rbac.authorization.k8s.io","kind":"Group","name":"system:unauthenticated"}]' \
    '[{"nonResourceURLs":["/healthz","/livez","/readyz","/version","/version/"],"verbs":["get"]}]'

### Validate that there are no other bindings with subjects as system:anonymous, system:unauthenticated and system:authenticated.
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
            echo $'\u274c' "found unexpected $kind $bad_binding_name in namespace $bad_binding_namespace"
        else
            echo $'\u274c' "found unexpected $kind $bad_binding_name"
        fi
    done
done