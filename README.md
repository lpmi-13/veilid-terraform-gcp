# Veilid Terraform GCP

Because GCP has a free tier, we can run a super tiny VM for free. And Veilid-Server is a super low resource consumer, so we can easily run a node to sustain and grow the network.

This terraform configuration will help you do that!

## Setting up access

1. Sign up for a GCP account you don't already have one and create a project. Just call it whatever you want, but use that value in the `provider` block in `main.tf`.

2. Install the gcloud cli. The docs [here](https://cloud.google.com/sdk/docs/install) are very good and easy to follow.

3. Set up authentication locally. Just run `gcloud auth application-default login` and you'll have the credentials stored for when you want to run commands via terraform.

## Running the terraform commands

1. Add your public SSH key to the metadata in `main.tf` in the format of `"USER:PUBLIC_SSH_KEY_CONTENTS"`. I've left the `veilid` user in there by default, but you can specify whichever username you want.

2. Decide which region(s) you want to run a veilid node in, and uncomment the relevant line(s) in the `locals.free_regions` block in `regions.tf`. NOTE: only the regions in `free_regions` qualify for the free tier, so use one of those unless you want to spin up a bunch of nodes and pay more.

3. Run the terraform command and get a/some shiny new node(s)!

```
terraform init && terraform apply
```

> NOTE: the public IP address(es) will be an output from the action, though since the cloud init script takes a bit of time to run, if you SSH in immediately, you might not have access to the `veilid-cli` command for a few minutes.
