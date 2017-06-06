#!/usr/bin/env ruby

class Hash
  # sourced from: https://github.com/futurechimp/plissken/blob/master/lib/plissken/ext/hash/to_snake_keys.rb
  def to_snake_keys(value = self)
    case value
    when Array
      value.map { |v| to_snake_keys(v) }
    when Hash
      snake_hash(value)
    else
      value
    end
  end

  private

  def snake_hash(value)
    Hash[value.map { |k, v| [underscore_key(k), to_snake_keys(v)] }]
  end

  def underscore_key(k)
    if k.is_a? Symbol
      underscore(k.to_s)
    elsif k.is_a? String
      underscore(k)
    else
      k
    end
  end

  def underscore(string)
    string.gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end
end

class DeepMergeHash < Hash
  include Hashie::Extensions::MergeInitializer
  include Hashie::Extensions::DeepMerge
end
