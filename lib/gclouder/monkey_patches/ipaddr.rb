#!/usr/bin/env ruby

class IPAddr
  def self.valid?(obj)
    IPAddr.new(obj)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
end
