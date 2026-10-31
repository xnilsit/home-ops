# vim: ft=zsh
# paseo-read only grants get/list/watch without Secrets, so the edit, delete,
# exec and secret aliases fail with Forbidden, as do the helm ones, since helm
# keeps its releases in Secrets.

# kn/kcn rewrite the current context, which in-cluster config does not have.
# This kubeconfig is the same ServiceAccount, as a context that can be edited.
() {
  local sa=/var/run/secrets/kubernetes.io/serviceaccount
  [[ -z $KUBECONFIG && ! -e $HOME/.kube/config && -r $sa/token && -n $KUBERNETES_SERVICE_HOST ]] || return 0
  local host=$KUBERNETES_SERVICE_HOST
  [[ $host == *:* ]] && host="[$host]"
  {
    kubectl config set-cluster in-cluster --server="https://${host}:${KUBERNETES_SERVICE_PORT:-443}" --certificate-authority=$sa/ca.crt
    kubectl config set users.paseo.tokenFile $sa/token
    kubectl config set-context in-cluster --cluster=in-cluster --user=paseo --namespace="$(<$sa/namespace)"
    kubectl config use-context in-cluster
  } >/dev/null
}

# helm
alias hg='helm get'
alias hgv='hg values'
alias hgh='hg hooks'
alias hgm='hg manifest'
alias hgn='hg notes'
alias hga='hg all'
alias hr='helm repo'
alias hra='helm repo add'
alias hru='helm repo update'
alias hi='helm install --upgrade'
alias hup='helm upgrade'
alias hun='helm uninstall'
alias hl='helm list'
alias hlan='helm list --all-namespaces'

# flux
alias fl='flux'
alias flli='fl list'
alias fllo='fl logs'
alias fllof='fllog --f'
alias fld='fl delete'
alias fldk='fld kustomization'
alias fldh='fld helmrelease'
alias flg='fl get'
alias flgh='flg helmreleases'
alias flghall='flgh --all-namespaces'
alias flgs='flg sources'
alias flgk='flg kustomizations'
alias flgkall='flgk --all-namespaces'
alias flgkallc='flgkall --controller'
alias flr='fl reconcile'
alias flrk='flr kustomization'

alias k='kubectl'
alias kt='k top'
alias ktp='kt pod'
alias ktpa='kt pod --all-namespaces'
alias ktn='kt node'
alias ktm='ktn -l node-role.kubernetes.io/control-plane='
alias kdelfinalizers='kubectl patch -p "{\"metadata\":{\"finalizers\":null}}" --type=merge'
alias kdelfin='kdelfinalizers'

function kn(){
  kubectl config set-context --current --namespace=$1
}

# exec
alias kexec='k exec -it'
kexecbash(){
  k exec -it $1 -- bash
}

kcn(){
  kubectl config set-context --current --namespace=$1
}

alias kcnd='kcn default'
alias ke='k edit'
alias kej='ke jobs'
alias kede='ke deployments'
alias keda='ke daemonsets'
alias kest='ke statefulsets'
alias kei='ke ingress'
alias kepvc='ke pvc'
alias ken='ke nodes'
alias kec='ke certificate'
alias key='ke -o yaml'
alias kep='ke pods'
alias kes='ke secrets'
alias kesvc='ke service'

alias kg='k get'
alias kr='k rollout'
alias krr='kr restart'
alias krrd='krr deployment'
alias krrs='krr statefulset'
alias krrj='krr job'
alias krp='kr pause'
alias krc='kr resume'
alias krs='kr status'
alias kga='kg --all-namespaces'
alias kgall='kg all'
alias kgj='kg jobs'
alias kgde='kg deployments'
alias kgda='kg daemonsets'
alias kgst='kg statefulsets'
alias kgi='kg ingress'
alias kgiy='kgi -o yaml'
alias kgpvc='kg pvc'
alias kgpv='kg pv'
alias kgn='kg nodes -o wide'
alias kgno='kgn'
alias kgna='kg namespaces'
alias kgns='kgna'
alias kgnm='kgn -l node-role.kubernetes.io/control-plane'
alias kgncp='kgnm'
alias kgnn='kgn -l node-role.kubernetes.io/node'
alias kgc='kg configmap'
alias kgcy='kgc -o yaml'
alias kgce='kg certificate'
alias kgcey='kg certificate -o yaml'
alias kgy='kg -o yaml'
alias kgp='kg pods -o wide'
alias kgpa='kgp --all-namespaces'
alias kgpy='kgp -o yaml'
alias kgs='kg secrets'
alias kgsvc='kg service'
alias kgsvcy='kg service -o yaml'
alias kgsy='kg secrets -o yaml'
alias kgsj='kg secrets -o json'

kgspw(){
    kg secret $1 -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
}

alias kdrain='k drain --delete-emptydir-data --ignore-daemonsets'

alias kdes='k describe'
alias kdesde='kdes deployments'
alias kdesda='kdes daemonsets'
alias kdesst='kdes statefulsets'
alias kdessvc='kdes service'
alias kdesj='kdes jobs'
alias kdesi='kdes ingress'
alias kdesn='kdes nodes'
alias kdesp='kdes pods'
alias kdespods='kdesp'
alias kdespvc='kdes pvc'

alias kdel='kubectl delete'
alias kdelde='kdel deployments'
alias kdelda='kdel daemonsets'
alias kdelst='kdel statefulsets'
alias kdels='kdel secret'
alias kdeln='kdel node'
alias kdelsvc='kdel service'
alias kdelj='kdel jobs'
alias kdeli='kdel ingress'
alias kdelp='kdel pods'
alias kdelpf='kdelp --force'
alias kdelpods='kdelp'
alias kdelpodsf='kdelpf'
alias kdelj='kdel job'
alias kdelpvc='kdel pvc'

alias kl='kubectl logs'
alias klf='kl -f --max-log-requests=1000'

alias kpf='kubectl port-forward'
alias kcp='kubectl cp'
alias kcpr='kubectl cp -r'
alias ka='kubectl apply -f'

alias kc='kubectl create'
alias kcj='kc job'
