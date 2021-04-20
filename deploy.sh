#!/bin/bash
BOOK_NS=bookinfo
ISTIO_SYSTEM_NS=bookretail-istio-system
SUB_DOMAIN="cluster-8a4c.8a4c.sandbox1190.opentlc.com"
echo "Creating bookinfo project and installing app"
oc new-project bookinfo
oc apply -f https://raw.githubusercontent.com/istio/istio/1.6.0/samples/bookinfo/platform/kube/bookinfo.yaml -n ${BOOK_NS}
oc expose service productpage
echo -en "\n$(oc get route productpage --template '{{ .spec.host }}')\n"


echo -en "\n installing operators required for service mesh"
oc apply -f elasticoperator.yaml
while ! oc get ClusterServiceVersion | grep -i elastic | grep Succeeded  ; do echo "waiting for elastic operator install"; sleep 5; done
oc apply -f jaegeroperator.yaml
while ! oc get ClusterServiceVersion | grep -i jaeger | grep Succeeded  ; do echo "waiting for jaeger operator install";sleep 5; done
oc apply -f kialioperator.yaml
while ! oc get ClusterServiceVersion | grep -i kiali | grep Succeeded ; do echo "waiting for kiali operator install";sleep 5; done
oc apply -f servicemeshoperator.yaml 
while ! oc get ClusterServiceVersion | grep -i servicemeshoperator | grep Succeeded ; do echo "waiting for isito operator install";sleep 5; done

oc new-project bookretail-istio-system

oc apply -f servicemeshcp.yaml

for i in grafana istiod istio-ingressgateway istio-egressgateway jaeger kiali prometheus; do while [[ $(oc get pods -l app=$i -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for $i pods" && sleep 1; done;done

oc apply -f servicemeshmemberroll.yaml -n ${ISTIO_SYSTEM_NS}

# Responsible for injecting the istio annotation that opts in a DC for auto injection of the envoy sidecar
function injectAndResume() {

  echo -en "\n\nInjecting istio sidecar annotation into DC: $DC_NAME\n"

  # 1)  Add istio inject annotion into pod.spec.template
oc patch deploy $DC_NAME -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n ${BOOK_NS}
  # 2)  Loop until envoy enabled pod starts up
  replicas=1
  readyReplicas=0 
  counter=1
  while (( $replicas != $readyReplicas && $counter != 20 ))
  do
    sleep 1 
    oc get deploy $DC_NAME -o json -n ${BOOK_NS} > /tmp/$DC_NAME.json
    replicas=$(cat /tmp/$DC_NAME.json | jq .status.replicas)
    readyReplicas=$(cat /tmp/$DC_NAME.json | jq .status.readyReplicas)
    echo -en "\n$counter    $DC_NAME    $replicas   $readyReplicas\n"
    let counter=counter+1
  done
}

# Enable bookinfo  Deployments for Envoy auto-injection
for  DC_NAME in `oc get deploy  -o template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end }}' -n ${BOOK_NS}`
do
  injectAndResume
done

for i in `oc get pods -n ${BOOK_NS}  -o custom-columns=POD:.metadata.name --no-headers`; do oc get pod $i -o jsonpath='{.spec.containers[*].name}' -n ${BOOK_NS};echo -en "\n"; done

#add command based probes
oc patch deploy ratings-v1 -n ${BOOK_NS} --type='json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/livenessProbe", "value": { "exec": { "command" : ["curl", "http://127.0.0.1:9080/health/ready"]}, "initialDelaySeconds": 20, "timeoutSeconds": 3, "periodSeconds": 30, "successThreshold": 1, "failureThreshold": 3}}, {"op": "add", "path": "/spec/template/spec/containers/0/readinessProbe", "value": { "exec": { "command" : ["curl", "http://127.0.0.1:9080/health/ready"]}, "initialDelaySeconds": 10, "timeoutSeconds": 3, "periodSeconds": 30, "successThreshold": 1, "failureThreshold": 3}}]'


oc apply -f peerauthpolicy.yaml -n ${BOOK_NS}

oc create -f product-service-client-mtls-destinationrule.yml -n ${BOOK_NS}

openssl req -x509 -config productpage-cert.cfg -extensions req_ext -nodes -days 730 -newkey rsa:2048 -sha256 -keyout productpage-tls.key -out productpage-tls.crt

oc create secret tls product-page-certs --cert productpage-tls.crt --key productpage-tls.key -n ${ISTIO_SYSTEM_NS}

oc apply -f productpage-gateway.yml -n ${ISTIO_SYSTEM_NS}

oc apply -f productpage-virtualservice.yml -n ${BOOK_NS}

oc apply -f details-service-client-mtls-destinationrule.yml -n ${BOOK_NS}

oc apply -f reviews-service-client-mtls-destinationrule.yml -n ${BOOK_NS}

oc apply -f ratings-service-client-mtls-destinationrule.yml -n ${BOOK_NS}

#oc apply -f productpage-route.yml -n ${ISTIO_SYSTEM_NS}

oc get routes -n ${ISTIO_SYSTEM_NS} | grep -i productpage

curl -k -s  https://productpage.apps.cluster-e3f1.e3f1.sandbox37.opentlc.com/productpage | grep "<title>Simple Bookstore App</title>"