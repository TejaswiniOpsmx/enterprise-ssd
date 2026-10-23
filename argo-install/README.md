Instructions for installing SSD in an Argo Cluster

- copy the ssd-app.yaml to your local machine
- create repo in Argo: Settings-> Repositories->Connect Repo: Add ```https://github.com/ksrinimba/enterprise-ssd```
- create SSD application from the terminal: ```kubectl apply -n argocd -f ssd-app.yaml```
- in Arog UI: click sync

Access SSD: 
- Get the admin password: ```kubectl get secret -n argocd-ssd poc-passwords -o jsonpath="{.data.ADMIN_PASSWORD}" | base64 -d``` , #copy the password 
- Port forward: ```kubectl port-forward -n argocd-ssd svc/oes-ui 8080```
- In the browser, navigate to [http://localhost:8080](http://localhost:8080)
- username: admin , password: PASTE-THE_PASSWORD-FROM ABOVE


[http://localhost:8080/help](http://localhost:8080/help) provides instructions for further configuration and integration.

__Ingress__ : We can also create an ingress for SSD. Sample nginx Ingress Yamls are in this directory.
