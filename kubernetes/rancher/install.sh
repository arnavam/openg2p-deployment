#!/usr/bin/env bash

export RANCHER_HOSTNAME=${RANCHER_HOSTNAME:-rancher.openg2p.net}
export RANCHER_ISTIO_GATEWAY=${RANCHER_ISTIO_GATEWAY:-true}
export RANCHER_ISTIO_VIRTUALSERVICE=${RANCHER_ISTIO_VIRTUALSERVICE:-true}
export RANCHER_GATEWAY_NAME=${RANCHER_GATEWAY_NAME:-rancher}
# Set to an Ingress class (e.g. apisix) to publish Rancher with the chart's own Ingress through
# that controller, instead of the Istio Gateway and VirtualService below.
export RANCHER_INGRESS_CLASS=${RANCHER_INGRESS_CLASS:-}
export TLS=${TLS:-false}
export NS=${NS:-cattle-system}

kubectl create ns $NS

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

if [[ -n "$RANCHER_INGRESS_CLASS" ]]; then
    # The chart's Ingress terminates TLS with a cert-manager Issuer and sends plain HTTP to rancher:80.
    # The APISIX Ingress Controller needs the websocket annotation for the Rancher UI and its agents.
    helm -n $NS upgrade --install rancher rancher-stable/rancher \
        --set hostname=$RANCHER_HOSTNAME \
        --set ingress.ingressClassName=$RANCHER_INGRESS_CLASS \
        --set-string 'ingress.extraAnnotations.k8s\.apisix\.apache\.org/enable-websocket=true' \
        $@
    exit $?
fi

helm -n $NS upgrade --install rancher rancher-stable/rancher \
    --set ingress.enabled=false \
    --set tls=external \
    $@

if [[ "$RANCHER_ISTIO_GATEWAY" == "true" ]]; then
    if [[ "$TLS" == "true" ]]; then
        envsubst < istio-gateway-tls.template.yaml | kubectl -n $NS apply -f -
    else
        envsubst < istio-gateway.template.yaml | kubectl -n $NS apply -f -
    fi
fi

if [[ "$RANCHER_ISTIO_VIRTUALSERVICE" == "true" ]]; then
    envsubst < istio-virtualservice.template.yaml | kubectl -n $NS apply -f -
fi
