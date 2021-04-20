#!/bin/bash

BOOK_NS=booktest
# Responsible for injecting the istio annotation that opts in a DC for auto injection of the envoy sidecar
function injectAndResume() {

  echo -en "\n\nInjecting istio sidecar annotation into DC: $DC_NAME\n"

  # 1)  Add istio inject annotion into pod.spec.template
oc patch deploy $DC_NAME -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $BOOK_NS
  # 2)  Loop until envoy enabled pod starts up
  replicas=1
  readyReplicas=0 
  counter=1
  while (( $replicas != $readyReplicas && $counter != 20 ))
  do
    sleep 1 
    oc get deploy $DC_NAME -o json -n $BOOK_NS > /tmp/$DC_NAME.json
    replicas=$(cat /tmp/$DC_NAME.json | jq .status.replicas)
    readyReplicas=$(cat /tmp/$DC_NAME.json | jq .status.readyReplicas)
    echo -en "\n$counter    $DC_NAME    $replicas   $readyReplicas\n"
    let counter=counter+1
  done
}

# Enable ER-Demo DeploymentConfigs for Envoy auto-injection
for  DC_NAME in `oc get deploy  -o template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end }}' -n $BOOK_NS`
do
  injectAndResume
done


#add command based probes
#oc patch deploy ratings-v1 -n $BOOK_NS --type='json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/livenessProbe", "value": { "exec": { "command" : ["curl", "http://127.0.0.1:9080/health/ready"]}, "initialDelaySeconds": 20, "timeoutSeconds": 3, "periodSeconds": 30, "successThreshold": 1, "failureThreshold": 3}}, {"op": "add", "path": "/spec/template/spec/containers/0/readinessProbe", "value": { "exec": { "command" : ["curl", "http://127.0.0.1:9080/health/ready"]}, "initialDelaySeconds": 10, "timeoutSeconds": 3, "periodSeconds": 30, "successThreshold": 1, "failureThreshold": 3}}]'
