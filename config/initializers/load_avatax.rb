require 'ostruct'
raw_config = ERB.new(File.read(::Rails.root.to_s + "/config/avatax.yml")).result
AvataxConfig = OpenStruct.new(YAML.load(raw_config)[Rails.env])