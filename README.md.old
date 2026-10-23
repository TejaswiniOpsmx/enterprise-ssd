
# OpsMx Secure Software Delivery (SSD)
For more information, visit https://www.opsmx.com

## Installation Instructions
SSD can be installed in the following ways, depending on your requirements.

### Look and See (in testing)
- __[Argo Application](argo-install/README.md):__: If argoCD is already installed, we can simply install the SSD Application in "argo-install" folder above.

We can install SSD on a laptop with minikube, k3s, Docker Desktop, Rancher Desktop,etc.
The instructions for doing this as are follows:
- ```kubectl create ns try-ssd```
- ```kubectl -n try-ssd apply -f https://raw.githubusercontent.com/ksrinimba/testing/main/try-ssd.yaml```
- ```kubectl -n try-ssd port-forward svc/oes-ui 8080```
- Go to your browser, http://localhost:8080
- Get the password for logging in: user: admin, the password is in the secret **poc-passwords** in the try-ssd namespace: 
  ```kubectl get secret -n argocd-ssd poc-passwords -o jsonpath="{.data.ADMIN_PASSWORD}" | base64 -d```
- if you have argocd installed locally, configure it using instructions **here**.

### Poc install
The same instructios above can be used for POC as well. If we need to integrate with an SSO, we will need URLs, so access to a DNS and ingress/LB is required.
- This is a helm based installation where we start with a minimal*values.yaml based on your requirements
- If integration with an SSO is not required, choose minimal-poc-values.yaml
- If integrating with SAML, choose minimal-saml-values.yaml
- For all other SSOs, choose minimal-dex-values.yaml. We will need to configure the [dex connector](https://dexidp.io/docs/connectors/) based on your backend (e.g. google auth, AWS, etc.)
- Edit as required w.r.t. the URL, ingress, etc. Comments are in the file.
- execute:
  ```
  kubectl create ns poc-ssd
  helm install <chart-name> ssd -f modified-minimal-*-values.yaml -n poc-ssd
  ```
- Navigate to <your base URL>/diagnostics to see the configuration, status and resolve any issues

### Production install
In addition to the Poc Install instructions, this requires that we install the product in HA, have external storage and redis. See instructions **here**.


## Monitor the installation process
- Wait for all pods to stabilize (about 2- min, depending on your cluster load). Check status using:

    ```console
    $ kubectl -n try-ssd get po -w
    ```

## Check the installation
1. Access SSD using the URL specified during the installation (or localhost:8080) in a browser such as Chrome.
2. Navigate to the the **SSD-URL**/diagnostics

## Use below document to Integrate Spinnaker with SSD

 https://docs.google.com/document/d/1T8mJgymIv3z5EI_ZtsqrguqLGBDygTwbp-emZ-Vq020/edit

## Use below document to Integrate Argo with SSD

 https://docs.google.com/document/d/1-p8TkyziN-vvG5skmMMoegnlvwIi9Q2Uc6IzDdOfD3E/edit
