#!/usr/bin/env ruby

module GClouder
  module Helpers
    def self.included(klass)
      klass.extend Helpers
    end

    def hash_to_args(hash)
      raise StandardError, "hash_to_args: input not a hash: #{hash}" unless hash.is_a?(Hash)
      hash.map { |param, value|
        next if param == "name"
        to_arg(param, value)
      }.join(" ")
    end

    def to_arg(param, value)
      param = param.tr("_", "-")

      value = case value
      when Boolean
        return value ? "--#{param}" : "--no-#{param}"
      when Array
        value.join(",")
      else
        value
      end

      "--#{param}='#{value}'"
    end

    def valid_json?(object)
      JSON.parse(object.to_s)
      return true
    rescue JSON::ParserError
      return false
    end

    def to_deep_merge_hash(hash, hash_type = DeepMergeHash)
      raise StandardError, "to_deep_merge_hash: argument must be a hash" unless hash.is_a?(Hash)

      hash.each do |k,v|
        case v
        when Hash
          hash_to_deep_merge_hash(hash, k, v, hash_type)
        when Array
          array_to_deep_merge_hash(v, hash_type)
        end
      end

      hash_type.new(hash)
    end

    def module_exists?(name, base = self.class)
      raise StandardError, "module name must be a string" unless name.is_a?(String)
      base.const_defined?(name) && base.const_get(name).instance_of?(::Module)
    end

    private

    def hash_to_deep_merge_hash(obj, index, hash, hash_type)
      obj[index] = hash_type.new(hash)
      to_deep_merge_hash(obj[index], hash_type)
    end

    def array_to_deep_merge_hash(array, hash_type)
      array.each_with_index do |e,i|
        case e
        when Hash
          hash_to_deep_merge_hash(array, i, e, hash_type)
        when Array
          array_to_deep_merge_hash(array, hash_type)
        end
      end
    end
  end
end
