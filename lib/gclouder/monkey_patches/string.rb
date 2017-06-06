#!/usr/bin/env ruby

class String
  include GClouder::Shell

  def snakecase
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def mixedcase
    self.split('_').collect(&:capitalize).join.sub(/^[A-Z]/, &:downcase)
  end

  def truncate(length = 32)
    raise 'Pleasant: Length should be greater than 3' unless length > 3

    truncated_string = self.to_s

    if truncated_string.length > length
      truncated_string = truncated_string[0...(length - 3)]
      truncated_string += "..."
    end

    truncated_string
  end
end
