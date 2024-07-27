# Hands-on Jenkins-07 : Jenkins Pipeline to Deploy Application on Kubernetes Cluster

Purpose of the this hands-on training is to teach the students how to build Jenkins pipeline to create Docker image, push the images to AWS Elastic Container Registry (ECR) and deploy them on Kubernetes Cluster.

## Learning Outcomes

At the end of the this hands-on training, students will be able to;

- create and configure AWS ECR from the AWS Management Console.

- configure Jenkins Server with Git, Docker, AWS CLI on Amazon Linux 2023 EC2 instance using Terraform file.

- demonstrate how to build a docker image with Dockerfile.

- build Jenkins pipelines with Jenkinsfile.

- integrate Jenkins pipelines with GitHub using Webhook.

- use Docker commands effectively to tag, push, and pull images to/from ECR.

- create repositories on ECR from the AWS Management Console.

- Deploy application to kubernetes cluster using jenkins pipeline.

- delete images and repositories on ECR from the AWS CLI.

## Outline

- Part 1 - Launching a Jenkins Server Configured for ECR Management

- Part 2 - Setting up the Kubernetes Cluster

- Part 3 - Integrate Kubernetes Cluster with Jenkins

- Part 4 - Create a Pipeline to Deploy an Application on Kubernetes Cluster

## Part 1 - Launching a Jenkins Server Configured for ECR Management

- Launch a pre-configured `Jenkins Server` from the terraform file running on Amazon Linux 2023, allowing SSH (port 22) and HTTP (ports 80, 8080) connections.

- Open your Jenkins dashboard and navigate to `Manage Jenkins` >> `Manage Plugins` >> `Available` tab

- Search and select `Kubernetes, Kubernetes Credentials and Kubernetes CLI` plugins, then click to `Install without restart`. Note: No need to install the other `Git plugin` which is already installed can be seen under `Installed` tab.

### İnstall kubectl

- Download the Amazon EKS vended kubectl binary.

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
```

- Apply execute permissions to the binary.

```bash
chmod +x ./kubectl
```

- Copy the binary to a folder in your PATH.

```bash
sudo cp ./kubectl /usr/local/bin/kubectl
```

- After you install kubectl , you can verify its version with the following command:

```bash
kubectl version --client
```

- Copy the hands-on folder to jenkins server.

## Part 2 - Setting up the Kubernetes Cluster

- Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](./cfn-template-to-create-k8s-cluster.yml). *Note: Once the master node up and running, worker node automatically joins the cluster.*

- Check if Kubernetes is running and nodes are ready.

```bash
kubectl cluster-info
kubectl get node
```

- Add following inbound rule to `kubernetes security group` to allow jenkins server to kube-apiserver.

```yaml
Type: Custom TCP

Port range: 6443

Source: Jenkins server sg
```

## Part 3 - Integrate Remote Kubernetes Cluster with Jenkins

### Step-1 - Create credentials for jenkins to manage kubernetes cluster

- Open the Jenkins UI and navigate to `Manage Jenkins -> Nodes -> Credentials -> System -> Global Credentials`.

    - Kind: `Secret text`

    - ID: `kube_token` 

    - Description: `kube_token`

    - Secret: `Get from kubernetes master node`

#### Secret:

- Execute following commands on `kubernetes master node`.

- Create a kubernetes service account named `jenkins`.

```bash
kubectl create serviceaccount jenkins
```

- Create a `clusterrolebinging` for jenkins serviceaccount.

```bash
kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: jenkins
 labels:
   k8s: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: default
EOF
```

- Create a secret for `jenkins serviceaccount`.

```bash
kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
 name: jenkins
 annotations:
   kubernetes.io/service-account.name: jenkins
EOF
```

- Get the token from `jenkins secret`.

```bash
kubectl get secrets jenkins -o jsonpath='{.data.token}' | base64 -d
```

### Step-2 - Integrate kubernetes with jenkins

- Open the Jenkins UI and navigate to `Manage Jenkins -> Nodes -> Clouds -> New cloud -> cloud-name: kube-cluster-1 and click Kubernetes` and input the data as below.

### Kubernetes url:

- Execute this command on `kubernetes master node` and get the `control plane URL`.

```bash
kubectl cluster-info
```

### Kubernetes server certificate key:

- Execute this command on `kubernetes master node` and copy the `certificate-authority-data of cluster`.

```bash
cd
cd .kube
cat config
```

- Convert kubernetes server certificate key to base64 format.

```bash
echo -n <contents_of_the_certificate-authority-data> | base64 --decode
```

- You will get an output like below.

```bash
-----BEGIN CERTIFICATE-----
...
...
-----END CERTIFICATE-----
```

## Part 4 - Create a Pipeline to Deploy an Application on Kubernetes Cluster

### Step -1: Prepare github repo 

- Create a github repo named `k8s-phonebook`.

- Change the `CLUSTER_URL="Kubernetes url"` in the Jenkinsfile.

- Execute the following commands in the k8s-phonebook under the project folder.

```bash
git init
git add .
git config --global user.email "you@example.com"
git config --global user.name "Your Name
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/<github-username>/k8s-phonebook.git
git push -u origin main 
```

### Step-2: Create Webhook 

- Go to the `k8s-phonebook` repository page and click on `Settings`.

- Click on the `Webhooks` on the left hand menu, and then click on `Add webhook`.

- Copy the Jenkins URL from the AWS Management Console, paste it into `Payload URL` field, add `/github-webhook/` at the end of URL, and click on `Add webhook`.

```text
http://ec2-54-144-151-76.compute-1.amazonaws.com:8080/github-webhook/
```

### Step -3: Create a pipeline

```yaml
- job name: phonebook
- job type: Pipeline
- Pipeline: 
      SCM: Git
      Repository URL: https://github.com/[your-github-account]/k8s-phonebook.git
- Branches to build:
      Branch Specifier (blank for 'any'): main
- Build Triggers: GitHub hook trigger for GITScm polling
- Script Path: Jenkinsfile
```

- Click `Build Now`.

- Check the application on `kubernetes-master-node:30001` and `30002` ports.

- Change something in the `k8s-phonebook folder` and see that the app changes automatically.