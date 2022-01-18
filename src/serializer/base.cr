require "./dsl"
require "./serializable"

module Serializer
  # Base serialization superclass.
  #
  # ```
  # class AddressSerializer < Serializer::Base(Address)
  #   attributes :street
  # end
  #
  # class ChildSerializer < Serializer::Base(Child)
  #   attribute :age
  #
  #   has_one :address, AddressSerializer
  #   has_one :dipper, ChildSerializer
  # end
  #
  # class ModelSerializer < Serializer::Base(Model)
  #   attribute :name
  #   attribute :own_field
  #
  #   has_many :children, ChildSerializer
  #
  #   def own_field
  #     12
  #   end
  # end
  #
  # ModelSerializer.new(object).serialize(
  #   except: [:own_field],
  #   includes: {
  #     :children => {:address => nil, :dipper => [:address]},
  #   },
  #   meta: {:page => 0}
  # )
  # ```
  #
  # Example above produces next output (this one is made to be readable -
  # real one has no newlines and indentations):
  #
  # ```json
  # {
  #   "data":{
  #     "name":"test",
  #     "children":[
  #       {
  #         "age":60,
  #         "address":null,
  #         "dipper":{
  #           "age":20,
  #           "address":{
  #             "street":"some street"
  #           }
  #         }
  #       }
  #     ]
  #   },
  #   "meta":{
  #     "page":0
  #   }
  # }
  # ```
  #
  # For a details about DSL specification or serialization API see `DSL` and `Serializable`.
  #
  # ## Inheritance
  #
  # You can DRY your serializers by inheritance - just add required attributes and/or associations in
  # the subclasses.
  #
  # ```
  # class UserSerializer < Serializer::Base(User)
  #   attributes :name, :age
  # end
  #
  # class FullUserSerializer < UserSerializer
  #   attributes :email, :created_at
  #
  #   has_many :identities, IdentitySerializer
  # end
  # ```
  abstract class Base(T) < Serializable
    include DSL

    # :nodoc:
    macro define_serialization
      {% if !@type.has_constant?("ATTRIBUTES") %}
        # :nodoc:
        ATTRIBUTES = {} of Nil => Nil
      {% end %}

      {% if !@type.has_constant?("RELATIONS") %}
        # :nodoc:
        RELATIONS = {} of Nil => Nil
      {% end %}

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
                  key = key_transform("{{props[:key].id}}", opts)
                  io << "\"#{key}\":" << {{target.id}}.{{name.id}}.to_json
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
                  key = key_transform("{{props[:key].id}}", opts)
                  io << "\"#{key}\":"
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
    def key_transform(string, opts)
      return string if string.nil?
      string = string.as(String)
      # not the best code
      if opts && opts.has_key?(:key_transform)
        case opts[:key_transform]
        when "camelcase_down"
          string.camelcase(lower: true)
        when "camelcase_up"
          string.camelcase
        when "upcase"
          string.upcase
        when "downcase"
          string.downcase
        when "underscore"
          string.underscore
        else
          string
        end
      else
        string
      end
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
      io << "["
      collection.each_with_index do |object, index|
        io << "," if index != 0
        _serialize(object, io, except, includes, opts)
      end
      io << "]"
    end

    # :nodoc:
    def render_root(io : IO, except : Array, includes : Array | Hash, opts : Hash?, meta)
      root_key = (opts && opts.has_key?(:root_key)) ? opts[:root_key] : self.class.root_key
      key = key_transform(root_key, opts)
      io << "{\"" << key << "\":"
      _serialize(@target, io, except, includes, opts)
      default_meta = self.class.meta(opts)
      metas = {} of String => MetaAny
      default_meta.each do |k,v|
        metas[key_transform(k.to_s, opts)] = v
      end
      unless meta.nil?
        meta.each do |key, value|
          metas[key_transform(key.to_s, opts)] = value
        end
      end

      io << ",\"#{ key_transform("meta", opts)}\":" << metas.to_json unless metas.empty?
      io << "}"
    end
  end
end
