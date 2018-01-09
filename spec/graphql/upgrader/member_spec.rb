# frozen_string_literal: true

require "spec_helper"
require './lib/graphql/upgrader/member.rb'

describe GraphQL::Upgrader::Member do
  def upgrade(old)
    GraphQL::Upgrader::Member.new(old).upgrade
  end

  describe 'field arguments' do
    it 'upgrades' do
      old = %{argument :status, !TodoStatus, "Restrict items to this status"}
      new = %{argument :status, TodoStatus, "Restrict items to this status", required: true}

      assert_equal new, upgrade(old)
    end
  end

  it 'upgrades the property definition to method' do
    old = %{field :name, String, property: :name}
    new = %{field :name, String, method: :name, null: true}

    assert_equal new, upgrade(old)
  end

  it 'upgrades the property definition in a block to method' do
    old = %{field :name, String do\n  property :name\nend}
    new = %{field :name, String, method: :name, null: true}
    assert_equal new, upgrade(old)
  end

  describe 'name' do
    it 'removes the name field if it can be inferred from the class' do
      old = %{
        UserType = GraphQL::ObjectType.define do
          name "User"
        end
      }
      new = %{
        class UserType < Types::BaseObject
        end
      }
      assert_equal new, upgrade(old)
    end

    it 'removes the name field if it can be inferred from the class and under a module' do
      old = %{
        Types::UserType = GraphQL::ObjectType.define do
          name "User"
        end
      }
      new = %{
        class Types::UserType < Types::BaseObject
        end
      }
      assert_equal new, upgrade(old)
    end

    it 'upgrades the name into graphql_name if it can\'t be inferred from the class' do
      old = %{
        TeamType = GraphQL::ObjectType.define do
          name "User"
        end
      }
      new = %{
        class TeamType < Types::BaseObject
          graphql_name "User"
        end
      }
      assert_equal new, upgrade(old)

      old = %{
        UserInterface = GraphQL::InterfaceType.define do
          name "User"
        end
      }
      new = %{
        class UserInterface < Types::BaseInterface
          graphql_name "User"
        end
      }
      assert_equal new, upgrade(old)

      old = %{
        UserEnum = GraphQL::EnumType.define do
          name "User"
        end
      }
      new = %{
        class UserEnum < Types::BaseEnum
          graphql_name "User"
        end
      }
      assert_equal new, upgrade(old)
    end
  end

  describe 'definition' do
    it 'upgrades the .define into class based definition' do
      old = %{UserType = GraphQL::ObjectType.define do
      end}
      new = %{class UserType < Types::BaseObject
      end}
      assert_equal new, upgrade(old)

      old = %{UserInterface = GraphQL::InterfaceType.define do
      end}
      new = %{class UserInterface < Types::BaseInterface
      end}
      assert_equal new, upgrade(old)

      old = %{UserUnion = GraphQL::UnionType.define do
      end}
      new = %{class UserUnion < Types::BaseUnion
      end}
      assert_equal new, upgrade(old)

      old = %{UserEnum = GraphQL::EnumType.define do
      end}
      new = %{class UserEnum < Types::BaseEnum
      end}
      assert_equal new, upgrade(old)

      old = %{UserInput = GraphQL::InputObjectType.define do
      end}
      new = %{class UserInput < Types::BaseInputObject
      end}
      assert_equal new, upgrade(old)

      old = %{UserScalar = GraphQL::ScalarType.define do
      end}
      new = %{class UserScalar < Types::BaseScalar
      end}
      assert_equal new, upgrade(old)
    end

    it 'upgrades including the module' do
      old = %{Module::UserType = GraphQL::ObjectType.define do
      end}
      new = %{class Module::UserType < Types::BaseObject
      end}
      assert_equal new, upgrade(old)
    end
  end

  describe 'fields' do
    it 'underscorizes field name' do
      old = %{field :firstName, !types.String}
      new = %{field :first_name, String, null: false}
      assert_equal new, upgrade(old)
    end

    it 'converts resolve proc to method' do
      old = %{
        field :firstName, !types.String do
          resolve ->(obj, arg, ctx) {
            ctx.something
            obj[ctx] + obj
            obj.given_name
          }
        end
      }
      new = %{
        field :first_name, String, null: false

        def first_name
          @context.something
          @object[@context] + @object
          @object.given_name
        end
      }
      assert_equal new, upgrade(old)
    end


    it 'upgrades to the new definition' do
      old = %{field :name, !types.String}
      new = %{field :name, String, null: false}
      assert_equal new, upgrade(old)

      old = %{field :name, !types.String, "description", method: :name}
      new = %{field :name, String, "description", method: :name, null: false}
      assert_equal new, upgrade(old)

      old = %{field :name, -> { !types.String }}
      new = %{field :name, -> { String }, null: false}
      assert_equal new, upgrade(old)

      old = %{connection :name, Name.connection_type, "names"}
      new = %{field :name, Name.connection_type, "names", null: true, connection: true}
      assert_equal new, upgrade(old)

      old = %{connection :name, !Name.connection_type, "names"}
      new = %{field :name, Name.connection_type, "names", null: false, connection: true}
      assert_equal new, upgrade(old)

      old = %{field :names, types[types.String]}
      new = %{field :names, [String], null: true}
      assert_equal new, upgrade(old)

      old = %{field :names, !types[types.String]}
      new = %{field :names, [String], null: false}
      assert_equal new, upgrade(old)

      old = %{
        field :name, types.String do
        end
      }
      new = %{
        field :name, String, null: true
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name, !types.String do
          description "abc"
        end

        field :name2, !types.Int do
          description "def"
        end
      }
      new = %{
        field :name, String, description: "abc", null: false

        field :name2, Integer, description: "def", null: false
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name, -> { !types.String } do
        end
      }
      new = %{
        field :name, -> { String }, null: false
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name do
          type -> { String }
        end
      }
      new = %{
        field :name, -> { String }, null: true
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name do
          type !String
        end

        field :name2 do
          type !String
        end
      }
      new = %{
        field :name, String, null: false

        field :name2, String, null: false
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name, -> { types.String },
          "newline description" do
        end
      }
      new = %{
        field :name, -> { String }, "newline description", null: true
      }
      assert_equal new, upgrade(old)

      old = %{
        field :name, -> { !types.String },
          "newline description" do
        end
      }
      new = %{
        field :name, -> { String }, "newline description", null: false
      }
      assert_equal new, upgrade(old)

      old = %{
       field :name, String,
         field: SomeField do
       end
      }
      new = %{
       field :name, String, field: SomeField, null: true
      }
      assert_equal new, upgrade(old)
    end
  end

  describe 'multi-line field with property/method' do
    it 'upgrades without breaking syntax' do
      old = %{
        field :is_example_field, types.Boolean,
          property: :example_field?
      }
      new = %{
        field :is_example_field, Boolean, null: true
          method: :example_field?
      }

      assert_equal new, upgrade(old)
    end
  end

  describe 'multi-line connection with property/method' do
    it 'upgrades without breaking syntax' do
      old = %{
        connection :example_connection, -> { ExampleConnectionType },
          property: :example_connections
      }
      new = %{
        field :example_connection, -> { ExampleConnectionType }, null: true, connection: true
          method: :example_connections
      }

      assert_equal new, upgrade(old)
    end
  end

  describe 'input_field' do
    it 'upgrades to argument' do
      old = %{input_field :id, !types.ID}
      new = %{argument :id, ID, required: true}
      assert_equal new, upgrade(old)
    end
  end

  describe 'implements' do
    it 'upgrades interfaces to implements' do
      old = %{
        interfaces [Types::SearchableType, Types::CommentableType]
        interfaces [Types::ShareableType]
      }
      new = %{
        implements Types::SearchableType
        implements Types::CommentableType
        implements Types::ShareableType
      }
      assert_equal new, upgrade(old)
    end
  end

  describe "fixtures" do
    original_files = Dir.glob("spec/fixtures/upgrader/*.original.rb")
    original_files.each do |original_file|
      transformed_file = original_file.sub(".original.", ".transformed.")
      it "transforms #{original_file} -> #{transformed_file}" do
        original_text = File.read(original_file)
        expected_text = File.read(transformed_file)
        transformed_text = upgrade(original_text)
        assert_equal(expected_text, transformed_text)
      end
    end
  end
end