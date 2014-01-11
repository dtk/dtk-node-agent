dtk-node-agent
==============

Code that is present in AMIs that server basis for nodes being spun up

### Build the gem:
`gem build dtk-node-agent.gemspec`

### Intalling the node agent on an existing AMI
`sudo dtk-node-agent`

### Install the agent and create a new AMI image
```
./create_agent_ami.rb --help
Options:
          --region, -r <s>:   AWS Region on which to create the AMI image
         --aws-key, -a <s>:   AWS Access Key
      --aws-secret, -w <s>:   AWS Secret Access Key
  --security-group, -s <s>:   AWS Security group (default: default)
        --key-pair, -k <s>:   AWS keypair for the new instance
        --key-path, -e <s>:   Path to the PEM file for ssh access
    --ssh-username, -u <s>:   SSH Username
     --ssh-timeout, -t <i>:   Time to wait before instance is ssh ready (seconds) (default: 100)
          --ami-id, -m <s>:   AMI id which to spin up
      --image-name, -i <s>:   Name of the new image
                --help, -h:   Show this message
```

example:  
```
ruby create_agent_ami.rb --region us-east-1 --ami-id ami-da0000aa --key-pair test_key --key-path /somepath/test_key.pem \
--ssh-username root --image-name r8-agent-ubuntu-precise
```



