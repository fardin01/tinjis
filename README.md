# Preface

We're really happy that you're considering to join us! Here's a challenge that will help us understand your skills and serve as a starting discussion point for the interview.

We're not expecting that everything will be done perfectly as we value your time. You're encouraged to point out possible improvements during the interview though!

Have fun!

## The challenge

Pleo runs most of its infrastructure in Kubernetes. It's a bunch of microservices talking to each other and performing various tasks like verifying card transactions, moving money around, paying invoices ...

We would like to see that you both:
- Know how to create a small microservice
- Know how to wire it together with other services running in Kubernetes

We're providing you with a small service (Antaeus) written in Kotlin that's used to charge a monthly subscription to our customers. The trick is, this service needs to call an external payment provider to make a charge and this is where you come in.

You're expected to create a small payment microservice that Antaeus can call to pay the invoices. You can use the language of your choice. Your service should randomly succeed/fail to pay the invoice.

On top of that, we would like to see Kubernetes scripts for deploying both Antaeus and your service into the cluster. This is how we will test that the solution works.

## Instructions

Start by forking this repository. :)

1. Build and test Antaeus to make sure you know how the API works. We're providing a `docker-compose.yml` file that should help you run the app locally.
2. Create your own service that Antaeus will use to pay the invoices. Use the `PAYMENT_PROVIDER_ENDPOINT` env variable to point Antaeus to your service.
3. Your service will be called if you invoke `/rest/v1/invoices/pay` call on Antaeus. You can probably figure out which call returns the current status invoices by looking at the code ;)
4. Kubernetes: Provide deployment scripts for both Antaeus and your service. Don't forget about Service resources so we can call Antaeus from outside the cluster and check the results.
    - Bonus points if your scripts use liveness/readiness probes.
5. **Discussion bonus points:** Use the README file to discuss how this setup could be improved for production environments. We're especially interested in:
    1. How would a new deployment look like for these services? What kind of tools would you use?
    2. If a developers needs to push updates to just one of the services, how can we grant that permission without allowing the same developer to deploy any other services running in K8s?
    3. How do we prevent other services running in the cluster to talk to your service. Only Antaeus should be able to do it.

## How to run

If you want to run Antaeus locally, we've prepared a docker compose file that should help you do it. Just run:
```
docker-compose up
```
and the app should build and start running (after a few minutes when gradle does its job)

## How to deploy

### Bash script
This project comes with a `deploy.sh` script that can take of the deployment for you. It's not ideal and in my opinion not
suitable for production. Similar to the rest of this project, the script is a MVP just to get this microservice up and running
quickly.

The script will get the active/current kubectl context and will attempt to deploy to the active/current context/cluster.
So make sure to choose the correct context before executing the script (by running `./deploy.sh`). It will also validate whether you have the needed tools installed (`kubectl`, `helm`, `jq`).

### Helm 3
If for any reason you do not want to use the script to deploy, you can simply run `helm upgrade --install <helm release name> kubernetes/`.
The `kubectl` context still has to be correct. Make sure you are using Helm 3, because we do not want to deal with installing and maintaining Tiller.


Finally, the script will give you the AWS LoadBalancer URL which you can use to call Antaeus API. If that does not happen for any reason, simply run `kubectl get --namespace <namespace> svc tinjis  -o json | jq .status.loadBalancer.ingress[0].hostname`
## How we'll test the solution

1. We will use your scripts to deploy both services to our Kubernetes cluster.
2. Run the pay endpoint on Antaeus to try and pay the invoices using your service.
3. Fetch all the invoices from Antaeus and confirm that roughly 50% (remember, your app should randomly fail on some of the invoices) of them will have status "PAID".

# Discussion bonus points
Q: How would a new deployment look like for these services? What kind of tools would you use?  
A: I think that all microservices need to be deployed in the same way regardless of being a new or legacy
service. There are multiple tools to use. I will briefly discuss a few of them here. 
   1. Terraform would be a top candidate for me if it supported CRDs. There is a Kubernetes provider that supports it but it 
   is not generally available which makes it unsuitable for production environment. 
   2. Helm is a widely used tool which I have experience with. It does offer some good features but it could be hard to get it 
      right. After using Helm for ~2 years, I am open to exploring alternatives.
   3. An alternative that I would like to explore is Pulumi. It has the same concept as Terraform but it is written using
      a real programming language (Go, Python, etc.). That gives you a real flexibility to do many things that Helm and
      Terraform do not. Plus, it has an easier learning curve for a software engineer.
      
In addition, the deploy pipeline should ideally be integrated with the CI pipeline. If there has been big investments in
the CI pipeline, then it can, to some extend, dictate how the deploy pipeline looks like. I will be happy to discuss and
address specific issues/questions.

Q: If a developers needs to push updates to just one of the services, how can we grant that permission without allowing the same developer to deploy any other services running in K8s?  
A: In situations like this, I usually take a step back and try to look at the problem from a higher level, in an attempt
to approach the problem differently. Giving developers access to a specific set of pods seems like a strange thing to do so
my first step would be to understand the problem fully and correctly. Of course no developer should have `sudo` rights or
be able to look at Kubernetes secret objects, but other than that they should have the freedom to deploy and debug their
services. 

To directly answer this question, we can combine RBAC and an OIDC provider (such as an LDAP server) to control who can do what
inside the cluster. One limitation I recently discovered in this case is that `exec` permission on pods cannot be limited to a specific
set of pods. The lowest level it can be set is the namespace level.

If we have a deploy pipeline in place (using Jenkins, Rundeck, etc.) we can again integrate that to an LDAP server and allow
the user to trigger/deploy specific jobs based on their LDAP group membership.

Q: How do we prevent other services running in the cluster to talk to your service. Only Antaeus should be able to do it.  
A: EKS offers a feature called Pod Security Group which is EC2 security groups on pods, allowing admins to specify who can
talk to who (basically opening ports to specific request origins). However, it appears that Pod Security Group feature [is
being deprecated](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html) for pods running on EC2 
nodes and will only be supported on pods running on Fargate:
> You can only use security groups for pods with pods running on AWS Fargate if your cluster is 1.18 with platform version eks.7 or later, 1.19 with platform version eks.5 or later, or 1.20 or later.

In that case, we might be able to use the networking plugin to define such rules, or use the "native" Network Policies resource. 
