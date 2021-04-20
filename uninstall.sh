#!/bin/bash
BOOK_NS=bookinfo
ISTIO_SYSTEM_NS=bookretail-istio-system

oc delete subscription elasticsearch-operator jaeger-product kiali-ossm   servicemeshoperator -n openshift-operators

oc delete clusterserviceversion kiali-operator.v1.24.5 jaeger-operator.v1.17.8 elasticsearch-operator.4.5.0-202103270246.p0 servicemeshoperator.v2.0.2  -n openshift-operators

oc delete project ${BOOK_NS}

oc delete project ${ISTIO_SYSTEM_NS}

