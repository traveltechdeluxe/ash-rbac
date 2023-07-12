defmodule AshRbacTest do
  use ExUnit.Case, async: true

  alias PolicyTestSupport.{Api, ChildResource, RootResource}

  @bypass_role :admin
  @user_role :user

  setup do
    root_resource = Api.create!(Ash.Changeset.for_create(RootResource, :create))

    child_resource =
      Api.create!(Ash.Changeset.for_create(ChildResource, :create, %{root_id: root_resource.id}))

    [root_resource: root_resource, child_resource: child_resource]
  end

  @tag :unit
  test "can select all attributes/relationships/calculations/aggregates in allow list", _ do
    assert {
             :ok,
             [_]
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:child, :number, :children])
             |> Api.read(actor: %{roles: [@user_role]})
  end

  @tag :unit
  test "cannot select a attribute/relationship/calculation/aggregate not allow list", _ do
    # not specifying select is the same as selecting everything
    assert {
             :ok,
             [
               %PolicyTestSupport.RootResource{
                 admin_only_number: %Ash.NotLoaded{},
                 number: %Ash.NotLoaded{},
                 admin_only_children: %Ash.NotLoaded{},
                 children: %Ash.NotLoaded{},
                 admin_only_child: %Ash.NotLoaded{},
                 child: %Ash.NotLoaded{},
                 __meta__: %Ecto.Schema.Metadata{},
                 updated_at: %Ash.ForbiddenField{field: :updated_at, type: :attribute},
                 created_at: %Ash.ForbiddenField{field: :created_at, type: :attribute},
                 id: _,
                 admin_only: %Ash.ForbiddenField{field: :admin_only, type: :attribute},
                 aggregates: %{},
                 calculations: %{
                   {:__ash_fields_are_visible__, [:admin_only]} => false,
                   {:__ash_fields_are_visible__, [:created_at]} => false,
                   {:__ash_fields_are_visible__, [:created_by]} => false,
                   {:__ash_fields_are_visible__, [:updated_at]} => false,
                   {:__ash_fields_are_visible__, [:updated_by]} => false
                 },
                 __order__: nil
               }
             ]
           } =
             RootResource
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden field
    assert {
             :error,
             %Ash.Error.Forbidden{}
           } =
             RootResource
             |> Ash.Query.select([:admin_only])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden relationship
    assert {
             :error,
             %Ash.Error.Forbidden{}
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_child])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden calculation
    assert {
             :error,
             %Ash.Error.Forbidden{}
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_number])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden aggregate
    assert {
             :error,
             %Ash.Error.Forbidden{}
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_children])
             |> Api.read(actor: %{roles: [@user_role]})
  end

  @tag :unit
  test "bypass role can select everything", _ do
    assert {
             :ok,
             [_]
           } =
             RootResource
             |> Api.read(actor: %{roles: [@bypass_role]})
  end
end
