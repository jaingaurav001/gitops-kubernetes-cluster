.PHONY: up

up:
	kind create cluster --config=resources/cluster.yaml

install: install-argocd get-argocd-password check-argocd-ready install-cert-manager install-certs install-ingress-nginx install-argocd-ingress install-grafana-ingress get-grafana-password

install-argocd:
	kubectl create ns argocd || true
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f resources/application-bootstrap.yaml -n argocd

get-argocd-password:
	kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2

check-argocd-ready:
	kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=argocd-server" -n argocd --timeout=300s

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
	kubectl apply -f resources/ingress.yaml -n kube-system

install-argocd-ingress:
	kubectl create -f resources/argocd-ingress.yaml -n argocd
	kubectl patch deployment argocd-server --type json -p='[ { "op": "replace", "path":"/spec/template/spec/containers/0/command","value": ["argocd-server","--staticassets","/shared/app","--insecure"] }]' -n argocd

install-grafana-ingress:
	kubectl create -f resources/grafana-ingress.yaml -n monitoring

install-elasticsearch-ingress:
	kubectl create -f resources/elasticsearch-ingress.yaml -n elastic

install-kibana-ingress:
	kubectl create -f resources/kibana-ingress.yaml -n elastic

get-grafana-password:
	kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" -n monitoring | base64 --decode ; echo

down:
	kind delete cluster
