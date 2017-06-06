#!/usr/bin/env ruby

class Array
  def clean
    uniq.delete_if(&:nil?)
  end

  def to_snake_keys
    each_with_index do |v, i|
      self[i] = v.to_snake_keys if v.is_a?(Hash)
    end
    self
  end

  def fetch_with_default(key, name, default)
    results = find { |e| e[key] == name }
    results || default
  end
end
