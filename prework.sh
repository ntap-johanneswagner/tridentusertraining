echo
echo "#######################################################################################################"
echo "# 1. UPGRADE HELM"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
tar -xvf helm-v3.15.3-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v3.15.3-linux-amd64.tar.gz

echo
echo "#######################################################################################################"
echo "# 2. MODIFY BASH.RC"
echo "#######################################################################################################"
echo

if [ $(more ~/.bashrc | grep kdesc | wc -l) -ne 1 ]; then

cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias ka='kubectl apply' 
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
source ~/.bashrc
fi


echo
echo "#######################################################################################################"
echo "# 3. REMOVE Trident"
echo "#######################################################################################################"
echo

kubectl patch torc trident --type=merge -p '{"spec":{"wipeout":["crds"],"uninstall":true}}'
frames="/ | \\ -"
while [ $(kubectl get crd | grep trident | wc | awk '{print $1}') != 1 ];do
        for frame in $frames; do
                sleep 0.5; printf "\rWaiting for Trident to be removed $frame"
        done
done
helm uninstall trident -n trident
frames="/ | \\ -"
while [ $(kubectl get pods -n trident | wc | awk '{print $1}') != 0 ];do
        for frame in $frames; do
                sleep 0.5; printf "\rWaiting for Trident to be removed $frame"
        done
done
kubectl delete ns trident
helm repo remove netapp-trident
kubectl delete sc storage-class-iscsi
kubectl delete sc storage-class-nfs
kubectl delete sc storage-class-smb
kubectl delete sc storage-class-nvme

echo
echo "#######################################################################################################"
echo "# 4. ENABLE POD SCHEDULING ON THE CONTROL PLANE, DISABLE WINDOWS, CHANGE TOPOLOGY LABELS"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes win1 win=true:NoSchedule
kubectl taint nodes win2 win=true:NoSchedule
kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite

echo
echo "#######################################################################################################"
echo "# 5. CACHING IMAGES"
echo "#######################################################################################################"
echo

kubectl create ns trident
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

if [[ $RATEREMAINING -lt 20 ]];then
  if ! grep -q "dockreg" /etc/containers/registries.conf; then
    echo
    echo "##############################################################"
    echo "# CONFIGURE MIRROR PASS THROUGH FOR IMAGES PULL"
    echo "##############################################################"
  cat <<EOT >> /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"
[[registry.mirror]]
prefix = "docker.io"
location = "dockreg.labs.lod.netapp.com"
EOT
  fi
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Multi-Arch TRIDENT Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --multi-arch all --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident:25.10.0 docker://registry.demo.netapp.com/trident:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-operator/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT OPERATOR Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident-operator:25.10.0 docker://registry.demo.netapp.com/trident-operator:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-autosupport/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT AUTOSUPPORT Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident-autosupport:25.10.0 docker://registry.demo.netapp.com/trident-autosupport:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/busybox/tags/list' | jq -r '.tags[]? | select(.=="1.35.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Busybox 1.35.0 Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://quay.io/yvosonthehub/busybox:1.35.0 docker://registry.demo.netapp.com/busybox:1.35.0 \
    --src-tls-verify=false --dest-tls-verify=false 
else
  echo
  echo "##############################################################"
  echo "# Busybox 1.35.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/controller/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Controller Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://docker.io/netapp/controller:25.10.0 docker://registry.demo.netapp.com/controller:25.10.0 \
    --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/exechook/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Exechook Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/exechook:25.10.0 docker://registry.demo.netapp.com/exechook:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi


if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcebackup/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceBackup Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcebackup:25.10.0 docker://registry.demo.netapp.com/resourcebackup:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcerestore/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceRestore Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcerestore:25.10.0 docker://registry.demo.netapp.com/resourcerestore:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcedelete/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceDelete Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcedelete:25.10.0 docker://registry.demo.netapp.com/resourcedelete:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/restic/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Restic Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/restic:25.10.0 docker://registry.demo.netapp.com/restic:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/kopia/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Kopia Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/kopia:25.10.0 docker://registry.demo.netapp.com/kopia:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/kopiablockrestore/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Kopia Block Restore Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/kopiablockrestore:25.10.0 docker://registry.demo.netapp.com/kopiablockrestore:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-protect-utils/tags/list' | jq -r '.tags[]? | select(.=="v1.0.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Trident Protect Utils Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/trident-protect-utils:v1.0.0 docker://registry.demo.netapp.com/trident-protect-utils:v1.0.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

echo "#######################################################################################################"
echo "6. INSTALL ANSIBLE"
echo "#######################################################################################################"

# test repo availability 
REPO_URL='http://repomirror-rtp.eng.netapp.com/rhel/9server-x86_64//rhel-9-for-x86_64-appstream-rpms/repodata/repomd.xml'

if curl -sSfI "$REPO_URL" >/dev/null 2>&1; then
  dnf install -y python-pip
else
  wget -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
  python3 /tmp/get-pip.py
fi

pip install ansible-core==2.15.12 netapp-lib
ansible-galaxy collection install netapp.ontap --ignore-certs


echo
echo "#######################################################################################################"
echo "# 7. CREATE LABSVM"
echo "#######################################################################################################"
echo

mkdir -p /etc/ansible
if [ -f /etc/ansible/hosts ]; then mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi;
cp hosts /etc/ansible/ 

ansible-playbook labsvm.yaml

echo "#################################################################"
echo "# 8. S3 SVM & Bucket Creation"
echo "#################################################################"
ansible-playbook svm_S3_setup.yaml > ansible_S3_SVM_result.txt

echo "#################################################################"
echo "# 9. TP NS and Secret generation"
echo "#################################################################"

kubectl create ns trident-protect
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com

echo "#################################################################"
echo "# 10. INSTALL TRIDENT 25.10.0"
echo "#################################################################"

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 100.2510.0 --create-namespace --namespace trident --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.10.0,operatorImage=registry.demo.netapp.com/trident-operator:25.10.0,tridentImage=registry.demo.netapp.com/trident:25.10.0,tridentSilenceAutosupport=true,windows=true,imagePullSecrets[0]=regcred
frames="/ | \\ -"
while [ $(kubectl get pods -n trident | wc | awk '{print $1}') != 8 ];do
        for frame in $frames; do
                sleep 0.5; printf "\rWaiting for Trident to be installed $frame"
        done
done
kubectl get pods -n trident