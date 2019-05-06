module Serializer
  # Contains DSL required to define required fields and relations for serialization.
  module DSL
    # TBA
    macro attributes(*names)
      {%
        names.reduce(ATTRIBUTES) do |hash, name|
          hash[name] = { key: name, if: nil }
          hash
        end
      %}
    end

    # TBA
    macro attribute(name, key = nil, if if_proc = nil)
      {% ATTRIBUTES[name] = { key: key || name, if: if_proc } %}
    end

    # TBA
    macro has_many(name, serializer, key = nil)
      {% RELATIONS[name] = { serializer: serializer, key: key || name, type: :has_many } %}
    end

    # TBA
    macro has_one(name, serializer, key = nil)
      {% RELATIONS[name] = { serializer: serializer, key: key || name, type: :has_one } %}
    end

    # TBA
    macro belongs_to(name, serializer, key = nil)
      {% RELATIONS[name] = { serializer: serializer, key: key || name, type: :belongs_to } %}
    end
  end

  # Abstract serializer static methods.
  module AbstractClassMethods
    # Returns json root key.
    abstract def root_key

    # Returns default meta options.
    #
    # If this is empty and no additional meta-options are given - `meta` key is avoided.
    abstract def meta(opts)
  end

  # Base abstract superclass for serialization.
  abstract class Interface
    extend AbstractClassMethods

    # Serializes *target*'s attributes to *io*.
    abstract def serialize_attributes(target, io, except, opts)

    # Serializes *target*'s relations to *io*.
    abstract def serialize_relations(target, fields_count, io, includes, opts)

    # TBA
    def serialize(except = %i(), includes = %i(), opts : Hash? = nil, meta : Hash? = nil)
      String.build do |io|
        serialize(io, except, includes, opts, meta)
      end
    end

    def serialize(io : IO, except = %i(), includes = [] of String, opts : Hash? = nil, meta : Hash? = nil)
      render_root(io, except, includes, opts, meta)
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

    def self.root_key
      "data"
    end

    def self.meta(_opts)
      {} of Symbol => JSON::Any::Type
    end
  end

  # Base serialization superclass.
  #
  # TBA
  abstract class Base(T) < Interface
    include DSL

    # :nodoc:
    macro define_serialization
      # :nodoc:
      ATTRIBUTES = {} of Nil => Nil
      # :nodoc:
      RELATIONS = {} of Nil => Nil

      macro finished
        {% verbatim do %}
          {% superclass = @type.superclass %}

          {% if ATTRIBUTES.size > 0 %}
            # :nodoc:
            def serialize_attributes(object, io, except, opts)
              fields_count =
                {{ superclass.methods.any?(&.name.==(:serialize_attributes.id)) ? :super.id : 0 }}
              {% for name, props in ATTRIBUTES %}
                {% target = @type.has_method?(name) ? :self : :object %}
                if !except.includes?(:{{name.id}}) {% if props[:if] %} && {{props[:if].id}}(object, opts) {% end %}
                  io << "," if fields_count > 0
                  fields_count += 1
                  io << "\"{{props[:key].id}}\":" << {{target.id}}.{{name.id}}.to_json
                end
              {% end %}
              fields_count
            end
          {% end %}

          {% if RELATIONS.size > 0 %}
            # :nodoc:
            def serialize_relations(object, fields_count, io, includes, opts)
              {% if superclass.methods.any?(&.name.==(:serialize_relations.id)) %} super {% end %}
              {% for name, props in RELATIONS %}
                {% if props[:type] == :has_many || props[:type] == :has_one || props[:type] == :belongs_to %}
                if has_relation?({{name}}, includes)
                  io << "," if fields_count > 0
                  fields_count += 1
                  io << "\"{{props[:key].id}}\":"
                  {{props[:serializer]}}.new(object.{{name.id}})._serialize(object.{{name.id}}, io, [] of Symbol, nested_includes({{name}}, includes), opts)
                end
                {% end %}
              {% end %}
              fields_count
            end
          {% end %}
        {% end %}
      end

      macro inherited
        define_serialization
      end
    end

    macro inherited
      define_serialization
    end

    # Entity to be serialized.
    protected getter target

    def initialize(@target : T | Array(T)?)
    end

    def serialize_attributes(object, io, except, opts)
      0
    end

    def serialize_relations(object, fields_count, io, includes, opts)
      fields_count
    end

    # :nodoc:
    def _serialize(object : T, io : IO, except : Array, includes : Array | Hash, opts : Hash?)
      io << "{"
      fields_count = serialize_attributes(object, io, except, opts)
      serialize_relations(object, fields_count, io, includes, opts)
      io << "}"
    end

    # :nodoc:
    def _serialize(collection : Array(T), io : IO, except : Array, includes : Array | Hash, opts : Hash?)
      collection.each_with_index do |object, index|
        io << "["
        io << "," if index != 0
        _serialize(object, io, except, includes, opts)
        io << "]"
      end
    end

    # :nodoc:
    def render_root(io : IO, except : Array, includes : Array | Hash, opts : Hash?, meta)
      io << "{\"" << self.class.root_key << "\":"
      _serialize(@target, io, except, includes, opts)
      unless meta.nil?
        io << %(,"meta":) << meta.to_json
      end
      io << "}"
    end
  end
end
