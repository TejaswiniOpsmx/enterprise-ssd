<p align="center">
	<img src="https://github.com/OpsMx/enterprise-argo/blob/main/img/opsmx.png" width="20%" align="center" alt="OpsMx">
</p>

# OpsMx Secure Software Delivery
For more information, visit https://www.opsmx.com

## Setup Instructions

### Prerequisites

- Kubernetes cluster 1.20 or later with at least 4 cores and 16 GB memory
- Helm 3 is setup on the client system with 3.10.3 or later.
- Kubernetes cluster should support persistent volumes.
- Ensure that this URL(SSD) is reachable from your browser. Either DNS name server record must exist or "hosts" file must be updated.The following URL need to be exist in DNS and point to Loadbalancer IP of the nginx ingress controller.

  ```console
  Ip-address SSD.REPLACE.THIS.WITH.YOURCOMPANY.COM
  ```
  `E.g.: ssd.opsmx.com`
- Use below command to check if helm is installed or not

   ```console
   helm version
   ```
  If helm is not setup, follow <https://helm.sh/docs/intro/install/> to install helm.

### Installation Instructions

- Clone the repo enterprise-ssd repo

   ```console
   git clone https://github.com/OpsMx/enterprise-ssd.git
   ```
- Add opsmx helm repo to your local machine

   ```console
   helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
   ```
  **Note**: If opsmx-ssd helm repo is already added, do a repo update before installing the chart

   ```console
   helm repo update
   ```
- It is assumed that an nginx ingress controller is installed on the cluster, by default ingress resources are created for ssd-ui. Customize the hosts for various installations using the options in the ssd-minimal-values.yaml under ssdUI. If any other ingress controller is installed, set createIngress flag to false and configure your ingress.

  Instructions to install nginx ingress
  https://kubernetes.github.io/ingress-nginx/deploy/

  Instructions to install cert-manager
  https://cert-manager.io/docs/installation/kubernetes/

- Helm v3 expects the namespace to be present before helm install command is run. If it does not exists,

  ```console
  kubectl create namespace opsmx-ssd
  ```
- There are different flavours of Installations

    Values yamls    | Description
  --------------| -----------
  ssd-minimal-values.yaml | This file is used for Installing SSD with default Authentication
  ssd-saml-values.yaml | This file is used for Installing SSD with Saml Authentication
  ssd-local-values.yaml | This file is used for Installing SSD without Ingress

- cd to the enterprise-ssd

  ```console
  cd enterprise-ssd/charts/ssd
  ```

- Update only the host value in the ssd-minimal-values.yaml and namespace value under the kubedetector section(If the namespace value is updated the data will be displayed in SSD).

  **NOTE**: Please read the inline comments of ssd-minimal-values.yaml.

- Install SSD by executing this command:

   ```console
   helm install ssd opsmxssd/ssd -f ssd-minimal-values.yaml -n opsmx-ssd --timeout=600s
   ```

## Monitor the installation process
- Wait for all pods to stabilize (about 2-3 min, depending on your cluster load). The "setup-job" in Completed status indicates completion of the installation process. Check status using:

    ```console
    $ kubectl -n opsmx-ssd get pods
    ```

## Check the installation

- Get the SSD URL using the below command and Access in a browser such as Chrome.

  ```console
   kubectl -n opsmx-ssd get ingress
  ````

- Fetch the SSD password from the Secret using the below command and Login to SSD

  ```console
  kubectl -n opsmx-ssd get secret ssd-initial-password -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
  ````
- After logging into the SSD the wait for 5m .. So the data will be populated.

## TroubleShooting

- TODO

## Use below document to Integrate Spinnaker with SSD

 https://docs.google.com/document/d/1T8mJgymIv3z5EI_ZtsqrguqLGBDygTwbp-emZ-Vq020/edit

## Use below document to Integrate Argo with SSD

 https://docs.google.com/document/d/1-p8TkyziN-vvG5skmMMoegnlvwIi9Q2Uc6IzDdOfD3E/edit

 TODO: Update this one.
