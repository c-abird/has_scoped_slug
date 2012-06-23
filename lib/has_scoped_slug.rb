# coding: utf-8
module ActiveRecord
  module Has
    module ScopedSlug
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Sets up the slugger
        #
        # == Options
        # * +name_column+ the column to be slugged, may by a virtual column
        # * +column+      the column that stores the slug, defaults to +slug+
        # * +scope+       the scope, may be an association which as also slugged or a regular column
        #
        def has_scoped_slug(options = {})
          config = { :name_column => "name", :column => "slug", :scope => nil }
          config.update(options) if options.is_a?(Hash)

          if !config[:scope].nil?
            column = self.columns.select { |c| c.name == config[:scope].to_s }.first
            config[:scope] = "#{config[:scope]}_id".to_sym if column.nil?
            config[:scope] = config[:scope].to_sym
          end


          # define sql condition method
          if config[:scope].nil?
            # no scope
            scope_condition_method = %(
              def slug_scope_condition
                "1 = 1"
              end

              def self.slug_scope
                nil
              end
            )
          else
            # association scope
            scope_condition_method = %(
              def slug_scope_condition
                if #{config[:scope].to_s}.nil?
                  "#{config[:scope].to_s} IS NULL"
                else
                  "#{config[:scope].to_s} = '\#{#{config[:scope].to_s}}'"
                end
              end

              def self.slug_scope
                :#{config[:scope]}
              end
            )
          end

          # define class methods
          class_eval <<-EOV
            include ActiveRecord::Has::ScopedSlug::InstanceMethods

            class << self
              def slug_column
                '#{config[:column]}'
              end

              def slug_name_column
                '#{config[:name_column]}'
              end
            end

            #{scope_condition_method}
            before_save :set_slug
          EOV
        end

        # Returns a model based on the slug parameters as given by get_params
        def find_by_params(params)
          puts "PARAMS: #{params.inspect}"
          puts "CLASS: #{self.name}"
          slug = params[self.name.underscore.to_sym]
          puts "SLUG: #{slug}"

          # no scope
          if slug_scope.nil?
            return self.find :first, :conditions => ["#{slug_column} = ?", slug]
          # with association scope
          elsif slug_scope.to_s =~ /^(.*)_id$/
            # TODO use joins
            parent_klass = ($1).classify.constantize
            parent = parent_klass.find_by_params(params)
            if slug.nil?
              puts "SLUG IS NIL"
              # guess  parent accessor
              parent_accessor = self.class.name.pluralize.underscore
              return parent.send(parent_accessor).first if parent.respond_to?(parent_accessor)
              return self.find :first, :conditions => ["#{slug_scope} = ?", parent.id]
            else
              return self.find :first, :conditions => ["#{slug_column} = ? AND #{slug_scope} = ?", slug, parent.id]
            end
          # value scope
          else
            if slug.nil?
              # TODO test this case
              return self.find :first, :conditions => ["#{slug_scope} = ?", params[slug_scope]]
            end
            return self.find :first, :conditions => ["#{slug_column} = ? AND #{slug_scope} = ?", slug, params[slug_scope]]
          end
        end
        alias_method :find_by_slug, :find_by_params
      end

      module InstanceMethods
        # Returns the slug parameters including slugs of scopes
        def get_params
          result = {}
          slug_scope = self.class.slug_scope
          if slug_scope
            # association scope
            if slug_scope.to_s =~ /^(.*)_id$/
              result = (self.send($1)).get_params
            # value scope
            else
              result[slug_scope.to_sym] = self.send slug_scope
            end
          end
          result["#{self.class.name.underscore}".to_sym] = slug
          result
        end
        alias_method :get_url_parameters, :get_params

        # Calculates and sets the slug
        def set_slug
          result = (self.send(self.class.slug_name_column) || "").downcase
          result = result.force_encoding "UTF-8" if RUBY_VERSION =~ /1\.9/
          replacements = {
            'Ä' => 'ae',
            'Ö' => 'oe',
            'Ü' => 'ue',
            'ä' => 'ae',
            'ö' => 'oe',
            'ü' => 'ue',
            'ß' => 'ss',
            ' ' => '-'
          }
          replacements.each do |search, replace|
            result.gsub! search, replace
          end
          result.gsub! /[^a-z0-9\-]/, ''
          self.send "#{self.class.slug_column}=", result

          i = 2
          while self.class.count(:conditions => "#{slug_scope_condition} AND
                                 #{self.class.slug_column} = '#{self.send(self.class.slug_column)}' AND
                                 id != #{id || 0}") > 0
            self.send "#{self.class.slug_column}=", "#{result}#{i}"
            i += 1
          end
        end

        # Returns the slug of the model
        def slug
          read_attribute(self.class.slug_column)
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval { include ActiveRecord::Has::ScopedSlug }
