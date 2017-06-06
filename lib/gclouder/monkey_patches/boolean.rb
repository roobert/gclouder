#!/usr/bin/env ruby

module Boolean
end

class TrueClass
  include Boolean
end

class FalseClass
  include Boolean
end
