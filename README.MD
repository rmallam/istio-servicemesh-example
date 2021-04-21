Scripts to install ISTIO and demo bookinfo application on OpenShift

The folder containers two shell scripts
1. Deploy.sh - This will create all the required resources for the lab
2. uninstall.sh - This will clean the environment by deleting all the resources

**Resources that will get installed**
1. Bookinfo application in bookinfo namepsace
2. Install required operators 
    1. ServiceMesh Operator
    2. ElasticSearch Operator
    3. Jaeger Operator 
    4. Kiali Operator
3. Configure service mesh control plane in a different namespace to manage bookinfo application
4. Update bookinfo application to include service mesh components.

Note: Deploy.sh will work only when run on a clean environment.
