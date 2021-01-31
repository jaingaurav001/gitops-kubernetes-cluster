.PHONY: up

up:
	kind create cluster --config=resources/cluster.yaml

install: install-argocd check-argocd-ready get-argocd-password install-cert-manager install-certs install-ingress-nginx install-argocd-ingress install-kibana-ingress install-elasticsearch-ingress install-grafana-ingress

install-argocd:
	kubectl create ns argocd || true
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f resources/application-bootstrap.yaml -n argocd

check-argocd-ready:
	kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=argocd-server" -n argocd --timeout=300s

get-argocd-password:
	kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2

set-argocd-password:
	kubectl -n argocd patch secret argocd-secret -p '{"stringData": { "admin.password": "$2y$12$Kg4H0rLL/RVrWUVhj6ykeO3Ei/YqbGaqp.jAtzzUSJdYWT6LUh/n6", "admin.passwordMtime": "'$(date +%FT%T%Z)'" }}'

install-cert-manager:
	helm repo add jetstack https://charts.jetstack.io
	kubectl create namespace cert-manager
	kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.2/cert-manager.crds.yaml
	helm install cert-manager --namespace cert-manager --version v1.0.2 jetstack/cert-manager

install-certs:
	kubectl rollout status deployment cert-manager-webhook -n cert-manager -w
	kubectl apply -f resources/issuer.yaml -n kube-system
	kubectl apply -f resources/local-certificate.yaml -n kube-system

install-ingress-nginx:
	kubectl create namespace ingress-nginx
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx -w

install-argocd-ingress:
	kubectl create -f resources/argocd-ingress.yaml -n argocd
	kubectl patch deployment argocd-server --type json -p='[ { "op": "replace", "path":"/spec/template/spec/containers/0/command","value": ["argocd-server","--staticassets","/shared/app","--insecure"] }]' -n argocd

install-kibana-ingress:
	kubectl create -f resources/kibana-ingress.yaml -n elastic

install-elasticsearch-ingress:
	kubectl create -f resources/elasticsearch-ingress.yaml -n elastic

install-grafana-ingress:
	kubectl create -f resources/grafana-ingress.yaml -n monitoring

get-grafana-password:
	kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" -n monitoring | base64 --decode ; echo

down:
	kind delete cluster
