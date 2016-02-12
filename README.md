dtk-node-agent
==============

Code that is present in AMIs that server basis for nodes being spun up

### Build the gem:
`gem build dtk-node-agent.gemspec`

#### Intalling the node agent on a running machine (without puppet omnibus)
`sudo dtk-node-agent`

#### Intalling the node agent on a running machine (with puppet omnibus)
`sudo ./install_agent.sh [--sanitize]`

#### Build all supported AMI images with [packer](http://www.packer.io/) 
```
export AWS_ACCESS_KEY="your aws access key"
export AWS_SECRET_KEY="your aws secret key"

packer build template.json
```  
This will also copy images to all AWS regions.  

To get json output of new images, first, add .fog file on your home directory (with valid aws credentials) and then run following ruby script:
```
ruby get_amis.rb <AMI_TIMESTAMPS>
```
AMI_TIMESTAMPS can be one timestamp or array of timestamps separated with delimiter (,)

## License

dtk-node-agent is copyright (C) 2010-2016 dtk contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this work except in compliance with the License.
You may obtain a copy of the License in the [LICENSE](LICENSE) file, or at:

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


