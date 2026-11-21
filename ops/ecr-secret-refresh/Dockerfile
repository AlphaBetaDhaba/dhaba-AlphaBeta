FROM registry.k8s.io/kubectl:v1.37.0 AS kubectl

FROM public.ecr.aws/aws-cli/aws-cli:latest

COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl

ENTRYPOINT ["/bin/sh"]
