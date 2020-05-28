require "yaml"

YAML.load_file(__dir__ + "/../../../manifest.yml")["releases"].each do |rel| 
  puts "#{rel["name"]}"
end