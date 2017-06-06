#!/usr/bin/env ruby

module GClouder
  module Resource
    module Cleaner
      def self.included(klass)
        klass.extend Cleaner
      end

      def clean
        return if undefined.empty?

        header :clean

        undefined.each do |namespace, resources|
          info namespace, indent: 2, heading: true
          info
          resources.each do |resource|
            message = resource['name']
            message += " (not defined locally)"
            warning message
            # FIXME: enable purge on --purge flag..
            #Resource.symlink.send(:purge, namespace, resource)
          end
        end
      end


      module Default
        def self.cleaner
          Proc.new do |resources, resource|
            resources.map do |r|
              r['name'] == resource
            end.include?(true)
          end
        end
      end

      def cleaner
        (self.const_defined?(:Cleaner) && self::Cleaner.respond_to?(:custom)) ? self::Cleaner.custom : Default.cleaner
      end

      def undefined
        self::Remote.list.each_with_object({}) do |(namespace, resources), collection|
          resources.each do |resource|
            namespace_resources = self::Local.list[namespace]

            # accept PROC for custom matching of undefined resources
            next if namespace_resources && cleaner.call(namespace_resources, resource["name"])

            collection[namespace] ||= []
            collection[namespace] << resource
          end
        end
      end
    end
  end
end
