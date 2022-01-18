module Serializer
  # Allowed types for *meta* hash values.
  alias MetaAny = JSON::Any::Type | Int32

  # Base abstract superclass for serialization.
  abstract class Serializable
    # Abstract serializer static methods.
    module AbstractClassMethods
      # Returns json root key.
      #
      # Default data root key is `"data"`. This behavior can be override by overriding this method.
      # It can be omited by setting nil, but any meta-options and `meta` keys will be ignored.
      # ```
      # class UserSerializer < Serializer::Base(User)
      #   def self.root_key
      #     "user"
      #   end
      # end
      # ```
      abstract def root_key

      # Returns default meta options.
      #
      # If this is empty and no additional meta-options are given - `meta` key is avoided. To define own default meta options
      # just override this in your serializer:
      #
      # ```
      # class UserSerializer < Serializer::Base(User)
      #   def self.meta(opts)
      #     {
      #       :status => "ok",
      #     } of Symbol => Serializer::MetaAny
      #   end
      # end
      # ```
      abstract def meta(opts) : Hash(Symbol, MetaAny)

      def root_key : String | Nil
        "data"
      end

      def meta(_opts)
        {} of Symbol => MetaAny
      end
    end

    extend AbstractClassMethods

    # Serializes *target*'s attributes to *io*.
    abstract def serialize_attributes(target, io, except, opts)

    # Serializes *target*'s relations to *io*.
    abstract def serialize_relations(target, fields_count, io, includes, opts)

    # Generates a JSON formatted string.
    #
    # Arguments:
    #
    # * *except* - array of fields should be excluded from serialization;
    # * *includes* - definition of relation that should be included into serialized string;
    # * *opts* - options that will be passed to methods defined for *if* attribute options, key transform and `.meta`;
    # * *meta* - meta attributes to be added under `"meta"` key at root level; it is merge into default
    # meta attributes returned by `.meta`.
    #
    # ```
    # ModelSerializer.new(object).serialize(
    #   except: [:own_field],
    #   includes: {
    #     :children => {:address => nil, :dipper => [:address]},
    #   },
    #   meta: {:page => 0},
    #   opts: { :key_transform => "camelcase_up", :root_key => "people" }
    # )
    # ```
    # *key_transform* can either be "upcase", "downcase", "underscore", "camelcase_down" or "camelcase_up"
    # *root_key* dynamically sets the root key, overriding the default one
    # ## Includes
    #
    # *includes* option accepts `Array` or `Hash` values. To define just a list of association of target object - just pass an array:
    #
    # ```
    # ModelSerializer.new(object).serialize(includes: [:children])
    # ```
    #
    # You can also specify deeper and more sophisticated schema by passing `Hash`. In this case hash values should be of
    # `Array(Symbol) | Hash | Nil` type. `nil` is used to mark association which name is used for key as a leaf in schema
    # tree.
    def serialize(except : Array(Symbol) = %i(), includes : Array(Symbol) | Hash = %i(), opts : Hash? = nil, meta : Hash(Symbol, MetaAny)? = nil)
      String.build do |io|
        serialize(io, except, includes, opts, meta)
      end
    end

    # :nodoc:
    def serialize(io : IO, except = %i(), includes = %i(), opts : Hash? = nil, meta : Hash? = nil)
      if self.class.root_key.nil? && !(opts && opts.has_key?(:root_key))
        _serialize(@target, io, except, includes, opts)
      else
        render_root(io, except, includes, opts, meta)
      end
    end

    # :nodoc:
    def _serialize(object : Nil, io : IO, except : Array, includes : Array | Hash, opts : Hash?)
      io << "null"
    end

    # Returns whether *includes* has a mention for relation *name*.
    protected def has_relation?(name, includes : Array)
      includes.includes?(name)
    end

    protected def has_relation?(name, includes : Hash)
      includes.has_key?(name)
    end

    # Returns nested inclusions for relation *name*.
    protected def nested_includes(name, includes : Array)
      %i()
    end

    protected def nested_includes(name, includes : Hash)
      includes[name] || %i()
    end
  end
end
