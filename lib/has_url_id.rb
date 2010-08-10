# coding: utf-8
module ActiveRecord
  module Has
    module UrlId
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def has_url_id(options = {})
          config = { :name_column => "name", :column => "url_id", :scope => nil }
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
              def url_id_scope_condition
                "1 = 1"
              end

              def self.url_id_scope
                nil
              end
            )
          else
            # association scope
            scope_condition_method = %(
              def url_id_scope_condition
                if #{config[:scope].to_s}.nil?
                  "#{config[:scope].to_s} IS NULL"
                else
                  "#{config[:scope].to_s} = '\#{#{config[:scope].to_s}}'"
                end
              end

              def self.url_id_scope
                :#{config[:scope]}
              end
            )
          end

          # define class methods
          class_eval <<-EOV
            include ActiveRecord::Has::UrlId::InstanceMethods

            class << self
              def url_id_column
                '#{config[:column]}'
              end

              def url_id_name_column
                '#{config[:name_column]}'
              end

              #def url_id_scope
              #  '#{config[:scope]}'
              #end
            end

            #{scope_condition_method}
            before_save :set_url_id
          EOV
        end

        def find_by_params(params)
          url_id = params[class_name.underscore.to_sym]

          # no scope
          if url_id_scope.nil?
              return self.find :first, :conditions => ["#{url_id_column} = ?", url_id]
          # with scope
          else
            # TODO use joins
            scope = url_id_scope.to_s[0..url_id_scope.to_s.size-4]
            parent_klass = scope.classify.constantize
            parent = parent_klass.find_by_url_id(params)
            if url_id.nil?
              # guess  parent accessor
              parent_accessor = self.class_name.pluralize.underscore
              return parent.send(parent_accessor).first if parent.respond_to?(parent_accessor)
              return self.find :first, :conditions => ["#{url_id_scope} = ?", parent.id]
            else
              return self.find :first, :conditions => ["#{url_id_column} = ? AND #{url_id_scope} = ?", url_id, parent.id]
            end
          end
        end
        alias_method :find_by_url_id, :find_by_params
      end

      module InstanceMethods
        def get_params
          result = {}
          url_id_scope = self.class.url_id_scope
          if url_id_scope
            # association scope
            if url_id_scope.is_a?(Symbol)
              scope = url_id_scope[0..url_id_scope.size-4]
              result = (self.send scope).get_url_parameters
            # value scope
            else
              result[url_id_scope.to_sym] = self.send url_id_scope
            end
          end
          result["#{self.class.class_name.underscore}".to_sym] = url_id
          result
        end
        alias_method :get_url_parameters, :get_params

        def set_url_id
          result = (self.send(self.class.url_id_name_column) || "").downcase
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
          self.send "#{self.class.url_id_column}=", result

          i = 2
          while self.class.count(:conditions => "#{url_id_scope_condition} AND
                                 #{self.class.url_id_column} = '#{self.send(self.class.url_id_column)}' AND
                                 id != #{id || 0}") > 0
            self.send "#{self.class.url_id_column}=", "#{result}#{i}"
            i += 1
          end
        end
      end
    end
  end
end
