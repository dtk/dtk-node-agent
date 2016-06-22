#!/usr/bin/env ruby

require 'fog'
require 'ap'
require 'yaml'

regions = [ "us-east-1", "us-west-1", "us-west-2", "eu-west-1"]

raise ArgumentError, "You must specify timestamp argument" if ARGV[0].nil?
ts_filter = ARGV[0].split(",")

module_hash = {
  'module' => 'image_aws',
  'dsl_version' => '1.0.0',
  'components' => {
    'image_aws' => { 
      'attributes' => { 
        'images' => { 
          'description' => 'Mapping of logical image names to amis', 
          'type' => 'hash', 
          'hidden' => true,
          'default' => {}
        }
      }
    }
  }
}

resolver = {
  'trusty' => 'ubuntu',
	'trusty_hvm' => 'ubuntu',
  'precise' => 'ubuntu',
	'precise_hvm' => 'ubuntu',
  'wheezy' => 'debian',
	'wheezy_hvm' => 'debian',
  'rhel6_hvm' => 'redhat',
	'rhel6' => 'redhat',
	'amazon' => 'amazon-linux',
	'amazon_hvm' => 'amazon-linux'
}

region_names = Hash.new
regions.each do |region|
  image_names = Hash.new
  fog = Fog::Compute.new({:provider => 'AWS', :region => region})
  fog.describe_images('Owner' => 'self').body["imagesSet"].each do |i|
    next unless ts_filter.any? { |w| i['name'] =~ /#{w}/ }
  	i['name'] =~ /dtk\-agent\-([a-zA-Z0-9_]*)\-([0-9]{10})/
      if $1 && !$2.strip.empty?
        raise "Missing mapping #{$1}  2: #{$2}" unless resolver[$1.downcase]
        unless $1.include? 'hvm'
          sizes = { 'micro' => "t1.micro", 'small' => "m1.small",'medium' => "m3.medium" }
        else 
          if $1 == 'amazon_hvm'
            sizes = { 'large' => "m4.large", 'micro' => "t2.micro", 'small' => "t2.small", 'medium' => "t2.medium" }
          else  
            sizes = { 'micro' => "t2.micro", 'small' => "t2.small", 'medium' => "t2.medium" }
          end
        end
        image_names[$1] = {"ami"=>i['imageId'], "os_type"=>resolver[$1.downcase], "sizes"=>sizes}
      else
      	puts "Your skipped #{i['name']} with 1: #{$1} 2: #{$2}"
      end
  end
  region_names[region] = image_names
end

module_hash['components']['image_aws']['attributes']['images']['default'] = region_names
puts module_hash.to_yaml

