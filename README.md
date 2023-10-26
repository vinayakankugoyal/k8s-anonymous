# audit_anonymous.sh

`audit_anonymous.sh` is a simple script to perform an audit of RBAC permissions
bound to `system:anonymous`, `system:authenticated` and
`system:unauthenticated`. Binding any roles to these users/groups other than
the default bindings that `kubernetes` creates can be very dangerous. Any 
non-standard bindings to these users/groups could indicate a compromise of your
cluster and you should delete such bindings.

You must have permissions that match the following ClusterRole to use this tool:
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: anonymous-auditor
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings", "rolebindings"]
  verbs: ["list"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  verbs: ["get"]
  resourceNames: ["system:discovery", "system:basic-user", "system:public-info-viewer"]
```

# cleanup_anonymous.sh
`cleanup_anonymous` is a simple script that deletes all non-standard bindings where
the subject is `system:anonymous` or `system:unauthenticated` or `system:authenticated`.

You must have permissions that match the following ClusterRole to use this tool:
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: anonymous-cleanup
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings", "rolebindings"]
  verbs: ["delete"]
```
