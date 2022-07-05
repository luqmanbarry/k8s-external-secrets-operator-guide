#!/bin/bash

echo "Uninstallting eso-deployment-ressources chart..."
helm uninstall eso-deployment-resources
sleep 30

echo "Uninstallting eso-sync-ressources chart..."
helm uninstall eso-sync-resources
sleep 30

echo "Removing ESO the OperatorConfig..."
ESO_OPERATOR_CONFIGS=$(oc get operatorconfig -o name | grep eso)
if [ -z $ESO_OPERATOR_CONFIGS ];
then
    echo "No OperatorConfig found..."
else
    for ocg in $ESO_OPERATOR_CONFIGS; do oc delete $ocg; done;
fi
sleep 30

echo "Deleting the SecretStore(s)..."
for ss in $(oc get secretstore -o name); do oc delete $ss; done;

echo "Deleting the ExternalSecret(s)..."
for es in $(oc get externalsecret -o name); do oc delete $es; done;
sleep 30

echo "Deleting eso operator csv..."
oc delete $(oc get csv -o name | grep external-secrets-operator | cut -d' ' -f 1)
sleep 30

oc delete all -l app.kubernetes.io/instance=eso