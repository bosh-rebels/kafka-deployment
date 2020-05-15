# kafka-deployment

This repo contains the basic [manifest](./manifest.yml) required to deploy a kafka [BOSH](https://bosh.io) deployment.

The CMAK password is automaticaly generated using BOSH variables.

There is a [pipeline](./ci/pipeline.yml) which makes sure that this manifest will successfully be deployed.

Pipeline can manually delete the deployment.